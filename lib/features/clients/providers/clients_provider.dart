import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/utils/id_generator.dart';
import '../models/client.dart';

class ClientsNotifier extends StateNotifier<List<Client>> {
  final Database _db;

  ClientsNotifier(this._db) : super([]) {
    loadClients();
  }

  void loadClients() {
    final ResultSet results = _db.select('SELECT * FROM clients ORDER BY name COLLATE NOCASE ASC');
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
    final createdAt = DateTime.now().toUtc().toIso8601String();

    final stmt = _db.prepare('''
      INSERT INTO clients (id, name, email, phone, address, tax_id, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    ''');
    try {
      stmt.execute([
        id,
        trimmedName,
        email.trim(),
        phone.trim(),
        address.trim(),
        taxId.trim(),
        createdAt,
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

    final stmt = _db.prepare('''
      UPDATE clients 
      SET name = ?, email = ?, phone = ?, address = ?, tax_id = ?
      WHERE id = ?
    ''');
    try {
      stmt.execute([
        trimmedName,
        email.trim(),
        phone.trim(),
        address.trim(),
        taxId.trim(),
        id,
      ]);
    } finally {
      stmt.dispose();
    }
    loadClients();
  }

  bool deleteClient(String id) {
    final check = _db.select(
      'SELECT (SELECT COUNT(*) FROM invoices WHERE client_id = ?) + (SELECT COUNT(*) FROM estimates WHERE client_id = ?) AS total_records',
      [id, id],
    );
    final count = (check.first['total_records'] as int?) ?? 0;
    if (count > 0) {
      return false;
    }

    final stmt = _db.prepare('DELETE FROM clients WHERE id = ?');
    try {
      stmt.execute([id]);
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
