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
    stmt.execute([
      id,
      trimmedName,
      email.trim(),
      phone.trim(),
      address.trim(),
      taxId.trim(),
      createdAt,
    ]);
    stmt.dispose();

    loadClients();
  }
}

final clientsProvider = StateNotifierProvider<ClientsNotifier, List<Client>>((ref) {
  return ClientsNotifier(ref.watch(databaseProvider));
});
