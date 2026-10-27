import 'package:sqlite3/sqlite3.dart' hide Row;
import 'package:sqlite3/sqlite3.dart' as sql show Row;

class Client {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String address;
  final String taxId;
  final String createdAt;

  const Client({
    required this.id,
    required this.name,
    this.email = '',
    this.phone = '',
    this.address = '',
    this.taxId = '',
    required this.createdAt,
  });

  factory Client.fromRow(sql.Row row) {
    return Client(
      id: row['id'] as String,
      name: row['name'] as String,
      email: (row['email'] as String?) ?? '',
      phone: (row['phone'] as String?) ?? '',
      address: (row['address'] as String?) ?? '',
      taxId: (row['tax_id'] as String?) ?? '',
      createdAt: row['created_at'] as String,
    );
  }

  Client copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? address,
    String? taxId,
    String? createdAt,
  }) {
    return Client(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      taxId: taxId ?? this.taxId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
