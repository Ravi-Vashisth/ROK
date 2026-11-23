import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:billing_app/core/database/database_provider.dart';
import 'package:billing_app/core/utils/id_generator.dart';
import 'package:billing_app/features/clients/models/client.dart';

class ClientsNotifier extends StateNotifier<List<Client>> {
  final Database _db;

  ClientsNotifier(this._db) : super([]) {
    loadClients();
  }

  void loadClients() {
    final ResultSet results = _db.select(
      'SELECT * FROM clients WHERE deleted_at IS NULL ORDER BY name COLLATE NOCASE ASC',
    );
    state = results.map((row) => Client.fromRow(row)).toList();
  }

  void addClient({
    required String name,
    String email = '',
    String phone = '',
    String address = '',
    String taxId = '',
  }) {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return;

    final id = generateUniqueId();
    final nowIso = DateTime.now().toUtc().toIso8601String();

    final stmt = _db.prepare('''
      INSERT INTO clients (id, name, email, phone, address, tax_id, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ''');
    try {
      stmt.execute([
        id,
        trimmedName,
        email.trim(),
        phone.trim(),
        address.trim(),
        taxId.trim(),
        nowIso,
        nowIso,
      ]);
    } finally {
      stmt.dispose();
    }

    loadClients();
  }

  void updateClient({
    required String id,
    required String name,
    String email = '',
    String phone = '',
    String address = '',
    String taxId = '',
  }) {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return;

    final updatedAt = DateTime.now().toUtc().toIso8601String();
    final stmt = _db.prepare('''
      UPDATE clients 
      SET name = ?, email = ?, phone = ?, address = ?, tax_id = ?, updated_at = ?
      WHERE id = ? AND deleted_at IS NULL
    ''');
    try {
      stmt.execute([
        trimmedName,
        email.trim(),
        phone.trim(),
        address.trim(),
        taxId.trim(),
        updatedAt,
        id,
      ]);
    } finally {
      stmt.dispose();
    }
    loadClients();
  }

  bool deleteClient(String id) {
    final check = _db.select(
      'SELECT (SELECT COUNT(*) FROM invoices WHERE client_id = ? AND deleted_at IS NULL) + (SELECT COUNT(*) FROM estimates WHERE client_id = ? AND deleted_at IS NULL) AS total_records',
      [id, id],
    );
    final count = (check.first['total_records'] as int?) ?? 0;
    if (count > 0) {
      return false;
    }

    final deletedAt = DateTime.now().toUtc().toIso8601String();
    final stmt = _db.prepare(
      'UPDATE clients SET deleted_at = ?, updated_at = ? WHERE id = ? AND deleted_at IS NULL',
    );
    try {
      stmt.execute([deletedAt, deletedAt, id]);
    } finally {
      stmt.dispose();
    }
    loadClients();
    return true;
  }
}

final clientsProvider = StateNotifierProvider<ClientsNotifier, List<Client>>((ref) {
  return ClientsNotifier(ref.watch(databaseProvider));
});
