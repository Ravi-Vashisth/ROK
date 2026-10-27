import 'package:sqlite3/sqlite3.dart' hide Row;
import 'package:sqlite3/sqlite3.dart' as sql show Row;

class InvoiceRecord {
  final String id;
  final String clientId;
  final String clientName;
  final String invoiceNumber;
  final int subtotalCents;
  final int taxCents;
  final int totalCents;
  final int paidCents;
  final int balanceDueCents;
  final String status;
  final String issueDate;
  final String dueDate;
  final String paymentTerms;
  final String createdAt;

  const InvoiceRecord({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.invoiceNumber,
    required this.subtotalCents,
    required this.taxCents,
    required this.totalCents,
    required this.paidCents,
    required this.balanceDueCents,
    required this.status,
    required this.issueDate,
    required this.dueDate,
    required this.paymentTerms,
    required this.createdAt,
  });

  factory InvoiceRecord.fromRow(sql.Row row) {
    final rawCreatedAt = (row['created_at'] as String?) ?? '';
    final rawIssue = (row['issue_date'] as String?) ?? '';
    final rawDue = (row['due_date'] as String?) ?? '';
    final rawTerms = (row['payment_terms'] as String?) ?? 'Due on Receipt';

    final effectiveIssueDate = rawIssue.isNotEmpty
        ? rawIssue
        : (rawCreatedAt.isNotEmpty ? rawCreatedAt.split('T').first : '');
    final effectiveDueDate = rawDue.isNotEmpty ? rawDue : effectiveIssueDate;

    final totalCents = row['total_cents'] as int;
    final paidCents = (row['paid_cents'] as int?) ?? 0;
    final balanceDueCents = (totalCents - paidCents) > 0 ? (totalCents - paidCents) : 0;

    return InvoiceRecord(
      id: row['id'] as String,
      clientId: row['client_id'] as String,
      clientName: (row['client_name'] as String?) ?? 'Unknown Client',
      invoiceNumber: row['invoice_number'] as String,
      subtotalCents: row['subtotal_cents'] as int,
      taxCents: row['tax_cents'] as int,
      totalCents: totalCents,
      paidCents: paidCents,
      balanceDueCents: balanceDueCents,
      status: row['status'] as String,
      issueDate: effectiveIssueDate,
      dueDate: effectiveDueDate,
      paymentTerms: rawTerms,
      createdAt: rawCreatedAt,
    );
  }

  /// Whether the invoice is fully settled.
  bool get isFullyPaid => paidCents >= totalCents || status.toUpperCase() == 'PAID';

  /// Whether some payment has been received but remaining balance is still due.
  bool get isPartiallyPaid => paidCents > 0 && paidCents < totalCents && status.toUpperCase() != 'PAID';

  /// Returns true if the invoice is not paid and the due date is strictly in the past.
  bool get isOverdue {
    if (isFullyPaid) return false;
    if (dueDate.isEmpty) return false;
    try {
      final due = DateTime.parse(dueDate);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final dueDay = DateTime(due.year, due.month, due.day);
      return today.isAfter(dueDay);
    } catch (_) {
      return false;
    }
  }

  /// Resolves the real-time dynamic status of the invoice based on payments and due date.
  String get computedStatus {
    if (isFullyPaid) return 'PAID';
    if (isPartiallyPaid) return 'PARTIALLY_PAID';
    if (isOverdue) return 'OVERDUE';
    return 'PENDING';
  }

  /// Calculates the number of days past due.
  int get daysOverdue {
    if (!isOverdue) return 0;
    try {
      final due = DateTime.parse(dueDate);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final dueDay = DateTime(due.year, due.month, due.day);
      final diff = today.difference(dueDay).inDays;
      return diff > 0 ? diff : 0;
    } catch (_) {
      return 0;
    }
  }
}
