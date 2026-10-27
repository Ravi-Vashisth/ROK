import test from 'node:test';
import assert from 'node:assert/strict';
import {
  parsePriceToCents,
  calculateInvoice,
  calculateCartTotals,
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
  const result1 = calculateInvoice(1550, 2, 10);
  assert.equal(result1.subtotalCents, 3100);
  assert.equal(result1.taxCents, 310);
  assert.equal(result1.totalCents, 3410);

  // Round-Half-Up Boundary:
  const result2 = calculateInvoice(105, 1, 7);
  assert.equal(result2.subtotalCents, 105);
  assert.equal(result2.taxCents, 7);
  assert.equal(result2.totalCents, 112);

  const result3 = calculateInvoice(150, 1, 7);
  assert.equal(result3.subtotalCents, 150);
  assert.equal(result3.taxCents, 11);
  assert.equal(result3.totalCents, 161);
});

test('calculateCartTotals calculates multi-line cart items sum and taxes correctly', () => {
  // Line item 1: Consulting 2 hrs @ $100.00 = 20000 cents ($200.00)
  // Line item 2: Hosting 1 yr @ $15.50 = 1550 cents ($15.50)
  // Line item 3: Domain setup 1 @ $12.00 = 1200 cents ($12.00)
  // Subtotal: 22750 cents ($227.50)
  // Tax 8%: (22750 * 8 + 50) ~/ 100 = (182000 + 50) ~/ 100 = 1820 cents ($18.20)
  // Grand total: 22750 + 1820 = 24570 cents ($245.70)
  const subtotal = 20000 + 1550 + 1200;
  const result = calculateCartTotals(subtotal, 8);
  assert.equal(result.subtotalCents, 22750);
  assert.equal(result.taxCents, 1820);
  assert.equal(result.totalCents, 24570);
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
