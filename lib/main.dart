import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqlite3/sqlite3.dart';

import 'app.dart';
import 'core/database/database_provider.dart';
import 'core/database/local_db.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final Database db = await openLocalDatabase();

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
      ],
      child: const BillingDesktopApp(),
    ),
  );
}