import 'package:sqlite3/sqlite3.dart' hide Row;
import 'package:sqlite3/sqlite3.dart' as sql show Row;

class EstimateItem {
  final String id;
  final String estimateId;
  final String description;
  final int quantity;
  final int unitPriceCents;
  final int taxRatePercentage;
  final int taxCents;
  final int totalCents;
  final String createdAt;

  const EstimateItem({
    required this.id,
    required this.estimateId,
    required this.description,
    required this.quantity,
    required this.unitPriceCents,
    this.taxRatePercentage = 0,
    this.taxCents = 0,
    required this.totalCents,
    required this.createdAt,
  });

  factory EstimateItem.fromRow(sql.Row row) {
    return EstimateItem(
      id: row['id'] as String,
      estimateId: row['estimate_id'] as String,
      description: row['description'] as String,
      quantity: row['quantity'] as int,
      unitPriceCents: row['unit_price_cents'] as int,
      taxRatePercentage: (row['tax_rate_percentage'] as int?) ?? 0,
      taxCents: (row['tax_cents'] as int?) ?? 0,
      totalCents: row['total_cents'] as int,
      createdAt: row['created_at'] as String,
    );
  }
}
