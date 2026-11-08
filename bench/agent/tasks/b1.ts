// B1: research three supplier sites and write a comparison table in a new Google Doc.
import { CHAIR, SUPPLIERS, VAT } from '../fixtures/web-data.ts';
import { DOC, docTables, files } from '../lib/gworkspace.ts';
import { has, nums, squash } from './text.ts';
import type { Item, Task } from './types.ts';

const urls = (lang: string) => SUPPLIERS.map((s) => `http://${s.host}/${lang}/`);

export const B1: Task = {
  id: 'B1',
  title: 'Research three suppliers, table in a new Google Doc',
  sites: true,
  google: true,
  prompt: {
    it: `Confronta la sedia ${CHAIR} su questi tre siti: ${urls('it').join(', ')}. Per ognuno trova il prezzo IVA inclusa, i tempi di consegna e gli anni di garanzia. Poi crea un nuovo Google Doc "Confronto sedie ${CHAIR}" con una tabella, una riga per fornitore.`,
    en: `Compare the ${CHAIR} chair on these three sites: ${urls('en').join(', ')}. For each one find the price including VAT, the delivery time and the years of warranty. Then create a new Google Doc "${CHAIR} chair comparison" with a table, one row per supplier.`,
  },
  seed: async () => ({}),
  async check(ctx) {
    const g = ctx.google!;
    const docs = (await files(g)).filter((f) => f.mimeType === DOC && !f.trashed && Date.parse(f.createdTime) >= ctx.started);
    const items: Item[] = [{ name: 'new Google Doc', ok: docs.length > 0, detail: docs.map((d) => d.name).join(', ') }];
    const rows = (await Promise.all(docs.map((d) => docTables(g, d.id)))).flat(2).map((r) => r.join(' | '));
    for (const s of SUPPLIERS) {
      const row = rows.find((r) => squash(r).includes(squash(s.name)));
      const prices = s.vatExcluded ? [Math.round(s.price * (1 + VAT) * 100) / 100]
        : s.discountPct ? [s.price, Math.round(s.price * (100 - s.discountPct)) / 100] : [s.price];
      const delivery = s.deliveryDays === '2' ? [2, 48] : s.deliveryDays.split('-').map(Number);
      const ok = !!row && prices.some((p) => has(row, p, 0.011)) && delivery.some((d) => nums(row).includes(d)) && nums(row).includes(s.warrantyYears);
      items.push({ name: `row ${s.name}: price ${prices.join(' or ')}, delivery ${s.deliveryDays}, warranty ${s.warrantyYears}`, ok, detail: row ?? 'no row' });
    }
    return items;
  },
};
