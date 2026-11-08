import { test } from 'node:test';
import assert from 'node:assert/strict';
import { daySerial, monthDay, nums, serialDay, squash } from '../tasks/text.ts';
import { addDays, epoch, nextMonday, weekday } from '../lib/time.ts';
import { makePdf } from '../lib/pdf.ts';
import { supplierProfile } from '../fixtures/documents.ts';

test('nums reads Italian and English formats', () => {
  assert.deepEqual(nums('€ 1.156,00'), [1156]);
  assert.deepEqual(nums('€1,249.90'), [1249.9]);
  assert.deepEqual(nums('298,90 IVA incl.'), [298.9]);
  assert.deepEqual(nums('245.00 + VAT'), [245]);
  assert.deepEqual(nums('3-5 giorni, 2 anni'), [3, 5, 2]);
  assert.deepEqual(nums('1,156'), [1156]);
});

test('monthDay reads serials, ISO, d/m, m/d and month names', () => {
  assert.equal(monthDay(daySerial('2026-12-14')), '12-14');
  assert.equal(monthDay('2026-12-22'), '12-22');
  assert.equal(monthDay('14/12/2026'), '12-14');
  assert.equal(monthDay('12/14/2026'), '12-14');
  assert.equal(monthDay('21 dicembre'), '12-21');
  assert.equal(monthDay('Dec 31, 2026'), '12-31');
  assert.equal(monthDay('Anna Conti'), null);
  assert.equal(monthDay(4), null);
  assert.equal(serialDay(daySerial('2026-07-03')), '2026-07-03');
});

test('squash ignores case, spaces and accents', () => {
  assert.equal(squash('Hotel Podgórze Bridge'), 'hotelpodgorzebridge');
  assert.equal(squash('LR 4410'), squash('lr4410'));
});

test('time helpers in Europe/Rome', () => {
  assert.equal(weekday('2026-11-09'), 0);
  assert.equal(nextMonday('2026-11-08'), '2026-11-09');
  assert.equal(nextMonday('2026-11-09'), '2026-11-16');
  assert.equal(addDays('2026-12-31', 1), '2027-01-01');
  assert.equal(new Date(epoch('2026-11-09', '09:00', 'Europe/Rome')).toISOString(), '2026-11-09T08:00:00.000Z');
  assert.equal(new Date(epoch('2026-07-01', '09:00', 'Europe/Rome')).toISOString(), '2026-07-01T07:00:00.000Z');
});

test('pdf writer gives a well-formed file', () => {
  const pdf = Buffer.from(supplierProfile('it')).toString('latin1');
  assert.match(pdf, /^%PDF-1\.4/);
  assert.match(pdf, /Tessiture Brambilla/);
  const xref = Number(/startxref\n(\d+)/.exec(pdf)![1]);
  assert.equal(pdf.slice(xref, xref + 4), 'xref');
  assert.throws(() => makePdf([[{ text: '😀' }]]));
});
