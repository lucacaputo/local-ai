// Reading numbers, dates and names out of what the agent wrote, in Italian and English formats.

// Every number in s: "€ 1.156,00" -> 1156, "298,90" -> 298.9, "1,249.90" -> 1249.9, "3-5" -> 3, 5.
export function nums(s: string): number[] {
  return (s.match(/\d[\d.,]*/g) ?? []).map((tok) => {
    tok = tok.replace(/[.,]+$/, '');
    const dot = tok.lastIndexOf('.'), comma = tok.lastIndexOf(',');
    if (dot >= 0 && comma >= 0) {
      const dec = Math.max(dot, comma);
      return Number(tok.slice(0, dec).replace(/[.,]/g, '') + '.' + tok.slice(dec + 1));
    }
    const sep = dot >= 0 ? '.' : comma >= 0 ? ',' : '';
    if (!sep) return Number(tok);
    const parts = tok.split(sep);
    // one separator followed by exactly 3 digits is a thousands separator; otherwise a decimal point
    if (parts.length > 2 || parts[1].length === 3) return Number(parts.join(''));
    return Number(parts[0] + '.' + parts[1]);
  });
}
export const has = (s: string, n: number, tol = 0.005) => nums(s).some((x) => Math.abs(x - n) <= tol);

// letters and digits only, lower case: "Ufficio Pro" ~ "UfficioPro", "LR 4410" ~ "LR4410"
export const squash = (s: string) => s.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().replace(/[^a-z0-9]/g, '');

const MONTHS: Record<string, number> = {
  gen: 1, gennaio: 1, jan: 1, january: 1, feb: 2, febbraio: 2, february: 2, mar: 3, marzo: 3, march: 3, apr: 4, aprile: 4, april: 4,
  mag: 5, maggio: 5, may: 5, giu: 6, giugno: 6, jun: 6, june: 6, lug: 7, luglio: 7, jul: 7, july: 7, ago: 8, agosto: 8, aug: 8, august: 8,
  set: 9, settembre: 9, sep: 9, sept: 9, september: 9, ott: 10, ottobre: 10, oct: 10, october: 10, nov: 11, novembre: 11, november: 11,
  dic: 12, dicembre: 12, dec: 12, december: 12,
};
const md = (m: number, d: number) => (m >= 1 && m <= 12 && d >= 1 && d <= 31 ? `${String(m).padStart(2, '0')}-${String(d).padStart(2, '0')}` : null);

// A Sheets serial number (days since 1899-12-30) as YYYY-MM-DD.
export function serialDay(n: number): string {
  return new Date(Date.UTC(1899, 11, 30) + Math.floor(n) * 86_400_000).toISOString().slice(0, 10);
}
export function daySerial(day: string): number {
  return Math.round((Date.parse(`${day}T00:00:00Z`) - Date.UTC(1899, 11, 30)) / 86_400_000);
}

// Month-day ("12-14") of a cell: a serial number, 2026-12-14, 14/12/2026, 12/14/2026 (day > 12), 14 dicembre, Dec 14.
export function monthDay(v: unknown): string | null {
  if (typeof v === 'number') return v > 20000 && v < 80000 ? serialDay(v).slice(5) : null;
  if (typeof v !== 'string') return null;
  const s = v.trim().toLowerCase();
  let m = /^(\d{4})-(\d{1,2})-(\d{1,2})/.exec(s);
  if (m) return md(+m[2], +m[3]);
  m = /^(\d{1,2})[/.-](\d{1,2})(?:[/.-](\d{2,4}))?$/.exec(s);
  if (m) return +m[1] > 12 ? md(+m[2], +m[1]) : +m[2] > 12 ? md(+m[1], +m[2]) : md(+m[2], +m[1]);
  m = /(\d{1,2})\s+([a-zà-ü]+)/.exec(s);
  if (m && MONTHS[m[2]]) return md(MONTHS[m[2]], +m[1]);
  m = /([a-z]+)\.?\s+(\d{1,2})/.exec(s);
  if (m && MONTHS[m[1]]) return md(MONTHS[m[1]], +m[2]);
  return null;
}
