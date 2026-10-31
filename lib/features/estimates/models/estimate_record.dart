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
  final String terms;
  final String notes;
  final String discountType; // 'none', 'percent', 'flat'
  final int discountValue;
  final int discountCents;
  final String poNumber;
  final String currencyCode;
  final String currencySymbol;
  final int currencyDecimals;
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
    this.terms = '',
    this.notes = '',
    this.discountType = 'none',
    this.discountValue = 0,
    this.discountCents = 0,
    this.poNumber = '',
    this.currencyCode = '',
    this.currencySymbol = '',
    this.currencyDecimals = 2,
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
      terms: (row['terms'] as String?) ?? '',
      notes: (row['notes'] as String?) ?? '',
      discountType: (row['discount_type'] as String?) ?? 'none',
      discountValue: (row['discount_value'] as int?) ?? 0,
      discountCents: (row['discount_cents'] as int?) ?? 0,
      poNumber: (row['po_number'] as String?) ?? '',
      currencyCode: (row['currency_code'] as String?) ?? '',
      currencySymbol: (row['currency_symbol'] as String?) ?? '',
      currencyDecimals: (row['currency_decimals'] as int?) ?? 2,
      createdAt: row['created_at'] as String,
    );
  }

  /// Net subtotal after applying discount.
  int get netSubtotalCents => (subtotalCents - discountCents) > 0 ? (subtotalCents - discountCents) : 0;

  bool get isConverted => status.toUpperCase() == 'CONVERTED';
}
