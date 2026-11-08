// B4: clean a Google Sheet, add a summary tab, file PDFs in Drive folders by client.
import { invoice, invoiceFile } from '../fixtures/documents.ts';
import { B4_HEADER, B4_INVOICES, B4_MESSY, B4_ORDERS, B4_SHEET_TITLE, B4_TAB, CLIENTS, CLIENT_KEY } from '../fixtures/google-data.ts';
import { FOLDER, createSheet, files, sheetTabs, upload } from '../lib/gworkspace.ts';
import { daySerial, has } from './text.ts';
import type { Item, Task } from './types.ts';

const total = (c: string) => Math.round(B4_ORDERS.filter((o) => o.client === c).reduce((a, o) => a + o.amount, 0) * 100) / 100;
const isEmpty = (r: unknown[]) => r.every((c) => c === '' || c === null || c === undefined);

export const B4: Task = {
  id: 'B4',
  title: 'Clean a Sheet, add a summary tab, file PDFs by client',
  google: true,
  prompt: {
    it: `Nel mio Drive c'è il foglio "${B4_SHEET_TITLE.it}". Puliscilo: togli righe vuote e duplicati, metti le date come date e gli importi come numeri, e scrivi i nomi dei clienti tutti allo stesso modo. Aggiungi una scheda "Riepilogo" con il totale degli importi per cliente. Poi sposta i PDF da documento_01 a documento_06 in una cartella per cliente, in base al cliente indicato in ciascuna fattura.`,
    en: `There is a sheet called "${B4_SHEET_TITLE.en}" in my Drive. Clean it up: remove empty and duplicate rows, make dates real dates and amounts numbers, and write each client's name the same way everywhere. Add a "Summary" tab with the total amount per client. Then move the PDFs documento_01 to documento_06 into one folder per client, based on the client named in each invoice.`,
  },
  async seed(g, lang) {
    const rows = [B4_HEADER[lang], ...B4_MESSY[lang].map(([i, date, client, amount]) =>
      i < 0 ? ['', '', '', '', ''] : [date, client, B4_ORDERS[i].product, String(B4_ORDERS[i].qty), amount])];
    const sheet = await createSheet(g, B4_SHEET_TITLE[lang], B4_TAB[lang], rows, lang === 'it' ? 'it_IT' : 'en_GB');
    const pdfs: string[] = [];
    for (let i = 0; i < B4_INVOICES.length; i++) pdfs.push(await upload(g, invoiceFile(i), 'application/pdf', invoice(i, lang)));
    return { sheet, pdfs };
  },
  async check(ctx) {
    const g = ctx.google!;
    const items: Item[] = [];
    const tabs = await sheetTabs(g, ctx.seed.sheet);
    const data = tabs.find((t) => t.title === B4_TAB[ctx.lang]) ?? tabs[0];
    const rows = data.values.slice(1).filter((r) => !isEmpty(r));
    items.push({ name: `${B4_ORDERS.length} data rows, no empty or duplicate rows`, ok: rows.length === B4_ORDERS.length, detail: `${rows.length} rows` });
    // each order: a row with the date as a date (serial number), the quantity and the amount as numbers
    const missing = B4_ORDERS.filter((o) => !rows.some((r) => r[0] === daySerial(o.date) && Number(r[3]) === o.qty && typeof r[4] === 'number' && Math.abs(r[4] - o.amount) < 0.005));
    items.push({ name: 'every order with a real date and numeric amount', ok: missing.length === 0, detail: missing.map((o) => `${o.date} ${o.client} ${o.amount}`).join('; ') });
    // one spelling per client, trimmed, not all upper or lower case
    const spellings = CLIENTS.map((c) => [...new Set(rows.map((r) => String(r[1])).filter((s) => CLIENT_KEY[c].test(s)))]);
    const consistent = spellings.every((s) => s.length === 1 && s[0] === s[0].trim() && s[0] !== s[0].toUpperCase() && s[0] !== s[0].toLowerCase());
    items.push({ name: 'client names consistent', ok: consistent, detail: JSON.stringify(spellings) });
    // summary: another tab with a row per client holding its total
    const others = tabs.filter((t) => t !== data);
    for (const c of CLIENTS) {
      const ok = others.some((t) => t.values.some((r) => r.some((v) => CLIENT_KEY[c].test(String(v))) && r.some((v) => (typeof v === 'number' ? Math.abs(v - total(c)) < 0.011 : has(String(v), total(c), 0.011)))));
      items.push({ name: `summary total ${c} = ${total(c)}`, ok });
    }
    // each invoice inside a folder named after its client
    const all = await files(g);
    const byId = new Map(all.map((f) => [f.id, f]));
    const misplaced = B4_INVOICES.filter((inv, i) => {
      const f = byId.get(ctx.seed.pdfs[i]);
      return !f || f.trashed || !(f.parents ?? []).some((p) => byId.get(p)?.mimeType === FOLDER && CLIENT_KEY[inv.client].test(byId.get(p)!.name));
    });
    items.push({ name: 'PDFs filed by client', ok: misplaced.length === 0, detail: misplaced.map((m) => m.no).join(', ') });
    return items;
  },
};
