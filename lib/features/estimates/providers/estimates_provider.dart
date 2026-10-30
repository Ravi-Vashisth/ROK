import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/money_utils.dart';
import '../../invoices/providers/invoices_provider.dart';
import '../models/estimate_item.dart';
import '../models/estimate_record.dart';

class EstimatesNotifier extends StateNotifier<List<EstimateRecord>> {
  final Database _db;
  final Ref _ref;

  EstimatesNotifier(this._db, this._ref) : super([]) {
    loadEstimates();
  }

  void loadEstimates() {
    final ResultSet results = _db.select('''
      SELECT 
        e.id,
        e.client_id,
        c.name AS client_name,
        e.estimate_number,
        e.subtotal_cents,
        e.tax_cents,
        e.total_cents,
        e.status,
        e.issue_date,
        e.expiry_date,
        e.converted_invoice_id,
        e.terms,
        e.notes,
        e.discount_type,
        e.discount_value,
        e.discount_cents,
        e.created_at
      FROM estimates e
      LEFT JOIN clients c ON e.client_id = c.id
      ORDER BY e.created_at DESC
    ''');

    state = results.map((row) => EstimateRecord.fromRow(row)).toList();
  }

  String getNextEstimateNumber() {
    final profileRes = _db.select("SELECT estimate_prefix FROM business_profile WHERE id = 'default'");
    String prefix = 'EST-';
    if (profileRes.isNotEmpty) {
      prefix = (profileRes.first['estimate_prefix'] as String?) ?? 'EST-';
    }
    final offset = prefix.length + 1;
    final result = _db.select('''
      SELECT COALESCE(MAX(CAST(SUBSTR(estimate_number, ?) AS INTEGER)), 0) + 1 AS next_num FROM estimates;
    ''', [offset]);
    final nextNumber = (result.first['next_num'] as int?) ?? 1;
    return '$prefix${nextNumber.toString().padLeft(4, '0')}';
  }

  List<EstimateItem> getEstimateItems(String estimateId) {
    final ResultSet results = _db.select(
      'SELECT * FROM estimate_items WHERE estimate_id = ? ORDER BY rowid ASC',
      [estimateId],
    );
    return results.map((row) => EstimateItem.fromRow(row)).toList();
  }

  String saveEstimate({
    required String clientId,
    required List<DraftItem> items,
    required int taxPercentage,
    String? issueDate,
    String? expiryDate,
    String terms = '',
    String notes = '',
    String discountType = 'none',
    int discountValue = 0,
    String status = 'PENDING',
  }) {
    if (items.isEmpty) {
      throw ArgumentError('Cannot save an estimate with no line items.');
    }

    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final effectiveIssueDate = (issueDate != null && issueDate.trim().isNotEmpty)
        ? issueDate.trim()
        : todayStr;

    String effectiveExpiryDate = (expiryDate != null && expiryDate.trim().isNotEmpty)
        ? expiryDate.trim()
        : '';

    if (effectiveExpiryDate.isEmpty) {
      try {
        final parsedIssue = DateTime.parse(effectiveIssueDate);
        final exp = parsedIssue.add(const Duration(days: 30));
        effectiveExpiryDate =
            '${exp.year}-${exp.month.toString().padLeft(2, '0')}-${exp.day.toString().padLeft(2, '0')}';
      } catch (_) {
        effectiveExpiryDate = effectiveIssueDate;
      }
    }

    final estimateId = generateUniqueId();
    final estimateNumber = getNextEstimateNumber();
    final createdAt = DateTime.now().toUtc().toIso8601String();

    final subtotalCents = items.fold<int>(0, (sum, item) => sum + item.totalCents);
    final discountCents = calculateDiscountCents(subtotalCents, discountType, discountValue);
    final netSubtotalCents = (subtotalCents - discountCents) > 0 ? (subtotalCents - discountCents) : 0;
    final itemsTaxSum = items.fold<int>(0, (sum, item) => sum + item.taxCents);
    final taxCents = itemsTaxSum > 0 ? itemsTaxSum : calculateTaxCents(netSubtotalCents, taxPercentage);
    final totalCents = netSubtotalCents + taxCents;

    _db.execute('BEGIN TRANSACTION;');
    try {
      final stmt = _db.prepare('''
        INSERT INTO estimates (
          id, client_id, estimate_number, subtotal_cents, tax_cents, total_cents,
          status, issue_date, expiry_date, converted_invoice_id, terms, notes,
          discount_type, discount_value, discount_cents, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''');
      try {
        stmt.execute([
          estimateId,
          clientId,
          estimateNumber,
          subtotalCents,
          taxCents,
          totalCents,
          status,
          effectiveIssueDate,
          effectiveExpiryDate,
          '',
          terms,
          notes,
          discountType,
          discountValue,
          discountCents,
          createdAt,
        ]);
      } finally {
        stmt.dispose();
      }

      final itemStmt = _db.prepare('''
        INSERT INTO estimate_items (
          id, estimate_id, description, sac_hsn, quantity, unit_price_cents, tax_rate_percentage, tax_cents, total_cents, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''');
      try {
        for (final item in items) {
          final itemId = generateUniqueId();
          itemStmt.execute([
            itemId,
            estimateId,
            item.description,
            item.sacHsn,
            item.quantity,
            item.unitPriceCents,
            item.taxRatePercentage,
            item.taxCents,
            item.totalCents,
            createdAt,
          ]);
        }
      } finally {
        itemStmt.dispose();
      }

      _db.execute('COMMIT;');
    } catch (e) {
      _db.execute('ROLLBACK;');
      rethrow;
    }

    loadEstimates();
    return estimateId;
  }

  void convertEstimateToInvoice(String estimateId) {
    final estRes = _db.select('SELECT * FROM estimates WHERE id = ?', [estimateId]);
    if (estRes.isEmpty) return;

    final estRow = estRes.first;
    final clientId = estRow['client_id'] as String;
    final subtotalCents = estRow['subtotal_cents'] as int;
    final taxCents = estRow['tax_cents'] as int;
    final terms = (estRow['terms'] as String?) ?? '';
    final notes = (estRow['notes'] as String?) ?? '';
    final discountType = (estRow['discount_type'] as String?) ?? 'none';
    final discountValue = (estRow['discount_value'] as int?) ?? 0;
    final discountCents = (estRow['discount_cents'] as int?) ?? 0;

    final items = getEstimateItems(estimateId);
    final draftItems = items
        .map((it) => DraftItem(
              description: it.description,
              sacHsn: it.sacHsn,
              unitPriceCents: it.unitPriceCents,
              quantity: it.quantity,
              taxRatePercentage: it.taxRatePercentage,
              taxCents: it.taxCents,
              totalCents: it.totalCents,
            ))
        .toList();

    _db.execute('BEGIN TRANSACTION;');
    try {
      final invoiceId = generateUniqueId();
      final invoiceNumber = _ref.read(invoicesProvider.notifier).getNextInvoiceNumber();
      final createdAt = DateTime.now().toUtc().toIso8601String();

      final netSubtotalCents = (subtotalCents - discountCents) > 0 ? (subtotalCents - discountCents) : 0;
      final totalCents = netSubtotalCents + taxCents;
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final invoiceStmt = _db.prepare('''
        INSERT INTO invoices (
          id, client_id, invoice_number, subtotal_cents, tax_cents, total_cents,
          status, issue_date, due_date, payment_terms, terms, notes,
          discount_type, discount_value, discount_cents, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''');
      try {
        invoiceStmt.execute([
          invoiceId,
          clientId,
          invoiceNumber,
          subtotalCents,
          taxCents,
          totalCents,
          'PENDING',
          todayStr,
          todayStr,
          'Due on Receipt',
          terms,
          notes,
          discountType,
          discountValue,
          discountCents,
          createdAt,
        ]);
      } finally {
        invoiceStmt.dispose();
      }

      final itemStmt = _db.prepare('''
        INSERT INTO invoice_items (
          id, invoice_id, description, sac_hsn, quantity, unit_price_cents, tax_rate_percentage, tax_cents, total_cents, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''');
      try {
        for (final item in draftItems) {
          final itemId = generateUniqueId();
          itemStmt.execute([
            itemId,
            invoiceId,
            item.description,
            item.sacHsn,
            item.quantity,
            item.unitPriceCents,
            item.taxRatePercentage,
            item.taxCents,
            item.totalCents,
            createdAt,
          ]);
        }
      } finally {
        itemStmt.dispose();
      }

      _db.execute("UPDATE business_profile SET next_invoice_number = next_invoice_number + 1 WHERE id = 'default'");

      _db.execute(
        "UPDATE estimates SET status = 'CONVERTED', converted_invoice_id = ? WHERE id = ?",
        [invoiceId, estimateId],
      );

      _db.execute('COMMIT;');
    } catch (e) {
      _db.execute('ROLLBACK;');
      rethrow;
    }

    _ref.read(invoicesProvider.notifier).loadInvoices();
    loadEstimates();
  }

  void updateEstimateStatus(String estimateId, String newStatus) {
    _db.execute('UPDATE estimates SET status = ? WHERE id = ?', [newStatus, estimateId]);
    loadEstimates();
  }
}

final estimatesProvider = StateNotifierProvider<EstimatesNotifier, List<EstimateRecord>>((ref) {
  return EstimatesNotifier(ref.watch(databaseProvider), ref);
});
