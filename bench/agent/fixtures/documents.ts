// PDF documents the tasks hand to the agent (TASK-040): B3's supplier profile and B4's invoices.
import { makePdf, type Line } from '../lib/pdf.ts';
import { DECOY_SITE, SUPPLIER_PROFILE as P, type Lang } from './web-data.ts';
import { B4_INVOICES, B4_ORDERS } from './google-data.ts';

const t = (lang: Lang, it: string, en: string) => (lang === 'it' ? it : en);
const eur = (n: number, lang: Lang) => '€ ' + n.toLocaleString(lang === 'it' ? 'it-IT' : 'en-GB', { minimumFractionDigits: 2 });

export const PROFILE_FILE: Record<Lang, string> = { it: 'scheda-fornitore.pdf', en: 'supplier-profile.pdf' };

export function supplierProfile(lang: Lang): Uint8Array {
  const lines: Line[] = [
    { text: P.company, size: 18, bold: true },
    { text: t(lang, 'Scheda anagrafica fornitore', 'Supplier profile'), size: 13, gap: 4 },
    { text: t(lang, 'Dati societari', 'Company details'), bold: true, gap: 14 },
    { text: `${t(lang, 'Partita IVA', 'VAT number')}: ${P.vat}` },
    { text: `${t(lang, 'Sede legale', 'Registered office')}: ${P.street}, ${P.postcode} ${P.city} (BG), ${t(lang, 'Italia', 'Italy')}` },
    { text: `${t(lang, 'Sede operativa e magazzino', 'Operating site and warehouse')}: ${DECOY_SITE.street}, ${DECOY_SITE.postcode} ${DECOY_SITE.city} (BG)` },
    { text: t(lang, 'Contatti amministrativi', 'Accounts contacts'), bold: true, gap: 14 },
    { text: `${t(lang, 'Referente', 'Contact')}: ${P.contact}` },
    { text: `Email: ${P.email}` },
    { text: `${t(lang, 'Telefono', 'Phone')}: ${P.phone}` },
    { text: t(lang, 'Dati bancari', 'Bank details'), bold: true, gap: 14 },
    { text: `IBAN: ${P.iban.replace(/(.{4})/g, '$1 ').trim()}` },
    { text: t(lang, 'Banca: Intesa Sanpaolo, filiale di Bergamo centro', 'Bank: Intesa Sanpaolo, Bergamo centre branch') },
    { text: t(lang, 'Condizioni commerciali', 'Terms'), bold: true, gap: 14 },
    { text: t(lang, `Pagamento: ${P.terms} giorni data fattura`, `Payment: ${P.terms} days from invoice date`) },
    { text: t(lang, 'Resa: franco destino per ordini oltre € 500', 'Delivery: free for orders over € 500') },
    { text: t(lang, 'Documento aggiornato a ottobre 2026.', 'Document updated October 2026.'), size: 9, gap: 20 },
  ];
  return makePdf([lines]);
}

export const invoiceFile = (i: number) => `documento_${String(i + 1).padStart(2, '0')}.pdf`;

export function invoice(i: number, lang: Lang): Uint8Array {
  const inv = B4_INVOICES[i];
  const order = B4_ORDERS.find((o) => o.client === inv.client && o.amount === inv.amount);
  const lines: Line[] = [
    { text: 'Arredo Nord S.p.A.', size: 16, bold: true },
    { text: 'Via Torino 12, 20123 Milano · P. IVA IT09876543210', size: 9 },
    { text: `${t(lang, 'FATTURA', 'INVOICE')} n. ${inv.no}`, size: 14, bold: true, gap: 18 },
    { text: `${t(lang, 'Data', 'Date')}: ${order?.date.split('-').reverse().join('/') ?? '30/09/2026'}` },
    { text: t(lang, 'Intestata a', 'Bill to'), bold: true, gap: 12 },
    { text: inv.client },
    { text: t(lang, 'Ufficio acquisti', 'Purchasing office') },
    { text: t(lang, 'Descrizione', 'Description'), bold: true, gap: 12 },
    { text: `${order?.product ?? t(lang, 'Arredi', 'Furniture')} × ${order?.qty ?? 1}` },
    { text: `${t(lang, 'Totale', 'Total')}: ${eur(inv.amount, lang)}`, bold: true, gap: 8 },
    { text: t(lang, 'Pagamento a 60 giorni data fattura.', 'Payment within 60 days of the invoice date.'), size: 9, gap: 16 },
  ];
  return makePdf([lines]);
}
