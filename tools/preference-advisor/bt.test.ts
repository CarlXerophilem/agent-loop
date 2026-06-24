// Convergence test for the online Bradley-Terry learner (mirror of the Python
// design-time check). Run with Node's native TS + test runner:
//   node --test bt.test.ts
import { test } from "node:test";
import assert from "node:assert/strict";
import { initBT, updatePref, score } from "./bt.ts";

// Small deterministic PRNG so the test is reproducible (mulberry32).
function rng(seed: number) {
  let a = seed >>> 0;
  return () => {
    a |= 0; a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
const D = 6;
const wTrue = [2.0, 1.2, 0.8, 1.5, -0.5, -1.0];
const dot = (a: number[], b: number[]) => a.reduce((s, x, i) => s + x * b[i], 0);
const sig = (z: number) => 1 / (1 + Math.exp(-Math.max(-30, Math.min(30, z))));

function agreement(w: number[], rand: () => number, n = 2000) {
  let ok = 0;
  for (let i = 0; i < n; i++) {
    const a = Array.from({ length: D }, () => (rand() < 0.5 ? 0 : 1));
    const b = Array.from({ length: D }, () => (rand() < 0.5 ? 0 : 1));
    if (dot(w, a) > dot(w, b) === dot(wTrue, a) > dot(wTrue, b)) ok++;
  }
  return ok / n;
}

test("cold start abstains (agreement ~ 0.5 with zero weights)", () => {
  const s = initBT(["f0", "f1", "f2", "f3", "f4", "f5"]);
  const ag = agreement(s.w, rng(1));
  assert.ok(Math.abs(ag - 0.5) < 0.08, `cold-start agreement ${ag} should be ~0.5`);
});

test("learns fast from sparse pairwise preferences", () => {
  const rand = rng(7);
  const s = initBT(["f0", "f1", "f2", "f3", "f4", "f5"]);
  const item = () => Array.from({ length: D }, () => (rand() < 0.5 ? 0 : 1));
  for (let t = 0; t < 25; t++) {
    const a = item(), b = item();
    const aWins = rand() < sig(dot(wTrue, a.map((v, i) => v - b[i])));
    if (aWins) updatePref(s, a, b); else updatePref(s, b, a);
  }
  const ag = agreement(s.w, rng(99));
  assert.ok(ag > 0.8, `agreement after 25 prefs was ${ag}, expected > 0.8`);
});

test("score orders candidates by learned taste", () => {
  const s = initBT(["f0", "f1", "f2", "f3", "f4", "f5"]);
  s.w = [...wTrue]; // pretend fully trained
  const docSmall = [1, 0, 0, 1, 1, 0];
  const bigTemplate = [0, 0, 0, 0, 0, 1];
  assert.ok(score(s, docSmall) > score(s, bigTemplate));
});
