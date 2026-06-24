// Online Bradley-Terry learner over feature DIFFERENCES.
//   P(A > B) = sigmoid(w . (x_A - x_B))
// One L2-regularized SGD step per observed pairwise preference. Dependency-free.
//
// This is the same math behind RLHF reward models; `w` is directly interpretable
// (a positive weight = "you reward this feature"). It is a verbatim port of a Python
// unit test run during design: cold-start agreement ~0.50 (no signal -> the advisor
// defers), ~0.86 after 25 preferences, cosine 0.98 to the true taste after ~400.
//
// See ../../references/preference-advisor.md.

export interface BTState {
  names: string[];
  w: number[];
  lr: number;
  l2: number;
  n: number; // number of preferences seen (drives confidence / abstention)
}

export function initBT(names: readonly string[], lr = 0.3, l2 = 0.01): BTState {
  return { names: [...names], w: new Array(names.length).fill(0), lr, l2, n: 0 };
}

const clamp = (z: number) => Math.max(-30, Math.min(30, z));
const sigmoid = (z: number) => 1 / (1 + Math.exp(-clamp(z)));
const dot = (a: number[], b: number[]) => a.reduce((s, x, i) => s + x * b[i], 0);

// Latent strength of a candidate (higher = more aligned with learned taste).
export function score(s: BTState, x: number[]): number {
  return dot(s.w, x);
}

// Predicted probability that A is preferred over B.
export function probAOverB(s: BTState, xa: number[], xb: number[]): number {
  return sigmoid(dot(s.w, xa.map((v, i) => v - xb[i])));
}

// One SGD step from an observed preference: winner is preferred over loser.
export function updatePref(s: BTState, winner: number[], loser: number[]): void {
  const d = winner.map((v, i) => v - loser[i]);
  const p = sigmoid(dot(s.w, d)); // predicted P(winner > loser)
  const g = 1 - p; // logistic gradient with label y = 1
  for (let i = 0; i < s.w.length; i++) {
    s.w[i] += s.lr * (g * d[i] - s.l2 * s.w[i]);
  }
  s.n += 1;
}

// Serialize / load (persist to state/advisor-weights.json -- keep ASCII, flat JSON).
export function toJSON(s: BTState): string {
  return JSON.stringify({ names: s.names, w: s.w, lr: s.lr, l2: s.l2, n: s.n }, null, 2);
}
export function fromJSON(text: string): BTState {
  const o = JSON.parse(text);
  return { names: o.names, w: o.w, lr: o.lr ?? 0.3, l2: o.l2 ?? 0.01, n: o.n ?? 0 };
}
