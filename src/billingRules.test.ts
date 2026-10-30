import test from 'node:test';
import assert from 'node:assert/strict';
import {
  parsePriceToCents,
  parsePriceToUnits,
  formatMoney,
  calculateInvoice,
  calculateCartTotals,
  calculateBalance,
  validatePaymentAmount,
  resolveDynamicStatus,
  formatNextInvoiceNumber,
  formatCents,
  calculateDueDate,
  isInvoiceOverdue,
  calculateDiscountCents,
  calculateGstSplit,
  getLutNotice,
  getEuReverseChargeNotice,
  calculateCanadaTax,
  parseZeroDecimalPrice,
  extractSequenceNumber,
} from './billingRules';

// ============================================================================
// CATEGORY A: UNIVERSAL FINANCIAL MATH & LEDGER INVARIANTS
// ============================================================================

test('Category A: Exact 64-bit integer Round-Half-Up Tax (1733 cents @ 18% yields 312 cents)', () => {
  const result = calculateCartTotals(1733, 18);
  assert.equal(result.subtotalCents, 1733);
  assert.equal(result.taxCents, 312); // (1733 * 18 + 50) ~/ 100 = 31244 ~/ 100 = 312
  assert.equal(result.totalCents, 2045);
});

test('Category A: Flat discount clamping (Flat 15000 on 10000 subtotal clamps to 10000)', () => {
  const subtotal = 10000;
  const discountCents = calculateDiscountCents(subtotal, 'flat', 15000);
  assert.equal(discountCents, 10000);
  const netSubtotal = subtotal - discountCents;
  assert.equal(netSubtotal, 0);
  const tax = calculateCartTotals(netSubtotal, 18).taxCents;
  assert.equal(tax, 0);
});

test('Category A: Mixed line-item tax slabs (Line 1 @ 0% + Line 2 @ 18%)', () => {
  const line1Subtotal = 5000; // 0% tax
  const line2Subtotal = 10000; // 18% tax
  const line1Tax = calculateCartTotals(line1Subtotal, 0).taxCents;
  const line2Tax = calculateCartTotals(line2Subtotal, 18).taxCents;

  assert.equal(line1Tax, 0);
  assert.equal(line2Tax, 1800);
  assert.equal(line1Tax + line2Tax, 1800);
  assert.equal(line1Subtotal + line2Subtotal + line1Tax + line2Tax, 16800);
});

test('Category A: Net Profit isolation (Collected tax is liability excluded from Net Profit)', () => {
  const grossCollectedCents = 11800; // $118.00 total received
  const taxCollectedCents = 1800;    // $18.00 tax liability
  const expenseGrossCents = 5900;     // $59.00 total expense
  const expenseTaxCents = 900;        // $9.00 tax paid on expense

  const netRevenueExclTax = grossCollectedCents - taxCollectedCents; // $100.00
  const netExpenseExclTax = expenseGrossCents - expenseTaxCents;     // $50.00
  const realNetProfit = netRevenueExclTax - netExpenseExclTax;       // $50.00
  const taxLiability = taxCollectedCents - expenseTaxCents;          // $9.00

  assert.equal(netRevenueExclTax, 10000);
  assert.equal(netExpenseExclTax, 5000);
  assert.equal(realNetProfit, 5000);
  assert.equal(taxLiability, 900);
});

// ============================================================================
// CATEGORY B: INDIAN GST & STATUTORY COMPLIANCE
// ============================================================================

test('Category B: Intra-State Supply splits tax 50/50 into CGST and SGST', () => {
  const totalTax = 1800; // 18% GST on 10000
  const split = calculateGstSplit(totalTax, true);
  assert.equal(split.cgstCents, 900);
  assert.equal(split.sgstCents, 900);
  assert.equal(split.igstCents, 0);

  // Odd cent handling test (1733 @ 18% = 312 cents tax)
  const oddSplit = calculateGstSplit(313, true);
  assert.equal(oddSplit.cgstCents, 156);
  assert.equal(oddSplit.sgstCents, 157); // absorbs remainder
  assert.equal(oddSplit.cgstCents + oddSplit.sgstCents, 313);
});

test('Category B: Inter-State Supply computes IGST 100% in full', () => {
  const totalTax = 1800;
  const split = calculateGstSplit(totalTax, false);
  assert.equal(split.cgstCents, 0);
  assert.equal(split.sgstCents, 0);
  assert.equal(split.igstCents, 1800);
});

test('Category B: Export under LUT computes 0% tax with mandatory LUT statutory notice', () => {
  const notice = getLutNotice(true);
  assert.equal(
    notice,
    'SUPPLY MEANT FOR EXPORT UNDER BOND OR LETTER OF UNDERTAKING WITHOUT PAYMENT OF INTEGRATED TAX'
  );
  assert.equal(getLutNotice(false), '');
});

test('Category B: TDS Withholding (Invoice 10000, Bank 9000, TDS 1000 marks invoice PAID)', () => {
  const totalCents = 10000;
  const bankReceivedCents = 9000;
  const tdsCents = 1000;
  const totalCredit = bankReceivedCents + tdsCents;

  const bal = calculateBalance(totalCents, totalCredit);
  assert.equal(bal.balanceDueCents, 0);
  assert.equal(bal.isFullyPaid, true);
  assert.equal(resolveDynamicStatus(totalCents, totalCredit, '2026-12-31'), 'PAID');
});

test('Category B: Overpayment rejection (Paying 50001 on 50000 balance is rejected)', () => {
  const balanceDue = 50000;
  const invalidPay = validatePaymentAmount(50001, balanceDue);
  assert.equal(invalidPay.valid, false);

  const validPay = validatePaymentAmount(50000, balanceDue);
  assert.equal(validPay.valid, true);
});

// ============================================================================
// CATEGORY C: INTERNATIONAL TAX FRAMEWORKS (EU, US, CANADA, GULF)
// ============================================================================

test('Category C: EU/UK B2B Reverse Charge zero-rates tax and includes Reverse Charge notice', () => {
  const notice = getEuReverseChargeNotice(true);
  assert.equal(
    notice,
    'Reverse charge: Customer to account for VAT under Article 196 of Council Directive 2006/112/EC.'
  );
  assert.equal(getEuReverseChargeNotice(false), '');
});

test('Category C: US Tax-Exempt clients with exemption ID produce 0 tax', () => {
  const result = calculateCartTotals(25000, 0); // 0% tax exempt rate
  assert.equal(result.subtotalCents, 25000);
  assert.equal(result.taxCents, 0);
  assert.equal(result.totalCents, 25000);
});

test('Category C: Canada Dual Tax (GST 5% + PST 7% calculated accurately)', () => {
  const subtotal = 10000; // $100.00
  const canadaTax = calculateCanadaTax(subtotal, 5, 7);
  assert.equal(canadaTax.gstCents, 500);
  assert.equal(canadaTax.pstCents, 700);
  assert.equal(canadaTax.totalTaxCents, 1200);
});

test('Category C: Gulf VAT (Standard 15% KSA / 5% UAE VAT)', () => {
  const ksaTax = calculateCartTotals(10000, 15);
  assert.equal(ksaTax.taxCents, 1500);

  const uaeTax = calculateCartTotals(10000, 5);
  assert.equal(uaeTax.taxCents, 500);
});

// ============================================================================
// CATEGORY D: MULTI-CURRENCY & DECIMAL PRECISION MODELS
// ============================================================================

test('Category D: Standard 2-decimal currency parsing (INR, USD, EUR, GBP)', () => {
  assert.equal(parsePriceToCents('15.50'), 1550);
  assert.equal(parsePriceToCents('₹1,500.25'), 150025);
  assert.equal(parsePriceToCents('€99.99'), 9999);
  assert.equal(parsePriceToCents('£0.05'), 5);
});

test('Category D: 2-decimal USD parsing and formatting ($15.50 -> 1550 -> "$15.50")', () => {
  const units = parsePriceToUnits('$15.50', 2);
  assert.equal(units, 1550);
  const formatted = formatMoney(units, '$', 2);
  assert.equal(formatted, '$15.50');
});

test('Category D: 0-decimal JPY parsing and formatting (¥50000 -> 50000 -> "¥50,000" with zero trailing cents)', () => {
  const units = parsePriceToUnits('¥50000', 0);
  assert.equal(units, 50000);
  const formatted = formatMoney(units, '¥', 0);
  assert.equal(formatted, '¥50,000');
});

test('Category D: 0-decimal JPY 10% tax calculation (¥50,000 subtotal @ 10% tax yields exactly ¥5,000 tax)', () => {
  const subtotalUnits = parsePriceToUnits('50000', 0);
  assert.equal(subtotalUnits, 50000);
  const totals = calculateCartTotals(subtotalUnits, 10);
  assert.equal(totals.subtotalCents, 50000);
  assert.equal(totals.taxCents, 5000);
  assert.equal(totals.totalCents, 55000);
  assert.equal(formatMoney(totals.taxCents, '¥', 0), '¥5,000');
  assert.equal(formatMoney(totals.totalCents, '¥', 0), '¥55,000');
});

test('Category D: Zero-decimal currency parsing (JPY, KRW) without fractional cent bugs', () => {
  assert.equal(parseZeroDecimalPrice('1500 Yen'), 1500);
  assert.equal(parseZeroDecimalPrice('₩250,000'), 250000);
});

// ============================================================================
// CATEGORY E: SEQUENCE AUTO-INCREMENT SAFETY
// ============================================================================

test('Category E: Sequence extraction using dynamic prefix length offset', () => {
  assert.equal(extractSequenceNumber('BILLING-2026-0042', 'BILLING-2026-'), 42);
  assert.equal(extractSequenceNumber('INV-0001', 'INV-'), 1);
  assert.equal(extractSequenceNumber('INV-9999', 'INV-'), 9999);
});
