import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqlite3/sqlite3.dart';

/// Provider for the singleton SQLite database instance.
/// Overridden at app startup in ProviderScope.
final databaseProvider = Provider<Database>((ref) {
  throw UnimplementedError('Database must be provided at startup');
});
