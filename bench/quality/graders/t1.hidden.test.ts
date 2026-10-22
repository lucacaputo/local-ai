// TASK-034 T1 hidden tests: copied into the run folder after the model is done, never shown to it.
import { test } from "node:test";
import assert from "node:assert/strict";
import { calcTotal } from "../src/pricing.ts";
import { Cart } from "../src/cart.ts";

test("hidden: no discount keeps the old total", () => {
  assert.equal(calcTotal([{ name: "a", price: 2, qty: 3 }, { name: "b", price: 1, qty: 1 }]), 7);
});
test("hidden: discountPercent applies per item", () => {
  assert.equal(calcTotal([{ name: "a", price: 10, qty: 2, discountPercent: 50 }, { name: "b", price: 8, qty: 1, discountPercent: 25 }]), 16);
});
test("hidden: 0 and 100 are allowed", () => {
  assert.equal(calcTotal([{ name: "a", price: 10, qty: 2, discountPercent: 0 }]), 20);
  assert.equal(calcTotal([{ name: "a", price: 10, qty: 2, discountPercent: 100 }]), 0);
});
test("hidden: outside 0 to 100 throws RangeError", () => {
  assert.throws(() => calcTotal([{ name: "a", price: 10, qty: 1, discountPercent: 101 }]), RangeError);
  assert.throws(() => calcTotal([{ name: "a", price: 10, qty: 1, discountPercent: -1 }]), RangeError);
});
test("hidden: Cart.count sums quantities", () => {
  const c = new Cart();
  assert.equal(c.count(), 0);
  c.add({ name: "a", price: 1, qty: 3 });
  c.add({ name: "b", price: 2, qty: 4 });
  assert.equal(c.count(), 7);
});
