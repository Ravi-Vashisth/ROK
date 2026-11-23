import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' hide Row;

import 'package:billing_app/app.dart';
import 'package:billing_app/core/database/database_provider.dart';
import 'package:billing_app/core/database/local_db.dart';
import 'package:billing_app/core/theme/app_theme.dart';
import 'package:billing_app/features/clients/models/client.dart';
import 'package:billing_app/features/clients/presentation/client_statement_dialog.dart';
import 'package:billing_app/features/invoices/presentation/invoice_editor_screen.dart';

Database _createSeededInMemoryDb({String themeMode = 'light'}) {
  final db = sqlite3.openInMemory();
  initializeLocalSchema(db);

  const nowIso = '2026-04-10T10:00:00Z';
  db.execute(
    "UPDATE business_profile SET theme_mode = ?, updated_at = ? WHERE id = 'default';",
    [themeMode, nowIso],
  );

  db.execute(
    '''
    INSERT INTO clients (id, name, email, phone, address, tax_id, created_at, updated_at)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ''',
    [
      'client-seed-1',
      'Acme Global Corp',
      'billing@acme.test',
      '+1 555 010 9988',
      '42 Market Street, San Francisco, CA',
      'US-EIN-123456',
      nowIso,
      nowIso,
    ],
  );

  db.execute(
    '''
    INSERT INTO invoices (
      id, client_id, invoice_number, subtotal_cents, tax_cents, total_cents,
      status, issue_date, due_date, payment_terms, currency_code, currency_symbol,
      currency_decimals, created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''',
    [
      'inv-seed-1',
      'client-seed-1',
      'INV-0001',
      10000,
      1000,
      11000,
      'PENDING',
      '2026-04-01',
      '2026-04-15',
      'Net 15 Days',
      'USD',
      '\$',
      2,
      nowIso,
      nowIso,
    ],
  );

  db.execute(
    '''
    INSERT INTO invoice_items (
      id, invoice_id, description, sac_hsn, quantity, unit_price_cents,
      tax_rate_percentage, tax_cents, total_cents, created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''',
    [
      'item-seed-1',
      'inv-seed-1',
      'Platform Architecture Advisory',
      '998314',
      1,
      10000,
      10,
      1000,
      10000,
      nowIso,
      nowIso,
    ],
  );

  db.execute(
    '''
    INSERT INTO estimates (
      id, client_id, estimate_number, subtotal_cents, tax_cents, total_cents,
      status, issue_date, expiry_date, currency_code, currency_symbol,
      currency_decimals, created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''',
    [
      'est-seed-1',
      'client-seed-1',
      'EST-0001',
      25000,
      2500,
      27500,
      'PENDING',
      '2026-04-05',
      '2026-05-05',
      'USD',
      '\$',
      2,
      nowIso,
      nowIso,
    ],
  );

  db.execute(
    '''
    INSERT INTO expenses (
      id, category, vendor, amount_cents, tax_cents, expense_date, notes,
      currency_code, currency_decimals, created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''',
    [
      'exp-seed-1',
      'Software',
      'Cloud Hosting Co',
      4500,
      0,
      '2026-04-03',
      'Monthly production server',
      'USD',
      2,
      nowIso,
      nowIso,
    ],
  );

  db.execute(
    '''
    INSERT INTO saved_items (
      id, title, sac_hsn, default_price_cents, description,
      currency_code, currency_decimals, created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''',
    [
      'saved-seed-1',
      'Advisory Retainer',
      '998314',
      15000,
      'Monthly technical consultation',
      'USD',
      2,
      nowIso,
      nowIso,
    ],
  );

  return db;
}

void main() {
  testWidgets(
    'DatabaseBootstrapApp renders explicit disk-error retry UI without silent in-memory fallback',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        DatabaseBootstrapApp(
          initialError: StateError('Simulated SQLite open failure'),
        ),
      );

      expect(find.text('Local Storage Unavailable'), findsOneWidget);
      expect(find.text('Retry Database Connection'), findsOneWidget);
      expect(find.textContaining('Simulated SQLite open failure'), findsOneWidget);
      expect(find.byIcon(Icons.storage_rounded), findsOneWidget);
    },
  );

  group('Responsive & 2.0x TextScaler Zero-Overflow Matrix', () {
    const viewports = <String, Size>{
      'compact_320x568': Size(320, 568),
      'desktop_1280x800': Size(1280, 800),
    };
    const themes = <String, String>{
      'light': 'light',
      'dark': 'dark',
    };

    for (final viewportEntry in viewports.entries) {
      for (final themeEntry in themes.entries) {
        testWidgets(
          'BillingDesktopApp (${viewportEntry.key}, ${themeEntry.key}, 2.0x textScale) renders Dashboard, Sales, Expenses, Settings with zero layout errors',
          (WidgetTester tester) async {
            final db = _createSeededInMemoryDb(themeMode: themeEntry.value);
            addTearDown(db.dispose);

            tester.view.physicalSize = viewportEntry.value;
            tester.view.devicePixelRatio = 1.0;
            tester.platformDispatcher.textScaleFactorTestValue = 2.0;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

            final capturedErrors = <FlutterErrorDetails>[];
            final previousOnError = FlutterError.onError;
            FlutterError.onError = (details) {
              capturedErrors.add(details);
            };
            addTearDown(() => FlutterError.onError = previousOnError);

            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  databaseProvider.overrideWithValue(db),
                ],
                child: const BillingDesktopApp(),
              ),
            );
            await tester.pumpAndSettle();

            expect(tester.takeException(), isNull);
            expect(
              capturedErrors,
              isEmpty,
              reason: 'Dashboard overflow/error on ${viewportEntry.key} (${themeEntry.key}): '
                  '${capturedErrors.map((e) => e.exceptionAsString()).join('; ')}',
            );

            final navType = viewportEntry.value.width >= 900 ? NavigationRail : NavigationBar;
            for (final tabLabel in const ['Sales', 'Expenses', 'Settings', 'Dashboard']) {
              final navTabFinder = find.descendant(
                of: find.byType(navType),
                matching: find.text(tabLabel),
              );
              expect(navTabFinder, findsOneWidget);
              await tester.tap(navTabFinder);
              await tester.pumpAndSettle();

              expect(tester.takeException(), isNull);
              expect(
                capturedErrors,
                isEmpty,
                reason: '$tabLabel overflow/error on ${viewportEntry.key} (${themeEntry.key}): '
                    '${capturedErrors.map((e) => e.exceptionAsString()).join('; ')}',
              );
            }
          },
        );

        testWidgets(
          'ClientStatementDialog (${viewportEntry.key}, ${themeEntry.key}, 2.0x textScale) renders with zero overflow errors',
          (WidgetTester tester) async {
            final db = _createSeededInMemoryDb(themeMode: themeEntry.value);
            addTearDown(db.dispose);

            tester.view.physicalSize = viewportEntry.value;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);

            final capturedErrors = <FlutterErrorDetails>[];
            final previousOnError = FlutterError.onError;
            FlutterError.onError = (details) {
              capturedErrors.add(details);
            };
            addTearDown(() => FlutterError.onError = previousOnError);

            const seededClient = Client(
              id: 'client-seed-1',
              name: 'Acme Global Corp',
              email: 'billing@acme.test',
              phone: '+1 555 010 9988',
              address: '42 Market Street, San Francisco, CA',
              taxId: 'US-EIN-123456',
              createdAt: '2026-04-10T10:00:00Z',
            );

            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  databaseProvider.overrideWithValue(db),
                ],
                child: MaterialApp(
                  theme: AppTheme.lightTheme(),
                  darkTheme: AppTheme.darkTheme(),
                  themeMode: themeEntry.value == 'dark' ? ThemeMode.dark : ThemeMode.light,
                  home: MediaQuery(
                    data: MediaQueryData(
                      size: viewportEntry.value,
                      textScaler: const TextScaler.linear(2.0),
                    ),
                    child: const Scaffold(
                      body: Center(
                        child: ClientStatementDialog(client: seededClient),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();

            expect(find.textContaining('Acme Global Corp'), findsWidgets);
            expect(tester.takeException(), isNull);
            expect(
              capturedErrors,
              isEmpty,
              reason: 'ClientStatementDialog error on ${viewportEntry.key} (${themeEntry.key}): '
                  '${capturedErrors.map((e) => e.exceptionAsString()).join('; ')}',
            );
          },
        );
      }
    }
  });

  testWidgets(
    'InvoiceEditorScreen deleting middle line item preserves exact remaining row descriptions and prices',
    (WidgetTester tester) async {
      final db = _createSeededInMemoryDb();
      addTearDown(db.dispose);

      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
          ],
          child: const MaterialApp(
            home: InvoiceEditorScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final addItemBtn = find.text('Add Line Item');
      await tester.ensureVisible(addItemBtn);
      await tester.tap(addItemBtn);
      await tester.pumpAndSettle();
      await tester.ensureVisible(addItemBtn);
      await tester.tap(addItemBtn);
      await tester.pumpAndSettle();

      final descFields = find.widgetWithText(TextFormField, 'Description *');
      final priceFields = find.widgetWithText(TextFormField, 'Price (\$)');
      expect(descFields, findsNWidgets(3));
      expect(priceFields, findsNWidgets(3));

      await tester.ensureVisible(descFields.at(0));
      await tester.enterText(descFields.at(0), 'Alpha Design');
      await tester.enterText(priceFields.at(0), '111.00');

      await tester.ensureVisible(descFields.at(1));
      await tester.enterText(descFields.at(1), 'Beta Middle Row');
      await tester.enterText(priceFields.at(1), '222.00');

      await tester.ensureVisible(descFields.at(2));
      await tester.enterText(descFields.at(2), 'Gamma Delivery');
      await tester.enterText(priceFields.at(2), '333.00');
      await tester.pumpAndSettle();

      // Delete the middle row (index 1)
      final deleteButtons = find.byIcon(Icons.delete_outline);
      expect(deleteButtons, findsNWidgets(3));
      await tester.ensureVisible(deleteButtons.at(1));
      await tester.tap(deleteButtons.at(1));
      await tester.pumpAndSettle();

      final remainingDescFields = find.widgetWithText(TextFormField, 'Description *');
      final remainingPriceFields = find.widgetWithText(TextFormField, 'Price (\$)');
      expect(remainingDescFields, findsNWidgets(2));
      expect(remainingPriceFields, findsNWidgets(2));

      expect(find.text('Beta Middle Row'), findsNothing);
      expect(find.text('222.00'), findsNothing);

      expect(
        tester.widget<TextFormField>(remainingDescFields.at(0)).initialValue,
        'Alpha Design',
      );
      expect(find.text('Alpha Design'), findsWidgets);
      expect(find.text('111.00'), findsOneWidget);
      expect(find.text('Gamma Delivery'), findsWidgets);
      expect(find.text('333.00'), findsOneWidget);
    },
  );
}
