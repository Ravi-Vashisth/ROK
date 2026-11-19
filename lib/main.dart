import 'package:flutter/material.dart';
import 'package:sqlite3/sqlite3.dart' hide Row;

import 'package:billing_app/app.dart';
import 'package:billing_app/core/database/local_db.dart';

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