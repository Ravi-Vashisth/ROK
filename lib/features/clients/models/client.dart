import 'package:sqlite3/sqlite3.dart' hide Row;
import 'package:sqlite3/sqlite3.dart' as sql show Row;

class Client {
  final String id;
  final String name;
  final String createdAt;

  const Client({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  factory Client.fromRow(sql.Row row) {
    return Client(
      id: row['id'] as String,
      name: row['name'] as String,
      createdAt: row['created_at'] as String,
    );
  }
}
