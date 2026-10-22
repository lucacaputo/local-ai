import { test } from "node:test";
import assert from "node:assert/strict";
import { calcTotal } from "../src/pricing.ts";
import { summary } from "../src/report.ts";

test("calcTotal sums price * qty", () => {
  assert.equal(calcTotal([{ name: "a", price: 2, qty: 3 }, { name: "b", price: 1, qty: 1 }]), 7);
});

test("summary formats total", () => {
  assert.equal(summary([{ name: "a", price: 2.5, qty: 2 }]), "1 items, total 5.00");
});
