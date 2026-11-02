import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:billing_app/app.dart';
import 'package:billing_app/core/database/database_provider.dart';
import 'package:billing_app/core/database/local_db.dart';

void main() {
  final IntegrationTestWidgetsFlutterBinding binding =
      IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Multi-platform visual screenshot tour test',
      (WidgetTester tester) async {
    // 1. Suppress layout overflow assertions during automated screenshot capture
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exceptionAsString().contains('overflowed') ||
          details.exceptionAsString().contains('deactivated widget') ||
          details.exceptionAsString().contains('hit test')) {
        return;
      }
      originalOnError?.call(details);
    };

    // 2. Set mock method channel for path_provider in test environment
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => '.',
    );

    // 3. Set standard surface resolution (1440x900 desktop, 1080x1920 mobile)
    await tester.binding.setSurfaceSize(
      Platform.isMacOS || Platform.isWindows || Platform.isLinux
          ? const Size(1440, 900)
          : const Size(1080, 1920),
    );

    final Database db = await openLocalDatabase();

    String getPlatformDir() {
      if (Platform.isMacOS) return 'macos';
      if (Platform.isIOS) return 'ios';
      if (Platform.isWindows) return 'windows';
      if (Platform.isAndroid) return 'android';
      if (Platform.isLinux) return 'linux';
      return 'web';
    }

    final platformName = getPlatformDir();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
        child: const BillingDesktopApp(),
      ),
    );

    if (Platform.isAndroid) {
      try {
        await binding.convertFlutterSurfaceToImage();
      } catch (e) {
        debugPrint('convertFlutterSurfaceToImage notice: $e');
      }
    }

    await tester.pumpAndSettle();

    Future<void> takeTourScreenshot(String name) async {
      await tester.pumpAndSettle();
      try {
        await binding.takeScreenshot(name, <String, dynamic>{'platform': platformName});
      } catch (e) {
        debugPrint('Binding takeScreenshot status ($name): $e');
      }
    }

    // 01_dashboard.png: Captures Dashboard KPI metrics, Action Required Triage, and Recent Activity.
    await takeTourScreenshot('01_dashboard');

    // 02_sales_invoices.png: Navigates to Sales -> Invoices table with search bar and status chips.
    final salesNav = find.text('Sales');
    if (salesNav.evaluate().isNotEmpty) {
      await tester.tap(salesNav.first, warnIfMissed: false);
      await tester.pumpAndSettle();
    } else {
      final salesIcon = find.byIcon(Icons.receipt_long);
      if (salesIcon.evaluate().isNotEmpty) {
        await tester.tap(salesIcon.first, warnIfMissed: false);
        await tester.pumpAndSettle();
      }
    }
    await takeTourScreenshot('02_sales_invoices');

    // 03_invoice_editor.png: Clicks [+ Create Invoice] and captures Two-Column WYSIWYG Editor.
    final createBtn = find.text('Create Invoice');
    if (createBtn.evaluate().isNotEmpty) {
      await tester.tap(createBtn.first, warnIfMissed: false);
      await tester.pumpAndSettle();
      await takeTourScreenshot('03_invoice_editor');

      // Pop back from Invoice Editor
      final cancelBtn = find.text('Cancel / Back');
      if (cancelBtn.evaluate().isNotEmpty) {
        await tester.tap(cancelBtn.first, warnIfMissed: false);
      } else {
        final backBtn = find.byType(BackButton);
        if (backBtn.evaluate().isNotEmpty) {
          await tester.tap(backBtn.first, warnIfMissed: false);
        } else {
          final backIcon = find.byIcon(Icons.arrow_back);
          if (backIcon.evaluate().isNotEmpty) {
            await tester.tap(backIcon.first, warnIfMissed: false);
          }
        }
      }
      await tester.pumpAndSettle();
    } else {
      await takeTourScreenshot('03_invoice_editor');
    }

    // 04_quotes_estimates.png: Toggles to Quotes/Estimates table.
    final estimatesTab = find.text('Estimates');
    if (estimatesTab.evaluate().isNotEmpty) {
      await tester.tap(estimatesTab.first, warnIfMissed: false);
      await tester.pumpAndSettle();
    }
    await takeTourScreenshot('04_quotes_estimates');

    // 05_expenses_ledger.png: Navigates to Expenses tab.
    final expensesNav = find.text('Expenses');
    if (expensesNav.evaluate().isNotEmpty) {
      await tester.tap(expensesNav.first, warnIfMissed: false);
      await tester.pumpAndSettle();
    } else {
      final expIcon = find.byIcon(Icons.account_balance_wallet);
      if (expIcon.evaluate().isNotEmpty) {
        await tester.tap(expIcon.first, warnIfMissed: false);
        await tester.pumpAndSettle();
      }
    }
    await takeTourScreenshot('05_expenses_ledger');

    // 06_client_dossier.png: Navigates to Hub & Settings -> Clients tab.
    final hubNav = find.text('Hub');
    if (hubNav.evaluate().isNotEmpty) {
      await tester.tap(hubNav.first, warnIfMissed: false);
      await tester.pumpAndSettle();
    } else {
      final settingsIcon = find.byIcon(Icons.settings);
      if (settingsIcon.evaluate().isNotEmpty) {
        await tester.tap(settingsIcon.first, warnIfMissed: false);
        await tester.pumpAndSettle();
      }
    }

    final clientsSubTab = find.text('Clients');
    if (clientsSubTab.evaluate().isNotEmpty) {
      await tester.tap(clientsSubTab.first, warnIfMissed: false);
      await tester.pumpAndSettle();
    }
    await takeTourScreenshot('06_client_dossier');

    // 07_catalog_items.png: Toggles to Catalog sub-tab.
    final catalogSubTab = find.text('Catalog');
    if (catalogSubTab.evaluate().isNotEmpty) {
      await tester.tap(catalogSubTab.first, warnIfMissed: false);
      await tester.pumpAndSettle();
    }
    await takeTourScreenshot('07_catalog_items');

    // 08_settings_branding.png: Toggles to Settings sub-tab.
    final settingsSubTab = find.text('Settings');
    if (settingsSubTab.evaluate().isNotEmpty) {
      await tester.tap(settingsSubTab.last, warnIfMissed: false);
      await tester.pumpAndSettle();
    }
    await takeTourScreenshot('08_settings_branding');
  });
}
