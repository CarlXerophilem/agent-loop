// Shared types for the preference advisor (suggestion provider only).
// See ../../references/preference-advisor.md for the design and safety rails.

// Feature vector is aligned, position-by-position, to FEATURE_NAMES.
export const FEATURE_NAMES = [
  "is_doc",
  "is_robustness",
  "is_test",
  "small",
  "area_hooks",
  "area_templates",
  "touches_gate", // edits to smoke/governance -- the advisor should *down*weight, never reward
] as const;

export type FeatureVec = number[]; // length === FEATURE_NAMES.length, values typically 0/1

export type Outcome = "merged" | "edited" | "closed";

export interface Candidate {
  id: string;
  title: string;
  area: string; // e.g. "hooks", "templates", "references"
  type: string; // e.g. "doc" | "robustness" | "test"
  features: FeatureVec;
}

// A single observed pairwise preference (the "choice difference").
export interface Preference {
  winner: FeatureVec;
  loser: FeatureVec;
}

export interface RankedItem {
  id: string;
  score: number;
  rationale: string;
}

// The advisor only ever returns one of these. It never acts.
export interface Suggestion {
  phase: "brainstorm" | "selection" | "final-review";
  ranking: RankedItem[];
  confidence: number; // 0..1
  abstain: boolean; // true => "no strong signal; defer to the rubric / human"
  note: string;
}
