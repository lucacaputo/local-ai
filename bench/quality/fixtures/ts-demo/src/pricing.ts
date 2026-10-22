export interface Item { name: string; price: number; qty: number }

export function calcTotal(items: Item[]): number {
  return items.reduce((sum, i) => sum + i.price * i.qty, 0);
}
