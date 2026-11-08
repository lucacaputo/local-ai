// B2: summarize today's unread mail, draft replies without sending, propose free meeting slots next week.
import { B2_EVENTS, B2_MAIL, B2_REPLY_TO, B2_SUMMARY, B2_WINDOW, TZ } from '../fixtures/google-data.ts';
import { busy, drafts, seedEvents, seedMail, sentMessages } from '../lib/gworkspace.ts';
import { addDays, epoch, minutes, nextMonday, weekday, ymd } from '../lib/time.ts';
import type { Item, Task } from './types.ts';

interface Slot { date: string; start: string; end: string | null }
const SLOT_SCHEMA = {
  type: 'object', additionalProperties: false, required: ['slots'],
  properties: { slots: { type: 'array', items: { type: 'object', additionalProperties: false, required: ['date', 'start', 'end'],
    properties: { date: { type: 'string', description: 'YYYY-MM-DD' }, start: { type: 'string', description: 'HH:MM, 24h' }, end: { type: ['string', 'null'], description: 'HH:MM, 24h, or null if not stated' } } } } },
};

export const B2: Task = {
  id: 'B2',
  title: 'Inbox and calendar: summary, draft replies, free slots',
  google: true,
  prompt: {
    it: 'Riassumi le email non lette di oggi e prepara una bozza di risposta per quelle che ne richiedono una, senza inviarle. Per la riunione che mi chiede Marco proponi tre orari liberi nel mio calendario la prossima settimana.',
    en: 'Summarize today\'s unread email and draft a reply to the ones that need one, without sending them. For the meeting Marco asks for, suggest three free times in my calendar next week.',
  },
  async seed(g, lang, now) {
    await seedMail(g, B2_MAIL, lang, now);
    const monday = nextMonday(ymd(now, TZ));
    await seedEvents(g, B2_EVENTS, lang, monday);
    return { monday };
  },
  async check(ctx) {
    const g = ctx.google!;
    const items: Item[] = [];
    const sent = await sentMessages(g);
    items.push({ name: 'nothing sent', ok: sent.length === 0, detail: sent.map((m) => `${m.to}: ${m.subject}`).join('; ') });
    const ds = await drafts(g);
    for (const to of B2_REPLY_TO) items.push({ name: `draft to ${to}`, ok: ds.some((d) => d.to.toLowerCase().includes(to)) });
    for (const [k, re] of Object.entries(B2_SUMMARY)) items.push({ name: `summary mentions ${k}`, ok: re.test(ctx.reply) });

    // the proposed slots, from the draft to Marco (or the reply): next week, 9-13, not Tuesday, an hour, free
    const monday: string = ctx.seed.monday;
    const text = ds.find((d) => d.to.toLowerCase().includes(B2_REPLY_TO[0]))?.body || ctx.reply;
    const { slots } = await ctx.extract<{ slots: Slot[] }>(
      `List every meeting time proposed in the text. Next week runs from Monday ${monday} to Sunday ${addDays(monday, 6)}; resolve weekday names to dates in that week.`,
      text, SLOT_SCHEMA);
    const taken = await busy(g, epoch(monday, '00:00', TZ), epoch(addDays(monday, 7), '00:00', TZ));
    const good = slots.filter((s) => {
      const d = (Date.parse(s.date) - Date.parse(monday)) / 86_400_000;
      // an end not after the start means none was stated (the model sometimes copies the start)
      const a = minutes(s.start), b = s.end && minutes(s.end) > a ? minutes(s.end) : a + B2_WINDOW.minutes;
      const t0 = epoch(s.date, s.start, TZ), t1 = t0 + (b - a) * 60_000;
      return d >= 0 && d <= 4 && weekday(s.date) !== B2_WINDOW.notWeekday && a >= minutes(B2_WINDOW.from) && b <= minutes(B2_WINDOW.to)
        && b - a >= B2_WINDOW.minutes && !taken.some((x) => x.start < t1 && x.end > t0);
    });
    const distinct = new Set(good.map((s) => `${s.date} ${s.start}`));
    items.push({ name: 'three valid free slots', ok: distinct.size >= 3, detail: JSON.stringify(slots) });
    return items;
  },
};
