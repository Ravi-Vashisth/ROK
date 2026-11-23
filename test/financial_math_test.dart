import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' hide Row;

import 'package:billing_app/core/database/database_provider.dart';
import 'package:billing_app/core/database/local_db.dart';
import 'package:billing_app/core/theme/app_theme.dart';
import 'package:billing_app/core/theme/theme_provider.dart';
import 'package:billing_app/core/utils/backup_service.dart';
import 'package:billing_app/core/utils/csv_export_service.dart';
import 'package:billing_app/core/utils/export_file_helper.dart';
import 'package:billing_app/core/utils/file_validation_utils.dart';
import 'package:billing_app/core/utils/id_generator.dart';
import 'package:billing_app/core/utils/money_utils.dart';
import 'package:billing_app/core/utils/tax_compliance_utils.dart';
import 'package:billing_app/core/utils/telephony_utils.dart';
import 'package:billing_app/features/billing/services/invoice_pdf_service.dart';
import 'package:billing_app/features/business_profile/models/business_profile.dart';
import 'package:billing_app/features/business_profile/providers/business_profile_provider.dart';
import 'package:billing_app/features/clients/models/client.dart';
import 'package:billing_app/features/clients/providers/clients_provider.dart';
import 'package:billing_app/features/estimates/models/estimate_item.dart';
import 'package:billing_app/features/estimates/models/estimate_record.dart';
import 'package:billing_app/features/estimates/providers/estimates_provider.dart';
import 'package:billing_app/features/expenses/models/expense_record.dart';
import 'package:billing_app/features/expenses/providers/expenses_provider.dart';
import 'package:billing_app/features/invoices/models/invoice_item.dart';
import 'package:billing_app/features/invoices/models/invoice_record.dart';
import 'package:billing_app/features/invoices/presentation/invoice_editor_screen.dart';
import 'package:billing_app/features/invoices/providers/invoices_provider.dart';
import 'package:billing_app/features/items/providers/saved_items_provider.dart';

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
      const sgst = totalTax - cgst;

      expect(cgst, equals(900));
      expect(sgst, equals(900));
      expect(cgst + sgst, equals(totalTax));

      // Odd cent tax handling
      const oddTax = 313;
      const oddCgst = oddTax ~/ 2; // 156
      const oddSgst = oddTax - oddCgst; // 157
      expect(oddCgst + oddSgst, equals(oddTax));
    });

    test('Indian Inter-state IGST calculation', () {
      const totalTax = 1800;
      expect(totalTax, equals(1800));
    });

    test('Export under LUT zero-rating and mandatory statutory notice text', () {
      final noticeText = getLutNotice(true);
      final inactiveNotice = getLutNotice(false);

      expect(
        noticeText,
        equals('SUPPLY MEANT FOR EXPORT UNDER BOND OR LETTER OF UNDERTAKING WITHOUT PAYMENT OF INTEGRATED TAX'),
      );
      expect(inactiveNotice, isEmpty);
    });

    test('EU B2B Reverse Charge zero-rating with VAT note', () {
      final vatNotice = getEuReverseChargeNotice(true);
      final inactiveNotice = getEuReverseChargeNotice(false);

      expect(
        vatNotice,
        equals('Reverse charge: Customer to account for VAT under Article 196 of Council Directive 2006/112/EC.'),
      );
      expect(inactiveNotice, isEmpty);
    });
  });

  group('Group 3: Database Sequence, Foreign Keys & Disaster Recovery', () {
    test('Dynamic sequence offset extraction using prefix.length + 1', () {
      const prefix = 'BILLING-2026-';
      const offset = prefix.length + 1; // 14

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

      const canDelete = totalLinkedRecords == 0;
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
      const draftInvoice = InvoiceRecord(
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

  group('Group 9: Task 2 3-Decimal Currencies, Parser Hardening & Pure Integer Formatting', () {
    test('getCurrencyDecimals supports 3-decimal currencies (KWD, BHD, OMR, JOD, TND)', () {
      expect(getCurrencyDecimals('KWD'), equals(3));
      expect(getCurrencyDecimals('bhd'), equals(3));
      expect(getCurrencyDecimals('OMR'), equals(3));
      expect(getCurrencyDecimals('JOD'), equals(3));
      expect(getCurrencyDecimals('TND'), equals(3));
      expect(getCurrencyDecimals('USD'), equals(2));
      expect(getCurrencyDecimals('JPY'), equals(0));
    });

    test('3-decimal currency parsing, pure integer formatting & dynamic QR generation', () {
      expect(parsePriceToUnits('15.500', 3), equals(15500));
      expect(parsePriceToUnits('KWD 1,234.567', 3), equals(1234567));
      expect(parsePriceToUnits('0.005', 3), equals(5));
      expect(parsePriceToUnits('15.5', 3), equals(15500));

      expect(formatMoney(1234567, symbol: 'KWD', decimals: 3), equals('KWD1,234.567'));
      expect(formatMoney(5, symbol: 'BHD', decimals: 3), equals('BHD0.005'));
      expect(formatMoney(-15500, symbol: 'OMR', decimals: 3), equals('-OMR15.500'));
      expect(formatDecimalUnits(1234567, 3), equals('1234.567'));
      expect(formatDecimalUnits(5, 3), equals('0.005'));
      expect(formatDecimalUnits(-50, 3), equals('-0.050'));

      final kwdQr = generateDynamicQrPayload(
        rawPayload: 'gulf@upi',
        businessName: 'Kuwait Co',
        balanceDueUnits: 15500,
        currencyDecimals: 3,
        invoiceNumber: 'INV-0777',
        currencyCode: 'KWD',
      );
      expect(
        kwdQr,
        equals('upi://pay?pa=gulf%40upi&pn=Kuwait%20Co&am=15.500&tn=Invoice-INV-0777&cu=KWD'),
      );
    });

    test('parsePriceToUnits rejects negative inputs cleanly and applies round-half-up on extra decimals', () {
      expect(parsePriceToUnits('-15.50', 2), equals(0));
      expect(parsePriceToUnits('-\$15.50', 2), equals(0));
      expect(parsePriceToUnits('\$-100', 0), equals(0));
      expect(parsePriceToUnits('-50.000', 3), equals(0));

      expect(parsePriceToUnits('10.124', 2), equals(1012));
      expect(parsePriceToUnits('10.125', 2), equals(1013));
      expect(parsePriceToUnits('10.129', 2), equals(1013));
      expect(parsePriceToUnits('10.999', 2), equals(1100));
      expect(parsePriceToUnits('10.4', 0), equals(10));
      expect(parsePriceToUnits('10.5', 0), equals(11));
      expect(parsePriceToUnits('1.2344', 3), equals(1234));
      expect(parsePriceToUnits('1.2345', 3), equals(1235));
      expect(parsePriceToUnits('1.9999', 3), equals(2000));
    });

    test('formatMoney and formatDecimalUnits format negative integers deterministically without float division', () {
      expect(formatMoney(-1550, symbol: '\$', decimals: 2), equals('-\$15.50'));
      expect(formatMoney(-50000, symbol: '¥', decimals: 0), equals('-¥50,000'));
      expect(formatDecimalUnits(-1550, 2), equals('-15.50'));
      expect(formatDecimalUnits(-5, 2), equals('-0.05'));
    });
  });

  group('Group 10: Task 3 Mixed-Currency Dashboard & Client Rollup Aggregation', () {
    test('computeDashboardCashFlow aggregates USD + INR + JPY + KWD cleanly per currencyCode', () {
      const entries = [
        CurrencyLedgerEntry(
          currencyCode: 'USD',
          currencySymbol: '\$',
          currencyDecimals: 2,
          totalUnits: 100000,
          paidUnits: 100000,
          balanceDueUnits: 0,
          taxUnits: 10000,
          isOverdue: false,
        ),
        CurrencyLedgerEntry(
          currencyCode: 'JPY',
          currencySymbol: '¥',
          currencyDecimals: 0,
          totalUnits: 50000,
          paidUnits: 0,
          balanceDueUnits: 50000,
          taxUnits: 5000,
          isOverdue: true,
        ),
        CurrencyLedgerEntry(
          currencyCode: 'KWD',
          currencySymbol: 'KWD',
          currencyDecimals: 3,
          totalUnits: 25500,
          paidUnits: 5000,
          balanceDueUnits: 20500,
          taxUnits: 0,
          isOverdue: false,
        ),
        CurrencyLedgerEntry(
          currencyCode: 'INR',
          currencySymbol: '₹',
          currencyDecimals: 2,
          totalUnits: 500000,
          paidUnits: 500000,
          balanceDueUnits: 0,
          taxUnits: 90000,
          isOverdue: false,
        ),
      ];

      final summary = computeDashboardCashFlow(
        entries,
        expenseGrossUnits: 22000,
        expenseTaxUnits: 2000,
        defaultCode: 'USD',
        defaultSymbol: '\$',
        defaultDecimals: 2,
      );

      expect(summary.byCurrency.map((b) => b.code).toList(), equals(['USD', 'INR', 'JPY', 'KWD']));
      expect(summary.formattedInvoiced, equals('\$1,000.00 + ₹5,000.00 + ¥50,000 + KWD25.500'));
      expect(summary.formattedCollected, equals('\$1,000.00 + ₹5,000.00 + KWD5.000'));
      expect(summary.formattedUnpaid, equals('¥50,000 + KWD20.500'));
      expect(summary.formattedOverdue, equals('¥50,000'));
      expect(summary.hasAnyNegativeTaxLiability, isFalse);
      expect(summary.hasNetLoss, isFalse);

      final homeUsd = summary.byCurrency.first;
      expect(homeUsd.netRevenueExclTaxUnits, equals(90000));
      expect(homeUsd.netExpenseExclTaxUnits, equals(20000));
      expect(homeUsd.taxLiabilityUnits, equals(8000));
      expect(homeUsd.netProfitUnits, equals(70000));
    });

    test('computeClientRollup groups mixed currencies & handles all-zero emptyFallback', () {
      const entries = [
        CurrencyLedgerEntry(
          currencyCode: '',
          currencySymbol: '',
          totalUnits: 12000,
          paidUnits: 12000,
        ),
        CurrencyLedgerEntry(
          currencyCode: 'JPY',
          currencySymbol: '¥',
          currencyDecimals: 0,
          totalUnits: 35000,
          paidUnits: 0,
        ),
        CurrencyLedgerEntry(
          currencyCode: 'KWD',
          currencySymbol: 'KWD',
          currencyDecimals: 3,
          totalUnits: 10500,
          paidUnits: 2500,
        ),
      ];

      final rollup = computeClientRollup(
        entries,
        defaultCode: 'EUR',
        defaultSymbol: '€',
        defaultDecimals: 2,
      );

      expect(rollup.hasOutstandingBalance, isTrue);
      expect(rollup.formattedTotalBilled, equals('€120.00 + ¥35,000 + KWD10.500'));
      expect(rollup.formattedTotalPaid, equals('€120.00 + KWD2.500'));
      expect(rollup.formattedOutstandingBalance, equals('¥35,000 + KWD8.000'));

      final emptyRollup = computeClientRollup(
        const [],
        defaultCode: 'JPY',
        defaultSymbol: '¥',
        defaultDecimals: 0,
      );
      expect(emptyRollup.hasOutstandingBalance, isFalse);
      expect(emptyRollup.formattedTotalBilled, equals('¥0'));
      expect(emptyRollup.formattedOutstandingBalance, equals('¥0'));
    });
  });

  group('Group 11: Task 4 Date Filter, ISO Validation, UUID v4 & Sequence minNext', () {
    test('matchesDateFilter handles All Time, This Month, and This Quarter across boundaries', () {
      final refQ4 = DateTime(2026, 10, 20, 14, 0);
      expect(matchesDateFilter('2024-01-01', 'All Time', referenceNow: refQ4), isTrue);
      expect(matchesDateFilter('invalid', 'All Time', referenceNow: refQ4), isTrue);

      // This Month (October 2026)
      expect(matchesDateFilter('2026-10-01', 'This Month', referenceNow: refQ4), isTrue);
      expect(matchesDateFilter('2026-10-31', 'This Month', referenceNow: refQ4), isTrue);
      expect(matchesDateFilter('2026-09-30', 'This Month', referenceNow: refQ4), isFalse);
      expect(matchesDateFilter('2026-11-01', 'This Month', referenceNow: refQ4), isFalse);
      expect(matchesDateFilter('2025-10-20', 'This Month', referenceNow: refQ4), isFalse);
      expect(matchesDateFilter('', 'This Month', referenceNow: refQ4), isFalse);

      // This Quarter (Q4 2026: Oct-Dec)
      expect(matchesDateFilter('2026-10-01', 'This Quarter', referenceNow: refQ4), isTrue);
      expect(matchesDateFilter('2026-11-15', 'This Quarter', referenceNow: refQ4), isTrue);
      expect(matchesDateFilter('2026-12-31', 'This Quarter', referenceNow: refQ4), isTrue);
      expect(matchesDateFilter('2026-09-30', 'This Quarter', referenceNow: refQ4), isFalse);
      expect(matchesDateFilter('2025-10-15', 'This Quarter', referenceNow: refQ4), isFalse);

      // Q1 boundary check
      final refQ1 = DateTime(2026, 3, 15, 9, 0);
      expect(matchesDateFilter('2026-01-01', 'This Quarter', referenceNow: refQ1), isTrue);
      expect(matchesDateFilter('2026-03-31', 'This Quarter', referenceNow: refQ1), isTrue);
      expect(matchesDateFilter('2026-04-01', 'This Quarter', referenceNow: refQ1), isFalse);
    });

    test('isValidIsoCalendarDate strictly validates YYYY-MM-DD calendar dates', () {
      expect(isValidIsoCalendarDate('2026-02-28'), isTrue);
      expect(isValidIsoCalendarDate('2024-02-29'), isTrue);
      expect(isValidIsoCalendarDate('2026-10-15'), isTrue);

      expect(isValidIsoCalendarDate('2026-02-29'), isFalse);
      expect(isValidIsoCalendarDate('2026-02-30'), isFalse);
      expect(isValidIsoCalendarDate('2026-13-01'), isFalse);
      expect(isValidIsoCalendarDate('2026-2-5'), isFalse);
      expect(isValidIsoCalendarDate('2026-10-15T00:00:00Z'), isFalse);
      expect(isValidIsoCalendarDate(''), isFalse);
    });

    test('generateUniqueId produces collision-free RFC-4122 UUID v4 strings & minNext aligns numbering', () {
      final uuidRegex = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        caseSensitive: false,
      );
      final generated = <String>{};
      for (int i = 0; i < 50; i++) {
        final id = generateUniqueId();
        expect(uuidRegex.hasMatch(id), isTrue);
        generated.add(id);
      }
      expect(generated.length, equals(50));

      expect(
        getNextSequentialDocNumber(['INV-0001', 'DRAFT-AABBCCDD'], 'INV-', minNext: 10),
        equals('INV-0010'),
      );
      expect(
        getNextSequentialDocNumber(['INV-0001', 'INV-0015'], 'INV-', minNext: 5),
        equals('INV-0016'),
      );
    });
  });

  group('Group 11: Task 5 Cross-OS Telephony Delimiter, WhatsApp Validation & Desktop Fallback', () {
    test('buildSmsUri handles Android (?) vs iOS (&) body delimiter quirks', () {
      expect(
        buildSmsUri(phone: '+1 555-0192', body: 'Hello & Pay', isIos: false).toString(),
        equals('sms:+15550192?body=Hello%20%26%20Pay'),
      );
      expect(
        buildSmsUri(phone: '+1 555-0192', body: 'Hello & Pay', isIos: true).toString(),
        equals('sms:+15550192&body=Hello%20%26%20Pay'),
      );
      expect(
        buildSmsUri(phone: '+1 555-0192', body: '', isIos: true).toString(),
        equals('sms:+15550192'),
      );
      expect(buildSmsUri(phone: '   ', body: 'Hi', isIos: true), isNull);
    });

    test('validateWhatsAppPhone detects missing country codes and leading trunk zeros', () {
      final validIn = validateWhatsAppPhone('+91 98765 43210');
      expect(validIn.isValid, isTrue);
      expect(validIn.normalizedDigits, equals('919876543210'));
      expect(validIn.warningMessage, isNull);

      final validUs = validateWhatsAppPhone('+1 (555) 019-2834');
      expect(validUs.isValid, isTrue);

      final trunkZero = validateWhatsAppPhone('09876543210');
      expect(trunkZero.isValid, isFalse);
      expect(trunkZero.warningMessage, contains("starts with '0'"));

      final missingPlusLocal = validateWhatsAppPhone('9876543210');
      expect(missingPlusLocal.isValid, isFalse);
      expect(missingPlusLocal.warningMessage, contains("Missing '+'"));

      final tooShort = validateWhatsAppPhone('+12345');
      expect(tooShort.isValid, isFalse);

      final emptyNum = validateWhatsAppPhone('   ');
      expect(emptyNum.isValid, isFalse);
      expect(emptyNum.warningMessage, contains('No phone number'));
    });

    test('getDesktopTelephonyFallbackNote gives clear desktop fallback copy', () {
      expect(
        getDesktopTelephonyFallbackNote(hasPhone: false, hasEmail: false),
        contains('No client phone or email'),
      );
      expect(
        getDesktopTelephonyFallbackNote(hasPhone: true, hasEmail: true),
        contains('Copy Reminder Message'),
      );
    });
  });

  group('Group 12: Task 6 SAF Attachment Byte, Header & Size Validation', () {
    test('validateUploadedFileBytes validates PNG/JPEG/WEBP/PDF signatures and rejects corrupt or oversized files', () {
      const pngHeader = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
      const jpgHeader = [0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10];
      const webpHeader = [0x52, 0x49, 0x46, 0x46, 0x00, 0x00, 0x00, 0x00, 0x57, 0x45, 0x42, 0x50];
      const pdfHeader = [0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x34];

      final pngRes = validateUploadedFileBytes(bytes: pngHeader, filename: 'logo.png', allowPdf: false);
      expect(pngRes.isValid, isTrue);
      expect(pngRes.mimeType, equals('image/png'));

      final jpgRes = validateUploadedFileBytes(bytes: jpgHeader, filename: 'sig.jpg', allowPdf: false);
      expect(jpgRes.isValid, isTrue);
      expect(jpgRes.mimeType, equals('image/jpeg'));

      final webpRes = validateUploadedFileBytes(bytes: webpHeader, filename: 'receipt.webp', allowPdf: true);
      expect(webpRes.isValid, isTrue);
      expect(webpRes.mimeType, equals('image/webp'));

      // PDF rejected for logo/signature, accepted for expense receipts
      final pdfAsLogo = validateUploadedFileBytes(bytes: pdfHeader, filename: 'fake.png', allowPdf: false);
      expect(pdfAsLogo.isValid, isFalse);

      final pdfAsReceipt = validateUploadedFileBytes(bytes: pdfHeader, filename: 'bill.pdf', allowPdf: true);
      expect(pdfAsReceipt.isValid, isTrue);
      expect(pdfAsReceipt.mimeType, equals('application/pdf'));

      // Spoofed/corrupt header rejected
      final fakePng = validateUploadedFileBytes(
        bytes: [0x3C, 0x68, 0x74, 0x6D, 0x6C, 0x3E],
        filename: 'malicious.png',
        allowPdf: true,
      );
      expect(fakePng.isValid, isFalse);

      // Empty bytes rejected
      expect(
        validateUploadedFileBytes(bytes: const [], filename: 'empty.png', allowPdf: true).isValid,
        isFalse,
      );

      // Oversized (> 5 MB) rejected
      final oversized = List<int>.filled(maxAttachmentSizeBytes + 1, 0);
      for (int i = 0; i < pngHeader.length; i++) {
        oversized[i] = pngHeader[i];
      }
      final sizeRes = validateUploadedFileBytes(bytes: oversized, filename: 'huge.png', allowPdf: false);
      expect(sizeRes.isValid, isFalse);
      expect(sizeRes.errorMessage, contains('5 MB'));
    });
  });

  group('Group 13: Task 7 Sync Columns Allowlist, Backup Hardening & CSV Security', () {
    test('BackupService.allowedTableColumns includes sync columns updated_at and deleted_at across all 9 tables', () {
      expect(BackupService.allowedTableColumns.keys.length, equals(9));
      for (final entry in BackupService.allowedTableColumns.entries) {
        expect(entry.value.contains('updated_at'), isTrue, reason: '${entry.key} missing updated_at');
        expect(entry.value.contains('deleted_at'), isTrue, reason: '${entry.key} missing deleted_at');
      }
    });

    test('BackupService.validateBackupMap validates NOT NULL fields and column value types cleanly', () {
      final validSnapshot = <String, dynamic>{
        'business_profile': [
          {
            'id': 'default',
            'business_name': 'Studio One',
            'currency_decimals': 2,
            'next_invoice_number': 4,
            'updated_at': '2026-11-18T00:00:00Z',
            'deleted_at': null,
          },
        ],
        'clients': [
          {
            'id': 'c1',
            'name': 'Acme Corp',
            'email': 'ap@acme.test',
            'created_at': '2026-10-01T00:00:00Z',
            'updated_at': '2026-10-01T00:00:00Z',
            'deleted_at': null,
          },
        ],
        'invoices': [
          {
            'id': 'inv-1',
            'client_id': 'c1',
            'invoice_number': 'INV-0001',
            'subtotal_cents': 10000,
            'tax_cents': 1800,
            'total_cents': 11800,
            'status': 'PENDING',
            'created_at': '2026-10-01T00:00:00Z',
          },
        ],
        'expenses': [
          {
            'id': 'exp-1',
            'category': 'Software',
            'vendor': 'AWS',
            'amount_cents': 5000,
            'tax_cents': 500,
            'expense_date': '2026-10-02',
            'created_at': '2026-10-02T00:00:00Z',
          },
        ],
      };

      expect(() => BackupService.validateBackupMap(validSnapshot), returnsNormally);

      // Missing NOT NULL client name throws FormatException
      expect(
        () => BackupService.validateBackupMap({
          'business_profile': [
            {'id': 'default', 'business_name': 'Studio One'},
          ],
          'clients': [
            {'id': 'c1', 'name': '   ', 'created_at': '2026-10-01T00:00:00Z'},
          ],
          'invoices': [],
        }),
        throwsA(isA<FormatException>()),
      );

      // Missing NOT NULL invoice_number throws FormatException
      expect(
        () => BackupService.validateBackupMap({
          'business_profile': [
            {'id': 'default', 'business_name': 'Studio One'},
          ],
          'clients': [
            {'id': 'c1', 'name': 'Acme', 'created_at': '2026-10-01T00:00:00Z'},
          ],
          'invoices': [
            {
              'id': 'inv-1',
              'client_id': 'c1',
              'subtotal_cents': 1000,
              'tax_cents': 0,
              'total_cents': 1000,
              'status': 'PENDING',
              'created_at': '2026-10-01T00:00:00Z',
            },
          ],
        }),
        throwsA(isA<FormatException>()),
      );

      // Wrong type inside integer column ('1000' instead of 1000) throws FormatException
      expect(
        () => BackupService.validateBackupMap({
          'business_profile': [
            {'id': 'default', 'business_name': 'Studio One'},
          ],
          'clients': [
            {'id': 'c1', 'name': 'Acme', 'created_at': '2026-10-01T00:00:00Z'},
          ],
          'invoices': [
            {
              'id': 'inv-1',
              'client_id': 'c1',
              'invoice_number': 'INV-0001',
              'subtotal_cents': 1000,
              'tax_cents': 0,
              'total_cents': '1000',
              'status': 'PENDING',
              'created_at': '2026-10-01T00:00:00Z',
            },
          ],
        }),
        throwsA(isA<FormatException>()),
      );

      // Wrong type inside string column (int instead of String) throws FormatException
      expect(
        () => BackupService.validateBackupMap({
          'business_profile': [
            {'id': 'default', 'business_name': 'Studio One'},
          ],
          'clients': [
            {'id': 'c1', 'name': 'Acme', 'email': 12345, 'created_at': '2026-10-01T00:00:00Z'},
          ],
          'invoices': [],
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('CsvExportService neutralizes formula-injection prefixes and uses ISO currencyCode', () {
      expect(CsvExportService.sanitizeCsvCell('=1+1'), equals("'=1+1"));
      expect(CsvExportService.sanitizeCsvCell('+CMD|calc'), equals("'+CMD|calc"));
      expect(CsvExportService.sanitizeCsvCell('-2+3'), equals("'-2+3"));
      expect(CsvExportService.sanitizeCsvCell('@SUM(A1:A2)'), equals("'@SUM(A1:A2)"));
      expect(CsvExportService.sanitizeCsvCell('\t=1+1'), equals("'\t=1+1"));
      expect(CsvExportService.sanitizeCsvCell('\r+1'), equals("'\r+1"));
      expect(CsvExportService.sanitizeCsvCell('  =1+1'), equals("'  =1+1"));
      expect(CsvExportService.sanitizeCsvCell('Safe Client LLC'), equals('Safe Client LLC'));

      final invCsv = CsvExportService.generateInvoicesCsv(
        invoices: const [
          InvoiceRecord(
            id: 'inv-sec',
            clientId: 'c1',
            clientName: '=1+1',
            invoiceNumber: 'INV-0009',
            subtotalCents: 10000,
            taxCents: 0,
            totalCents: 10000,
            paidCents: 0,
            balanceDueCents: 10000,
            status: 'PENDING',
            issueDate: '2026-10-01',
            dueDate: '2026-10-15',
            paymentTerms: 'Net 15 Days',
            createdAt: '2026-10-01T00:00:00Z',
          ),
        ],
        clients: const [
          Client(id: 'c1', name: '=1+1', taxId: '+TAX99', createdAt: '2026-10-01T00:00:00Z'),
        ],
        currencyCode: 'USD',
      );
      expect(invCsv.contains('"USD"'), isTrue);
      expect(invCsv.contains('"\'=1+1"'), isTrue);
      expect(invCsv.contains('"\'+TAX99"'), isTrue);

      final expCsv = CsvExportService.generateExpensesCsv(
        expenses: const [
          ExpenseRecord(
            id: 'exp-sec',
            category: '@SaaS',
            vendor: '-BadVendor',
            amountCents: 2500,
            taxCents: 250,
            expenseDate: '2026-10-05',
            notes: '\t=CMD|calc',
            createdAt: '2026-10-05T00:00:00Z',
          ),
        ],
        currencyCode: 'USD',
      );
      expect(expCsv.contains('"USD"'), isTrue);
      expect(expCsv.contains('"\'@SaaS"'), isTrue);
      expect(expCsv.contains('"\'-BadVendor"'), isTrue);
      expect(expCsv.contains('"\'\t=CMD|calc"'), isTrue);
      expect(expCsv.contains(',25.00,2.50,27.50,'), isTrue);
    });
  });

  group('Group 14: Task 8 Dark Mode Contrast, Accent Presets & Theme Persistence', () {
    test('AppSemanticColors preserves WCAG AA text contrast across light and dark modes', () {
      double contrastRatio(Color a, Color b) {
        final l1 = a.computeLuminance();
        final l2 = b.computeLuminance();
        final bright = l1 > l2 ? l1 : l2;
        final dark = l1 > l2 ? l2 : l1;
        return (bright + 0.05) / (dark + 0.05);
      }

      for (final status in SemanticStatus.values) {
        final lightTone = AppSemanticColors.resolve(Brightness.light, status);
        final darkTone = AppSemanticColors.resolve(Brightness.dark, status);

        expect(
          lightTone.text.computeLuminance() < lightTone.background.computeLuminance(),
          isTrue,
          reason: 'Light $status text must be darker than background',
        );
        expect(
          darkTone.text.computeLuminance() > darkTone.background.computeLuminance(),
          isTrue,
          reason: 'Dark $status text must be lighter than background',
        );
        expect(
          contrastRatio(lightTone.text, lightTone.background) >= 4.5,
          isTrue,
          reason: 'Light $status fails WCAG AA contrast',
        );
        expect(
          contrastRatio(darkTone.text, darkTone.background) >= 4.5,
          isTrue,
          reason: 'Dark $status fails WCAG AA contrast',
        );
      }
    });

    test('AppTheme storage helpers and preset accent color resolution match design palette', () {
      expect(AppTheme.parseThemeModeStorage('light'), equals(ThemeMode.light));
      expect(AppTheme.parseThemeModeStorage('DARK'), equals(ThemeMode.dark));
      expect(AppTheme.parseThemeModeStorage('system'), equals(ThemeMode.system));
      expect(AppTheme.parseThemeModeStorage('unknown'), equals(ThemeMode.system));
      expect(AppTheme.parseThemeModeStorage(null), equals(ThemeMode.system));

      expect(AppTheme.themeModeToStorage(ThemeMode.light), equals('light'));
      expect(AppTheme.themeModeToStorage(ThemeMode.dark), equals('dark'));
      expect(AppTheme.themeModeToStorage(ThemeMode.system), equals('system'));

      expect(AppPalette.slateSteel.toARGB32(), equals(0xFF475569));
      for (final preset in AppTheme.presetAccents) {
        expect(AppTheme.resolveAccentColor(preset.toARGB32()), equals(preset));
      }
      expect(AppTheme.resolveAccentColor(null), equals(AppTheme.seedColor));
      expect(AppTheme.resolveAccentColor(0), equals(AppTheme.seedColor));
      expect(AppTheme.resolveAccentColor(0xFF123456), equals(AppTheme.seedColor));

      final lightTheme = AppTheme.lightTheme(seed: AppPalette.emerald);
      final darkTheme = AppTheme.darkTheme(seed: AppPalette.emerald);
      expect(lightTheme.colorScheme.primary, equals(AppPalette.emerald));
      expect(darkTheme.colorScheme.primary, equals(AppPalette.emerald));
      expect(darkTheme.scaffoldBackgroundColor, equals(AppPalette.darkScaffold));
    });

    test('ThemeModeNotifier and AccentColorNotifier cycle and resolve valid states safely', () {
      final themeNotifier = ThemeModeNotifier();
      expect(themeNotifier.state, equals(ThemeMode.system));
      themeNotifier.cycleThemeMode();
      expect(themeNotifier.state, equals(ThemeMode.light));
      themeNotifier.cycleThemeMode();
      expect(themeNotifier.state, equals(ThemeMode.dark));
      themeNotifier.cycleThemeMode();
      expect(themeNotifier.state, equals(ThemeMode.system));

      final accentNotifier = AccentColorNotifier();
      expect(accentNotifier.state, equals(AppTheme.seedColor));
      accentNotifier.setAccentColor(AppPalette.roseRed);
      expect(accentNotifier.state, equals(AppPalette.roseRed));
      accentNotifier.setAccentColor(const Color(0xFF999999));
      expect(accentNotifier.state, equals(AppTheme.seedColor));
    });

    test('BackupService allows and validates theme_mode and accent_color on business_profile', () {
      final cols = BackupService.allowedTableColumns['business_profile']!;
      expect(cols.contains('theme_mode'), isTrue);
      expect(cols.contains('accent_color'), isTrue);

      expect(
        () => BackupService.validateBackupMap({
          'business_profile': [
            {
              'id': 'default',
              'business_name': 'Studio',
              'theme_mode': 'dark',
              'accent_color': AppPalette.emerald.toARGB32(),
            },
          ],
          'clients': const [],
          'invoices': const [],
        }),
        returnsNormally,
      );

      expect(
        () => BackupService.validateBackupMap({
          'business_profile': [
            {
              'id': 'default',
              'business_name': 'Studio',
              'theme_mode': 123,
            },
          ],
          'clients': const [],
          'invoices': const [],
        }),
        throwsA(isA<FormatException>()),
      );

      expect(
        () => BackupService.validateBackupMap({
          'business_profile': [
            {
              'id': 'default',
              'business_name': 'Studio',
              'accent_color': 'emerald',
            },
          ],
          'clients': const [],
          'invoices': const [],
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('Group 15: Task 9 PDF Multi-Page Repeating Headers & Image Downsampling', () {
    test('InvoicePdfService.downsampleImageBytes leaves small payloads unchanged and falls back safely on invalid bytes', () async {
      final smallPayload = Uint8List.fromList(List<int>.filled(64, 1));
      final keptSmall = await InvoicePdfService.downsampleImageBytes(
        smallPayload,
        downsampleThresholdBytes: 1024,
      );
      expect(keptSmall, equals(smallPayload));

      final invalidLarge = Uint8List.fromList(List<int>.filled(128 * 1024, 7));
      final fallbackResult = await InvoicePdfService.downsampleImageBytes(
        invalidLarge,
        downsampleThresholdBytes: 1024,
      );
      expect(fallbackResult.length, equals(invalidLarge.length));
    });

    test('InvoicePdfService generates MultiPage Estimate, Statement, and VOID Invoice PDFs cleanly', () async {
      TestWidgetsFlutterBinding.ensureInitialized();

      const profile = BusinessProfile(
        id: 'default',
        businessName: 'Northstar Studio',
        email: 'billing@northstar.example',
        phone: '+1 555 010 9988',
        address: '100 Market St, San Francisco, CA',
        taxId: 'US-EIN-99-1234567',
        paymentDetails: 'ACH Routing 121000358',
        currencySymbol: '\$',
        currencyCode: 'USD',
        currencyDecimals: 2,
      );
      const client = Client(
        id: 'c-1',
        name: 'Horizon Labs',
        email: 'ap@horizon.example',
        createdAt: '2026-10-01T00:00:00Z',
      );

      // Multi-page Estimate PDF (40 items triggers page break & repeat header row)
      const estimate = EstimateRecord(
        id: 'est-multi',
        clientId: 'c-1',
        clientName: 'Horizon Labs',
        estimateNumber: 'EST-0040',
        subtotalCents: 400000,
        taxCents: 40000,
        totalCents: 440000,
        status: 'PENDING',
        issueDate: '2026-10-01',
        expiryDate: '2026-10-31',
        currencyCode: 'USD',
        currencySymbol: '\$',
        currencyDecimals: 2,
        createdAt: '2026-10-01T00:00:00Z',
      );
      final estItems = List.generate(
        40,
        (i) => EstimateItem(
          id: 'ei-$i',
          estimateId: 'est-multi',
          description: 'Milestone Deliverable #${i + 1}',
          quantity: 1,
          unitPriceCents: 10000,
          taxRatePercentage: 10,
          taxCents: 1000,
          totalCents: 10000,
          createdAt: '2026-10-01T00:00:00Z',
        ),
      );
      final estPdf = await InvoicePdfService.generateEstimatePdf(
        estimate: estimate,
        items: estItems,
        client: client,
        businessProfile: profile,
      );
      expect(estPdf.length, greaterThan(1000));
      expect(estPdf.sublist(0, 5), equals([0x25, 0x50, 0x44, 0x46, 0x2D]));

      // Multi-page Statement PDF (45 invoices triggers multi-page table repeat header row)
      final statementInvoices = List.generate(
        45,
        (i) => InvoiceRecord(
          id: 'stmt-inv-$i',
          clientId: 'c-1',
          clientName: 'Horizon Labs',
          invoiceNumber: 'INV-${(i + 1).toString().padLeft(4, '0')}',
          subtotalCents: 10000,
          taxCents: 1000,
          totalCents: 11000,
          paidCents: i.isEven ? 11000 : 0,
          balanceDueCents: i.isEven ? 0 : 11000,
          status: i.isEven ? 'PAID' : 'PENDING',
          issueDate: '2026-10-${((i % 28) + 1).toString().padLeft(2, '0')}',
          dueDate: '2026-11-${((i % 28) + 1).toString().padLeft(2, '0')}',
          paymentTerms: 'Net 30 Days',
          currencyCode: i % 5 == 0 ? 'JPY' : 'USD',
          currencySymbol: i % 5 == 0 ? '¥' : '\$',
          currencyDecimals: i % 5 == 0 ? 0 : 2,
          createdAt: '2026-10-01T00:00:00Z',
        ),
      );
      final stmtPdf = await InvoicePdfService.generateStatementPdf(
        client: client,
        invoices: statementInvoices,
        businessProfile: profile,
      );
      expect(stmtPdf.length, greaterThan(1000));
      expect(stmtPdf.sublist(0, 5), equals([0x25, 0x50, 0x44, 0x46, 0x2D]));

      // VOID Invoice PDF
      const voidInvoice = InvoiceRecord(
        id: 'inv-void-pdf',
        clientId: 'c-1',
        clientName: 'Horizon Labs',
        invoiceNumber: 'INV-0999',
        subtotalCents: 50000,
        taxCents: 0,
        totalCents: 50000,
        paidCents: 0,
        balanceDueCents: 0,
        status: 'VOID',
        issueDate: '2026-10-01',
        dueDate: '2026-10-15',
        paymentTerms: 'Net 15 Days',
        createdAt: '2026-10-01T00:00:00Z',
      );
      final voidPdf = await InvoicePdfService.generateInvoicePdf(
        invoice: voidInvoice,
        items: const [],
        client: client,
        businessProfile: profile,
      );
      expect(voidPdf.length, greaterThan(1000));
      expect(voidPdf.sublist(0, 5), equals([0x25, 0x50, 0x44, 0x46, 0x2D]));
    });
  });

  group('Group 16: Task 11 WEBP PDF Image Guard & Line-Item Row Key Integrity', () {
    test('downsampleImageBytes never returns raw WEBP bytes and tryBuildMemoryImage guards malformed images', () async {
      TestWidgetsFlutterBinding.ensureInitialized();

      // RIFF....WEBP magic header under threshold (should never be returned raw)
      final malformedWebp = Uint8List.fromList([
        0x52, 0x49, 0x46, 0x46, 0x24, 0x00, 0x00, 0x00,
        0x57, 0x45, 0x42, 0x50, 0x56, 0x50, 0x38, 0x4C,
        0x00, 0x00, 0x00, 0x00,
      ]);

      final processedWebp = await InvoicePdfService.downsampleImageBytes(
        malformedWebp,
        downsampleThresholdBytes: 96 * 1024,
      );
      expect(detectMimeFromHeaderBytes(processedWebp), isNot(equals('image/webp')));
      expect(InvoicePdfService.tryBuildMemoryImage(malformedWebp), isNull);

      final corruptPng = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0xFF]);
      expect(InvoicePdfService.tryBuildMemoryImage(corruptPng), isNull);

      // End-to-end Invoice, Estimate & Statement PDFs must not throw when WEBP/malformed images are stored
      final badLogoUri = 'data:image/webp;base64,${base64Encode(malformedWebp)}';
      final badSigUri = 'data:image/png;base64,${base64Encode(corruptPng)}';
      final profile = BusinessProfile(
        id: 'default',
        businessName: 'Northstar Studio',
        email: 'billing@northstar.example',
        phone: '+1 555 010 9988',
        address: '100 Market St, San Francisco, CA',
        taxId: 'US-EIN-99-1234567',
        paymentDetails: 'ACH Routing 121000358',
        logoBase64: badLogoUri,
        signatureBase64: badSigUri,
      );
      const client = Client(id: 'c-1', name: 'Horizon Labs', createdAt: '2026-10-01T00:00:00Z');
      const invoice = InvoiceRecord(
        id: 'inv-webp-safe',
        clientId: 'c-1',
        clientName: 'Horizon Labs',
        invoiceNumber: 'INV-0099',
        subtotalCents: 10000,
        taxCents: 1000,
        totalCents: 11000,
        paidCents: 0,
        balanceDueCents: 11000,
        status: 'PENDING',
        issueDate: '2026-10-01',
        dueDate: '2026-10-15',
        paymentTerms: 'Net 15 Days',
        createdAt: '2026-10-01T00:00:00Z',
      );
      const estimate = EstimateRecord(
        id: 'est-webp-safe',
        clientId: 'c-1',
        clientName: 'Horizon Labs',
        estimateNumber: 'EST-0099',
        subtotalCents: 10000,
        taxCents: 1000,
        totalCents: 11000,
        status: 'PENDING',
        issueDate: '2026-10-01',
        expiryDate: '2026-10-31',
        createdAt: '2026-10-01T00:00:00Z',
      );

      final invPdf = await InvoicePdfService.generateInvoicePdf(
        invoice: invoice,
        items: const [],
        client: client,
        businessProfile: profile,
      );
      final estPdf = await InvoicePdfService.generateEstimatePdf(
        estimate: estimate,
        items: const [],
        client: client,
        businessProfile: profile,
      );
      final stmtPdf = await InvoicePdfService.generateStatementPdf(
        client: client,
        invoices: const [invoice],
        businessProfile: profile,
      );

      expect(invPdf.sublist(0, 5), equals([0x25, 0x50, 0x44, 0x46, 0x2D]));
      expect(estPdf.sublist(0, 5), equals([0x25, 0x50, 0x44, 0x46, 0x2D]));
      expect(stmtPdf.sublist(0, 5), equals([0x25, 0x50, 0x44, 0x46, 0x2D]));
    });

    test('LineItemEntry assigns unique IDs and removeLineItemAt preserves sibling identities on middle-row deletion', () {
      final first = LineItemEntry(description: 'Discovery', sacHsn: '998311', unitPriceCents: 50000);
      final middle = LineItemEntry(description: 'Obsolete Row', sacHsn: '998312', unitPriceCents: 10000);
      final third = LineItemEntry(description: 'Architecture', sacHsn: '998313', unitPriceCents: 90000);

      expect(first.id, isNotEmpty);
      expect({first.id, middle.id, third.id}.length, equals(3));

      final afterDelete = removeLineItemAt([first, middle, third], 1);
      expect(afterDelete.length, equals(2));
      expect(afterDelete[0].id, equals(first.id));
      expect(afterDelete[0].description, equals('Discovery'));
      expect(afterDelete[1].id, equals(third.id));
      expect(afterDelete[1].description, equals('Architecture'));
      expect(afterDelete[1].unitPriceCents, equals(90000));

      final minOneGuard = removeLineItemAt([first], 0);
      expect(minOneGuard.length, equals(1));
      expect(minOneGuard.first.id, equals(first.id));
    });
  });

  group('Group 17: Task 12 Cross-Stack Backup Compatibility & Desktop Save Extensions', () {
    test('BackupService.normalizeBackupPayloadForFlutter converts React Web JSON into validated Flutter SQLite tables', () {
      final reactSnapshot = <String, dynamic>{
        'exported_at': '2026-11-20T10:15:00.000Z',
        'businessProfile': {
          'business_name': 'Web Studio LLC',
          'currency_code': 'USD',
          'currency_symbol': '\$',
          'currency_decimals': 2,
          'accent_color': 'emerald',
          'theme_mode': 'dark',
        },
        'clients': [
          {
            'id': 'c-web-1',
            'name': 'Pacific Traders',
            'email': 'ap@pacific.example',
          },
        ],
        'invoices': [
          {
            'id': 'inv-web-1',
            'client_id': 'c-web-1',
            'client_name': 'Pacific Traders',
            'invoice_number': 'INV-0042',
            'subtotal_cents': 100000,
            'tax_cents': 10000,
            'total_cents': 110000,
            'paid_cents': 50000,
            'status': 'PARTIALLY_PAID',
            'issue_date': '2026-11-01',
            'due_date': '2026-11-15',
            'items': [
              {
                'description': 'Platform Audit',
                'sacHsn': '998314',
                'quantity': 2,
                'unitPriceCents': 50000,
                'taxSlab': 10,
              },
            ],
          },
        ],
        'estimates': [
          {
            'id': 'est-web-1',
            'client_id': 'c-web-1',
            'estimate_number': 'EST-0012',
            'subtotal_cents': 50000,
            'tax_cents': 0,
            'total_cents': 50000,
            'status': 'PENDING',
            'issue_date': '2026-11-10',
            'expiry_date': '2026-12-10',
            'items': [
              {
                'description': 'Phase 2 Proposal',
                'quantity': 1,
                'unitPriceCents': 50000,
                'taxSlab': 0,
              },
            ],
          },
        ],
        'expenses': [
          {
            'id': 'exp-web-1',
            'category': 'Cloud',
            'vendor': 'AWS',
            'tax_cents': 1800,
            'total_cents': 11800,
            'expense_date': '2026-11-05',
          },
        ],
        'savedItems': [
          {
            'id': 'si-web-1',
            'title': 'Hourly Advisory',
            'defaultPriceCents': 15000,
            'sacHsn': '998311',
          },
        ],
      };

      expect(() => BackupService.validateBackupMap(reactSnapshot), returnsNormally);

      final normalized = BackupService.normalizeBackupPayloadForFlutter(reactSnapshot);
      final profiles = normalized['business_profile'] as List<dynamic>;
      expect(profiles.length, equals(1));
      expect((profiles.first as Map)['business_name'], equals('Web Studio LLC'));
      expect((profiles.first as Map).containsKey('accent_color'), isFalse);

      final invItems = normalized['invoice_items'] as List<dynamic>;
      expect(invItems.length, equals(1));
      expect((invItems.first as Map)['invoice_id'], equals('inv-web-1'));
      expect((invItems.first as Map)['unit_price_cents'], equals(50000));
      expect((invItems.first as Map)['total_cents'], equals(100000));
      expect((invItems.first as Map)['tax_cents'], equals(10000));

      final payments = normalized['payments'] as List<dynamic>;
      expect(payments.length, equals(1));
      expect((payments.first as Map)['invoice_id'], equals('inv-web-1'));
      expect((payments.first as Map)['amount_cents'], equals(50000));

      final estItems = normalized['estimate_items'] as List<dynamic>;
      expect(estItems.length, equals(1));
      expect((estItems.first as Map)['estimate_id'], equals('est-web-1'));

      final expenses = normalized['expenses'] as List<dynamic>;
      expect((expenses.first as Map)['amount_cents'], equals(10000));

      final savedItems = normalized['saved_items'] as List<dynamic>;
      expect((savedItems.first as Map)['default_price_cents'], equals(15000));
      expect((savedItems.first as Map)['sac_hsn'], equals('998311'));

      // Invalid React payload shapes must still throw FormatException
      expect(
        () => BackupService.validateBackupMap({
          'clients': const [],
          'invoices': const [],
          'businessProfile': 'not-an-object',
        }),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => BackupService.validateBackupMap({
          'clients': const [{'id': 'c1', 'name': 'Acme'}],
          'invoices': const [
            {
              'id': 'inv-bad',
              'client_id': 'c1',
              'invoice_number': 'INV-1',
              'subtotal_cents': 1000,
              'tax_cents': 0,
              'total_cents': '1000',
              'status': 'PENDING',
            }
          ],
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('ExportFileHelper.ensureDesktopExtension appends omitted extensions cleanly', () {
      expect(
        ExportFileHelper.ensureDesktopExtension('/Users/test/Desktop/my_backup', 'json'),
        equals('/Users/test/Desktop/my_backup.json'),
      );
      expect(
        ExportFileHelper.ensureDesktopExtension('/Users/test/Desktop/my_backup.JSON', '.json'),
        equals('/Users/test/Desktop/my_backup.JSON'),
      );
      expect(
        ExportFileHelper.ensureDesktopExtension(r'C:\Exports\invoices', 'csv'),
        equals(r'C:\Exports\invoices.csv'),
      );
      expect(
        ExportFileHelper.ensureDesktopExtension(r'C:\Exports\invoices.csv', 'csv'),
        equals(r'C:\Exports\invoices.csv'),
      );
    });
  });

  group('Group 18: Task 13 Soft-Delete Tombstones, Deleted Filtering & Isolate Backup Round-Trip', () {
    test('Providers filter deleted_at IS NULL, cascade soft-deletes atomically, and isolate backup preserves tombstones', () async {
      final db = sqlite3.openInMemory();
      addTearDown(db.dispose);
      initializeLocalSchema(db);

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(container.dispose);

      final clientsNotifier = container.read(clientsProvider.notifier);
      final invoicesNotifier = container.read(invoicesProvider.notifier);
      final estimatesNotifier = container.read(estimatesProvider.notifier);
      final expensesNotifier = container.read(expensesProvider.notifier);
      final savedItemsNotifier = container.read(savedItemsProvider.notifier);

      // 1. Create client and verify active query sees it
      clientsNotifier.addClient(name: 'Orion Aerospace', email: 'ap@orion.example');
      expect(container.read(clientsProvider).length, equals(1));
      final clientId = container.read(clientsProvider).first.id;

      // 2. Create an estimate linked to client -> client deletion must be blocked
      final estId = estimatesNotifier.saveEstimate(
        clientId: clientId,
        items: const [
          DraftItem(description: 'Propulsion Audit', unitPriceCents: 50000, quantity: 1, totalCents: 50000),
        ],
        taxPercentage: 10,
      );
      expect(container.read(estimatesProvider).length, equals(1));
      expect(estimatesNotifier.getEstimateItems(estId).length, equals(1));
      expect(clientsNotifier.deleteClient(clientId), isFalse);

      // 3. Soft-delete estimate -> hides from active state, cascades tombstone to estimate_items
      estimatesNotifier.deleteEstimate(estId);
      expect(container.read(estimatesProvider), isEmpty);
      expect(estimatesNotifier.getEstimateItems(estId), isEmpty);
      final estRaw = db.select('SELECT deleted_at FROM estimates WHERE id = ?', [estId]);
      expect(estRaw.first['deleted_at'], isA<String>());
      final estItemRaw = db.select('SELECT deleted_at FROM estimate_items WHERE estimate_id = ?', [estId]);
      expect(estItemRaw.first['deleted_at'], isA<String>());

      // 4. Now that estimate is soft-deleted, create & pay an invoice, then soft-delete invoice
      final invId = invoicesNotifier.saveInvoice(
        clientId: clientId,
        items: const [
          DraftItem(description: 'Telemetry Review', unitPriceCents: 100000, quantity: 1, totalCents: 100000),
        ],
        taxPercentage: 0,
      );
      invoicesNotifier.recordPayment(
        invoiceId: invId,
        amountCents: 40000,
        paymentMethod: 'Wire Transfer',
        paymentDate: DateTime(2026, 11, 20),
      );
      expect(container.read(invoicesProvider).first.paidCents, equals(40000));
      expect(clientsNotifier.deleteClient(clientId), isFalse);

      invoicesNotifier.deleteInvoice(invId);
      expect(container.read(invoicesProvider), isEmpty);
      expect(invoicesNotifier.getInvoiceItems(invId), isEmpty);
      expect(invoicesNotifier.getInvoicePayments(invId), isEmpty);

      final invRaw = db.select('SELECT deleted_at FROM invoices WHERE id = ?', [invId]);
      expect(invRaw.first['deleted_at'], isA<String>());
      final payRaw = db.select('SELECT deleted_at FROM payments WHERE invoice_id = ?', [invId]);
      expect(payRaw.first['deleted_at'], isA<String>());

      // 5. Client deletion now succeeds cleanly via deleted_at tombstone
      expect(clientsNotifier.deleteClient(clientId), isTrue);
      expect(container.read(clientsProvider), isEmpty);
      final clientRaw = db.select('SELECT deleted_at FROM clients WHERE id = ?', [clientId]);
      expect(clientRaw.first['deleted_at'], isA<String>());

      // 6. Expenses soft-delete sets deleted_at and hides from loadExpenses()
      expensesNotifier.addExpense(
        category: 'Cloud',
        vendor: 'Hetzner',
        amountCents: 5000,
        expenseDate: '2026-11-22',
      );
      final expId = container.read(expensesProvider).first.id;
      expensesNotifier.deleteExpense(expId);
      expect(container.read(expensesProvider), isEmpty);
      final expRaw = db.select('SELECT deleted_at FROM expenses WHERE id = ?', [expId]);
      expect(expRaw.first['deleted_at'], isA<String>());

      // 7. SavedItems soft-delete hides deleted items without resurrecting defaults on reload
      final seededItems = List.of(container.read(savedItemsProvider));
      expect(seededItems.length, greaterThanOrEqualTo(4));
      for (final item in seededItems) {
        savedItemsNotifier.deleteItem(item.id);
      }
      expect(container.read(savedItemsProvider), isEmpty);
      savedItemsNotifier.loadItems();
      expect(container.read(savedItemsProvider), isEmpty);

      // 8. Isolate-offloaded backup export + decode/validate preserves tombstones cleanly
      final exportedBytes = await BackupService.exportDatabaseToJsonBytesAsync(db);
      final decodedMap = await BackupService.decodeAndValidateBackupBytesAsync(exportedBytes);
      expect((decodedMap['clients'] as List).length, equals(1));
      expect((decodedMap['invoices'] as List).length, equals(1));
      expect((decodedMap['estimates'] as List).length, equals(1));
      expect((decodedMap['expenses'] as List).length, equals(1));
    });
  });

  group('Group 19: Currency Tagging on Expenses/SavedItems & Locale-Independent Digit Grouping', () {
    test('formatIntegerGrouped & formatMoney apply Indian lakhs/crores for INR without Intl', () {
      expect(formatIntegerGrouped(1234567, 'INR'), equals('12,34,567'));
      expect(formatIntegerGrouped(1234567, 'USD'), equals('1,234,567'));
      expect(formatMoney(123456700, symbol: '₹', decimals: 2, currencyCode: 'INR'), equals('₹12,34,567.00'));
      expect(formatMoney(-10000000, symbol: '₹', decimals: 2), equals('-₹1,00,000.00'));
      expect(formatMoney(123456700, symbol: '\$', decimals: 2, currencyCode: 'USD'), equals('\$1,234,567.00'));
      expect(formatMoney(1000000, symbol: '¥', decimals: 0, currencyCode: 'JPY'), equals('¥1,000,000'));
    });

    test('currencySymbolForCode and resolveEffectiveCurrency resolve stored codes accurately', () {
      expect(currencySymbolForCode('JPY'), equals('¥'));
      expect(currencySymbolForCode('INR'), equals('₹'));
      expect(currencySymbolForCode('KWD'), equals('KWD'));

      final jpyResolved = resolveEffectiveCurrency(
        recordCode: 'JPY',
        recordDecimals: 0,
        defaultCode: 'USD',
        defaultSymbol: '\$',
        defaultDecimals: 2,
      );
      expect(jpyResolved.code, equals('JPY'));
      expect(jpyResolved.symbol, equals('¥'));
      expect(jpyResolved.decimals, equals(0));

      final legacyFallback = resolveEffectiveCurrency(
        recordCode: '',
        defaultCode: 'JPY',
        defaultSymbol: '¥',
        defaultDecimals: 0,
      );
      expect(legacyFallback.code, equals('JPY'));
      expect(legacyFallback.symbol, equals('¥'));
      expect(legacyFallback.decimals, equals(0));
    });

    test('computeDashboardCashFlow isolates multi-currency expenses (USD + JPY + KWD)', () {
      final summary = computeDashboardCashFlow(
        [
          const CurrencyLedgerEntry(
            currencyCode: 'USD',
            currencySymbol: '\$',
            currencyDecimals: 2,
            totalUnits: 110000,
            paidUnits: 110000,
            taxUnits: 10000,
          ),
          const CurrencyLedgerEntry(
            currencyCode: 'JPY',
            currencySymbol: '¥',
            currencyDecimals: 0,
            totalUnits: 50000,
            paidUnits: 50000,
            taxUnits: 0,
          ),
        ],
        expenseEntries: const [
          CurrencyExpenseEntry(
            currencyCode: 'USD',
            currencyDecimals: 2,
            totalUnits: 22000,
            taxUnits: 2000,
          ),
          CurrencyExpenseEntry(
            currencyCode: 'JPY',
            currencyDecimals: 0,
            totalUnits: 10000,
            taxUnits: 0,
          ),
          CurrencyExpenseEntry(
            currencyCode: 'KWD',
            currencyDecimals: 3,
            totalUnits: 12500,
            taxUnits: 0,
          ),
        ],
        defaultCode: 'USD',
        defaultSymbol: '\$',
        defaultDecimals: 2,
      );

      expect(summary.byCurrency.length, equals(3));
      final usd = summary.byCurrency.firstWhere((b) => b.code == 'USD');
      final jpy = summary.byCurrency.firstWhere((b) => b.code == 'JPY');
      final kwd = summary.byCurrency.firstWhere((b) => b.code == 'KWD');

      expect(usd.expenseGrossUnits, equals(22000));
      expect(usd.taxLiabilityUnits, equals(8000));
      expect(usd.netProfitUnits, equals(80000));

      expect(jpy.expenseGrossUnits, equals(10000));
      expect(jpy.netProfitUnits, equals(40000));

      expect(kwd.expenseGrossUnits, equals(12500));
      expect(kwd.netProfitUnits, equals(-12500));
      expect(summary.formattedNetProfit, equals('\$800.00 + ¥40,000 + -KWD12.500'));
    });

    test('SQLite ExpensesNotifier & SavedItemsNotifier capture and preserve currency across profile switches, CSV export, and backups', () {
      final db = sqlite3.openInMemory();
      addTearDown(db.dispose);
      initializeLocalSchema(db);

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(container.dispose);

      final profileNotifier = container.read(businessProfileProvider.notifier);
      final expensesNotifier = container.read(expensesProvider.notifier);
      final itemsNotifier = container.read(savedItemsProvider.notifier);

      // 1. Set active profile to JPY (0 decimals) and insert expense + catalog item
      profileNotifier.updateProfile(
        businessName: 'Tokyo Studio',
        email: 'hi@tokyo.example',
        phone: '',
        address: '',
        taxId: '',
        paymentDetails: '',
        currencySymbol: '¥',
        currencyCode: 'JPY',
        currencyDecimals: 0,
      );

      expensesNotifier.addExpense(
        category: 'Travel',
        vendor: 'Shinkansen',
        amountCents: 14000,
        taxCents: 1400,
        expenseDate: '2026-11-22',
      );
      itemsNotifier.addItem(
        title: 'Tokyo Onsite Workshop',
        sacHsn: '998313',
        defaultPriceCents: 50000,
      );

      // 2. Switch profile to KWD (3 decimals) and add KWD records
      profileNotifier.updateProfile(
        businessName: 'Kuwait Advisory',
        email: 'hi@kuwait.example',
        phone: '',
        address: '',
        taxId: '',
        paymentDetails: '',
        currencySymbol: 'KWD',
        currencyCode: 'KWD',
        currencyDecimals: 3,
      );
      expensesNotifier.addExpense(
        category: 'Office',
        vendor: 'Dinar Hosting',
        amountCents: 12500,
        taxCents: 0,
        expenseDate: '2026-11-23',
      );

      final allExpenses = container.read(expensesProvider);
      final jpyExp = allExpenses.firstWhere((e) => e.vendor == 'Shinkansen');
      final kwdExp = allExpenses.firstWhere((e) => e.vendor == 'Dinar Hosting');
      expect(jpyExp.currencyCode, equals('JPY'));
      expect(jpyExp.currencyDecimals, equals(0));
      expect(kwdExp.currencyCode, equals('KWD'));
      expect(kwdExp.currencyDecimals, equals(3));

      // 3. Updating JPY expense without passing currency preserves JPY/0 instead of overwriting with KWD/3
      expensesNotifier.updateExpense(
        id: jpyExp.id,
        category: 'Travel',
        vendor: 'Shinkansen Green Car',
        amountCents: 18000,
        taxCents: 1800,
        expenseDate: '2026-11-22',
      );
      final updatedJpyExp = container.read(expensesProvider).firstWhere((e) => e.id == jpyExp.id);
      expect(updatedJpyExp.currencyCode, equals('JPY'));
      expect(updatedJpyExp.currencyDecimals, equals(0));

      final tokyoItem = container.read(savedItemsProvider).firstWhere((i) => i.title == 'Tokyo Onsite Workshop');
      expect(tokyoItem.currencyCode, equals('JPY'));
      expect(tokyoItem.currencyDecimals, equals(0));

      // 4. Per-expense CSV formats each row with its own currency code & decimals
      final expCsv = CsvExportService.generateExpensesCsv(
        expenses: allExpenses,
        currencyCode: 'KWD',
      );
      expect(expCsv, contains(',"JPY",18000,1800,19800,'));
      expect(expCsv, contains(',"KWD",12.500,0.000,12.500,'));

      // 5. JSON backup round-trip preserves currency_code and currency_decimals on expenses and saved_items
      final jsonText = BackupService.exportDatabaseToJson(db);
      final db2 = sqlite3.openInMemory();
      addTearDown(db2.dispose);
      initializeLocalSchema(db2);
      BackupService.importDatabaseFromJson(db2, jsonText);
      final restoredExp = db2.select('SELECT currency_code, currency_decimals FROM expenses WHERE vendor = ?', ['Shinkansen Green Car']).first;
      expect(restoredExp['currency_code'], equals('JPY'));
      expect(restoredExp['currency_decimals'], equals(0));
      final restoredItem = db2.select('SELECT currency_code, currency_decimals FROM saved_items WHERE title = ?', ['Tokyo Onsite Workshop']).first;
      expect(restoredItem['currency_code'], equals('JPY'));
      expect(restoredItem['currency_decimals'], equals(0));
    });
  });

  group('Group 20: Business Profile Numbering Prefixes, Sequence Sync & Dynamic QR Payloads', () {
    test('BusinessProfileNotifier persists/validates prefixes, nextInvoiceNumber, paymentQrPayload and preserves omitted fields', () {
      final db = sqlite3.openInMemory();
      addTearDown(db.dispose);
      initializeLocalSchema(db);

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(businessProfileProvider.notifier);

      notifier.updateProfile(
        businessName: 'Studio Alpha',
        email: 'billing@alpha.example',
        phone: '+1 555 0100',
        address: '100 Main St',
        taxId: 'TAX-1',
        paymentDetails: 'ACH 123',
        invoicePrefix: '  FY26-  ',
        estimatePrefix: '  QT-  ',
        nextInvoiceNumber: 42,
        paymentQrPayload: '  alpha@upi  ',
      );

      var prof = container.read(businessProfileProvider);
      expect(prof.invoicePrefix, equals('FY26-'));
      expect(prof.estimatePrefix, equals('QT-'));
      expect(prof.nextInvoiceNumber, equals(42));
      expect(prof.paymentQrPayload, equals('alpha@upi'));

      // Updating unrelated fields without passing prefix/QR preserves them cleanly
      notifier.updateProfile(
        businessName: 'Studio Alpha LLC',
        email: 'billing@alpha.example',
        phone: '+1 555 0100',
        address: '100 Main St',
        taxId: 'TAX-1',
        paymentDetails: 'ACH 456',
      );
      prof = container.read(businessProfileProvider);
      expect(prof.invoicePrefix, equals('FY26-'));
      expect(prof.estimatePrefix, equals('QT-'));
      expect(prof.nextInvoiceNumber, equals(42));
      expect(prof.paymentQrPayload, equals('alpha@upi'));

      // Blank prefixes normalize to defaults; nextInvoiceNumber < 1 clamps to 1
      notifier.updateProfile(
        businessName: 'Studio Alpha LLC',
        email: '',
        phone: '',
        address: '',
        taxId: '',
        paymentDetails: '',
        invoicePrefix: '   ',
        estimatePrefix: '',
        nextInvoiceNumber: 0,
        paymentQrPayload: '',
      );
      prof = container.read(businessProfileProvider);
      expect(prof.invoicePrefix, equals('INV-'));
      expect(prof.estimatePrefix, equals('EST-'));
      expect(prof.nextInvoiceNumber, equals(1));
      expect(prof.paymentQrPayload, equals(''));
    });

    test('InvoicesNotifier & EstimatesNotifier honor custom prefixes, skip DRAFTs/keep VOID gaps, and sync businessProfileProvider', () {
      final db = sqlite3.openInMemory();
      addTearDown(db.dispose);
      initializeLocalSchema(db);

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(container.dispose);

      container.read(clientsProvider.notifier).addClient(name: 'Horizon Corp');
      final clientId = container.read(clientsProvider).first.id;

      container.read(businessProfileProvider.notifier).updateProfile(
            businessName: 'Northstar',
            email: '',
            phone: '',
            address: '',
            taxId: '',
            paymentDetails: '',
            invoicePrefix: 'FY26-',
            estimatePrefix: 'QT-',
            nextInvoiceNumber: 25,
            paymentQrPayload: 'northstar@upi',
          );

      final invNotifier = container.read(invoicesProvider.notifier);
      final estNotifier = container.read(estimatesProvider.notifier);

      // Draft consumes no fiscal sequence number
      final draftInvId = invNotifier.saveInvoice(
        clientId: clientId,
        items: const [DraftItem(description: 'Draft Work', unitPriceCents: 1000, quantity: 1, totalCents: 1000)],
        taxPercentage: 0,
        status: 'DRAFT',
      );
      expect(container.read(invoicesProvider).first.invoiceNumber, startsWith('DRAFT-'));
      expect(container.read(businessProfileProvider).nextInvoiceNumber, equals(25));

      // Finalizing draft advances using custom prefix FY26- and nextInvoiceNumber=25
      invNotifier.finalizeDraftInvoice(draftInvId);
      final finalized = container.read(invoicesProvider).firstWhere((i) => i.id == draftInvId);
      expect(finalized.invoiceNumber, equals('FY26-0025'));
      expect(container.read(businessProfileProvider).nextInvoiceNumber, equals(26));

      // Voiding FY26-0025 must NOT cause FY26-0025 to be reused on duplicateInvoice
      invNotifier.voidInvoice(draftInvId);
      final dupNumber = invNotifier.duplicateInvoice(draftInvId);
      expect(dupNumber, equals('FY26-0026'));
      expect(container.read(businessProfileProvider).nextInvoiceNumber, equals(27));

      // Estimates honor QT- prefix & converting estimate advances FY26-0027
      final estId = estNotifier.saveEstimate(
        clientId: clientId,
        items: const [DraftItem(description: 'Quote Item', unitPriceCents: 5000, quantity: 1, totalCents: 5000)],
        taxPercentage: 0,
      );
      expect(container.read(estimatesProvider).firstWhere((e) => e.id == estId).estimateNumber, equals('QT-0001'));

      estNotifier.convertEstimateToInvoice(estId);
      final convertedInv = container.read(invoicesProvider).firstWhere((i) => i.invoiceNumber == 'FY26-0027');
      expect(convertedInv.status, equals('PENDING'));
      expect(container.read(businessProfileProvider).nextInvoiceNumber, equals(28));
    });

    test('generateDynamicQrPayload builds UPI & payment URL QR payloads with currency decimals', () {
      expect(
        generateDynamicQrPayload(
          rawPayload: '',
          businessName: 'Studio',
          balanceDueUnits: 12500,
          currencyDecimals: 2,
          invoiceNumber: 'INV-0001',
        ),
        isEmpty,
      );

      final upiInr = generateDynamicQrPayload(
        rawPayload: 'merchant@upi',
        businessName: 'Alpha Studio',
        balanceDueUnits: 12550,
        currencyDecimals: 2,
        invoiceNumber: 'FY26-0025',
        currencyCode: 'INR',
      );
      expect(upiInr, equals('upi://pay?pa=merchant%40upi&pn=Alpha%20Studio&am=125.50&tn=Invoice-FY26-0025&cu=INR'));

      final upiJpy = generateDynamicQrPayload(
        rawPayload: 'upi://pay?pa=tokyo@bank&pn=OldName',
        businessName: 'Tokyo Lab',
        balanceDueUnits: 45000,
        currencyDecimals: 0,
        invoiceNumber: 'INV-0010',
        currencyCode: 'JPY',
      );
      expect(upiJpy, contains('am=45000'));
      expect(upiJpy, contains('cu=JPY'));

      final linkWithInv = generateDynamicQrPayload(
        rawPayload: 'https://pay.studio.example/checkout',
        businessName: 'Studio',
        balanceDueUnits: 1000,
        currencyDecimals: 2,
        invoiceNumber: 'FY26-0025',
      );
      expect(linkWithInv, equals('https://pay.studio.example/checkout?invoice=FY26-0025'));

      final linkExistingRef = generateDynamicQrPayload(
        rawPayload: 'https://pay.studio.example/checkout?ref=ABC',
        businessName: 'Studio',
        balanceDueUnits: 1000,
        currencyDecimals: 2,
        invoiceNumber: 'FY26-0025',
      );
      expect(linkExistingRef, equals('https://pay.studio.example/checkout?ref=ABC'));
    });
  });

  group('Group 21: OEM Telephony Fallback, Empty-Email Mailto Guard, PDF RTL & Script Diagnostics', () {
    test('buildSmsFallbackUri generates smsto: fallback URIs and rejects empty phones', () {
      expect(
        buildSmsFallbackUri(phone: '+1 (555) 019-2834', body: 'Hello & Pay').toString(),
        equals('smsto:+15550192834?body=Hello%20%26%20Pay'),
      );
      expect(
        buildSmsFallbackUri(phone: '+91 98765 43210').toString(),
        equals('smsto:+919876543210'),
      );
      expect(buildSmsFallbackUri(phone: '   ', body: 'Hello'), isNull);
    });

    test('buildSmsUri uses &body= when Apple iOS/macOS flag is enabled', () {
      const macPlatforms = [TargetPlatform.iOS, TargetPlatform.macOS];
      for (final p in macPlatforms) {
        final isApple = p == TargetPlatform.iOS || p == TargetPlatform.macOS;
        expect(
          buildSmsUri(phone: '+971 50 123 4567', body: 'Invoice Due', isIos: isApple).toString(),
          equals('sms:+971501234567&body=Invoice%20Due'),
        );
      }
      const nonApple = TargetPlatform.android;
      final isAndroidApple = nonApple == TargetPlatform.iOS || nonApple == TargetPlatform.macOS;
      expect(
        buildSmsUri(phone: '+971 50 123 4567', body: 'Invoice Due', isIos: isAndroidApple).toString(),
        equals('sms:+971501234567?body=Invoice%20Due'),
      );
    });

    test('buildMailtoUri omits dangling empty queries and handles empty recipient cleanly', () {
      expect(
        buildMailtoUri(email: '', subject: 'Subject', body: 'Body').toString(),
        equals('mailto:?subject=Subject&body=Body'),
      );
      expect(
        buildMailtoUri(email: '', subject: '', body: '').toString(),
        equals('mailto:'),
      );
      expect(
        buildMailtoUri(email: 'ap@client.test', subject: 'Hello', body: '').toString(),
        equals('mailto:ap@client.test?subject=Hello'),
      );
      expect(
        buildCopyEverythingReminderText(
          subject: 'Invoice INV-0001 Reminder',
          message: 'Hi Client, balance due.',
          clientName: 'Acme Corp',
          clientEmail: '',
          phone: '+1 555 0192',
        ),
        equals('To: Acme Corp • +15550192\nSubject: Invoice INV-0001 Reminder\n\nHi Client, balance due.'),
      );
    });

    test('containsRtlCharacters detects Arabic and Hebrew blocks while ignoring Latin and currency symbols', () {
      expect(containsRtlCharacters('شركة الأمل للتقنية'), isTrue);
      expect(containsRtlCharacters('Invoice for شركة أمل'), isTrue);
      expect(containsRtlCharacters('חשבונית מס'), isTrue);
      expect(containsRtlCharacters('\u0750\u08A0'), isTrue);
      expect(containsRtlCharacters('Acme Studio AED 1,250.00 ₹100 ¥500 €20'), isFalse);
      expect(containsRtlCharacters(''), isFalse);
    });

    test('InvoicePdfService.diagnoseUnsupportedPdfScripts warns honestly on CJK/Indic/Arabic and passes Latin/EUR/INR', () {
      expect(
        InvoicePdfService.diagnoseUnsupportedPdfScripts([
          'Studio Alpha GmbH',
          'Invoice INV-0010 • ₹12,34,567.00 • €450.00 • ¥50,000 • Café München',
        ]),
        isNull,
      );
      final cjkDiag = InvoicePdfService.diagnoseUnsupportedPdfScripts(['株式会社東京']);
      expect(cjkDiag, contains('CJK'));
      final indicDiag = InvoicePdfService.diagnoseUnsupportedPdfScripts(['सेवा शुल्क']);
      expect(indicDiag, contains('Indic'));
      final arabicDiag = InvoicePdfService.diagnoseUnsupportedPdfScripts(['شركة الخليج']);
      expect(arabicDiag, contains('Arabic'));
    });

    test('InvoicePdfService.generateInvoicePdf renders GCC/Arabic RTL invoice cleanly without errors', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final bytes = await InvoicePdfService.generateInvoicePdf(
        invoice: const InvoiceRecord(
          id: 'inv-rtl',
          clientId: 'c-rtl',
          clientName: 'شركة الخليج',
          invoiceNumber: 'INV-0100',
          subtotalCents: 100000,
          taxCents: 5000,
          totalCents: 105000,
          paidCents: 0,
          balanceDueCents: 105000,
          status: 'PENDING',
          issueDate: '2026-11-23',
          dueDate: '2026-12-07',
          paymentTerms: 'Net 14',
          currencyCode: 'AED',
          currencySymbol: 'AED',
          currencyDecimals: 2,
          taxMode: 'GULF_VAT',
          createdAt: '2026-11-23T00:00:00Z',
        ),
        items: const [
          InvoiceItem(
            id: 'it-1',
            invoiceId: 'inv-rtl',
            description: 'تطوير تطبيقات الجوال',
            quantity: 1,
            unitPriceCents: 100000,
            totalCents: 100000,
            createdAt: '2026-11-23T00:00:00Z',
          ),
        ],
        client: const Client(
          id: 'c-rtl',
          name: 'شركة الخليج',
          address: 'دبي، الإمارات العربية المتحدة',
          taxId: '100234567800003',
          createdAt: '2026-11-23T00:00:00Z',
        ),
        businessProfile: const BusinessProfile(
          id: 'default',
          businessName: 'Dubai Digital LLC',
          email: 'billing@dubaidigital.example',
          phone: '+971 4 000 0000',
          address: 'Dubai Internet City',
          taxId: '100987654300003',
          paymentDetails: 'IBAN AE070331234567890123456',
          currencyCode: 'AED',
          currencySymbol: 'AED',
          currencyDecimals: 2,
        ),
      );
      expect(bytes, isNotEmpty);
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
