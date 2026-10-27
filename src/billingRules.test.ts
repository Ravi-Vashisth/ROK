import test from 'node:test';
import assert from 'node:assert/strict';
import {
  parsePriceToCents,
  calculateInvoice,
  formatNextInvoiceNumber,
  formatCents,
} from './billingRules';

test('parsePriceToCents converts decimal strings to exact integer cents', () => {
  assert.equal(parsePriceToCents('15.50'), 1550);
  assert.equal(parsePriceToCents('$15.50'), 1550);
  assert.equal(parsePriceToCents('15'), 1500);
  assert.equal(parsePriceToCents('0.99'), 99);
  assert.equal(parsePriceToCents('0.05'), 5);
  assert.equal(parsePriceToCents(''), 0);
  assert.equal(parsePriceToCents('  $123.45  '), 12345);
});

test('calculateInvoice applies strict integer round-half-up tax rule', () => {
  // $15.50 * 2 = $31.00 (3100 cents)
  // Tax 10%: (3100 * 10 + 50) ~/ 100 = (31050) ~/ 100 = 310 cents ($3.10)
  // Total: 3100 + 310 = 3410 cents ($34.10)
  const result1 = calculateInvoice(1550, 2, 10);
  assert.equal(result1.subtotalCents, 3100);
  assert.equal(result1.taxCents, 310);
  assert.equal(result1.totalCents, 3410);

  // Test Round-Half-Up Boundary:
  // Subtotal: 105 cents, Tax 7%
  // 105 * 7 = 735. + 50 = 785. ~/ 100 = 7 cents.
  const result2 = calculateInvoice(105, 1, 7);
  assert.equal(result2.subtotalCents, 105);
  assert.equal(result2.taxCents, 7);
  assert.equal(result2.totalCents, 112);

  // Subtotal: 150 cents, Tax 7%
  // 150 * 7 = 1050. + 50 = 1100. ~/ 100 = 11 cents. (exact half rounds up!)
  const result3 = calculateInvoice(150, 1, 7);
  assert.equal(result3.subtotalCents, 150);
  assert.equal(result3.taxCents, 11);
  assert.equal(result3.totalCents, 161);
});

test('formatNextInvoiceNumber generates zero-padded sequential IDs', () => {
  assert.equal(formatNextInvoiceNumber(0), 'INV-0001');
  assert.equal(formatNextInvoiceNumber(1), 'INV-0002');
  assert.equal(formatNextInvoiceNumber(9), 'INV-0010');
  assert.equal(formatNextInvoiceNumber(99), 'INV-0100');
  assert.equal(formatNextInvoiceNumber(999), 'INV-1000');
});

test('formatCents displays integer cents formatted as standard currency', () => {
  assert.equal(formatCents(1550), '$15.50');
  assert.equal(formatCents(3410), '$34.10');
  assert.equal(formatCents(0), '$0.00');
});
