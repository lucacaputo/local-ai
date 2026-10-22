import { calcTotal, type Item } from "./pricing.ts";

export class Cart {
  private items: Item[] = [];
  add(item: Item): void { this.items.push(item); }
  total(): number { return calcTotal(this.items); }
}
