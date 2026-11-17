import 'package:flutter/material.dart';
import 'package:sqlite3/sqlite3.dart';

import 'app.dart';
import 'core/database/local_db.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Database? db;
  Object? dbError;

  try {
    db = await openLocalDatabase();
  } catch (e) {
    dbError = e;
  }

  runApp(
    DatabaseBootstrapApp(
      initialDb: db,
      initialError: dbError,
    ),
  );
}