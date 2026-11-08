// The user's own tasks (TASK-040 AC6, 2026-11-08): time-off requests into a Sheet, a conference trip for three,
// and the week's meetings.
import { TZ, U1_EXPECTED, U1_MAIL, U1_NOT, U3_EVENTS, U3_MUST, U3_MUST_NOT } from '../fixtures/google-data.ts';
import { BEST, CONF, FLIGHTS_HOST, HOTELS_HOST } from '../fixtures/web-data.ts';
import { SHEET, files, seedEvents, seedMail, sheetTabs } from '../lib/gworkspace.ts';
import { ymd } from '../lib/time.ts';
import { monthDay, squash } from './text.ts';
import type { Item, Task } from './types.ts';

export const U1: Task = {
  id: 'U1',
  title: 'Sheet of employees\' time-off requests from email',
  google: true,
  prompt: {
    it: 'Crea un Google Sheet "Ferie dicembre" con i dipendenti e le loro richieste di ferie e permessi che trovi nella mia email: nome, primo giorno, ultimo giorno e tipo (ferie o permesso).',
    en: 'Create a Google Sheet "December time off" with the employees and the holiday and day-off requests you find in my email: name, first day, last day and type (holiday or day off).',
  },
  async seed(g, lang, now) {
    await seedMail(g, U1_MAIL, lang, now);
    return {};
  },
  async check(ctx) {
    const g = ctx.google!;
    const sheets = (await files(g)).filter((f) => f.mimeType === SHEET && !f.trashed && Date.parse(f.createdTime) >= ctx.started);
    const items: Item[] = [{ name: 'new Google Sheet', ok: sheets.length > 0, detail: sheets.map((s) => s.name).join(', ') }];
    const rows = (await Promise.all(sheets.map((s) => sheetTabs(g, s.id)))).flat().flatMap((t) => t.values);
    const dated = rows.map((r) => ({ text: r.map(String).join(' | '), days: r.map(monthDay).filter((d): d is string => !!d) })).filter((r) => r.days.length > 0);
    for (const e of U1_EXPECTED) {
      const mine = dated.filter((r) => e.who.test(r.text) && !/annullat|cancel/i.test(r.text));   // a cancelled request may stay, marked
      const ok = mine.length === 1 && mine[0].days[0] === e.first && (mine[0].days[1] ?? mine[0].days[0]) === e.last;
      items.push({ name: `one row ${e.who.source}: ${e.first} to ${e.last}`, ok, detail: mine.map((r) => r.text).join(' / ') || 'no row' });
    }
    const extra = dated.filter((r) => U1_NOT.test(r.text));
    items.push({ name: 'no rows for non-employees', ok: extra.length === 0, detail: extra.map((r) => r.text).join(' / ') });
    return items;
  },
};

export const U2: Task = {
  id: 'U2',
  title: 'Flights and a hotel near the venue for three, no booking',
  sites: true,
  prompt: {
    it: `Siamo in 3 e partiamo da Milano per la ${CONF.name} (http://${CONF.host}/it/). Su http://${FLIGHTS_HOST}/it/ cerca i voli diretti più economici per arrivare il giorno prima dell'inizio e tornare la sera dell'ultimo giorno, dopo la chiusura. Su http://${HOTELS_HOST}/it/ trova l'hotel più economico entro 1 km dalla sede, con posto per tutti e 3 per tutte le notti. Non prenotare niente: dimmi voli, hotel e costo totale.`,
    en: `Three of us are going from Milan to ${CONF.name} (http://${CONF.host}/en/). On http://${FLIGHTS_HOST}/en/ find the cheapest direct flights that arrive the day before it starts and fly back on the evening of the last day, after it closes. On http://${HOTELS_HOST}/en/ find the cheapest hotel within 1 km of the venue with room for all 3 of us for every night. Don't book anything: tell me the flights, the hotel and the total cost.`,
  },
  async check(ctx) {
    const booked = ctx.siteLog.filter((e) => (e.host === FLIGHTS_HOST || e.host === HOTELS_HOST) && e.method === 'POST');
    const r = squash(ctx.reply);
    return [
      { name: 'nothing booked', ok: booked.length === 0, detail: booked.map((b) => b.body).join('; ') },
      { name: `outbound ${BEST.outbound}`, ok: r.includes(squash(BEST.outbound)) },
      { name: `return ${BEST.back}`, ok: r.includes(squash(BEST.back)) },
      { name: BEST.hotel, ok: r.includes(squash(BEST.hotel)) },
    ];
  },
};

export const U3: Task = {
  id: 'U3',
  title: 'Summary of the next 7 days of meetings',
  google: true,
  prompt: {
    it: 'Riassumi le mie riunioni dei prossimi 7 giorni: per ognuna giorno, ora, con chi e di cosa si tratta.',
    en: 'Summarize my meetings for the next 7 days: for each one the day, the time, who with and what it is about.',
  },
  async seed(g, lang, now) {
    await seedEvents(g, U3_EVENTS, lang, ymd(now, TZ));
    return {};
  },
  async check(ctx) {
    return [
      ...U3_MUST.map((re) => ({ name: `mentions ${re.source}`, ok: re.test(ctx.reply) })),
      { name: 'leaves out past and later events', ok: !U3_MUST_NOT.test(ctx.reply), detail: U3_MUST_NOT.exec(ctx.reply)?.[0] },
    ];
  },
};
