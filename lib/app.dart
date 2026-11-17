import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqlite3/sqlite3.dart' hide Row;

import 'core/database/database_provider.dart';
import 'core/database/local_db.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/billing/presentation/billing_dashboard_screen.dart';

class DatabaseBootstrapApp extends StatefulWidget {
  final Database? initialDb;
  final Object? initialError;

  const DatabaseBootstrapApp({
    super.key,
    this.initialDb,
    this.initialError,
  });

  @override
  State<DatabaseBootstrapApp> createState() => _DatabaseBootstrapAppState();
}

class _DatabaseBootstrapAppState extends State<DatabaseBootstrapApp> {
  Database? _db;
  Object? _error;
  bool _retrying = false;

  @override
  void initState() {
    super.initState();
    _db = widget.initialDb;
    _error = widget.initialError;
  }

  Future<void> _retryOpen() async {
    setState(() {
      _retrying = true;
    });
    try {
      final opened = await openLocalDatabase();
      if (!mounted) return;
      setState(() {
        _db = opened;
        _error = null;
        _retrying = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _retrying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = _db;
    if (db != null) {
      return ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
        child: const BillingDesktopApp(),
      );
    }

    return MaterialApp(
      title: 'Freelance Ledger',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              margin: const EdgeInsets.all(24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.storage_rounded, color: Colors.red, size: 28),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Local Storage Unavailable',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Freelance Ledger could not open its local persistent SQLite database. To protect your financial records from silent data loss, temporary in-memory fallback has been disabled.',
                      style: TextStyle(fontSize: 13),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$_error',
                          style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _retrying ? null : _retryOpen,
                        icon: _retrying
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh),
                        label: Text(_retrying ? 'Retrying...' : 'Retry Database Connection'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BillingDesktopApp extends ConsumerWidget {
  const BillingDesktopApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final accentColor = ref.watch(accentColorProvider);

    return MaterialApp(
      title: 'Freelance Ledger',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(seed: accentColor),
      darkTheme: AppTheme.darkTheme(seed: accentColor),
      themeMode: themeMode,
      home: const BillingDashboardScreen(),
    );
  }
}
