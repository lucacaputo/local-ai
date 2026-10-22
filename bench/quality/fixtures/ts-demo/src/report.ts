import { calcTotal, type Item } from "./pricing.ts";

export function summary(items: Item[]): string {
  return `${items.length} items, total ${calcTotal(items).toFixed(2)}`;
}
