import test from 'node:test';
import assert from 'node:assert/strict';
import {
  parsePriceToCents,
  calculateInvoice,
  calculateCartTotals,
  calculateBalance,
  validatePaymentAmount,
  resolveDynamicStatus,
  formatNextInvoiceNumber,
  formatCents,
  calculateDueDate,
  isInvoiceOverdue,
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
  const subtotal = 20000 + 1550 + 1200;
  const result = calculateCartTotals(subtotal, 8);
  assert.equal(result.subtotalCents, 22750);
  assert.equal(result.taxCents, 1820);
  assert.equal(result.totalCents, 24570);
});

test('calculateBalance accurately calculates balance due and settlement flags', () => {
  // Total $100.00 (10000 cents), Paid $0
  const b1 = calculateBalance(10000, 0);
  assert.equal(b1.balanceDueCents, 10000);
  assert.equal(b1.isFullyPaid, false);
  assert.equal(b1.isPartiallyPaid, false);

  // Total $100.00, Paid $30.00 (Deposit)
  const b2 = calculateBalance(10000, 3000);
  assert.equal(b2.balanceDueCents, 7000);
  assert.equal(b2.isFullyPaid, false);
  assert.equal(b2.isPartiallyPaid, true);

  // Total $100.00, Paid $100.00 (Full settlement)
  const b3 = calculateBalance(10000, 10000);
  assert.equal(b3.balanceDueCents, 0);
  assert.equal(b3.isFullyPaid, true);
  assert.equal(b3.isPartiallyPaid, false);
});

test('validatePaymentAmount rejects <= 0 or overpayments beyond balance due', () => {
  // Balance due $50.00 (5000 cents)
  const valZero = validatePaymentAmount(0, 5000);
  assert.equal(valZero.valid, false);

  const valNegative = validatePaymentAmount(-100, 5000);
  assert.equal(valNegative.valid, false);

  const valOver = validatePaymentAmount(5001, 5000);
  assert.equal(valOver.valid, false);

  const valExact = validatePaymentAmount(5000, 5000);
  assert.equal(valExact.valid, true);

  const valPartial = validatePaymentAmount(2500, 5000);
  assert.equal(valPartial.valid, true);
});

test('resolveDynamicStatus determines correct status across all states', () => {
  // Fully paid
  assert.equal(resolveDynamicStatus(10000, 10000, '2026-01-01'), 'PAID');

  // Partially paid before due date
  assert.equal(resolveDynamicStatus(10000, 4000, '2030-01-01'), 'PARTIALLY_PAID');

  // Overdue without payments
  assert.equal(resolveDynamicStatus(10000, 0, '2020-01-01'), 'OVERDUE');

  // Pending normal
  assert.equal(resolveDynamicStatus(10000, 0, '2030-01-01'), 'PENDING');
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

test('calculateDueDate handles Due on Receipt, Net 15, Net 30, and Net 60', () => {
  const issue = '2026-10-01';
  assert.equal(calculateDueDate(issue, 'Due on Receipt'), '2026-10-01');
  assert.equal(calculateDueDate(issue, 'Net 15 Days'), '2026-10-16');
  assert.equal(calculateDueDate(issue, 'Net 30 Days'), '2026-10-31');
  assert.equal(calculateDueDate(issue, 'Net 60 Days'), '2026-11-30');
});
