// Wipe, seed and read back the test Google account (TASK-040). Every function takes a Google client that has
// passed assertAccount(), so it only ever touches the test account.
import crypto from 'node:crypto';
import type { Google } from './google.ts';
import { addDays, epoch, ymd } from './time.ts';
import type { Event, Mail } from '../fixtures/google-data.ts';
import { TZ } from '../fixtures/google-data.ts';
import type { Lang } from '../fixtures/web-data.ts';

const GMAIL = 'https://gmail.googleapis.com/gmail/v1/users/me';
const CAL = 'https://www.googleapis.com/calendar/v3';
const DRIVE = 'https://www.googleapis.com/drive/v3';

async function pages<T>(g: Google, url: string, key: string): Promise<T[]> {
  const out: T[] = [];
  let token = '';
  do {
    const sep = url.includes('?') ? '&' : '?';
    const r = await g.call('GET', `${url}${token ? `${sep}pageToken=${token}` : ''}`);
    out.push(...((r[key] ?? []) as T[]));
    token = r.nextPageToken ?? '';
  } while (token);
  return out;
}

// ---- wipe: every message, draft, filter, event and Drive file of the test account
export async function wipe(g: Google): Promise<void> {
  await g.assertAccount();
  const msgs = await pages<{ id: string }>(g, `${GMAIL}/messages?includeSpamTrash=true&maxResults=500`, 'messages');
  for (let i = 0; i < msgs.length; i += 1000) {
    await g.call('POST', `${GMAIL}/messages/batchDelete`, { ids: msgs.slice(i, i + 1000).map((m) => m.id) });
  }
  for (const d of await pages<{ id: string }>(g, `${GMAIL}/drafts?maxResults=500`, 'drafts')) await g.call('DELETE', `${GMAIL}/drafts/${d.id}`);
  const filters = (await g.call('GET', `${GMAIL}/settings/filters`)).filter ?? [];
  for (const f of filters) await g.call('DELETE', `${GMAIL}/settings/filters/${f.id}`);
  await g.call('POST', `${CAL}/calendars/primary/clear`);
  await g.call('PATCH', `${CAL}/calendars/primary`, { timeZone: TZ });
  const files = await pages<{ id: string }>(g, `${DRIVE}/files?q=${encodeURIComponent("'me' in owners")}&fields=nextPageToken,files(id)&pageSize=1000`, 'files');
  for (const f of files) {
    // deleting a folder deletes what is inside it, so a later file may be gone already
    await g.call('DELETE', `${DRIVE}/files/${f.id}`).catch((e: Error) => { if (!/: 404 /.test(e.message)) throw e; });
  }
  await g.call('DELETE', `${DRIVE}/files/trash`);
}

// ---- mail
const b64url = (b: Uint8Array | string) => Buffer.from(b).toString('base64url');
const header = (s: string) => (/^[\x20-\x7e]*$/.test(s) ? s : `=?UTF-8?B?${Buffer.from(s).toString('base64')}?=`);

function mailTimes(mails: Mail[], now: number): number[] {
  const today = ymd(now, TZ);
  const start = epoch(today, '00:00', TZ);
  const todays = mails.filter((m) => m.when === 'today');
  return mails.map((m, i) => {
    if (m.when === 'today') {
      const k = todays.indexOf(m) + 1;
      return Math.floor(start + ((now - 60_000 - start) * k) / (todays.length + 1));
    }
    return epoch(addDays(today, -m.when), '10:00', TZ) + i * 60_000;
  });
}

export async function seedMail(g: Google, mails: Mail[], lang: Lang, now = Date.now()): Promise<Record<string, string>> {
  const times = mailTimes(mails, now);
  const order = mails.map((_, i) => i).sort((a, b) => times[a] - times[b]);   // oldest first, so a "Re:" finds its thread
  const ids: Record<string, string> = {};
  const bySubject: Record<string, { threadId: string; msgId: string }> = {};
  for (const i of order) {
    const m = mails[i];
    const subject = m.subject[lang];
    const msgId = `<${crypto.randomUUID()}@bench.test>`;
    const parent = subject.startsWith('Re: ') ? bySubject[subject.slice(4)] : undefined;
    const raw = [
      `From: ${header(m.fromName)} <${m.from}>`, `To: <${g.account}>`, `Subject: ${header(subject)}`,
      `Date: ${new Date(times[i]).toUTCString().replace('GMT', '+0000')}`, `Message-ID: ${msgId}`,
      ...(parent ? [`In-Reply-To: ${parent.msgId}`, `References: ${parent.msgId}`] : []),
      'MIME-Version: 1.0', 'Content-Type: text/plain; charset=UTF-8', 'Content-Transfer-Encoding: 8bit', '', m.body[lang].replace(/\n/g, '\r\n'), '',
    ].join('\r\n');
    const r = await g.call('POST', `${GMAIL}/messages?internalDateSource=dateHeader`, {
      raw: b64url(raw), labelIds: ['INBOX', ...(m.unread ? ['UNREAD'] : [])], ...(parent ? { threadId: parent.threadId } : {}),
    });
    ids[m.key] = r.id;
    bySubject[subject] = { threadId: r.threadId, msgId };
  }
  return ids;
}

export interface MsgInfo { id: string; threadId: string; labels: string[]; to: string; subject: string; body: string }
function bodyText(p: any): string {
  if (p.mimeType === 'text/plain' && p.body?.data) return Buffer.from(p.body.data, 'base64url').toString('utf8');
  if (p.parts) return p.parts.map(bodyText).filter(Boolean).join('\n');
  if (p.mimeType === 'text/html' && p.body?.data) return Buffer.from(p.body.data, 'base64url').toString('utf8').replace(/<[^>]+>/g, ' ');
  return '';
}
async function message(g: Google, id: string): Promise<MsgInfo> {
  const m = await g.call('GET', `${GMAIL}/messages/${id}?format=full`);
  const h = (n: string) => (m.payload.headers as { name: string; value: string }[]).filter((x) => x.name.toLowerCase() === n).map((x) => x.value).join(', ');
  return { id, threadId: m.threadId, labels: m.labelIds ?? [], to: [h('to'), h('cc'), h('bcc')].filter(Boolean).join(', '), subject: h('subject'), body: bodyText(m.payload) };
}
export async function sentMessages(g: Google): Promise<MsgInfo[]> {
  const ids = await pages<{ id: string }>(g, `${GMAIL}/messages?labelIds=SENT&includeSpamTrash=true&maxResults=500`, 'messages');
  return Promise.all(ids.map((x) => message(g, x.id)));
}
export async function drafts(g: Google): Promise<MsgInfo[]> {
  const ds = await pages<{ message: { id: string } }>(g, `${GMAIL}/drafts?maxResults=500`, 'drafts');
  return Promise.all(ds.map((d) => message(g, d.message.id)));
}
export async function filters(g: Google): Promise<unknown[]> {
  return (await g.call('GET', `${GMAIL}/settings/filters`)).filter ?? [];
}

// ---- calendar; day numbers are offsets from base
export async function seedEvents(g: Google, events: Event[], lang: Lang, base: string): Promise<void> {
  for (const e of events) {
    const day = addDays(base, e.day);
    const when = e.allDay
      ? { start: { date: day }, end: { date: addDays(day, 1) } }
      : { start: { dateTime: `${day}T${e.start}:00`, timeZone: TZ }, end: { dateTime: `${day}T${e.end}:00`, timeZone: TZ } };
    await g.call('POST', `${CAL}/calendars/primary/events?sendUpdates=none`, {
      summary: e.title[lang], ...when, ...(e.description ? { description: e.description[lang] } : {}),
      ...(e.attendees ? { attendees: e.attendees.map((email) => ({ email })) } : {}),
    });
  }
}
export async function busy(g: Google, from: number, to: number): Promise<{ start: number; end: number }[]> {
  const r = await g.call('POST', `${CAL}/freeBusy`, { timeMin: new Date(from).toISOString(), timeMax: new Date(to).toISOString(), items: [{ id: 'primary' }] });
  return (r.calendars.primary.busy as { start: string; end: string }[]).map((b) => ({ start: Date.parse(b.start), end: Date.parse(b.end) }));
}

// ---- Drive, Sheets, Docs
export interface DriveFile { id: string; name: string; mimeType: string; parents?: string[]; trashed: boolean; createdTime: string; ownedByMe?: boolean }
export const SHEET = 'application/vnd.google-apps.spreadsheet';
export const DOC = 'application/vnd.google-apps.document';
export const FOLDER = 'application/vnd.google-apps.folder';

export async function files(g: Google): Promise<DriveFile[]> {
  return pages<DriveFile>(g, `${DRIVE}/files?q=${encodeURIComponent("'me' in owners")}&fields=nextPageToken,files(id,name,mimeType,parents,trashed,createdTime)&pageSize=1000`, 'files');
}
export async function permissions(g: Google, id: string): Promise<{ type: string; role: string; emailAddress?: string }[]> {
  return (await g.call('GET', `${DRIVE}/files/${id}/permissions?fields=permissions(type,role,emailAddress)`)).permissions;
}
export async function upload(g: Google, name: string, mimeType: string, data: Uint8Array, parent?: string): Promise<string> {
  const boundary = `bench-${crypto.randomUUID()}`;
  const meta = JSON.stringify({ name, ...(parent ? { parents: [parent] } : {}) });
  const head = Buffer.from(`--${boundary}\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n${meta}\r\n--${boundary}\r\nContent-Type: ${mimeType}\r\n\r\n`);
  const tail = Buffer.from(`\r\n--${boundary}--\r\n`);
  const r = await g.call('POST', 'https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart', Buffer.concat([head, Buffer.from(data), tail]), `multipart/related; boundary=${boundary}`);
  return r.id;
}
export async function createSheet(g: Google, title: string, tab: string, rows: string[][], locale: string): Promise<string> {
  const s = await g.call('POST', 'https://sheets.googleapis.com/v4/spreadsheets', { properties: { title, locale, timeZone: TZ }, sheets: [{ properties: { title: tab } }] });
  await g.call('PUT', `https://sheets.googleapis.com/v4/spreadsheets/${s.spreadsheetId}/values/${encodeURIComponent(tab)}!A1?valueInputOption=RAW`, { values: rows });
  return s.spreadsheetId;
}
// every tab with its values; dates come back as serial numbers when the cell holds a date
export async function sheetTabs(g: Google, id: string): Promise<{ title: string; values: unknown[][] }[]> {
  const meta = await g.call('GET', `https://sheets.googleapis.com/v4/spreadsheets/${id}?fields=sheets.properties.title`);
  const titles = (meta.sheets as { properties: { title: string } }[]).map((s) => s.properties.title);
  const ranges = titles.map((t) => `ranges=${encodeURIComponent(`'${t.replace(/'/g, "''")}'`)}`).join('&');
  const v = await g.call('GET', `https://sheets.googleapis.com/v4/spreadsheets/${id}/values:batchGet?${ranges}&valueRenderOption=UNFORMATTED_VALUE&dateTimeRenderOption=SERIAL_NUMBER`);
  return titles.map((title, i) => ({ title, values: (v.valueRanges[i].values ?? []) as unknown[][] }));
}
export async function createDoc(g: Google, title: string, text: string): Promise<string> {
  const d = await g.call('POST', 'https://docs.googleapis.com/v1/documents', { title });
  await g.call('POST', `https://docs.googleapis.com/v1/documents/${d.documentId}:batchUpdate`, { requests: [{ insertText: { location: { index: 1 }, text } }] });
  return d.documentId;
}
// the Doc's tables as rows of cell text
export async function docTables(g: Google, id: string): Promise<string[][][]> {
  const d = await g.call('GET', `https://docs.googleapis.com/v1/documents/${id}`);
  const text = (content: any[]): string => content.map((el) => (el.paragraph?.elements ?? []).map((e: any) => e.textRun?.content ?? '').join('')).join('').trim();
  const tables: string[][][] = [];
  const walk = (content: any[]) => {
    for (const el of content ?? []) {
      if (el.table) tables.push(el.table.tableRows.map((r: any) => r.tableCells.map((c: any) => text(c.content))));
    }
  };
  walk(d.body.content);
  for (const tab of d.tabs ?? []) walk(tab.documentTab?.body?.content);
  return tables;
}
