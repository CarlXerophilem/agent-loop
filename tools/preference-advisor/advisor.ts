// PreferenceAdvisor -- SUGGESTION PROVIDER ONLY.
//
// It returns suggestions at three decision points (brainstorm / selection / final-review).
// It has NO write tools: it never edits files, never commits, never opens/merges PRs, and
// never touches the smoke suite or governance. You + references/rubric.md keep all decisions.
// Below a confidence threshold it abstains (honest cold start). See
// ../../references/preference-advisor.md.

import { BTState, score, probAOverB } from "./bt.ts";
import type { Candidate, Suggestion } from "./types.ts";

// Below this many observed preferences, there is no trustworthy signal -> abstain.
const MIN_PREFS_FOR_SIGNAL = 12;
const FULL_CONFIDENCE_AT = 50;

export class PreferenceAdvisor {
  constructor(
    private bt: BTState,
    private preferencesMd: string, // the Reflexion verbal rubric (state/preferences.md)
  ) {}

  private confidence(): number {
    return Math.max(0, Math.min(1, this.bt.n / FULL_CONFIDENCE_AT));
  }
  private hasSignal(): boolean {
    return this.bt.n >= MIN_PREFS_FOR_SIGNAL && this.bt.w.some((x) => Math.abs(x) > 1e-6);
  }

  // INITIAL (selection) phase: rank candidate choices by learned taste. Never picks.
  suggestAtSelection(cands: Candidate[]): Suggestion {
    if (!this.hasSignal()) {
      return {
        phase: "selection",
        ranking: [],
        confidence: 0,
        abstain: true,
        note: `cold start (${this.bt.n} prefs < ${MIN_PREFS_FOR_SIGNAL}); deferring to references/rubric.md.`,
      };
    }
    const ranking = cands
      .map((c) => ({ id: c.id, score: score(this.bt, c.features), rationale: this.rationale(c) }))
      .sort((a, b) => b.score - a.score);
    return {
      phase: "selection",
      ranking,
      confidence: this.confidence(),
      abstain: false,
      note: "suggestion only -- the rubric / you make the call.",
    };
  }

  // The "choice difference": which of two choices fits your taste, with a probability.
  suggestChoiceDiff(a: Candidate, b: Candidate): { prefer: string | null; p: number; abstain: boolean } {
    if (!this.hasSignal()) return { prefer: null, p: 0.5, abstain: true };
    const p = probAOverB(this.bt, a.features, b.features);
    return { prefer: p >= 0.5 ? a.id : b.id, p, abstain: false };
  }

  // BRAINSTORM phase: propose candidate choices the user is likely to value.
  // SCAFFOLD: wire to @anthropic-ai/claude-agent-sdk `query()`, seeding the prompt with
  // this.preferencesMd. The SDK returns text candidates; the caller turns them into
  // Candidate[] (feature extraction). See README.md for the demos-repo pattern. The advisor
  // proposes options; it does not choose among them.
  async suggestAtBrainstorm(_context: string): Promise<string[]> {
    // TODO(sdk): const out = query({ prompt: brainstormPrompt(this.preferencesMd, _context),
    //                                options: { allowedTools: [], permissionMode: "dontAsk" } });
    return [];
  }

  // FINAL REVIEW phase: predict whether you'll accept-as-is, edit, or close, + the expected
  // tweak. SCAFFOLD: LLM-judge over the diff, seeded by this.preferencesMd. Output is advice.
  async suggestAtFinalReview(_diff: string): Promise<{ likely: "merge" | "edit" | "close"; note: string }> {
    // TODO(sdk): LLM-judge call; until wired, abstain.
    return { likely: "edit", note: "advisor scaffold: LLM-judge not yet wired; treat as no-signal." };
  }

  // Short, interpretable rationale from the strongest contributing feature weights.
  private rationale(c: Candidate): string {
    const contribs = c.features
      .map((v, i) => ({ name: this.bt.names[i], val: v * this.bt.w[i] }))
      .filter((x) => Math.abs(x.val) > 1e-3)
      .sort((a, b) => Math.abs(b.val) - Math.abs(a.val))
      .slice(0, 2)
      .map((x) => `${x.val >= 0 ? "+" : "-"}${x.name}`);
    return contribs.length ? `learned taste: ${contribs.join(", ")}` : "no strong learned features";
  }
}
