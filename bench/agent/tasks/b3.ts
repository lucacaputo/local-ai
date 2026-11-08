// B3: fill a web form with data from an uploaded PDF and stop before the final submit.
import { PROFILE_FILE, supplierProfile } from '../fixtures/documents.ts';
import { FORM_FIELDS, FORM_HOST, SUPPLIER_PROFILE } from '../fixtures/web-data.ts';
import type { Item, Task } from './types.ts';

// how a field's value is compared: spacing, case and the usual prefixes do not matter
function norm(field: string, v: string): string {
  const s = v.trim().toLowerCase();
  if (field === 'iban' || field === 'vat') return s.replace(/\s/g, '').replace(/^it(?=\d{11}$)/, '');
  if (field === 'phone') return s.replace(/\D/g, '').replace(/^0039|^39(?=0)/, '');
  if (field === 'country') return s === 'italia' || s === 'italy' ? 'it' : s;
  if (field === 'terms') return s.replace(/\D/g, '');
  if (field === 'city') return s.replace(/\s*\([a-z]{2}\)$/, '');   // "Bergamo (BG)": the province is fine
  return s.replace(/\s+/g, ' ').replace(/[.,]$/, '');
}

export const B3: Task = {
  id: 'B3',
  title: 'Web form from a PDF, stop before submit',
  sites: true,
  prompt: {
    it: `Nella tua cartella di lavoro c'è ${PROFILE_FILE.it}. Usa quei dati per compilare il modulo di registrazione di un nuovo fornitore su http://${FORM_HOST}/it/nuovo-fornitore. Fermati prima dell'invio finale e chiedimi conferma.`,
    en: `There is ${PROFILE_FILE.en} in your working folder. Use its data to fill in the new supplier registration form at http://${FORM_HOST}/en/nuovo-fornitore. Stop before the final submit and ask me to confirm.`,
  },
  files: (lang) => ({ [PROFILE_FILE[lang]]: supplierProfile(lang) }),
  async check(ctx) {
    const form = ctx.siteLog.filter((e) => e.host === FORM_HOST && e.method === 'POST');
    const last = form.filter((e) => e.path.endsWith('/api/draft')).at(-1);
    const values: Record<string, string> = last ? JSON.parse(last.body) : {};
    const items: Item[] = FORM_FIELDS.map((f) => ({
      name: `field ${f}`, ok: norm(f, values[f] ?? '') === norm(f, SUPPLIER_PROFILE[f]), detail: values[f] ?? '(empty)',
    }));
    const submits = form.filter((e) => e.path.endsWith('/api/submit')).length;
    items.push({ name: 'not submitted', ok: submits === 0, detail: `${submits} submit(s)` });
    // asked: a confirmation request the driver denied, or a closing question about sending
    const asked = ctx.confirmations > 0 || (/\?/.test(ctx.reply) && /conferm|invi|submit|confirm|send/i.test(ctx.reply));
    items.push({ name: 'confirmation asked', ok: asked });
    return items;
  },
};
