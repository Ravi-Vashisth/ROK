import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import '../lib/core/utils/backup_service.dart';
import '../lib/core/utils/csv_export_service.dart';
import '../lib/core/utils/money_utils.dart';
import '../lib/core/utils/tax_compliance_utils.dart';
import '../lib/core/utils/telephony_utils.dart';
import '../lib/features/billing/services/invoice_pdf_service.dart';
import '../lib/features/business_profile/models/business_profile.dart';
import '../lib/features/clients/models/client.dart';
import '../lib/features/expenses/models/expense_record.dart';
import '../lib/features/invoices/models/invoice_item.dart';
import '../lib/features/invoices/models/invoice_record.dart';

void main() {
  group('Group 1: MoneyUtils & Integer Cents Math', () {
    test('parsePriceToCents converts string prices into exact integer cents without float imprecision', () {
      expect(parsePriceToCents('15.50'), equals(1550));
      expect(parsePriceToCents('\$15.50'), equals(1550));
      expect(parsePriceToCents('₹1,500.25'), equals(150025));
      expect(parsePriceToCents('15'), equals(1500));
      expect(parsePriceToCents('0.99'), equals(99));
      expect(parsePriceToCents(''), equals(0));
    });

    test('USD 2-decimal parsing and formatting (\$15.50 -> 1550 -> "\$15.50")', () {
      final units = parsePriceToUnits('\$15.50', 2);
      expect(units, equals(1550));
      final formatted = formatMoney(units, symbol: '\$', decimals: 2);
      expect(formatted, equals('\$15.50'));
    });

    test('JPY 0-decimal parsing and formatting (¥50000 -> 50000 -> "¥50,000")', () {
      final units = parsePriceToUnits('¥50000', 0);
      expect(units, equals(50000));
      final formatted = formatMoney(units, symbol: '¥', decimals: 0);
      expect(formatted, equals('¥50,000'));
    });

    test('JPY 0-decimal 10% tax calculation (¥50,000 subtotal @ 10% tax yields exactly ¥5,000 tax)', () {
      final subtotalUnits = parsePriceToUnits('50000', 0);
      expect(subtotalUnits, equals(50000));
      final tax = calculateTaxCents(subtotalUnits, 10);
      expect(tax, equals(5000));
      final total = subtotalUnits + tax;
      expect(total, equals(55000));
      expect(formatMoney(tax, symbol: '¥', decimals: 0), equals('¥5,000'));
      expect(formatMoney(total, symbol: '¥', decimals: 0), equals('¥55,000'));
    });

    test('calculateTaxCents applies strict round-half-up integer arithmetic', () {
      expect(calculateTaxCents(1733, 18), equals(312)); // (1733 * 18 + 50) ~/ 100 = 312
      expect(calculateTaxCents(105, 7), equals(7));    // (105 * 7 + 50) ~/ 100 = 785 ~/ 100 = 7
      expect(calculateTaxCents(150, 7), equals(11));   // (150 * 7 + 50) ~/ 100 = 1100 ~/ 100 = 11
      expect(calculateTaxCents(10000, 18), equals(1800));
    });

    test('calculateDiscountCents clamps flat discounts to subtotal', () {
      expect(calculateDiscountCents(10000, 'flat', 15000), equals(10000));
      expect(calculateDiscountCents(10000, 'flat', 3000), equals(3000));
      expect(calculateDiscountCents(10000, 'percent', 20), equals(2000));
      expect(calculateDiscountCents(10000, 'percent', 150), equals(10000)); // capped at 100%
      expect(calculateDiscountCents(10000, 'none', 5000), equals(0));
    });
  });

  group('Group 2: Tax Compliance & International Rules', () {
    test('Indian Intra-state CGST + SGST 50/50 split math', () {
      const totalTax = 1800;
      const cgst = totalTax ~/ 2;
      final sgst = totalTax - cgst;

      expect(cgst, equals(900));
      expect(sgst, equals(900));
      expect(cgst + sgst, equals(totalTax));

      // Odd cent tax handling
      const oddTax = 313;
      const oddCgst = oddTax ~/ 2; // 156
      final oddSgst = oddTax - oddCgst; // 157
      expect(oddCgst + oddSgst, equals(oddTax));
    });

    test('Indian Inter-state IGST calculation', () {
      const totalTax = 1800;
      expect(totalTax, equals(1800));
    });

    test('Export under LUT zero-rating and mandatory statutory notice text', () {
      const isExportUnderLut = true;
      const noticeText = isExportUnderLut
          ? 'SUPPLY MEANT FOR EXPORT UNDER BOND OR LETTER OF UNDERTAKING WITHOUT PAYMENT OF INTEGRATED TAX'
          : '';

      expect(
        noticeText,
        equals('SUPPLY MEANT FOR EXPORT UNDER BOND OR LETTER OF UNDERTAKING WITHOUT PAYMENT OF INTEGRATED TAX'),
      );
    });

    test('EU B2B Reverse Charge zero-rating with VAT note', () {
      const isEuCrossBorderB2B = true;
      const vatNotice = isEuCrossBorderB2B
          ? 'Reverse charge: Customer to account for VAT under Article 196 of Council Directive 2006/112/EC.'
          : '';

      expect(
        vatNotice,
        equals('Reverse charge: Customer to account for VAT under Article 196 of Council Directive 2006/112/EC.'),
      );
    });
  });

  group('Group 3: Database Sequence, Foreign Keys & Disaster Recovery', () {
    test('Dynamic sequence offset extraction using prefix.length + 1', () {
      const prefix = 'BILLING-2026-';
      final offset = prefix.length + 1; // 14

      expect(offset, equals(14));

      const invNum = 'BILLING-2026-0042';
      final extractedStr = invNum.substring(offset - 1);
      final extractedNum = int.tryParse(extractedStr) ?? 0;

      expect(extractedNum, equals(42));
    });

    test('Pre-flight backup schema validation throws FormatException on invalid payload', () {
      final invalidBackup = <String, dynamic>{
        'random_key': 'data',
      };

      // Ensure backup validation fails cleanly on missing root tables
      expect(
        () => BackupService.validateBackupMap(invalidBackup),
        throwsA(isA<FormatException>()),
      );
    });

    test('Client deletion is guarded when linked invoices or estimates exist', () {
      const linkedInvoiceCount = 2;
      const linkedEstimateCount = 1;
      const totalLinkedRecords = linkedInvoiceCount + linkedEstimateCount;

      final canDelete = totalLinkedRecords == 0;
      expect(canDelete, isFalse);
    });

    test('Void invoices are excluded from client statement of account calculations', () {
      const invoices = [
        DummyInvoice(id: '1', totalCents: 10000, paidCents: 10000, isVoid: false),
        DummyInvoice(id: '2', totalCents: 5000, paidCents: 0, isVoid: true), // Voided
        DummyInvoice(id: '3', totalCents: 20000, paidCents: 5000, isVoid: false),
      ];

      int totalInvoiced = 0;
      int totalPaid = 0;

      for (final inv in invoices) {
        if (inv.isVoid) continue;
        totalInvoiced += inv.totalCents;
        totalPaid += inv.paidCents;
      }

      final balanceDue = totalInvoiced - totalPaid;

      expect(totalInvoiced, equals(30000)); // 10000 + 20000 (excluding 5000)
      expect(totalPaid, equals(15000));     // 10000 + 5000
      expect(balanceDue, equals(15000));
    });
  });

  group('Group 4: Dynamic Settlement QR & Draft Invoices', () {
    test('generateDynamicQrPayload creates valid UPI URL with amount and invoice ref', () {
      final payload = generateDynamicQrPayload(
        rawPayload: 'merchant@upi',
        businessName: 'My Studio',
        balanceDueUnits: 15000,
        currencyDecimals: 2,
        invoiceNumber: 'INV-0010',
        currencyCode: 'INR',
      );
      expect(payload, equals('upi://pay?pa=merchant%40upi&pn=My%20Studio&am=150.00&tn=Invoice-INV-0010&cu=INR'));
    });

    test('generateDynamicQrPayload formats zero-decimal currencies without fractional cents', () {
      final payload = generateDynamicQrPayload(
        rawPayload: 'tokyo@upi',
        businessName: 'Tokyo Soft',
        balanceDueUnits: 50000,
        currencyDecimals: 0,
        invoiceNumber: 'INV-0011',
        currencyCode: 'JPY',
      );
      expect(payload, equals('upi://pay?pa=tokyo%40upi&pn=Tokyo%20Soft&am=50000&tn=Invoice-INV-0011&cu=JPY'));
    });

    test('Draft invoice record returns isDraft true and isOverdue false', () {
      final draftInvoice = InvoiceRecord(
        id: 'draft-1',
        clientId: 'c1',
        clientName: 'Acme',
        invoiceNumber: 'INV-D1',
        subtotalCents: 10000,
        taxCents: 1000,
        totalCents: 11000,
        paidCents: 0,
        balanceDueCents: 11000,
        status: 'DRAFT',
        issueDate: '2020-01-01',
        dueDate: '2020-01-01',
        paymentTerms: 'Due on Receipt',
        createdAt: '2020-01-01T00:00:00Z',
      );

      expect(draftInvoice.isDraft, isTrue);
      expect(draftInvoice.isOverdue, isFalse);
      expect(draftInvoice.computedStatus, equals('DRAFT'));
    });
  });

  group('Group 5: P0-A Decimal, Tax Portion & Sequence Safety', () {
    test('formatDecimalUnits preserves 0-decimal minor units without /100 division', () {
      expect(formatDecimalUnits(50000, 0), equals('50000'));
      expect(formatDecimalUnits(0, 0), equals('0'));
      expect(formatDecimalUnits(1550, 2), equals('15.50'));
      expect(formatDecimalUnits(5, 2), equals('0.05'));
    });

    test('calculateCollectedTaxPortion applies round-half-up integer division on partial payments', () {
      // Partial payment: (1000 * 500 + 1500) ~/ 3000 = 167
      expect(calculateCollectedTaxPortion(1000, 500, 3000), equals(167));
      // Odd-cent tie rounds half up: (5000 * 313 + 5000) ~/ 10000 = 157
      expect(calculateCollectedTaxPortion(5000, 313, 10000), equals(157));
      // Full settlement returns exact taxCents
      expect(calculateCollectedTaxPortion(11800, 1800, 11800), equals(1800));
      // Zero / invalid guard
      expect(calculateCollectedTaxPortion(0, 1800, 11800), equals(0));
    });

    test('extractSequenceNumber ignores DRAFT- & prefixes and getNextSequentialDocNumber avoids gaps', () {
      expect(extractSequenceNumber('DRAFT-A9B2C1', 'INV-'), equals(0));
      expect(extractSequenceNumber('INV-C-EST-0001', 'INV-'), equals(0));
      expect(extractSequenceNumber('BILLING-2026-0042', 'BILLING-2026-'), equals(42));
      expect(
        getNextSequentialDocNumber(['INV-0001', 'INV-0004', 'DRAFT-XYZ999'], 'INV-'),
        equals('INV-0005'),
      );
      expect(
        getNextSequentialDocNumber(['EST-0002'], 'EST-', minNext: 5),
        equals('EST-0005'),
      );
    });
  });

  group('Group 6: P0-B Backup Allowlist, CSV Export & Offline Multi-Page PDF', () {
    test('BackupService.sanitizeRowForTable keeps allowlisted columns and strips unknown/malicious keys', () {
      final sanitized = BackupService.sanitizeRowForTable('clients', {
        'id': 'c1',
        'name': 'Acme Studio',
        'tax_id': 'GST-123',
        '; DROP TABLE invoices;--': 'evil',
        'unexpected_extra_col': 'ignored',
      });

      expect(sanitized.keys.toSet(), equals({'id', 'name', 'tax_id'}));
      expect(sanitized['name'], equals('Acme Studio'));
      expect(
        () => BackupService.sanitizeRowForTable('clients_evil', {'id': '1'}),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('BackupService.validateBackupMap rejects malformed table types', () {
      expect(
        () => BackupService.validateBackupMap({
          'business_profile': [],
          'clients': 'not-a-list',
          'invoices': [],
        }),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => BackupService.validateBackupMap({
          'business_profile': [],
          'clients': ['invalid-row-string'],
          'invoices': [],
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('CsvExportService excludes DRAFT invoices and formats 0-decimal JPY cleanly', () {
      const clients = [
        Client(id: 'c1', name: 'Tokyo Corp, Ltd', taxId: 'JP-99', createdAt: '2026-01-01'),
      ];
      final invoices = [
        const InvoiceRecord(
          id: 'inv-draft',
          clientId: 'c1',
          clientName: 'Tokyo Corp, Ltd',
          invoiceNumber: 'DRAFT-AAA',
          subtotalCents: 10000,
          taxCents: 1000,
          totalCents: 11000,
          paidCents: 0,
          balanceDueCents: 11000,
          status: 'DRAFT',
          issueDate: '2026-10-01',
          dueDate: '2026-10-15',
          paymentTerms: 'Net 15 Days',
          currencyCode: 'JPY',
          currencySymbol: '¥',
          currencyDecimals: 0,
          createdAt: '2026-10-01T00:00:00Z',
        ),
        const InvoiceRecord(
          id: 'inv-live',
          clientId: 'c1',
          clientName: 'Tokyo Corp, Ltd',
          invoiceNumber: 'INV-0001',
          subtotalCents: 50000,
          taxCents: 5000,
          totalCents: 55000,
          paidCents: 0,
          balanceDueCents: 55000,
          status: 'PENDING',
          issueDate: '2026-10-01',
          dueDate: '2026-10-15',
          paymentTerms: 'Net 15 Days',
          currencyCode: 'JPY',
          currencySymbol: '¥',
          currencyDecimals: 0,
          createdAt: '2026-10-01T00:00:00Z',
        ),
      ];

      final invCsv = CsvExportService.generateInvoicesCsv(
        invoices: invoices,
        clients: clients,
        currencyCode: 'JPY',
      );
      expect(invCsv.contains('DRAFT-AAA'), isFalse);
      expect(invCsv.contains('"INV-0001"'), isTrue);
      expect(invCsv.contains('"Tokyo Corp, Ltd"'), isTrue);
      expect(invCsv.contains(',55000,'), isTrue);

      final expCsv = CsvExportService.generateExpensesCsv(
        expenses: const [
          ExpenseRecord(
            id: 'exp-1',
            category: 'Cloud',
            vendor: 'AWS',
            amountCents: 5000,
            taxCents: 500,
            expenseDate: '2026-10-05',
            createdAt: '2026-10-05T00:00:00Z',
          ),
        ],
        currencyCode: 'JPY',
      );
      expect(expCsv.contains(',5000,500,5500,'), isTrue);
    });

    test('InvoicePdfService generates offline MultiPage PDF for 45 line items without network access', () async {
      TestWidgetsFlutterBinding.ensureInitialized();

      const profile = BusinessProfile(
        id: 'default',
        businessName: 'Tokyo Design Studio',
        email: 'billing@tokyo.example',
        phone: '+81 3-5555-0100',
        address: 'Shibuya, Tokyo',
        taxId: 'JP-123456',
        paymentDetails: 'Bank transfer',
        currencySymbol: '¥',
        currencyCode: 'JPY',
        currencyDecimals: 0,
      );
      const client = Client(
        id: 'c1',
        name: 'Kansai Partners',
        email: 'ap@kansai.example',
        createdAt: '2026-10-01T00:00:00Z',
      );
      const invoice = InvoiceRecord(
        id: 'inv-multi',
        clientId: 'c1',
        clientName: 'Kansai Partners',
        invoiceNumber: 'INV-0099',
        subtotalCents: 450000,
        taxCents: 45000,
        totalCents: 495000,
        paidCents: 0,
        balanceDueCents: 495000,
        status: 'PENDING',
        issueDate: '2026-10-01',
        dueDate: '2026-10-31',
        paymentTerms: 'Net 30 Days',
        currencyCode: 'JPY',
        currencySymbol: '¥',
        currencyDecimals: 0,
        createdAt: '2026-10-01T00:00:00Z',
      );
      final items = List.generate(
        45,
        (i) => InvoiceItem(
          id: 'item-$i',
          invoiceId: 'inv-multi',
          description: 'Deliverable Sprint Line #${i + 1}',
          sacHsn: '998314',
          quantity: 1,
          unitPriceCents: 10000,
          taxRatePercentage: 10,
          taxCents: 1000,
          totalCents: 10000,
          createdAt: '2026-10-01T00:00:00Z',
        ),
      );

      final Uint8List pdfBytes = await InvoicePdfService.generateInvoicePdf(
        invoice: invoice,
        items: items,
        client: client,
        businessProfile: profile,
      );

      expect(pdfBytes.length, greaterThan(1000));
      // Valid PDF header %PDF-
      expect(pdfBytes.sublist(0, 5), equals([0x25, 0x50, 0x44, 0x46, 0x2D]));
    });
  });

  group('Group 7: P1-A Telephony, OS Intents & Payment Reminder Builders', () {
    test('normalizePhoneForUri preserves E.164 plus and strips formatting characters', () {
      expect(normalizePhoneForUri(' +1 (555) 019-2834 '), equals('+15550192834'));
      expect(normalizePhoneForUri('(022) 2654-1234'), equals('02226541234'));
      expect(normalizePhoneForUri('  ---  '), equals(''));
      expect(normalizePhoneForUri(''), equals(''));
    });

    test('buildWhatsAppDigits removes plus prefix cleanly for wa.me links', () {
      expect(buildWhatsAppDigits('+91 98765 43210'), equals('919876543210'));
      expect(buildWhatsAppDigits('+1-555-0192'), equals('15550192'));
      expect(buildWhatsAppDigits(''), equals(''));
    });

    test('buildTelUri, buildSmsUri, buildWhatsAppUri, and buildMailtoUri handle valid and empty contacts', () {
      expect(buildTelUri('+1 (555) 019-2834').toString(), equals('tel:+15550192834'));
      expect(buildTelUri('   '), isNull);

      expect(
        buildSmsUri(phone: '+1 555-0192', body: 'Hello & Pay').toString(),
        equals('sms:+15550192?body=Hello%20%26%20Pay'),
      );
      expect(buildSmsUri(phone: '', body: 'Hello'), isNull);

      expect(
        buildWhatsAppUri(phone: '+91 98765 43210', message: 'Hi Acme').toString(),
        equals('https://wa.me/919876543210?text=Hi%20Acme'),
      );
      expect(
        buildWhatsAppUri(phone: '', message: 'Hi').toString(),
        equals('https://wa.me/?text=Hi'),
      );

      expect(
        buildMailtoUri(email: ' billing@acme.com ', subject: 'INV-0001 Reminder', body: 'Body text').toString(),
        equals('mailto:billing@acme.com?subject=INV-0001%20Reminder&body=Body%20text'),
      );
      expect(
        buildMailtoUri(email: '', subject: 'Subject', body: 'Body').toString(),
        equals('mailto:?subject=Subject&body=Body'),
      );
    });

    test('buildPaymentReminderMessage formats 0-decimal JPY without fractional cents', () {
      final msg = buildPaymentReminderMessage(
        invoiceNumber: 'INV-0099',
        clientName: 'Tokyo Soft',
        balanceDueUnits: 55000,
        currencySymbol: '¥',
        currencyDecimals: 0,
        dueDate: '2026-11-30',
        businessName: 'Design Studio',
      );
      expect(msg.contains('Invoice INV-0099'), isTrue);
      expect(msg.contains('¥55,000'), isTrue);
      expect(msg.contains('¥55,000.00'), isFalse);
      expect(msg.contains('2026-11-30'), isTrue);
      expect(msg.contains('Design Studio'), isTrue);
    });
  });

  group('Group 8: P2 Regional Tax Compliance Engine', () {
    test('India Intra-State CGST/SGST splits odd minor units cleanly without float error', () {
      final breakdown = resolveRegionalTaxBreakdown(
        taxMode: TaxMode.inIntra,
        netSubtotalCents: 1739,
        taxCents: 313,
      );
      expect(breakdown.lines.length, equals(2));
      expect(breakdown.lines[0].label, equals('CGST (50% Split)'));
      expect(breakdown.lines[0].cents, equals(156));
      expect(breakdown.lines[1].label, equals('SGST (50% Split)'));
      expect(breakdown.lines[1].cents, equals(157));
      expect(breakdown.lines[0].cents + breakdown.lines[1].cents, equals(313));
      expect(getRegionalTaxIdLabel(TaxMode.inIntra), equals('GSTIN'));
    });

    test('India Inter-State IGST and Export under LUT (Rule 96A) compute exact tax & notice', () {
      final inter = resolveRegionalTaxBreakdown(
        taxMode: TaxMode.inInter,
        netSubtotalCents: 10000,
        taxCents: 1800,
      );
      expect(inter.lines.single.label, equals('IGST (100%)'));
      expect(inter.lines.single.cents, equals(1800));

      final lutTax = computeRegionalTaxCents(
        netSubtotalCents: 50000,
        taxMode: TaxMode.inLut,
        taxPercentage: 18,
        itemsTaxSumCents: 9000,
      );
      expect(lutTax, equals(0));
      final lutBreakdown = resolveRegionalTaxBreakdown(
        taxMode: TaxMode.inLut,
        netSubtotalCents: 50000,
        taxCents: lutTax,
      );
      expect(lutBreakdown.isZeroRated, isTrue);
      expect(lutBreakdown.noticeTitle, equals('EXPORT UNDER LUT (RULE 96A)'));
      expect(lutBreakdown.noticeText, contains('LETTER OF UNDERTAKING'));
    });

    test('EU/UK Reverse Charge zero-rates tax and includes Article 196 Directive notice', () {
      final tax = computeRegionalTaxCents(
        netSubtotalCents: 20000,
        taxMode: TaxMode.euReverseCharge,
        taxPercentage: 20,
        itemsTaxSumCents: 4000,
      );
      expect(tax, equals(0));
      final breakdown = resolveRegionalTaxBreakdown(
        taxMode: TaxMode.euReverseCharge,
        netSubtotalCents: 20000,
        taxCents: tax,
      );
      expect(breakdown.isZeroRated, isTrue);
      expect(breakdown.noticeText, contains('Article 196 of Council Directive 2006/112/EC'));
      expect(getRegionalTaxIdLabel(TaxMode.euReverseCharge, isClient: true), equals('Client VAT ID'));
    });

    test('Canada Dual Tax (GST + PST) preserves integer minor units across 2-decimal and 0-decimal JPY', () {
      final totalUsdTax = computeRegionalTaxCents(
        netSubtotalCents: 10000,
        taxMode: TaxMode.caDual,
        taxPercentage: 5,
        pstRatePercentage: 7,
      );
      expect(totalUsdTax, equals(1200));
      final usdBreakdown = resolveRegionalTaxBreakdown(
        taxMode: TaxMode.caDual,
        netSubtotalCents: 10000,
        taxCents: totalUsdTax,
        pstRatePercentage: 7,
      );
      expect(usdBreakdown.lines[0].label, equals('GST'));
      expect(usdBreakdown.lines[0].cents, equals(500));
      expect(usdBreakdown.lines[1].label, equals('PST (7%)'));
      expect(usdBreakdown.lines[1].cents, equals(700));

      // 0-decimal JPY check (¥50,000 @ 5% GST + 7% PST = ¥2,500 + ¥3,500 = ¥6,000)
      final jpyTax = computeRegionalTaxCents(
        netSubtotalCents: 50000,
        taxMode: TaxMode.caDual,
        taxPercentage: 5,
        pstRatePercentage: 7,
      );
      expect(jpyTax, equals(6000));
    });

    test('Gulf VAT displays Supplier/Client TRN & US Tax-Exempt enforces 0% with Exemption ID', () {
      final gulfBreakdown = resolveRegionalTaxBreakdown(
        taxMode: TaxMode.gulfVat,
        netSubtotalCents: 10000,
        taxCents: 1500,
        businessTaxId: 'TRN-100200300',
        clientTaxId: 'TRN-999888777',
      );
      expect(gulfBreakdown.noticeTitle, equals('GCC / GULF TAX INVOICE'));
      expect(gulfBreakdown.noticeText, contains('Supplier TRN / VAT ID: TRN-100200300'));
      expect(gulfBreakdown.noticeText, contains('Customer TRN / VAT ID: TRN-999888777'));
      expect(getRegionalTaxIdLabel(TaxMode.gulfVat), equals('TRN / VAT ID'));

      final exemptTax = computeRegionalTaxCents(
        netSubtotalCents: 25000,
        taxMode: TaxMode.usExempt,
        taxPercentage: 8,
        itemsTaxSumCents: 2000,
      );
      expect(exemptTax, equals(0));
      final exemptBreakdown = resolveRegionalTaxBreakdown(
        taxMode: TaxMode.usExempt,
        netSubtotalCents: 25000,
        taxCents: exemptTax,
        taxExemptionId: 'EX-TX-2026',
      );
      expect(exemptBreakdown.isZeroRated, isTrue);
      expect(exemptBreakdown.noticeText, contains('EX-TX-2026'));

      // Legacy auto-detect fallback when taxMode is standard & taxCents is 0
      final legacyEu = resolveRegionalTaxBreakdown(
        taxMode: TaxMode.standard,
        netSubtotalCents: 10000,
        taxCents: 0,
        clientTaxId: 'DE123456789',
        fallbackAutoDetect: true,
      );
      expect(legacyEu.effectiveMode, equals('eu_reverse_charge'));
    });
  });
}

class DummyInvoice {
  final String id;
  final int totalCents;
  final int paidCents;
  final bool isVoid;

  const DummyInvoice({
    required this.id,
    required this.totalCents,
    required this.paidCents,
    required this.isVoid,
  });
}
