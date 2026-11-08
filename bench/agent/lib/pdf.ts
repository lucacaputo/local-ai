// Minimal text-only PDF writer for the bench's documents (B3 supplier profile, B4 invoices): Helvetica, WinAnsi
// encoding (covers Italian accents and €), one or more pages. Deterministic, so the same input gives the same bytes.
export interface Line { text: string; size?: number; bold?: boolean; gap?: number }

const WIN: Record<string, number> = { '€': 0x80, '’': 0x92, '“': 0x93, '”': 0x94, '–': 0x96, '—': 0x97 };
function winAnsi(s: string): number[] {
  return [...s].map((c) => {
    if (WIN[c] !== undefined) return WIN[c];
    const n = c.codePointAt(0)!;
    if (n < 256) return n;
    throw new Error(`character ${c} is not in WinAnsi`);
  });
}
function pdfString(s: string): number[] {
  const out: number[] = [0x28];
  for (const b of winAnsi(s)) {
    if (b === 0x28 || b === 0x29 || b === 0x5c) out.push(0x5c);
    out.push(b);
  }
  out.push(0x29);
  return out;
}

export function makePdf(pages: Line[][]): Uint8Array {
  const objs: number[][] = [];
  const ascii = (s: string) => [...Buffer.from(s, 'latin1')];
  const add = (body: number[]) => { objs.push(body); return objs.length; };
  // 1 catalog, 2 pages, 3 font, 4 bold font; pages follow
  add(ascii('<< /Type /Catalog /Pages 2 0 R >>'));
  add([]); // filled below
  add(ascii('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>'));
  add(ascii('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>'));
  const kids: number[] = [];
  for (const lines of pages) {
    const content: number[] = [];
    let y = 800;
    for (const l of lines) {
      const size = l.size ?? 11;
      y -= (l.gap ?? 0) + size * 1.45;
      content.push(...ascii(`BT /${l.bold ? 'F2' : 'F1'} ${size} Tf 56 ${y.toFixed(1)} Td `), ...pdfString(l.text), ...ascii(' Tj ET\n'));
    }
    const stream = add([...ascii(`<< /Length ${content.length} >>\nstream\n`), ...content, ...ascii('endstream')]);
    kids.push(add(ascii(`<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 3 0 R /F2 4 0 R >> >> /Contents ${stream} 0 R >>`)));
  }
  objs[1] = ascii(`<< /Type /Pages /Kids [${kids.map((k) => `${k} 0 R`).join(' ')}] /Count ${kids.length} >>`);

  const out: number[] = ascii('%PDF-1.4\n%\xe2\xe3\xcf\xd3\n');
  const offsets: number[] = [];
  objs.forEach((body, i) => {
    offsets.push(out.length);
    out.push(...ascii(`${i + 1} 0 obj\n`), ...body, ...ascii('\nendobj\n'));
  });
  const xref = out.length;
  out.push(...ascii(`xref\n0 ${objs.length + 1}\n0000000000 65535 f \n`));
  for (const o of offsets) out.push(...ascii(`${String(o).padStart(10, '0')} 00000 n \n`));
  out.push(...ascii(`trailer\n<< /Size ${objs.length + 1} /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF\n`));
  return Uint8Array.from(out);
}
