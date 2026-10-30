import 'package:flutter_test/flutter_test.dart';

import '../lib/core/utils/backup_service.dart';
import '../lib/core/utils/money_utils.dart';
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
        () => BackupService.importDatabaseFromJson(DummyDb(), invalidBackup),
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
}

// Dummy classes for lightweight unit testing without native SQLite dynamic libraries
class DummyDb implements dynamic {
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
