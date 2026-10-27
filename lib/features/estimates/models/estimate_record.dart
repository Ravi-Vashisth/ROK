import 'package:sqlite3/sqlite3.dart' hide Row;
import 'package:sqlite3/sqlite3.dart' as sql show Row;

class EstimateRecord {
  final String id;
  final String clientId;
  final String clientName;
  final String estimateNumber;
  final int subtotalCents;
  final int taxCents;
  final int totalCents;
  final String status; // 'PENDING', 'ACCEPTED', 'DECLINED', 'CONVERTED'
  final String issueDate;
  final String expiryDate;
  final String convertedInvoiceId;
  final String createdAt;

  const EstimateRecord({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.estimateNumber,
    required this.subtotalCents,
    required this.taxCents,
    required this.totalCents,
    required this.status,
    required this.issueDate,
    required this.expiryDate,
    this.convertedInvoiceId = '',
    required this.createdAt,
  });

  factory EstimateRecord.fromRow(sql.Row row, {String clientName = ''}) {
    return EstimateRecord(
      id: row['id'] as String,
      clientId: row['client_id'] as String,
      clientName: clientName.isNotEmpty ? clientName : (row['client_name'] as String? ?? 'Client'),
      estimateNumber: row['estimate_number'] as String,
      subtotalCents: row['subtotal_cents'] as int,
      taxCents: row['tax_cents'] as int,
      totalCents: row['total_cents'] as int,
      status: row['status'] as String? ?? 'PENDING',
      issueDate: row['issue_date'] as String? ?? '',
      expiryDate: row['expiry_date'] as String? ?? '',
      convertedInvoiceId: row['converted_invoice_id'] as String? ?? '',
      createdAt: row['created_at'] as String,
    );
  }

  bool get isConverted => status.toUpperCase() == 'CONVERTED';
}
