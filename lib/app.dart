import 'dart:ui' show AppExitResponse;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqlite3/sqlite3.dart' hide Row;

import 'package:billing_app/core/database/database_provider.dart';
import 'package:billing_app/core/database/local_db.dart';
import 'package:billing_app/core/theme/app_theme.dart';
import 'package:billing_app/core/theme/theme_provider.dart';
import 'package:billing_app/features/billing/presentation/billing_dashboard_screen.dart';

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
  bool _dbDisposed = false;
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _db = widget.initialDb;
    _error = widget.initialError;
    _lifecycleListener = AppLifecycleListener(
      onDetach: _checkpointAndDisposeDb,
      onExitRequested: () async {
        _checkpointAndDisposeDb();
        return AppExitResponse.exit;
      },
    );
  }

  void _checkpointAndDisposeDb() {
    if (_dbDisposed) return;
    final db = _db;
    if (db == null) return;
    _dbDisposed = true;
    try {
      db.execute('PRAGMA wal_checkpoint(TRUNCATE);');
    } catch (_) {
      // Best-effort WAL checkpoint on teardown; proceed to dispose handle.
    }
    try {
      db.dispose();
    } catch (_) {
      // Handle may already be closed during teardown.
    }
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    _checkpointAndDisposeDb();
    super.dispose();
  }

  Future<void> _retryOpen() async {
    setState(() {
      _retrying = true;
    });
    try {
      final opened = await openLocalDatabase();
      if (!mounted) {
        try {
          opened.dispose();
        } catch (_) {}
        return;
      }
      setState(() {
        _db = opened;
        _dbDisposed = false;
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
                    Row(
                      children: [
                        Icon(Icons.storage_rounded, color: Theme.of(context).colorScheme.error, size: 28),
                        const SizedBox(width: 12),
                        const Expanded(
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
                          color: AppSemanticColors.resolve(Theme.of(context).brightness, SemanticStatus.danger).background,
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
