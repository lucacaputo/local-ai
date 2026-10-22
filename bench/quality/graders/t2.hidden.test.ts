// TASK-034 T2 hidden tests: copied into the run folder after the model is done, never shown to it.
import { test } from "node:test";
import assert from "node:assert/strict";
import { subtotal, calcTotal } from "../src/pricing.ts";
import { applyCoupon } from "../src/coupon.ts";
import { Cart } from "../src/cart.ts";
import { summary } from "../src/report.ts";

const items = [{ name: "a", price: 10, qty: 2 }, { name: "b", price: 5.5, qty: 1 }];

test("hidden: subtotal, and calcTotal still works", () => {
  assert.equal(subtotal(items), 25.5);
  assert.equal(calcTotal(items), 25.5);
});
test("hidden: SAVE10, case-insensitive, rounded", () => {
  assert.equal(applyCoupon(25.5, "SAVE10"), 22.95);
  assert.equal(applyCoupon(25.5, "save10"), 22.95);
  assert.equal(applyCoupon(10.01, "SAVE10"), 9.01);
});
test("hidden: FLAT5 never below 0", () => {
  assert.equal(applyCoupon(12, "flat5"), 7);
  assert.equal(applyCoupon(3, "FLAT5"), 0);
});
test("hidden: unknown coupon message", () => {
  assert.throws(() => applyCoupon(10, "Bogus"), { message: "unknown coupon: Bogus" });
});
test("hidden: Cart.setCoupon checks right away and total applies it", () => {
  const c = new Cart();
  assert.throws(() => c.setCoupon("NOPE"), { message: "unknown coupon: NOPE" });
  for (const i of items) c.add(i);
  assert.equal(c.total(), 25.5);
  c.setCoupon("save10");
  assert.equal(c.total(), 22.95);
});
test("hidden: summary with and without coupon", () => {
  assert.equal(summary([{ name: "a", price: 2.5, qty: 2 }]), "1 items, total 5.00");
  assert.equal(summary(items, "save10"), "2 items, total 22.95 (coupon SAVE10)");
});
