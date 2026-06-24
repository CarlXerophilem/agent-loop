// ingest.ts -- turn YOUR behavior (PR outcomes) into preferences and update the advisor.
//
// Signal source (no new instrumentation): every loop PR ends up merged / merged-after-edits /
// closed. Those outcomes are implicit pairwise preferences. This module:
//   1. reads PR outcomes (gh pr list --state merged|closed --json ...),
//   2. appends one line per proposal to state/acceptance-log.jsonl (ASCII, flat),
//   3. forms pairwise preferences (picked/merged > rejected/closed) and steps the BT learner,
//   4. asks an LLM (Reflexion) to rewrite state/preferences.md from the recent log.
//
// SCAFFOLD: the gh + LLM calls are stubbed; the deterministic preference math is real and
// reuses updatePref() from bt.ts. See ../../references/preference-advisor.md and README.md.

import { BTState, updatePref, toJSON, fromJSON } from "./bt.ts";
import { FEATURE_NAMES, type FeatureVec, type Outcome } from "./types.ts";

export interface LogEntry {
  ts: string;
  run: string;
  area: string;
  type: string;
  features: FeatureVec;
  outcome: Outcome;
}

// merged (unedited) is the strongest positive; edited-then-merged is a weak positive for the
// type; closed is negative. Build pairwise prefs within a batch: positives beat negatives.
export function preferencesFromBatch(batch: LogEntry[]): { winner: FeatureVec; loser: FeatureVec }[] {
  const pos = batch.filter((e) => e.outcome === "merged" || e.outcome === "edited");
  const neg = batch.filter((e) => e.outcome === "closed");
  const prefs: { winner: FeatureVec; loser: FeatureVec }[] = [];
  for (const w of pos) for (const l of neg) prefs.push({ winner: w.features, loser: l.features });
  return prefs;
}

// Apply a batch to the learner (deterministic; the verified core).
export function applyBatch(bt: BTState, batch: LogEntry[]): BTState {
  for (const { winner, loser } of preferencesFromBatch(batch)) updatePref(bt, winner, loser);
  return bt;
}

// --- persistence helpers (Node fs); ASCII JSON for state/ (cp936/GBK rule) ---
export async function loadState(path: string): Promise<BTState> {
  const { readFile } = await import("node:fs/promises");
  try {
    return fromJSON(await readFile(path, "utf8"));
  } catch {
    const { initBT } = await import("./bt.ts");
    return initBT(FEATURE_NAMES);
  }
}
export async function saveState(path: string, bt: BTState): Promise<void> {
  const { writeFile } = await import("node:fs/promises");
  await writeFile(path, toJSON(bt), { encoding: "ascii" });
}

// SCAFFOLD: fetch recent PR outcomes. Implement with: execFile("gh", ["pr","list",
// "--state","all","--json","number,title,state,mergedAt,closedAt,files,labels"]) then map to
// LogEntry[] (feature extraction from area/type/size). Returns [] until wired.
export async function fetchRecentOutcomes(): Promise<LogEntry[]> {
  return [];
}

// SCAFFOLD: rewrite state/preferences.md from the recent log via the Agent SDK (Reflexion).
// The "text gradient": summarize what was accepted/edited/closed and why, capped to a rubric.
export async function refreshPreferencesMd(_log: LogEntry[], _path: string): Promise<void> {
  // TODO(sdk): query({ prompt: reflexionPrompt(_log), options: { allowedTools: ["Read","Write"] } })
}
