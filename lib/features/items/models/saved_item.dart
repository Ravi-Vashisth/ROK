import 'package:sqlite3/sqlite3.dart' hide Row;
import 'package:sqlite3/sqlite3.dart' as sql show Row;

class SavedItem {
  final String id;
  final String title;
  final String sacHsn;
  final int defaultPriceCents;
  final String description;
  final String createdAt;

  const SavedItem({
    required this.id,
    required this.title,
    this.sacHsn = '',
    required this.defaultPriceCents,
    this.description = '',
    required this.createdAt,
  });

  factory SavedItem.fromRow(sql.Row row) {
    return SavedItem(
      id: row['id'] as String,
      title: row['title'] as String,
      sacHsn: (row['sac_hsn'] as String?) ?? '',
      defaultPriceCents: row['default_price_cents'] as int,
      description: row['description'] as String? ?? '',
      createdAt: row['created_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'sac_hsn': sacHsn,
      'default_price_cents': defaultPriceCents,
      'description': description,
      'created_at': createdAt,
    };
  }
}
