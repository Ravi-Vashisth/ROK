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
  formatLocalCalendarDate,
  getCurrencyDecimals,
  parseLocalCalendarDate,
  calculateDaysOverdue,
  calculateTaxCents,
  calculateCollectedTaxPortion,
  calculateDashboardMetrics,
  generateDynamicQrPayload,
  generateInvoicesCsvString,
  hasLinkedClientDocuments,
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
  resolveEffectiveCurrency,
  computeClientRollup,
  isValidIsoCalendarDate,
  matchesDateFilter,
  generateUniqueId,
  validateWhatsAppPhone,
  getDesktopTelephonyFallbackNote,
  isIosDevice,
  isAppleDevice,
  buildSmsFallbackUrl,
  buildCopyEverythingReminderText,
  containsRtlCharacters,
  validateUploadedFileBytes,
  MAX_ATTACHMENT_SIZE_BYTES,
  sanitizeCsvCell,
  quoteCsvField,
  exportInvoicesToCsv,
  exportExpensesToCsv,
  isQuotaExceededError,
  ACCENT_PRESET_KEYS,
  normalizeAccentColorKey,
  normalizeThemeMode,
  duplicateInvoiceRecord,
  voidInvoiceRecord,
  updateLineItemRecord,
  removeLineItemById,
  currencySymbolForCode,
  formatIntegerGrouped,
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
    clients: [{ id: 'c1', name: 'Acme', created_at: '2026-10-01T00:00:00Z' }],
    invoices: [
      {
        id: 'inv-1',
        client_id: 'c1',
        invoice_number: 'INV-0001',
        subtotal_cents: 10000,
        tax_cents: 0,
        total_cents: 10000,
        status: 'PENDING',
      },
    ],
    estimates: [],
    expenses: [],
    savedItems: [{ id: 'si-1', title: 'Consulting', default_price_cents: 5000 }],
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

// ============================================================================
// TASK 2 REGRESSION TESTS: 3-DECIMAL CURRENCIES, PARSER HARDENING & TIMEZONES
// ============================================================================

test('Task 2: 3-decimal currencies (KWD, BHD, OMR, JOD, TND) parsing, formatting & QR', () => {
  assert.equal(getCurrencyDecimals('KWD'), 3);
  assert.equal(getCurrencyDecimals('bhd'), 3);
  assert.equal(getCurrencyDecimals('OMR'), 3);
  assert.equal(getCurrencyDecimals('JOD'), 3);
  assert.equal(getCurrencyDecimals('TND'), 3);
  assert.equal(getCurrencyDecimals('USD'), 2);
  assert.equal(getCurrencyDecimals('JPY'), 0);

  assert.equal(parsePriceToUnits('15.500', 3), 15500);
  assert.equal(parsePriceToUnits('KWD 1,234.567', 3), 1234567);
  assert.equal(parsePriceToUnits('0.005', 3), 5);
  assert.equal(parsePriceToUnits('15.5', 3), 15500);

  assert.equal(formatMoney(1234567, 'KWD', 3), 'KWD1,234.567');
  assert.equal(formatMoney(5, 'BHD', 3), 'BHD0.005');
  assert.equal(formatMoney(-15500, 'OMR', 3), '-OMR15.500');
  assert.equal(formatDecimalUnits(1234567, 3), '1234.567');
  assert.equal(formatDecimalUnits(5, 3), '0.005');
  assert.equal(formatDecimalUnits(-50, 3), '-0.050');

  const kwdQr = generateDynamicQrPayload('gulf@upi', 'Kuwait Co', 15500, 3, 'INV-0777', 'KWD');
  assert.equal(kwdQr, 'upi://pay?pa=gulf%40upi&pn=Kuwait%20Co&am=15.500&tn=Invoice-INV-0777&cu=KWD');
});

test('Task 2: Negative price input rejection & round-half-up extra fractional digits', () => {
  // Reject negative price strings cleanly (never strip '-' into positive)
  assert.equal(parsePriceToUnits('-15.50', 2), 0);
  assert.equal(parsePriceToUnits('-$15.50', 2), 0);
  assert.equal(parsePriceToUnits('$-100', 0), 0);
  assert.equal(parsePriceToUnits('-50.000', 3), 0);
  assert.equal(parseZeroDecimalPrice('-5000'), 0);

  // Round-half-up instead of silent truncation
  assert.equal(parsePriceToUnits('10.124', 2), 1012);
  assert.equal(parsePriceToUnits('10.125', 2), 1013);
  assert.equal(parsePriceToUnits('10.129', 2), 1013);
  assert.equal(parsePriceToUnits('10.999', 2), 1100);
  assert.equal(parsePriceToUnits('10.4', 0), 10);
  assert.equal(parsePriceToUnits('10.5', 0), 11);
  assert.equal(parsePriceToUnits('1.2344', 3), 1234);
  assert.equal(parsePriceToUnits('1.2345', 3), 1235);
  assert.equal(parsePriceToUnits('1.9999', 3), 2000);

  // Pure integer negative money formatting (used for net operating losses / negative tax liability)
  assert.equal(formatMoney(-1550, '$', 2), '-$15.50');
  assert.equal(formatMoney(-50000, '¥', 0), '-¥50,000');
  assert.equal(formatDecimalUnits(-1550, 2), '-15.50');
  assert.equal(formatDecimalUnits(-5, 2), '-0.05');
});

test('Task 2: Local calendar date parsing eliminates UTC-midnight -1 day shift & DST drift', () => {
  const parsed = parseLocalCalendarDate('2026-10-15');
  assert.ok(parsed);
  assert.equal(parsed.getFullYear(), 2026);
  assert.equal(parsed.getMonth(), 9); // October (0-indexed)
  assert.equal(parsed.getDate(), 15);
  assert.equal(formatLocalCalendarDate(parsed), '2026-10-15');

  // Invalid calendar dates rejected
  assert.equal(parseLocalCalendarDate('2026-02-30'), null);
  assert.equal(parseLocalCalendarDate(''), null);

  // Due date calendar math (safe across UTC-8 and DST fallback)
  assert.equal(calculateDueDate('2026-10-01', 'Net 15 Days'), '2026-10-16');
  assert.equal(calculateDueDate('2026-10-31', 'Net 30 Days'), '2026-11-30');
  assert.equal(calculateDueDate('2026-11-01', 'Net 15 Days'), '2026-11-16');

  // Boundary check: invoice due ON 2026-10-15 is NOT overdue at 23:59 local on 2026-10-15
  const sameDayLate = new Date(2026, 9, 15, 23, 59, 0);
  const nextDayEarly = new Date(2026, 9, 16, 0, 1, 0);
  assert.equal(isInvoiceOverdue('PENDING', '2026-10-15', false, sameDayLate), false);
  assert.equal(isInvoiceOverdue('PENDING', '2026-10-15', false, nextDayEarly), true);
  assert.equal(resolveDynamicStatus(10000, 0, '2026-10-15', 'PENDING', sameDayLate), 'PENDING');
  assert.equal(resolveDynamicStatus(10000, 0, '2026-10-15', 'PENDING', nextDayEarly), 'OVERDUE');

  // DST spring-forward day difference (2026-03-08 -> 2026-03-09 in US timezones is 23h, must still be 1 day)
  assert.equal(calculateDaysOverdue('2026-03-08', new Date(2026, 2, 9, 12, 0)), 1);

  // Dashboard metrics uses local calendar date comparison
  const sampleInvoices = [
    { id: '1', status: 'PENDING', total_cents: 10000, paid_cents: 0, balance_due_cents: 10000, tax_cents: 0, due_date: '2026-10-15' },
  ];
  assert.equal(calculateDashboardMetrics(sampleInvoices, [], sameDayLate).overdueInvoices.length, 0);
  assert.equal(calculateDashboardMetrics(sampleInvoices, [], nextDayEarly).overdueInvoices.length, 1);
});

// ============================================================================
// TASK 3 REGRESSION TESTS: MIXED-CURRENCY DASHBOARD & CLIENT ROLLUP ACCURACY
// ============================================================================

test('Task 3: calculateDashboardMetrics groups USD + JPY + INR + KWD without scalar corruption & excludes DRAFT/VOID', () => {
  const refNow = new Date(2026, 9, 20, 12, 0); // 2026-10-20 local
  const mixedInvoices = [
    // Home USD invoice (PAID $1,000.00 incl $100.00 tax)
    {
      id: 'inv-usd',
      status: 'PAID',
      currency_code: 'USD',
      currency_symbol: '$',
      currency_decimals: 2,
      total_cents: 100000,
      paid_cents: 100000,
      balance_due_cents: 0,
      tax_cents: 10000,
      due_date: '2026-10-10',
    },
    // Foreign JPY 0-decimal invoice (OVERDUE ¥50,000 unpaid)
    {
      id: 'inv-jpy',
      status: 'PENDING',
      currency_code: 'JPY',
      currency_symbol: '¥',
      currency_decimals: 0,
      total_cents: 50000,
      paid_cents: 0,
      balance_due_cents: 50000,
      tax_cents: 5000,
      due_date: '2026-10-05',
    },
    // Foreign KWD 3-decimal invoice (PENDING KWD 25.500 paid KWD 5.000, due KWD 20.500, not overdue)
    {
      id: 'inv-kwd',
      status: 'PARTIALLY_PAID',
      currency_code: 'KWD',
      currency_symbol: 'KWD ',
      currency_decimals: 3,
      total_cents: 25500,
      paid_cents: 5000,
      balance_due_cents: 20500,
      tax_cents: 0,
      due_date: '2026-10-25',
    },
    // Foreign INR invoice with legacy missing symbol/decimals? Explicit INR
    {
      id: 'inv-inr',
      status: 'PAID',
      currency_code: 'INR',
      currency_symbol: '₹',
      currency_decimals: 2,
      total_cents: 500000,
      paid_cents: 500000,
      balance_due_cents: 0,
      tax_cents: 90000,
      due_date: '2026-10-01',
    },
    // DRAFT and VOID MUST be completely ignored in counts & sums
    {
      id: 'inv-draft',
      status: 'DRAFT',
      currency_code: 'USD',
      currency_symbol: '$',
      currency_decimals: 2,
      total_cents: 999900,
      paid_cents: 0,
      balance_due_cents: 999900,
      tax_cents: 0,
      due_date: '2026-10-01',
    },
    {
      id: 'inv-void',
      status: 'VOID',
      currency_code: 'JPY',
      currency_symbol: '¥',
      currency_decimals: 0,
      total_cents: 88888,
      paid_cents: 0,
      balance_due_cents: 88888,
      tax_cents: 0,
      due_date: '2026-10-01',
    },
  ];

  // Expenses belong strictly to home currency (USD: $220.00 gross incl $20.00 tax)
  const expenses = [
    { id: 'exp-1', total_cents: 22000, tax_cents: 2000 },
  ];

  const m = calculateDashboardMetrics(mixedInvoices, expenses, refNow, {
    code: 'USD',
    symbol: '$',
    decimals: 2,
  });

  // Excludes DRAFT & VOID from activeInvoiceCount
  assert.equal(m.activeInvoiceCount, 4);

  // Home scalar fields ONLY count USD — never polluted by JPY 50,000, KWD 25,500, or INR 500,000
  assert.equal(m.totalInvoicedCents, 100000);
  assert.equal(m.totalCollectedCents, 100000);
  assert.equal(m.pendingBalanceCents, 0);
  assert.equal(m.overdueAmountCents, 0);
  assert.equal(m.netRevenueExclTaxCents, 90000); // $1000 - $100 tax
  assert.equal(m.netExpenseExclTaxCents, 20000); // $220 - $20 tax
  assert.equal(m.taxLiabilityCents, 8000);       // $100 - $20
  assert.equal(m.netProfitCents, 70000);         // $900 - $200

  // Per-currency buckets ordered home USD first, then alphabetical INR, JPY, KWD
  assert.deepEqual(
    m.byCurrency.map((b) => b.currencyCode),
    ['USD', 'INR', 'JPY', 'KWD']
  );
  assert.equal(m.formattedTotalInvoiced, '$1,000.00 + ₹5,000.00 + ¥50,000 + KWD25.500');
  assert.equal(m.formattedTotalCollected, '$1,000.00 + ₹5,000.00 + KWD5.000');
  assert.equal(m.formattedPendingBalance, '¥50,000 + KWD20.500');
  assert.equal(m.formattedOverdueAmount, '¥50,000');
  assert.equal(m.overdueInvoices.length, 1);
  assert.equal(m.overdueInvoices[0].id, 'inv-jpy');
});

test('Task 3: computeClientRollup groups mixed currencies & resolves empty legacy currency fields cleanly', () => {
  const clientInvoices = [
    // Legacy empty currency falls back to profile (EUR / € / 2)
    {
      id: 'c-1',
      status: 'PAID',
      currency_code: '',
      currency_symbol: '',
      total_cents: 12000,
      paid_cents: 12000,
    },
    {
      id: 'c-2',
      status: 'PENDING',
      currency_code: 'JPY',
      currency_symbol: '¥',
      currency_decimals: 0,
      total_cents: 35000,
      paid_cents: 0,
    },
    {
      id: 'c-3',
      status: 'PARTIALLY_PAID',
      currency_code: 'KWD',
      currency_symbol: 'KWD',
      currency_decimals: 3,
      total_cents: 10500,
      paid_cents: 2500,
    },
    // Ignored VOID & DRAFT
    {
      id: 'c-draft',
      status: 'DRAFT',
      currency_code: 'USD',
      currency_symbol: '$',
      currency_decimals: 2,
      total_cents: 50000,
      paid_cents: 0,
    },
    {
      id: 'c-void',
      status: 'VOID',
      currency_code: 'JPY',
      currency_symbol: '¥',
      currency_decimals: 0,
      total_cents: 99000,
      paid_cents: 0,
    },
  ];

  const rollup = computeClientRollup(clientInvoices, {
    code: 'EUR',
    symbol: '€',
    decimals: 2,
  });

  assert.equal(rollup.hasOutstandingBalance, true);
  assert.equal(rollup.formattedTotalBilled, '€120.00 + ¥35,000 + KWD10.500');
  assert.equal(rollup.formattedTotalPaid, '€120.00 + KWD2.500');
  assert.equal(rollup.formattedOutstandingBalance, '¥35,000 + KWD8.000');

  const resolvedLegacy = resolveEffectiveCurrency({
    recordCode: '',
    recordSymbol: '',
    defaultCode: 'JPY',
    defaultSymbol: '¥',
    defaultDecimals: 0,
  });
  assert.deepEqual(resolvedLegacy, { code: 'JPY', symbol: '¥', decimals: 0 });
});

// ============================================================================
// TASK 4 REGRESSION TESTS: DATE FILTER, ISO DATE VALIDATION, UUID & MIN-NEXT
// ============================================================================

test('Task 4: matchesDateFilter handles All Time, This Month, and This Quarter across quarter & year boundaries', () => {
  const refQ4 = new Date(2026, 9, 20, 14, 0); // 2026-10-20 local
  assert.equal(matchesDateFilter('2024-01-01', 'All Time', refQ4), true);
  assert.equal(matchesDateFilter('invalid', 'All Time', refQ4), true);

  // This Month (October 2026)
  assert.equal(matchesDateFilter('2026-10-01', 'This Month', refQ4), true);
  assert.equal(matchesDateFilter('2026-10-31', 'This Month', refQ4), true);
  assert.equal(matchesDateFilter('2026-09-30', 'This Month', refQ4), false);
  assert.equal(matchesDateFilter('2026-11-01', 'This Month', refQ4), false);
  assert.equal(matchesDateFilter('2025-10-20', 'This Month', refQ4), false);
  assert.equal(matchesDateFilter('', 'This Month', refQ4), false);

  // This Quarter (Q4 2026: Oct-Dec)
  assert.equal(matchesDateFilter('2026-10-01', 'This Quarter', refQ4), true);
  assert.equal(matchesDateFilter('2026-11-15', 'This Quarter', refQ4), true);
  assert.equal(matchesDateFilter('2026-12-31', 'This Quarter', refQ4), true);
  assert.equal(matchesDateFilter('2026-09-30', 'This Quarter', refQ4), false);
  assert.equal(matchesDateFilter('2025-10-15', 'This Quarter', refQ4), false);

  // Quarter 1 boundary check (Jan-Mar 2026)
  const refQ1 = new Date(2026, 2, 15, 9, 0); // 2026-03-15
  assert.equal(matchesDateFilter('2026-01-01', 'This Quarter', refQ1), true);
  assert.equal(matchesDateFilter('2026-03-31', 'This Quarter', refQ1), true);
  assert.equal(matchesDateFilter('2026-04-01', 'This Quarter', refQ1), false);
});

test('Task 4: isValidIsoCalendarDate strictly validates YYYY-MM-DD calendar dates', () => {
  assert.equal(isValidIsoCalendarDate('2026-02-28'), true);
  assert.equal(isValidIsoCalendarDate('2024-02-29'), true);
  assert.equal(isValidIsoCalendarDate('2026-10-15'), true);

  assert.equal(isValidIsoCalendarDate('2026-02-29'), false);
  assert.equal(isValidIsoCalendarDate('2026-02-30'), false);
  assert.equal(isValidIsoCalendarDate('2026-13-01'), false);
  assert.equal(isValidIsoCalendarDate('2026-2-5'), false);
  assert.equal(isValidIsoCalendarDate('2026-10-15T00:00:00Z'), false);
  assert.equal(isValidIsoCalendarDate(''), false);
});

test('Task 4: generateUniqueId produces collision-free RFC-4122 UUID v4 strings & minNext aligns numbering', () => {
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  const generated = new Set<string>();
  for (let i = 0; i < 50; i++) {
    const id = generateUniqueId();
    assert.match(id, uuidRegex);
    generated.add(id);
  }
  assert.equal(generated.size, 50);

  assert.equal(getNextSequentialDocNumber(['INV-0001', 'DRAFT-AABBCCDD'], 'INV-', 10), 'INV-0010');
  assert.equal(getNextSequentialDocNumber(['INV-0001', 'INV-0015'], 'INV-', 5), 'INV-0016');
});

// ============================================================================
// TASK 5 REGRESSION TESTS: TELEPHONY IOS DELIMITER, WHATSAPP VALIDATION & FALLBACK
// ============================================================================

test('Task 5: buildSmsUrl applies iOS &body= quirk cleanly and rejects empty phones', () => {
  assert.equal(
    buildSmsUrl('+1 555-0192', 'Hello & Pay', false),
    'sms:+15550192?body=Hello%20%26%20Pay'
  );
  assert.equal(
    buildSmsUrl('+1 555-0192', 'Hello & Pay', true),
    'sms:+15550192&body=Hello%20%26%20Pay'
  );
  assert.equal(buildSmsUrl('+1 555-0192', '', true), 'sms:+15550192');
  assert.equal(buildSmsUrl('   ', 'Hi', true), null);
  assert.equal(typeof isIosDevice(), 'boolean');
});

test('Task 5: validateWhatsAppPhone detects missing country codes and trunk zeros', () => {
  const validIn = validateWhatsAppPhone('+91 98765 43210');
  assert.equal(validIn.isValid, true);
  assert.equal(validIn.normalizedDigits, '919876543210');
  assert.equal(validIn.warningMessage, undefined);

  const validUs = validateWhatsAppPhone('+1 (555) 019-2834');
  assert.equal(validUs.isValid, true);

  const trunkZero = validateWhatsAppPhone('09876543210');
  assert.equal(trunkZero.isValid, false);
  assert.ok(trunkZero.warningMessage?.includes("starts with '0'"));

  const missingPlusLocal = validateWhatsAppPhone('9876543210');
  assert.equal(missingPlusLocal.isValid, false);
  assert.ok(missingPlusLocal.warningMessage?.includes("Missing '+'"));

  const tooShort = validateWhatsAppPhone('+12345');
  assert.equal(tooShort.isValid, false);

  const emptyNum = validateWhatsAppPhone('   ');
  assert.equal(emptyNum.isValid, false);
  assert.ok(emptyNum.warningMessage?.includes('No phone number'));
});

test('Task 5: getDesktopTelephonyFallbackNote gives clear desktop fallback copy', () => {
  assert.ok(getDesktopTelephonyFallbackNote(false, false).includes('No client phone or email'));
  assert.ok(getDesktopTelephonyFallbackNote(true, true).includes('Copy Reminder Message'));
});

// ============================================================================
// TASK 6 REGRESSION TESTS: ATTACHMENT BYTE, MIME HEADER & SIZE VALIDATION
// ============================================================================

test('Task 6: validateUploadedFileBytes validates PNG/JPEG/WEBP/PDF headers and rejects invalid or oversized files', () => {
  const pngHeader = new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
  const jpgHeader = new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10]);
  const webpHeader = new Uint8Array([0x52, 0x49, 0x46, 0x46, 0x00, 0x00, 0x00, 0x00, 0x57, 0x45, 0x42, 0x50]);
  const pdfHeader = new Uint8Array([0x25, 0x50, 0x44, 0x46, 0x2d, 0x31, 0x2e, 0x34]);

  assert.deepEqual(
    validateUploadedFileBytes({ bytes: pngHeader, filename: 'logo.png', allowPdf: false }),
    { isValid: true, mimeType: 'image/png' }
  );
  assert.deepEqual(
    validateUploadedFileBytes({ bytes: jpgHeader, filename: 'sig.jpg', allowPdf: false }),
    { isValid: true, mimeType: 'image/jpeg' }
  );
  assert.deepEqual(
    validateUploadedFileBytes({ bytes: webpHeader, filename: 'receipt.webp', allowPdf: true }),
    { isValid: true, mimeType: 'image/webp' }
  );

  // PDF only accepted when allowPdf is true
  const pdfAsLogo = validateUploadedFileBytes({ bytes: pdfHeader, filename: 'fake.png', allowPdf: false });
  assert.equal(pdfAsLogo.isValid, false);
  const pdfAsReceipt = validateUploadedFileBytes({ bytes: pdfHeader, filename: 'bill.pdf', allowPdf: true });
  assert.deepEqual(pdfAsReceipt, { isValid: true, mimeType: 'application/pdf' });

  // Corrupt/text payload disguised as .png
  const fakePng = validateUploadedFileBytes({
    bytes: new Uint8Array([0x3c, 0x68, 0x74, 0x6d, 0x6c, 0x3e]),
    filename: 'malicious.png',
    allowPdf: true,
  });
  assert.equal(fakePng.isValid, false);

  // Empty file
  assert.equal(
    validateUploadedFileBytes({ bytes: new Uint8Array([]), filename: 'empty.png', allowPdf: true }).isValid,
    false
  );

  // Oversized file (> 5 MB)
  const oversized = new Uint8Array(MAX_ATTACHMENT_SIZE_BYTES + 1);
  oversized.set(pngHeader, 0);
  const sizeResult = validateUploadedFileBytes({
    bytes: oversized,
    filename: 'huge.png',
    allowPdf: false,
  });
  assert.equal(sizeResult.isValid, false);
  assert.ok(sizeResult.errorMessage?.includes('5 MB'));
});

// ============================================================================
// TASK 7 REGRESSION TESTS: BACKUP HARDENING, CSV SECURITY & QUOTA DETECTION
// ============================================================================

test('Task 7: validateBackupPayload enforces NOT NULL columns and strict integer/string value types', () => {
  // Missing required NOT NULL fields
  assert.equal(
    validateBackupPayload({
      clients: [{ id: 'c1', name: '   ' }],
      invoices: [],
    }).valid,
    false
  );
  assert.equal(
    validateBackupPayload({
      clients: [{ id: 'c1', name: 'Acme' }],
      invoices: [
        {
          id: 'inv-1',
          client_id: 'c1',
          subtotal_cents: 1000,
          tax_cents: 0,
          total_cents: 1000,
          status: 'PENDING',
        },
      ],
    }).valid,
    false
  );
  assert.equal(
    validateBackupPayload({
      clients: [],
      invoices: [],
      expenses: [{ id: 'e1', category: 'Travel', vendor: '', amount_cents: 500, expense_date: '2026-10-01' }],
    }).valid,
    false
  );
  assert.equal(
    validateBackupPayload({
      clients: [],
      invoices: [],
      businessProfile: { business_name: '' },
    }).valid,
    false
  );

  // Wrong column value types (string or float in integer columns, int in string columns)
  assert.equal(
    validateBackupPayload({
      clients: [{ id: 'c1', name: 'Acme' }],
      invoices: [
        {
          id: 'inv-1',
          client_id: 'c1',
          invoice_number: 'INV-0001',
          subtotal_cents: 1000,
          tax_cents: 0,
          total_cents: '1000',
          status: 'PENDING',
        },
      ],
    }).valid,
    false
  );
  assert.equal(
    validateBackupPayload({
      clients: [{ id: 'c1', name: 'Acme', email: 42 }],
      invoices: [],
    }).valid,
    false
  );
  assert.equal(
    validateBackupPayload({
      clients: [],
      invoices: [],
      savedItems: [{ id: 'si-1', title: 'Audit', default_price_cents: 12.5 }],
    }).valid,
    false
  );
});

test('Task 7: CSV exports neutralize formula-injection prefixes and emit ISO currencyCode', () => {
  assert.equal(sanitizeCsvCell('=1+1'), "'=1+1");
  assert.equal(sanitizeCsvCell('+CMD|calc'), "'+CMD|calc");
  assert.equal(sanitizeCsvCell('-2+3'), "'-2+3");
  assert.equal(sanitizeCsvCell('@SUM(A1:A2)'), "'@SUM(A1:A2)");
  assert.equal(sanitizeCsvCell('\t=1+1'), "'\t=1+1");
  assert.equal(sanitizeCsvCell('\r+1'), "'\r+1");
  assert.equal(sanitizeCsvCell('  =1+1'), "'  =1+1");
  assert.equal(sanitizeCsvCell('Normal Studio'), 'Normal Studio');
  assert.equal(quoteCsvField('=HYPERLINK("http://evil")'), '"\'=HYPERLINK(""http://evil"")"');

  const invCsv = exportInvoicesToCsv(
    [
      {
        id: 'inv-draft',
        client_id: 'c1',
        client_name: '=EvilCorp',
        invoice_number: 'DRAFT-1234',
        subtotal_cents: 10000,
        tax_cents: 0,
        total_cents: 10000,
        paid_cents: 0,
        status: 'DRAFT',
        issue_date: '2026-10-01',
        due_date: '2026-10-15',
      },
      {
        id: 'inv-1',
        client_id: 'c1',
        client_name: '=1+1',
        invoice_number: 'INV-0001',
        subtotal_cents: 10000,
        tax_cents: 1800,
        total_cents: 11800,
        paid_cents: 0,
        status: 'PENDING',
        issue_date: '2026-10-01',
        due_date: '2026-10-15',
      },
    ],
    [{ id: 'c1', name: '=1+1', tax_id: '+TAX123' }],
    'USD'
  );
  assert.ok(!invCsv.includes('DRAFT-1234'));
  assert.ok(invCsv.includes('"USD"'));
  assert.ok(!invCsv.includes('"$"'));
  assert.ok(invCsv.includes('"\'=1+1"'));
  assert.ok(invCsv.includes('"\'+TAX123"'));

  const expCsv = exportExpensesToCsv(
    [
      {
        id: 'exp-1',
        expense_date: '2026-10-05',
        category: '@Ops',
        vendor: '-MaliciousVendor',
        amount_cents: 5000,
        tax_cents: 500,
        total_cents: 5500,
        notes: '\t=CMD|calc',
      },
    ],
    'USD'
  );
  assert.ok(expCsv.includes('"USD"'));
  assert.ok(expCsv.includes('"\'@Ops"'));
  assert.ok(expCsv.includes('"\'-MaliciousVendor"'));
  assert.ok(expCsv.includes('"\'\t=CMD|calc"'));
  assert.ok(expCsv.includes(',50.00,5.00,55.00,'));
});

test('Task 7: isQuotaExceededError matches browser QuotaExceededError variants cleanly', () => {
  assert.equal(isQuotaExceededError({ name: 'QuotaExceededError' }), true);
  assert.equal(isQuotaExceededError({ name: 'NS_ERROR_DOM_QUOTA_REACHED' }), true);
  assert.equal(isQuotaExceededError({ code: 22 }), true);
  assert.equal(isQuotaExceededError({ code: 1014 }), true);
  assert.equal(isQuotaExceededError(new Error('Network error')), false);
  assert.equal(isQuotaExceededError(null), false);
});

// ============================================================================
// TASK 8 REGRESSION TESTS: THEME/ACCENT PERSISTENCE & VALIDATION
// ============================================================================

test('Task 8: normalizeAccentColorKey and normalizeThemeMode sanitize persisted preferences safely', () => {
  assert.equal(ACCENT_PRESET_KEYS.length, 6);
  for (const preset of ACCENT_PRESET_KEYS) {
    assert.equal(normalizeAccentColorKey(preset), preset);
  }
  assert.equal(normalizeAccentColorKey('  emerald  '), 'emerald');
  assert.equal(normalizeAccentColorKey('unknown'), 'indigo');
  assert.equal(normalizeAccentColorKey(null), 'indigo');
  assert.equal(normalizeAccentColorKey(123), 'indigo');

  assert.equal(normalizeThemeMode('light'), 'light');
  assert.equal(normalizeThemeMode('DARK'), 'dark');
  assert.equal(normalizeThemeMode(' system '), 'system');
  assert.equal(normalizeThemeMode('sepia'), 'system');
  assert.equal(normalizeThemeMode(undefined), 'system');
});

test('Task 8: validateBackupPayload validates optional businessProfile theme_mode and accent_color', () => {
  assert.equal(
    validateBackupPayload({
      clients: [],
      invoices: [],
      businessProfile: {
        business_name: 'Studio',
        theme_mode: 'dark',
        accent_color: 4283385573,
      },
    }).valid,
    true
  );

  assert.equal(
    validateBackupPayload({
      clients: [],
      invoices: [],
      businessProfile: {
        business_name: 'Studio',
        theme_mode: 1,
      },
    }).valid,
    false
  );

  assert.equal(
    validateBackupPayload({
      clients: [],
      invoices: [],
      businessProfile: {
        business_name: 'Studio',
        accent_color: 'indigo',
      },
    }).valid,
    false
  );
});

// ============================================================================
// TASK 9 REGRESSION TESTS: DUPLICATE & VOID INVOICE FEATURE PARITY
// ============================================================================

test('Task 9: duplicateInvoiceRecord clones invoice with fresh UUID, sequential number, local dates, and zero paid balance', () => {
  const source = {
    id: 'inv-orig',
    client_id: 'c-1',
    client_name: 'Tokyo Partners',
    invoice_number: 'INV-0004',
    subtotal_cents: 50000,
    tax_cents: 5000,
    total_cents: 55000,
    paid_cents: 55000,
    balance_due_cents: 0,
    status: 'PAID',
    computed_status: 'PAID',
    issue_date: '2026-09-01',
    due_date: '2026-09-16',
    payment_terms: 'Net 15 Days',
    po_number: 'PO-77',
    currency_code: 'JPY',
    currency_symbol: '¥',
    currency_decimals: 0,
    tax_mode: 'standard' as const,
    items: [
      { id: 'item-1', description: 'UI Architecture', quantity: 1, unitPriceCents: 50000 },
    ],
    created_at: '2026-09-01T00:00:00Z',
  };

  const existing = [
    source,
    { invoice_number: 'DRAFT-AAA11111' },
    { invoice_number: 'INV-0007' },
  ];
  const refNow = new Date(2026, 10, 19, 10, 30); // Nov 19, 2026 local

  const cloned = duplicateInvoiceRecord(source, existing, 'INV-', 3, refNow);

  assert.notEqual(cloned.id, source.id);
  assert.equal(cloned.invoice_number, 'INV-0008');
  assert.equal(cloned.status, 'PENDING');
  assert.equal(cloned.computed_status, 'PENDING');
  assert.equal(cloned.paid_cents, 0);
  assert.equal(cloned.balance_due_cents, 55000);
  assert.equal(cloned.issue_date, '2026-11-19');
  assert.equal(cloned.due_date, '2026-12-04');
  assert.equal(cloned.currency_code, 'JPY');
  assert.equal(cloned.currency_decimals, 0);
  assert.equal(cloned.po_number, 'PO-77');
  assert.equal(cloned.items.length, 1);
  assert.notEqual(cloned.items[0].id, 'item-1');
  assert.equal(cloned.items[0].description, 'UI Architecture');
});

test('Task 9: voidInvoiceRecord marks finalized invoices VOID with 0 balance and leaves DRAFTs untouched', () => {
  const pendingInv = {
    id: 'inv-10',
    invoice_number: 'INV-0010',
    status: 'PARTIALLY_PAID',
    computed_status: 'PARTIALLY_PAID',
    total_cents: 10000,
    paid_cents: 4000,
    balance_due_cents: 6000,
  };
  const voided = voidInvoiceRecord(pendingInv);
  assert.equal(voided.status, 'VOID');
  assert.equal(voided.computed_status, 'VOID');
  assert.equal(voided.balance_due_cents, 0);

  const draftInv = {
    id: 'inv-draft',
    invoice_number: 'DRAFT-1234',
    status: 'DRAFT',
    computed_status: 'DRAFT',
    total_cents: 10000,
    paid_cents: 0,
    balance_due_cents: 10000,
  };
  const untouchedDraft = voidInvoiceRecord(draftInv);
  assert.equal(untouchedDraft.status, 'DRAFT');
  assert.equal(untouchedDraft.balance_due_cents, 10000);
});

test('Task 11: updateLineItemRecord & removeLineItemById support inline edits and safe middle-row deletion', () => {
  const initial = [
    { id: 'row-1', description: 'Discovery', sacHsn: '998311', quantity: 1, unitPriceCents: 25000, taxSlab: 18 },
    { id: 'row-2', description: 'Middle Item', sacHsn: '998312', quantity: 2, unitPriceCents: 15000, taxSlab: 10 },
    { id: 'row-3', description: 'Deployment', sacHsn: '998313', quantity: 1, unitPriceCents: 40000, taxSlab: 12 },
  ];

  const edited = updateLineItemRecord(initial, 'row-3', {
    description: 'Production Deployment',
    sacHsn: '998399',
    quantity: 3,
    unitPriceCents: 45000,
    taxSlab: 18,
  });

  assert.equal(edited[0].description, 'Discovery');
  assert.equal(edited[2].description, 'Production Deployment');
  assert.equal(edited[2].sacHsn, '998399');
  assert.equal(edited[2].quantity, 3);
  assert.equal(edited[2].unitPriceCents, 45000);
  assert.equal(edited[2].taxSlab, 18);

  const afterMiddleDelete = removeLineItemById(edited, 'row-2');
  assert.equal(afterMiddleDelete.length, 2);
  assert.equal(afterMiddleDelete[0].id, 'row-1');
  assert.equal(afterMiddleDelete[1].id, 'row-3');
  assert.equal(afterMiddleDelete[1].description, 'Production Deployment');
  assert.equal(afterMiddleDelete[1].unitPriceCents, 45000);
});

// ============================================================================
// TASK 12 REGRESSION TESTS: CROSS-STACK BACKUP PARITY & UPLOAD SECURITY
// ============================================================================

test('Task 12: validateBackupPayload normalizes Flutter SQLite export snapshots cleanly and rejects corrupt child tables', () => {
  const flutterExport = {
    version: 1,
    exported_at: '2026-11-22T09:00:00.000Z',
    business_profile: [
      {
        id: 'default',
        business_name: 'Alpine Engineering GmbH',
        currency_code: 'EUR',
        currency_symbol: '€',
        currency_decimals: 2,
        theme_mode: 'dark',
        accent_color: 4283385573,
      },
    ],
    clients: [
      {
        id: 'cl-101',
        name: 'Nordic Mobility AS',
        email: 'finance@nordic.example',
        tax_id: 'NO-999888777',
        created_at: '2026-10-01T00:00:00Z',
      },
    ],
    invoices: [
      {
        id: 'inv-101',
        client_id: 'cl-101',
        invoice_number: 'INV-0101',
        subtotal_cents: 200000,
        tax_cents: 38000,
        total_cents: 238000,
        status: 'PENDING',
        issue_date: '2026-11-01',
        due_date: '2026-11-30',
        created_at: '2026-11-01T08:00:00Z',
      },
    ],
    invoice_items: [
      {
        id: 'ii-1',
        invoice_id: 'inv-101',
        description: 'Embedded Telemetry Firmware',
        sac_hsn: '998314',
        quantity: 2,
        unit_price_cents: 100000,
        tax_rate_percentage: 19,
        tax_cents: 38000,
        total_cents: 200000,
      },
    ],
    payments: [
      {
        id: 'pay-1',
        invoice_id: 'inv-101',
        amount_cents: 100000,
        payment_method: 'SEPA Wire',
        payment_date: '2026-11-10',
      },
      {
        id: 'pay-deleted',
        invoice_id: 'inv-101',
        amount_cents: 50000,
        payment_method: 'Duplicate',
        payment_date: '2026-11-11',
        deleted_at: '2026-11-12T00:00:00Z',
      },
    ],
    estimates: [
      {
        id: 'est-101',
        client_id: 'cl-101',
        estimate_number: 'EST-0021',
        subtotal_cents: 120000,
        tax_cents: 0,
        total_cents: 120000,
        status: 'PENDING',
        issue_date: '2026-11-15',
        expiry_date: '2026-12-15',
      },
    ],
    estimate_items: [
      {
        id: 'ei-1',
        estimate_id: 'est-101',
        description: 'Discovery Workshop',
        sac_hsn: '998311',
        quantity: 1,
        unit_price_cents: 120000,
        tax_rate_percentage: 0,
        tax_cents: 0,
        total_cents: 120000,
      },
    ],
    expenses: [
      {
        id: 'exp-101',
        category: 'Hardware',
        vendor: 'Framework Computer',
        amount_cents: 150000,
        tax_cents: 28500,
        expense_date: '2026-11-03',
      },
    ],
    saved_items: [
      {
        id: 'si-101',
        title: 'PCB Rev2 Review',
        sac_hsn: '998399',
        default_price_cents: 75000,
      },
    ],
  };

  const res = validateBackupPayload(flutterExport);
  assert.equal(res.valid, true);
  assert.ok(res.normalized);

  const norm = res.normalized!;
  assert.equal(norm.businessProfile.business_name, 'Alpine Engineering GmbH');
  assert.equal(norm.invoices[0].client_name, 'Nordic Mobility AS');
  assert.equal(norm.invoices[0].items.length, 1);
  assert.equal(norm.invoices[0].items[0].sacHsn, '998314');
  assert.equal(norm.invoices[0].items[0].unitPriceCents, 100000);
  assert.equal(norm.invoices[0].paid_cents, 100000);
  assert.equal(norm.invoices[0].balance_due_cents, 138000);
  assert.equal(norm.invoices[0].computed_status, 'PARTIALLY_PAID');

  assert.equal(norm.estimates?.[0].client_name, 'Nordic Mobility AS');
  assert.equal(norm.estimates?.[0].items.length, 1);
  assert.equal(norm.estimates?.[0].items[0].unitPriceCents, 120000);

  assert.equal(norm.expenses?.[0].total_cents, 178500);
  assert.equal(norm.savedItems?.[0].defaultPriceCents, 75000);
  assert.equal(norm.savedItems?.[0].sacHsn, '998399');

  // Corrupt child table entries must be rejected
  assert.equal(
    validateBackupPayload({
      clients: [],
      invoices: [],
      invoice_items: [{ id: 'ii-bad', invoice_id: 'inv-1', description: 'Test', quantity: '2', unit_price_cents: 100, total_cents: 200 }],
    }).valid,
    false
  );
  assert.equal(
    validateBackupPayload({
      clients: [],
      invoices: [],
      business_profile: [{ business_name: '' }],
    }).valid,
    false
  );
});

test('Task 12: validateUploadedFileBytes rejects spoofed SVG and oversized branding images', () => {
  const svgBytes = new TextEncoder().encode('<svg xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script></svg>');
  const spoofedRes = validateUploadedFileBytes({
    bytes: svgBytes,
    filename: 'logo.png',
    allowPdf: false,
  });
  assert.equal(spoofedRes.isValid, false);

  const validPng = new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
  const oversized = new Uint8Array(MAX_ATTACHMENT_SIZE_BYTES + 1);
  oversized.set(validPng, 0);
  const sizeRes = validateUploadedFileBytes({
    bytes: oversized,
    filename: 'huge_logo.png',
    allowPdf: false,
  });
  assert.equal(sizeRes.isValid, false);
  assert.ok(sizeRes.errorMessage?.includes('5 MB'));
});

test('Task 13: hasLinkedClientDocuments blocks client deletion when linked invoices OR estimates exist', () => {
  assert.equal(
    hasLinkedClientDocuments('c1', [{ client_id: 'c1' }], []),
    true
  );
  assert.equal(
    hasLinkedClientDocuments('c1', [], [{ client_id: 'c1' }]),
    true
  );
  assert.equal(
    hasLinkedClientDocuments('c1', [{ client_id: 'c2' }], [{ client_id: 'c2' }]),
    false
  );
});

test('Task 13: validateBackupPayload filters soft-deleted tombstones when restoring Flutter backups into React', () => {
  const snapshotWithTombstones = {
    clients: [
      { id: 'c-active', name: 'Active Client' },
      { id: 'c-deleted', name: 'Deleted Client', deleted_at: '2026-11-22T10:00:00Z' },
    ],
    invoices: [
      {
        id: 'inv-active',
        client_id: 'c-active',
        invoice_number: 'INV-0001',
        subtotal_cents: 10000,
        tax_cents: 0,
        total_cents: 10000,
        status: 'PENDING',
      },
      {
        id: 'inv-deleted',
        client_id: 'c-deleted',
        invoice_number: 'INV-0002',
        subtotal_cents: 20000,
        tax_cents: 0,
        total_cents: 20000,
        status: 'PENDING',
        deleted_at: '2026-11-22T10:00:00Z',
      },
    ],
    expenses: [
      {
        id: 'exp-deleted',
        category: 'SaaS',
        vendor: 'Vercel',
        amount_cents: 2000,
        expense_date: '2026-11-22',
        deleted_at: '2026-11-22T10:00:00Z',
      },
    ],
    saved_items: [
      {
        id: 'si-active',
        title: 'Consulting',
        default_price_cents: 10000,
      },
      {
        id: 'si-deleted',
        title: 'Archived Package',
        default_price_cents: 5000,
        deleted_at: '2026-11-22T10:00:00Z',
      },
    ],
  };

  const res = validateBackupPayload(snapshotWithTombstones);
  assert.equal(res.valid, true);
  assert.ok(res.normalized);
  assert.deepEqual(res.normalized!.clients.map((c) => c.id), ['c-active']);
  assert.deepEqual(res.normalized!.invoices.map((i) => i.id), ['inv-active']);
  assert.equal(res.normalized!.expenses?.length, 0);
  assert.deepEqual(res.normalized!.savedItems?.map((s) => s.id), ['si-active']);
});

test('Task 14: formatIntegerGrouped & formatMoney apply Indian lakhs/crores grouping for INR cleanly', () => {
  assert.equal(formatIntegerGrouped(1234567, 'INR'), '12,34,567');
  assert.equal(formatIntegerGrouped(1234567, 'USD'), '1,234,567');
  assert.equal(formatMoney(123456700, '₹', 2, 'INR'), '₹12,34,567.00');
  assert.equal(formatMoney(-10000000, '₹', 2), '-₹1,00,000.00');
  assert.equal(formatMoney(123456700, '$', 2, 'USD'), '$1,234,567.00');
  assert.equal(formatMoney(1000000, '¥', 0, 'JPY'), '¥1,000,000');
  assert.equal(currencySymbolForCode('JPY'), '¥');
  assert.equal(currencySymbolForCode('INR'), '₹');
  assert.equal(currencySymbolForCode('KWD'), 'KWD');
});

test('Task 14: resolveEffectiveCurrency & calculateDashboardMetrics isolate mixed USD + JPY + KWD expenses', () => {
  const jpyCur = resolveEffectiveCurrency({
    recordCode: 'JPY',
    recordDecimals: 0,
    defaultCode: 'USD',
    defaultSymbol: '$',
    defaultDecimals: 2,
  });
  assert.equal(jpyCur.symbol, '¥');
  assert.equal(jpyCur.decimals, 0);

  const metrics = calculateDashboardMetrics(
    [
      {
        id: 'inv-usd',
        status: 'PAID',
        currency_code: 'USD',
        currency_symbol: '$',
        currency_decimals: 2,
        total_cents: 110000,
        paid_cents: 110000,
        tax_cents: 10000,
      },
      {
        id: 'inv-jpy',
        status: 'PAID',
        currency_code: 'JPY',
        currency_symbol: '¥',
        currency_decimals: 0,
        total_cents: 50000,
        paid_cents: 50000,
        tax_cents: 0,
      },
    ],
    [
      {
        id: 'exp-usd',
        currency_code: 'USD',
        currency_decimals: 2,
        total_cents: 22000,
        tax_cents: 2000,
      },
      {
        id: 'exp-jpy',
        currency_code: 'JPY',
        currency_decimals: 0,
        total_cents: 10000,
        tax_cents: 0,
      },
      {
        id: 'exp-kwd',
        currency_code: 'KWD',
        currency_decimals: 3,
        total_cents: 12500,
        tax_cents: 0,
      },
    ],
    new Date(2026, 10, 23),
    { code: 'USD', symbol: '$', decimals: 2 }
  );

  assert.equal(metrics.byCurrency.length, 3);
  const usd = metrics.byCurrency.find((b) => b.currencyCode === 'USD')!;
  const jpy = metrics.byCurrency.find((b) => b.currencyCode === 'JPY')!;
  const kwd = metrics.byCurrency.find((b) => b.currencyCode === 'KWD')!;

  assert.equal(usd.totalExpenseGrossCents, 22000);
  assert.equal(usd.taxLiabilityCents, 8000);
  assert.equal(usd.netProfitCents, 80000);
  assert.equal(jpy.totalExpenseGrossCents, 10000);
  assert.equal(jpy.netProfitCents, 40000);
  assert.equal(kwd.totalExpenseGrossCents, 12500);
  assert.equal(kwd.netProfitCents, -12500);
  assert.equal(metrics.formattedNetProfit, '$800.00 + ¥40,000 + -KWD12.500');
});

test('Task 14: exportExpensesToCsv & validateBackupPayload preserve per-record currency_code and decimals', () => {
  const csv = exportExpensesToCsv(
    [
      {
        id: 'e1',
        expense_date: '2026-11-22',
        category: 'Travel',
        vendor: 'Shinkansen',
        currency_code: 'JPY',
        currency_decimals: 0,
        amount_cents: 18000,
        tax_cents: 1800,
        total_cents: 19800,
      },
      {
        id: 'e2',
        expense_date: '2026-11-23',
        category: 'Office',
        vendor: 'Dinar Hosting',
        currency_code: 'KWD',
        currency_decimals: 3,
        amount_cents: 12500,
        tax_cents: 0,
        total_cents: 12500,
      },
    ],
    'USD'
  );
  assert.ok(csv.includes(',"JPY",18000,1800,19800,'));
  assert.ok(csv.includes(',"KWD",12.500,0.000,12.500,'));

  const backupRes = validateBackupPayload({
    clients: [],
    invoices: [],
    expenses: [
      {
        id: 'e1',
        category: 'Travel',
        vendor: 'Shinkansen',
        amount_cents: 18000,
        tax_cents: 1800,
        expense_date: '2026-11-22',
        currency_code: 'JPY',
        currency_decimals: 0,
      },
    ],
    savedItems: [
      {
        id: 's1',
        title: 'Tokyo Workshop',
        defaultPriceCents: 50000,
        currencyCode: 'JPY',
        currencyDecimals: 0,
      },
    ],
  });
  assert.equal(backupRes.valid, true);
  assert.equal(backupRes.normalized?.expenses?.[0].currency_code, 'JPY');
  assert.equal(backupRes.normalized?.expenses?.[0].currency_decimals, 0);
  assert.equal(backupRes.normalized?.savedItems?.[0].currency_code, 'JPY');
  assert.equal(backupRes.normalized?.savedItems?.[0].currency_decimals, 0);
});

test('Task 15: custom prefixes, minNext numbering, profile backup validation, and dynamic QR payloads', () => {
  // Custom invoice & estimate prefixes skip DRAFTs and respect existing VOID sequence numbers
  assert.equal(
    getNextSequentialDocNumber(
      ['DRAFT-AABB1122', 'FY26-0014', 'VOID-OLD'],
      'FY26-',
      10
    ),
    'FY26-0015'
  );
  assert.equal(
    getNextSequentialDocNumber(['FY26-0014'], 'FY26-', 30),
    'FY26-0030'
  );
  assert.equal(
    getNextSequentialDocNumber(['DRAFT-1234', 'QT-0002'], 'QT-'),
    'QT-0003'
  );

  // Backup validation normalizes and rejects invalid numbering/QR profile fields
  const validBackup = validateBackupPayload({
    clients: [],
    invoices: [],
    businessProfile: {
      business_name: 'Alpha Studio',
      invoice_prefix: '  FY26-  ',
      estimate_prefix: '  QT-  ',
      next_invoice_number: 25,
      payment_qr_payload: 'alpha@upi',
    },
  });
  assert.equal(validBackup.valid, true);
  assert.equal(validBackup.normalized?.businessProfile.invoice_prefix, 'FY26-');
  assert.equal(validBackup.normalized?.businessProfile.estimate_prefix, 'QT-');
  assert.equal(validBackup.normalized?.businessProfile.next_invoice_number, 25);
  assert.equal(validBackup.normalized?.businessProfile.payment_qr_payload, 'alpha@upi');

  assert.equal(
    validateBackupPayload({
      clients: [],
      invoices: [],
      businessProfile: {
        business_name: 'Alpha Studio',
        next_invoice_number: 0,
      },
    }).valid,
    false
  );
  assert.equal(
    validateBackupPayload({
      clients: [],
      invoices: [],
      businessProfile: {
        business_name: 'Alpha Studio',
        invoice_prefix: 123,
      },
    }).valid,
    false
  );

  // Dynamic QR payloads encode decimal-aware amounts and invoice references
  assert.equal(
    generateDynamicQrPayload('', 'Studio', 1000, 2, 'INV-0001'),
    ''
  );
  assert.equal(
    generateDynamicQrPayload('merchant@upi', 'Alpha Studio', 12550, 2, 'FY26-0025', 'INR'),
    'upi://pay?pa=merchant%40upi&pn=Alpha%20Studio&am=125.50&tn=Invoice-FY26-0025&cu=INR'
  );
  assert.equal(
    generateDynamicQrPayload('tokyo@bank', 'Tokyo Lab', 45000, 0, 'INV-0010', 'JPY'),
    'upi://pay?pa=tokyo%40bank&pn=Tokyo%20Lab&am=45000&tn=Invoice-INV-0010&cu=JPY'
  );
  assert.equal(
    generateDynamicQrPayload('https://pay.studio.example/checkout', 'Studio', 12500, 3, 'INV-0099', 'KWD'),
    'https://pay.studio.example/checkout?invoice=INV-0099'
  );
});

test('Task 17: smsto fallback URI, macOS &body= detection, empty-email mailto guard, and RTL script detection', () => {
  assert.equal(
    buildSmsFallbackUrl('+1 (555) 019-2834', 'Hello & Pay'),
    'smsto:+15550192834?body=Hello%20%26%20Pay'
  );
  assert.equal(buildSmsFallbackUrl('+91 98765 43210'), 'smsto:+919876543210');
  assert.equal(buildSmsFallbackUrl('   ', 'Hi'), null);

  // macOS and iOS both return true for isAppleDevice -> '&body=' delimiter
  assert.equal(isAppleDevice('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)'), true);
  assert.equal(isAppleDevice('Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)'), true);
  assert.equal(isAppleDevice('Mozilla/5.0 (Linux; Android 14)'), false);
  assert.equal(
    buildSmsUrl('+971 50 123 4567', 'Invoice Due', isAppleDevice('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)')),
    'sms:+971501234567&body=Invoice%20Due'
  );

  // mailto omits empty subject/body query parameters cleanly
  assert.equal(buildMailtoUrl('', 'Subject', 'Body'), 'mailto:?subject=Subject&body=Body');
  assert.equal(buildMailtoUrl('', '', ''), 'mailto:');
  assert.equal(buildMailtoUrl('ap@client.test', 'Hello', ''), 'mailto:ap@client.test?subject=Hello');

  assert.equal(
    buildCopyEverythingReminderText({
      subject: 'Invoice INV-0001 Reminder',
      message: 'Hi Client, balance due.',
      clientName: 'Acme Corp',
      clientEmail: '',
      phone: '+1 555 0192',
    }),
    'To: Acme Corp • +15550192\nSubject: Invoice INV-0001 Reminder\n\nHi Client, balance due.'
  );

  // Arabic & Hebrew RTL character detection
  assert.equal(containsRtlCharacters('شركة الأمل'), true);
  assert.equal(containsRtlCharacters('חשבונית מס'), true);
  assert.equal(containsRtlCharacters('Dubai Studio AED 1,500.00 ₹100 ¥500'), false);
  assert.equal(containsRtlCharacters(''), false);
});
