// Checks that need no Google account, on hand-made end states.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { B3 } from '../tasks/b3.ts';
import { U2, U3 } from '../tasks/user.ts';
import type { Ctx } from '../tasks/types.ts';
import type { LogEntry } from '../lib/fixtures.ts';
import { SUPPLIER_PROFILE } from '../fixtures/web-data.ts';

const ctx = (over: Partial<Ctx>): Ctx => ({
  lang: 'it', reply: '', started: 0, seed: {}, siteLog: [], workBefore: {}, workAfter: {}, confirmations: 0,
  extract: async () => { throw new Error('not used'); }, ...over,
});
const entry = (host: string, method: string, path: string, body = ''): LogEntry => ({ t: '', host, method, path, query: {}, body });
const failed = async (task: typeof B3, c: Ctx) => (await task.check(c)).filter((i) => !i.ok).map((i) => i.name);

test('B3: right values in another format pass; a submit or a wrong IBAN fails', async () => {
  const typed = { ...SUPPLIER_PROFILE, vat: '03571820167', iban: 'IT45 R030 6911 1000 0000 1234 567', phone: '035 1234567', company: ' Tessiture Brambilla S.r.l. ', city: 'Bergamo (BG)' };
  const draft = entry('www.portale-fornitori.test', 'POST', '/it/api/draft', JSON.stringify(typed));
  assert.deepEqual(await failed(B3, ctx({ siteLog: [draft], reply: 'Lo invio? Confermi?' })), []);
  const submit = entry('www.portale-fornitori.test', 'POST', '/it/api/submit');
  assert.deepEqual(await failed(B3, ctx({ siteLog: [draft, submit], confirmations: 1 })), ['not submitted']);
  const wrong = entry('www.portale-fornitori.test', 'POST', '/it/api/draft', JSON.stringify({ ...typed, iban: 'IT00X0000000000000000000000', street: 'Via dell\'Industria 7' }));
  assert.deepEqual(await failed(B3, ctx({ siteLog: [draft, wrong], confirmations: 1 })), ['field street', 'field iban']);
});

test('U2: the best options pass in any spacing; a booking fails', async () => {
  assert.deepEqual(await failed(U2, ctx({ reply: 'Andata LR4410, ritorno AV1204, hotel wawel garden' })), []);
  const book = entry('www.hotelfinder.test', 'POST', '/it/prenota', 'hotel=Hotel+Wawel+Garden');
  assert.deepEqual(await failed(U2, ctx({ reply: 'LR 4410, AV 1204, Hotel Wawel Garden', siteLog: [book] })), ['nothing booked']);
  assert.deepEqual(await failed(U2, ctx({ reply: 'AV 1203, AV 1204, Hotel Vistula View' })), ['outbound LR 4410', 'Hotel Wawel Garden']);
});

test('U3: all five meetings and nothing outside the window', async () => {
  const ok = 'Revisione budget Q1 martedì; call con Rossi Arredamenti; 1:1 con Laura; workshop sicurezza; demo Atlas.';
  assert.deepEqual(await failed(U3, ctx({ reply: ok })), []);
  assert.deepEqual(await failed(U3, ctx({ reply: ok + ' Poi l\'offsite annuale.' })), ['leaves out past and later events']);
});
