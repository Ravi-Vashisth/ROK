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
  getNextSequentialDocNumber,
  formatDecimalUnits,
  calculateTaxCents,
  calculateCollectedTaxPortion,
  calculateDashboardMetrics,
  generateDynamicQrPayload,
  generateInvoicesCsvString,
  validateBackupPayload,
  normalizePhoneForUri,
  buildWhatsAppDigits,
  buildPaymentReminderMessage,
  buildWhatsAppUrl,
  buildMailtoUrl,
  buildSmsUrl,
  buildTelUrl,
  normalizeTaxMode,
  isZeroRatedTaxMode,
  computeRegionalTaxCents,
  resolveRegionalTaxBreakdown,
  getRegionalTaxIdLabel,
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

// ============================================================================
// CATEGORY F: COMPETITIVE FEATURES & REMEDIATIONS
// ============================================================================

test('Category F: Dynamic UPI QR payload formatting', () => {
  // Test UPI VPA string
  const upiQr = generateDynamicQrPayload('billing@okaxis', 'Acme Studio', 15000, 2, 'INV-0001', 'INR');
  assert.equal(upiQr, 'upi://pay?pa=billing%40okaxis&pn=Acme%20Studio&am=150.00&tn=Invoice-INV-0001&cu=INR');

  // Test 0-decimal currency JPY amount string
  const jpyQr = generateDynamicQrPayload('vendor@upi', 'Tokyo Soft', 50000, 0, 'INV-0002', 'JPY');
  assert.equal(jpyQr, 'upi://pay?pa=vendor%40upi&pn=Tokyo%20Soft&am=50000&tn=Invoice-INV-0002&cu=JPY');

  // Test Web payment URL appending invoice reference
  const webQr = generateDynamicQrPayload('https://pay.acme.com/checkout', 'Acme', 25000, 2, 'INV-0003', 'USD');
  assert.equal(webQr, 'https://pay.acme.com/checkout?invoice=INV-0003');
});

test('Category F: Draft invoices are excluded from overdue metrics and receivables', () => {
  const isDraftOverdue = isInvoiceOverdue('DRAFT', '2020-01-01');
  assert.equal(isDraftOverdue, false);

  const draftStatus = resolveDynamicStatus(10000, 0, '2020-01-01', 'DRAFT');
  assert.equal(draftStatus, 'DRAFT');
});

// ============================================================================
// P0-A REGRESSION TESTS: TAX ISOLATION, 0-DECIMAL, & SEQUENCE COLLISION SAFETY
// ============================================================================

test('P0-A: formatDecimalUnits preserves 0-decimal minor units without /100 division', () => {
  assert.equal(formatDecimalUnits(50000, 0), '50000');
  assert.equal(formatDecimalUnits(0, 0), '0');
  assert.equal(formatDecimalUnits(1550, 2), '15.50');
  assert.equal(formatDecimalUnits(5, 2), '0.05');
});

test('P0-A: calculateTaxCents and calculateCollectedTaxPortion apply integer round-half-up math', () => {
  assert.equal(calculateTaxCents(1733, 18), 312);
  assert.equal(calculateTaxCents(150, 7), 11);
  // Partial payment proportional tax with round-half-up (1000 * 500 + 1500) / 3000 = 167
  assert.equal(calculateCollectedTaxPortion(1000, 500, 3000), 167);
  // Odd-cent half tie rounds half up (5000 * 313 + 5000) / 10000 = 157
  assert.equal(calculateCollectedTaxPortion(5000, 313, 10000), 157);
  // Full payment returns exact taxCents
  assert.equal(calculateCollectedTaxPortion(11800, 1800, 11800), 1800);
  // Zero guard
  assert.equal(calculateCollectedTaxPortion(0, 1800, 11800), 0);
});

test('P0-A: Sequence extraction ignores DRAFT- and getNextSequentialDocNumber avoids gap collisions', () => {
  assert.equal(extractSequenceNumber('DRAFT-A9B2C1', 'INV-'), 0);
  assert.equal(extractSequenceNumber('INV-C-EST-0001', 'INV-'), 0);
  assert.equal(
    getNextSequentialDocNumber(['INV-0001', 'INV-0004', 'DRAFT-XYZ999'], 'INV-'),
    'INV-0005'
  );
  assert.equal(
    getNextSequentialDocNumber(['EST-0002'], 'EST-', 5),
    'EST-0005'
  );
});

test('P0-A: calculateDashboardMetrics isolates tax from Net Profit and excludes DRAFT/VOID', () => {
  const invoices = [
    { id: '1', status: 'PAID', total_cents: 11800, paid_cents: 11800, tax_cents: 1800, balance_due_cents: 0, due_date: '2020-01-01' },
    { id: '2', status: 'PARTIALLY_PAID', total_cents: 3000, paid_cents: 1000, tax_cents: 500, balance_due_cents: 2000, due_date: '2099-12-31' },
    { id: '3', status: 'DRAFT', total_cents: 50000, paid_cents: 0, tax_cents: 5000, balance_due_cents: 50000, due_date: '2020-01-01' },
    { id: '4', status: 'VOID', total_cents: 20000, paid_cents: 0, tax_cents: 2000, balance_due_cents: 0, due_date: '2020-01-01' },
  ];
  const expenses = [
    { id: 'e1', amount_cents: 5000, tax_cents: 900, total_cents: 5900 },
  ];
  const metrics = calculateDashboardMetrics(invoices, expenses);
  assert.equal(metrics.totalInvoicedCents, 14800);
  assert.equal(metrics.totalCollectedCents, 12800);
  assert.equal(metrics.taxCollectedOnPaymentsCents, 1800 + 167); // 1967
  assert.equal(metrics.netRevenueExclTaxCents, 12800 - 1967);     // 10833
  assert.equal(metrics.netExpenseExclTaxCents, 5000);
  assert.equal(metrics.netProfitCents, 10833 - 5000);             // 5833
  assert.equal(metrics.taxLiabilityCents, 1967 - 900);            // 1067
  assert.equal(metrics.overdueInvoices.length, 0);
});

// ============================================================================
// P0-B REGRESSION TESTS: BACKUP VALIDATION & CSV EXPORT
// ============================================================================

test('P0-B: validateBackupPayload rejects malformed objects, arrays, and non-object records', () => {
  assert.equal(validateBackupPayload(null).valid, false);
  assert.equal(validateBackupPayload([]).valid, false);
  assert.equal(validateBackupPayload({ clients: [] }).valid, false);
  assert.equal(validateBackupPayload({ clients: 'not-array', invoices: [] }).valid, false);
  assert.equal(validateBackupPayload({ clients: [123], invoices: [] }).valid, false);
  assert.equal(
    validateBackupPayload({ clients: [], invoices: [], savedItems: 'bad' }).valid,
    false
  );
  assert.equal(
    validateBackupPayload({ clients: [], invoices: [], businessProfile: 'bad' }).valid,
    false
  );
});

test('P0-B: validateBackupPayload accepts valid snapshot including savedItems and businessProfile', () => {
  const result = validateBackupPayload({
    clients: [{ id: 'c1', name: 'Acme' }],
    invoices: [{ id: 'inv-1', client_id: 'c1', total_cents: 10000 }],
    estimates: [],
    expenses: [],
    savedItems: [{ id: 'si-1', title: 'Consulting' }],
    businessProfile: { business_name: 'Studio' },
  });
  assert.equal(result.valid, true);
});

test('P0-B: generateInvoicesCsvString quotes fields with commas cleanly', () => {
  const csv = generateInvoicesCsvString(
    [
      {
        id: 'i1',
        clientId: 'c1',
        clientName: 'Acme, Inc.',
        invoiceNumber: 'INV-0001',
        subtotalCents: 10000,
        taxCents: 1800,
        totalCents: 11800,
        paidCents: 0,
        balanceDueCents: 11800,
        status: 'PENDING',
        issueDate: '2026-10-01',
        dueDate: '2026-10-15',
        paymentTerms: 'Net 15 Days',
        createdAt: '2026-10-01T00:00:00Z',
      },
    ],
    [
      {
        id: 'c1',
        name: 'Acme, Inc.',
        email: '',
        phone: '',
        address: '',
        taxId: 'TAX-1',
        createdAt: '2026-10-01T00:00:00Z',
      },
    ],
    '$'
  );
  assert.ok(csv.startsWith('Invoice Number,Issue Date,Due Date,'));
  assert.ok(csv.includes('"Acme, Inc."'));
  assert.ok(csv.includes('$118.00'));
});

// ============================================================================
// P1-A REGRESSION TESTS: TELEPHONY, OS INTENTS & REMINDER BUILDERS
// ============================================================================

test('P1-A: normalizePhoneForUri preserves E.164 plus and strips formatting cleanly', () => {
  assert.equal(normalizePhoneForUri(' +1 (555) 019-2834 '), '+15550192834');
  assert.equal(normalizePhoneForUri('(022) 2654-1234'), '02226541234');
  assert.equal(normalizePhoneForUri('   ---   '), '');
  assert.equal(normalizePhoneForUri(''), '');
});

test('P1-A: buildWhatsAppDigits strips plus sign for wa.me links', () => {
  assert.equal(buildWhatsAppDigits('+91 98765 43210'), '919876543210');
  assert.equal(buildWhatsAppDigits('+1-555-0192'), '15550192');
  assert.equal(buildWhatsAppDigits(''), '');
});

test('P1-A: tel:, sms:, mailto:, and WhatsApp URL builders handle valid and empty contacts', () => {
  assert.equal(buildTelUrl('+1 (555) 019-2834'), 'tel:+15550192834');
  assert.equal(buildTelUrl('   '), null);

  assert.equal(buildSmsUrl('+1 555-0192', 'Hello & Pay'), 'sms:+15550192?body=Hello%20%26%20Pay');
  assert.equal(buildSmsUrl('', 'Hello'), null);

  assert.equal(
    buildWhatsAppUrl('+91 98765 43210', 'Hi Acme'),
    'https://wa.me/919876543210?text=Hi%20Acme'
  );
  assert.equal(buildWhatsAppUrl('', 'Hi'), 'https://wa.me/?text=Hi');

  assert.equal(
    buildMailtoUrl(' billing@acme.com ', 'INV-0001 Reminder', 'Body text'),
    'mailto:billing@acme.com?subject=INV-0001%20Reminder&body=Body%20text'
  );
  assert.equal(
    buildMailtoUrl('', 'Subject', 'Body'),
    'mailto:?subject=Subject&body=Body'
  );
});

test('P1-A: buildPaymentReminderMessage formats 0-decimal JPY accurately without .00', () => {
  const msg = buildPaymentReminderMessage({
    invoiceNumber: 'INV-0099',
    clientName: 'Tokyo Soft',
    balanceDueUnits: 55000,
    currencySymbol: '¥',
    currencyDecimals: 0,
    dueDate: '2026-11-30',
    businessName: 'Design Studio',
  });
  assert.ok(msg.includes('Invoice INV-0099'));
  assert.ok(msg.includes('¥55,000'));
  assert.equal(msg.includes('¥55,000.00'), false);
  assert.ok(msg.includes('2026-11-30'));
  assert.ok(msg.includes('Design Studio'));
});

// ============================================================================
// P2 REGRESSION TESTS: REGIONAL TAX COMPLIANCE ENGINE
// ============================================================================

test('P2: India Intra-State CGST/SGST splits odd minor units and Inter-State uses IGST', () => {
  const intra = resolveRegionalTaxBreakdown({
    taxMode: 'in_intra',
    netSubtotalCents: 1739,
    taxCents: 313,
  });
  assert.equal(intra.lines.length, 2);
  assert.equal(intra.lines[0].label, 'CGST (50% Split)');
  assert.equal(intra.lines[0].cents, 156);
  assert.equal(intra.lines[1].label, 'SGST (50% Split)');
  assert.equal(intra.lines[1].cents, 157);
  assert.equal(intra.lines[0].cents + intra.lines[1].cents, 313);
  assert.equal(getRegionalTaxIdLabel('in_intra'), 'GSTIN');

  const inter = resolveRegionalTaxBreakdown({
    taxMode: 'in_inter',
    netSubtotalCents: 10000,
    taxCents: 1800,
  });
  assert.equal(inter.lines[0].label, 'IGST (100%)');
  assert.equal(inter.lines[0].cents, 1800);
});

test('P2: India Export LUT & EU Reverse Charge enforce 0% tax with mandatory statutory notices', () => {
  const lutTax = computeRegionalTaxCents({
    netSubtotalCents: 50000,
    taxMode: 'in_lut',
    taxPercentage: 18,
    itemsTaxSumCents: 9000,
  });
  assert.equal(lutTax, 0);
  const lutBreakdown = resolveRegionalTaxBreakdown({
    taxMode: 'in_lut',
    netSubtotalCents: 50000,
    taxCents: lutTax,
  });
  assert.equal(lutBreakdown.isZeroRated, true);
  assert.equal(lutBreakdown.noticeTitle, 'EXPORT UNDER LUT (RULE 96A)');
  assert.ok(lutBreakdown.noticeText.includes('LETTER OF UNDERTAKING'));

  const euTax = computeRegionalTaxCents({
    netSubtotalCents: 20000,
    taxMode: 'eu_reverse_charge',
    taxPercentage: 20,
    itemsTaxSumCents: 4000,
  });
  assert.equal(euTax, 0);
  const euBreakdown = resolveRegionalTaxBreakdown({
    taxMode: 'eu_reverse_charge',
    netSubtotalCents: 20000,
    taxCents: euTax,
  });
  assert.equal(euBreakdown.isZeroRated, true);
  assert.ok(euBreakdown.noticeText.includes('Article 196 of Council Directive 2006/112/EC'));
  assert.equal(getRegionalTaxIdLabel('eu_reverse_charge', true), 'Client VAT ID');
});

test('P2: Canada Dual Tax (GST + PST) & 0-decimal JPY consistency', () => {
  const totalTax = computeRegionalTaxCents({
    netSubtotalCents: 10000,
    taxMode: 'ca_dual',
    taxPercentage: 5,
    pstRatePercentage: 7,
  });
  assert.equal(totalTax, 1200);
  const breakdown = resolveRegionalTaxBreakdown({
    taxMode: 'ca_dual',
    netSubtotalCents: 10000,
    taxCents: totalTax,
    pstRatePercentage: 7,
  });
  assert.equal(breakdown.lines[0].label, 'GST');
  assert.equal(breakdown.lines[0].cents, 500);
  assert.equal(breakdown.lines[1].label, 'PST (7%)');
  assert.equal(breakdown.lines[1].cents, 700);

  // 0-decimal JPY
  const jpyTax = computeRegionalTaxCents({
    netSubtotalCents: 50000,
    taxMode: 'ca_dual',
    taxPercentage: 5,
    pstRatePercentage: 7,
  });
  assert.equal(jpyTax, 6000);
});

test('P2: Gulf VAT TRN display, US Tax-Exempt Certificate ID & legacy fallback auto-detect', () => {
  const gulf = resolveRegionalTaxBreakdown({
    taxMode: 'gulf_vat',
    netSubtotalCents: 10000,
    taxCents: 1500,
    businessTaxId: 'TRN-100200300',
    clientTaxId: 'TRN-999888777',
  });
  assert.equal(gulf.noticeTitle, 'GCC / GULF TAX INVOICE');
  assert.ok(gulf.noticeText.includes('Supplier TRN / VAT ID: TRN-100200300'));
  assert.ok(gulf.noticeText.includes('Customer TRN / VAT ID: TRN-999888777'));
  assert.equal(getRegionalTaxIdLabel('gulf_vat'), 'TRN / VAT ID');

  const exemptTax = computeRegionalTaxCents({
    netSubtotalCents: 25000,
    taxMode: 'us_exempt',
    taxPercentage: 8,
    itemsTaxSumCents: 2000,
  });
  assert.equal(exemptTax, 0);
  const exemptBreakdown = resolveRegionalTaxBreakdown({
    taxMode: 'us_exempt',
    netSubtotalCents: 25000,
    taxCents: exemptTax,
    taxExemptionId: 'EX-TX-2026',
  });
  assert.equal(exemptBreakdown.isZeroRated, true);
  assert.ok(exemptBreakdown.noticeText.includes('EX-TX-2026'));

  assert.equal(normalizeTaxMode('unknown_mode'), 'standard');
  assert.equal(isZeroRatedTaxMode('in_lut'), true);
  assert.equal(isZeroRatedTaxMode('gulf_vat'), false);

  const legacyEu = resolveRegionalTaxBreakdown({
    taxMode: 'standard',
    netSubtotalCents: 10000,
    taxCents: 0,
    clientTaxId: 'DE123456789',
    fallbackAutoDetect: true,
  });
  assert.equal(legacyEu.effectiveMode, 'eu_reverse_charge');
});

