import { useState, useEffect } from 'react';
import { 
  Building2, 
  FileText, 
  Plus, 
  Save, 
  Database, 
  Copy, 
  Check, 
  Download, 
  Monitor, 
  RefreshCw, 
  HardDrive, 
  FolderTree, 
  FileCode, 
  Trash2, 
  ChevronDown, 
  ChevronUp, 
  Printer, 
  X,
  CreditCard
} from 'lucide-react';
import {
  parsePriceToCents,
  calculateCartTotals,
  formatNextInvoiceNumber,
  formatCents,
} from './billingRules';

interface Client {
  id: string;
  name: string;
  created_at: string;
}

interface StoredInvoiceItem {
  id: string;
  invoice_id: string;
  description: string;
  quantity: number;
  unit_price_cents: number;
  total_cents: number;
  created_at: string;
}

interface InvoiceRecord {
  id: string;
  client_id: string;
  client_name: string;
  invoice_number: string;
  subtotal_cents: number;
  tax_cents: number;
  total_cents: number;
  status: string;
  created_at: string;
}

interface DraftLineItem {
  description: string;
  unitPriceCents: number;
  quantity: number;
  totalCents: number;
}

interface BusinessProfile {
  id: string;
  business_name: string;
  email: string;
  phone: string;
  address: string;
  tax_id: string;
  payment_details: string;
}

const DEFAULT_BUSINESS_PROFILE: BusinessProfile = {
  id: 'default',
  business_name: 'My Freelance Studio',
  email: 'billing@studio.com',
  phone: '+1 (555) 019-2834',
  address: '100 Tech Plaza, Suite 400, San Francisco, CA 94107',
  tax_id: 'US-EIN-987654321',
  payment_details: 'Bank: Silicon Valley Bank\nAccount: 987654321098\nRouting / SWIFT: SVB12345\nPayPal / UPI: pay@studio.com',
};

const MODULAR_FILES: Record<string, string> = {
  "lib/main.dart": "import 'package:flutter/material.dart';\nimport 'package:flutter_riverpod/flutter_riverpod.dart';\nimport 'package:sqlite3/sqlite3.dart';\n\nimport 'app.dart';\nimport 'core/database/database_provider.dart';\nimport 'core/database/local_db.dart';\n\nvoid main() async {\n  WidgetsFlutterBinding.ensureInitialized();\n  final Database db = await openLocalDatabase();\n\n  runApp(\n    ProviderScope(\n      overrides: [\n        databaseProvider.overrideWithValue(db),\n      ],\n      child: const BillingDesktopApp(),\n    ),\n  );\n}",
  "lib/app.dart": "import 'package:flutter/material.dart';\nimport 'package:flutter_riverpod/flutter_riverpod.dart';\n\nimport 'core/theme/app_theme.dart';\nimport 'core/theme/theme_provider.dart';\nimport 'features/billing/presentation/billing_dashboard_screen.dart';\n\nclass BillingDesktopApp extends ConsumerWidget {\n  const BillingDesktopApp({super.key});\n\n  @override\n  Widget build(BuildContext context, WidgetRef ref) {\n    final themeMode = ref.watch(themeModeProvider);\n    final accentColor = ref.watch(accentColorProvider);\n\n    return MaterialApp(\n      title: 'Local Billing',\n      debugShowCheckedModeBanner: false,\n      theme: AppTheme.lightTheme(seed: accentColor),\n      darkTheme: AppTheme.darkTheme(seed: accentColor),\n      themeMode: themeMode,\n      home: const BillingDashboardScreen(),\n    );\n  }\n}\n",
  "lib/core/theme/app_theme.dart": "import 'dart:ui';\nimport 'package:flutter/material.dart';\n\nclass AppTheme {\n  static const seedColor = Color(0xFF4F46E5); // Modern Indigo\n\n  // Preset Accent Palette for customization\n  static const List<Color> presetAccents = [\n    Color(0xFF4F46E5), // Indigo\n    Color(0xFF059669), // Emerald\n    Color(0xFF2563EB), // Royal Blue\n    Color(0xFFE11D48), // Rose\n    Color(0xFFD97706), // Amber\n    Color(0xFF475569), // Slate\n  ];\n\n  static TextTheme _withTabularFigures(TextTheme base) {\n    const tabular = [FontFeature.tabularFigures()];\n    return base.copyWith(\n      displayLarge: base.displayLarge?.copyWith(fontFeatures: tabular),\n      displayMedium: base.displayMedium?.copyWith(fontFeatures: tabular),\n      displaySmall: base.displaySmall?.copyWith(fontFeatures: tabular),\n      headlineLarge: base.headlineLarge?.copyWith(fontFeatures: tabular),\n      headlineMedium: base.headlineMedium?.copyWith(fontFeatures: tabular),\n      headlineSmall: base.headlineSmall?.copyWith(fontFeatures: tabular),\n      titleLarge: base.titleLarge?.copyWith(fontFeatures: tabular),\n      titleMedium: base.titleMedium?.copyWith(fontFeatures: tabular),\n      titleSmall: base.titleSmall?.copyWith(fontFeatures: tabular),\n      bodyLarge: base.bodyLarge?.copyWith(fontFeatures: tabular),\n      bodyMedium: base.bodyMedium?.copyWith(fontFeatures: tabular),\n      bodySmall: base.bodySmall?.copyWith(fontFeatures: tabular),\n      labelLarge: base.labelLarge?.copyWith(fontFeatures: tabular),\n      labelMedium: base.labelMedium?.copyWith(fontFeatures: tabular),\n      labelSmall: base.labelSmall?.copyWith(fontFeatures: tabular),\n    );\n  }\n\n  static ThemeData lightTheme({Color seed = seedColor}) {\n    final colorScheme = ColorScheme.fromSeed(\n      seedColor: seed,\n      brightness: Brightness.light,\n    );\n\n    return ThemeData(\n      useMaterial3: true,\n      colorScheme: colorScheme,\n      textTheme: _withTabularFigures(ThemeData.light().textTheme),\n      scaffoldBackgroundColor: const Color(0xFFF8FAFC), // Slate 50\n      cardTheme: CardTheme(\n        elevation: 0,\n        shape: RoundedRectangleBorder(\n          borderRadius: BorderRadius.circular(12),\n          side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),\n        ),\n      ),\n      inputDecorationTheme: InputDecorationTheme(\n        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),\n        border: OutlineInputBorder(\n          borderRadius: BorderRadius.circular(12),\n          borderSide: BorderSide(color: colorScheme.outline),\n        ),\n        enabledBorder: OutlineInputBorder(\n          borderRadius: BorderRadius.circular(12),\n          borderSide: BorderSide(color: colorScheme.outlineVariant),\n        ),\n        focusedBorder: OutlineInputBorder(\n          borderRadius: BorderRadius.circular(12),\n          borderSide: BorderSide(color: colorScheme.primary, width: 2),\n        ),\n      ),\n      filledButtonTheme: FilledButtonThemeData(\n        style: FilledButton.styleFrom(\n          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),\n          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),\n        ),\n      ),\n      outlinedButtonTheme: OutlinedButtonThemeData(\n        style: OutlinedButton.styleFrom(\n          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),\n          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),\n        ),\n      ),\n      dialogTheme: const DialogTheme(\n        shape: RoundedRectangleBorder(\n          borderRadius: BorderRadius.all(Radius.circular(14)),\n        ),\n      ),\n    );\n  }\n\n  static ThemeData darkTheme({Color seed = seedColor}) {\n    final colorScheme = ColorScheme.fromSeed(\n      seedColor: seed,\n      brightness: Brightness.dark,\n      surface: const Color(0xFF0F172A), // Slate 900\n    );\n\n    return ThemeData(\n      useMaterial3: true,\n      colorScheme: colorScheme,\n      textTheme: _withTabularFigures(ThemeData.dark().textTheme),\n      scaffoldBackgroundColor: const Color(0xFF0B0F19), // Deep Slate\n      cardTheme: CardTheme(\n        elevation: 0,\n        color: const Color(0xFF0F172A),\n        shape: RoundedRectangleBorder(\n          borderRadius: BorderRadius.circular(12),\n          side: BorderSide(color: const Color(0xFF1E293B)),\n        ),\n      ),\n      inputDecorationTheme: InputDecorationTheme(\n        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),\n        fillColor: const Color(0xFF0A0F1D),\n        filled: true,\n        border: OutlineInputBorder(\n          borderRadius: BorderRadius.circular(12),\n          borderSide: const BorderSide(color: Color(0xFF334155)),\n        ),\n        enabledBorder: OutlineInputBorder(\n          borderRadius: BorderRadius.circular(12),\n          borderSide: const BorderSide(color: Color(0xFF1E293B)),\n        ),\n        focusedBorder: OutlineInputBorder(\n          borderRadius: BorderRadius.circular(12),\n          borderSide: BorderSide(color: colorScheme.primary, width: 2),\n        ),\n      ),\n      filledButtonTheme: FilledButtonThemeData(\n        style: FilledButton.styleFrom(\n          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),\n          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),\n        ),\n      ),\n      outlinedButtonTheme: OutlinedButtonThemeData(\n        style: OutlinedButton.styleFrom(\n          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),\n          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),\n        ),\n      ),\n      dialogTheme: const DialogTheme(\n        backgroundColor: Color(0xFF0F172A),\n        shape: RoundedRectangleBorder(\n          borderRadius: BorderRadius.all(Radius.circular(14)),\n        ),\n      ),\n    );\n  }\n}\n",
  "lib/core/theme/theme_provider.dart": "import 'package:flutter/material.dart';\nimport 'package:flutter_riverpod/flutter_riverpod.dart';\n\nimport 'app_theme.dart';\n\nclass ThemeModeNotifier extends StateNotifier<ThemeMode> {\n  ThemeModeNotifier() : super(ThemeMode.system);\n\n  void setThemeMode(ThemeMode mode) {\n    state = mode;\n  }\n\n  /// Cycles through System -> Light -> Dark -> System\n  void cycleThemeMode() {\n    switch (state) {\n      case ThemeMode.system:\n        state = ThemeMode.light;\n        break;\n      case ThemeMode.light:\n        state = ThemeMode.dark;\n        break;\n      case ThemeMode.dark:\n        state = ThemeMode.system;\n        break;\n    }\n  }\n}\n\nfinal themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {\n  return ThemeModeNotifier();\n});\n\nclass AccentColorNotifier extends StateNotifier<Color> {\n  AccentColorNotifier() : super(AppTheme.seedColor);\n\n  void setAccentColor(Color color) {\n    state = color;\n  }\n}\n\nfinal accentColorProvider = StateNotifierProvider<AccentColorNotifier, Color>((ref) {\n  return AccentColorNotifier();\n});\n",
  "lib/core/utils/money_utils.dart": "import 'package:intl/intl.dart';\n\n/// Formats integer cents strictly at the UI display layer using NumberFormat.currency.\nfinal NumberFormat _currencyFormatter = NumberFormat.currency(symbol: '\\$');\n\n/// Parses price input string (e.g. \"15.50\" or \"$15.50\") directly into integer cents without float imprecision.\nint parsePriceToCents(String input) {\n  final cleaned = input.trim().replaceAll(RegExp(r'[^\\d.]'), '');\n  if (cleaned.isEmpty) return 0;\n  final parts = cleaned.split('.');\n  final dollars = int.tryParse(parts[0]) ?? 0;\n  int cents = 0;\n  if (parts.length > 1) {\n    final centsPart = parts[1].padRight(2, '0').substring(0, 2);\n    cents = int.tryParse(centsPart) ?? 0;\n  }\n  return (dollars * 100) + cents;\n}\n\n/// Formats integer cents as currency (e.g. 1550 -> \"$15.50\").\nString formatCents(int cents) {\n  return _currencyFormatter.format(cents / 100.0);\n}\n\n/// Calculates tax in integer cents using integer round-half-up math:\n/// (subtotal_cents * tax_percentage + 50) ~/ 100.\nint calculateTaxCents(int subtotalCents, int taxPercentage) {\n  final safePercentage = taxPercentage < 0 ? 0 : taxPercentage;\n  return (subtotalCents * safePercentage + 50) ~/ 100;\n}\n",
  "lib/core/utils/id_generator.dart": "import 'dart:math';\n\n/// Generates a local unique ID using timestamp and high-entropy randomness.\nString generateUniqueId() {\n  final timestamp = DateTime.now().microsecondsSinceEpoch;\n  final random = Random().nextInt(999999).toString().padLeft(6, '0');\n  return '$timestamp-$random';\n}\n",
  "lib/core/database/local_db.dart": "import 'package:path/path.dart' as p;\nimport 'package:path_provider/path_provider.dart';\nimport 'package:sqlite3/sqlite3.dart';\n\n/// Opens and configures the local SQLite database file in the application documents directory.\nFuture<Database> openLocalDatabase() async {\n  final docsDir = await getApplicationDocumentsDirectory();\n  final dbPath = p.join(docsDir.path, 'billing_local.db');\n  final db = sqlite3.open(dbPath);\n\n  // Enable WAL mode and foreign keys for durability and cascading deletions\n  db.execute('PRAGMA foreign_keys = ON;');\n  db.execute('PRAGMA journal_mode = WAL;');\n\n  // 1. Clients Table\n  db.execute('''\n    CREATE TABLE IF NOT EXISTS clients (\n      id TEXT PRIMARY KEY,\n      name TEXT NOT NULL,\n      created_at TEXT NOT NULL\n    );\n  ''');\n\n  // 2. Invoices Table\n  db.execute('''\n    CREATE TABLE IF NOT EXISTS invoices (\n      id TEXT PRIMARY KEY,\n      client_id TEXT NOT NULL,\n      invoice_number TEXT NOT NULL UNIQUE,\n      subtotal_cents INTEGER NOT NULL,\n      tax_cents INTEGER NOT NULL,\n      total_cents INTEGER NOT NULL,\n      status TEXT NOT NULL,\n      created_at TEXT NOT NULL,\n      FOREIGN KEY (client_id) REFERENCES clients (id) ON DELETE RESTRICT\n    );\n  ''');\n\n  // 3. Invoice Items Table (Multi-Line Items / Cart)\n  db.execute('''\n    CREATE TABLE IF NOT EXISTS invoice_items (\n      id TEXT PRIMARY KEY,\n      invoice_id TEXT NOT NULL,\n      description TEXT NOT NULL,\n      quantity INTEGER NOT NULL DEFAULT 1,\n      unit_price_cents INTEGER NOT NULL,\n      total_cents INTEGER NOT NULL,\n      created_at TEXT NOT NULL,\n      FOREIGN KEY (invoice_id) REFERENCES invoices (id) ON DELETE CASCADE\n    );\n  ''');\n\n  // 4. Business Profile & Payment Details Table\n  db.execute('''\n    CREATE TABLE IF NOT EXISTS business_profile (\n      id TEXT PRIMARY KEY DEFAULT 'default',\n      business_name TEXT NOT NULL DEFAULT 'My Studio',\n      email TEXT DEFAULT '',\n      phone TEXT DEFAULT '',\n      address TEXT DEFAULT '',\n      tax_id TEXT DEFAULT '',\n      payment_details TEXT DEFAULT ''\n    );\n  ''');\n\n  // Seed default business profile record if not already present\n  db.execute('''\n    INSERT OR IGNORE INTO business_profile (\n      id, business_name, email, phone, address, tax_id, payment_details\n    ) VALUES (\n      'default',\n      'My Freelance Studio',\n      'billing@studio.com',\n      '+1 (555) 019-2834',\n      '100 Tech Plaza, Suite 400, San Francisco, CA 94107',\n      'US-EIN-987654321',\n      'Bank: Silicon Valley Bank\\\\nAccount: 987654321098\\\\nRouting / SWIFT: SVB12345\\\\nPayPal / UPI: pay@studio.com'\n    );\n  ''');\n\n  return db;\n}\n",
  "lib/core/database/database_provider.dart": "import 'package:flutter_riverpod/flutter_riverpod.dart';\nimport 'package:sqlite3/sqlite3.dart';\n\n/// Provider for the singleton SQLite database instance.\n/// Overridden at app startup in ProviderScope.\nfinal databaseProvider = Provider<Database>((ref) {\n  throw UnimplementedError('Database must be provided at startup');\n});\n",
  "lib/features/clients/models/client.dart": "import 'package:sqlite3/sqlite3.dart' hide Row;\nimport 'package:sqlite3/sqlite3.dart' as sql show Row;\n\nclass Client {\n  final String id;\n  final String name;\n  final String createdAt;\n\n  const Client({\n    required this.id,\n    required this.name,\n    required this.createdAt,\n  });\n\n  factory Client.fromRow(sql.Row row) {\n    return Client(\n      id: row['id'] as String,\n      name: row['name'] as String,\n      createdAt: row['created_at'] as String,\n    );\n  }\n}\n",
  "lib/features/clients/providers/clients_provider.dart": "import 'package:flutter_riverpod/flutter_riverpod.dart';\nimport 'package:sqlite3/sqlite3.dart';\n\nimport '../../../core/database/database_provider.dart';\nimport '../../../core/utils/id_generator.dart';\nimport '../models/client.dart';\n\nclass ClientsNotifier extends StateNotifier<List<Client>> {\n  final Database _db;\n\n  ClientsNotifier(this._db) : super([]) {\n    loadClients();\n  }\n\n  void loadClients() {\n    final ResultSet results = _db.select('SELECT * FROM clients ORDER BY name COLLATE NOCASE ASC');\n    state = results.map((row) => Client.fromRow(row)).toList();\n  }\n\n  void addClient(String name) {\n    final trimmed = name.trim();\n    if (trimmed.isEmpty) return;\n\n    final id = generateUniqueId();\n    final createdAt = DateTime.now().toUtc().toIso8601String();\n\n    final stmt = _db.prepare('INSERT INTO clients (id, name, created_at) VALUES (?, ?, ?)');\n    stmt.execute([id, trimmed, createdAt]);\n    stmt.dispose();\n\n    loadClients();\n  }\n}\n\nfinal clientsProvider = StateNotifierProvider<ClientsNotifier, List<Client>>((ref) {\n  return ClientsNotifier(ref.watch(databaseProvider));\n});\n",
  "lib/features/invoices/models/invoice_item.dart": "import 'package:sqlite3/sqlite3.dart' hide Row;\nimport 'package:sqlite3/sqlite3.dart' as sql show Row;\n\nclass InvoiceItem {\n  final String id;\n  final String invoiceId;\n  final String description;\n  final int quantity;\n  final int unitPriceCents;\n  final int totalCents;\n  final String createdAt;\n\n  const InvoiceItem({\n    required this.id,\n    required this.invoiceId,\n    required this.description,\n    required this.quantity,\n    required this.unitPriceCents,\n    required this.totalCents,\n    required this.createdAt,\n  });\n\n  factory InvoiceItem.fromRow(sql.Row row) {\n    return InvoiceItem(\n      id: row['id'] as String,\n      invoiceId: row['invoice_id'] as String,\n      description: row['description'] as String,\n      quantity: row['quantity'] as int,\n      unitPriceCents: row['unit_price_cents'] as int,\n      totalCents: row['total_cents'] as int,\n      createdAt: row['created_at'] as String,\n    );\n  }\n}\n",
  "lib/features/invoices/models/invoice_record.dart": "import 'package:sqlite3/sqlite3.dart' hide Row;\nimport 'package:sqlite3/sqlite3.dart' as sql show Row;\n\nclass InvoiceRecord {\n  final String id;\n  final String clientId;\n  final String clientName;\n  final String invoiceNumber;\n  final int subtotalCents;\n  final int taxCents;\n  final int totalCents;\n  final String status;\n  final String createdAt;\n\n  const InvoiceRecord({\n    required this.id,\n    required this.clientId,\n    required this.clientName,\n    required this.invoiceNumber,\n    required this.subtotalCents,\n    required this.taxCents,\n    required this.totalCents,\n    required this.status,\n    required this.createdAt,\n  });\n\n  factory InvoiceRecord.fromRow(sql.Row row) {\n    return InvoiceRecord(\n      id: row['id'] as String,\n      clientId: row['client_id'] as String,\n      clientName: (row['client_name'] as String?) ?? 'Unknown Client',\n      invoiceNumber: row['invoice_number'] as String,\n      subtotalCents: row['subtotal_cents'] as int,\n      taxCents: row['tax_cents'] as int,\n      totalCents: row['total_cents'] as int,\n      status: row['status'] as String,\n      createdAt: row['created_at'] as String,\n    );\n  }\n}\n",
  "lib/features/invoices/providers/invoices_provider.dart": "import 'package:flutter_riverpod/flutter_riverpod.dart';\nimport 'package:sqlite3/sqlite3.dart';\n\nimport '../../../core/database/database_provider.dart';\nimport '../../../core/utils/id_generator.dart';\nimport '../../../core/utils/money_utils.dart';\nimport '../models/invoice_item.dart';\nimport '../models/invoice_record.dart';\n\n/// Lightweight representation of an in-memory draft line item before committing to SQLite.\nclass DraftItem {\n  final String description;\n  final int unitPriceCents;\n  final int quantity;\n  final int totalCents;\n\n  const DraftItem({\n    required this.description,\n    required this.unitPriceCents,\n    required this.quantity,\n    required this.totalCents,\n  });\n}\n\nclass InvoicesNotifier extends StateNotifier<List<InvoiceRecord>> {\n  final Database _db;\n\n  InvoicesNotifier(this._db) : super([]) {\n    loadInvoices();\n  }\n\n  void loadInvoices() {\n    final ResultSet results = _db.select('''\n      SELECT \n        i.id,\n        i.client_id,\n        c.name AS client_name,\n        i.invoice_number,\n        i.subtotal_cents,\n        i.tax_cents,\n        i.total_cents,\n        i.status,\n        i.created_at\n      FROM invoices i\n      LEFT JOIN clients c ON i.client_id = c.id\n      ORDER BY i.created_at DESC\n    ''');\n\n    state = results.map((row) => InvoiceRecord.fromRow(row)).toList();\n  }\n\n  String getNextInvoiceNumber() {\n    final result = _db.select('SELECT COUNT(*) AS total FROM invoices');\n    final count = (result.first['total'] as int?) ?? 0;\n    final nextNumber = count + 1;\n    return 'INV-${nextNumber.toString().padLeft(4, '0')}';\n  }\n\n  /// Fetches all line items associated with a specific invoice.\n  List<InvoiceItem> getInvoiceItems(String invoiceId) {\n    final ResultSet results = _db.select(\n      'SELECT * FROM invoice_items WHERE invoice_id = ? ORDER BY rowid ASC',\n      [invoiceId],\n    );\n    return results.map((row) => InvoiceItem.fromRow(row)).toList();\n  }\n\n  /// Commits an invoice and all its line items within an atomic SQLite transaction.\n  void saveInvoice({\n    required String clientId,\n    required List<DraftItem> items,\n    required int taxPercentage,\n  }) {\n    if (items.isEmpty) {\n      throw ArgumentError('Cannot save an invoice with no line items.');\n    }\n\n    final invoiceId = generateUniqueId();\n    final invoiceNumber = getNextInvoiceNumber();\n    final createdAt = DateTime.now().toUtc().toIso8601String();\n    const status = 'PAID';\n\n    final subtotalCents = items.fold<int>(0, (sum, item) => sum + item.totalCents);\n    final taxCents = calculateTaxCents(subtotalCents, taxPercentage);\n    final totalCents = subtotalCents + taxCents;\n\n    // Atomic SQLite Transaction\n    _db.execute('BEGIN TRANSACTION;');\n    try {\n      // 1. Insert master invoice record\n      final invoiceStmt = _db.prepare('''\n        INSERT INTO invoices (\n          id, client_id, invoice_number, subtotal_cents, tax_cents, total_cents, status, created_at\n        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)\n      ''');\n      invoiceStmt.execute([\n        invoiceId,\n        clientId,\n        invoiceNumber,\n        subtotalCents,\n        taxCents,\n        totalCents,\n        status,\n        createdAt,\n      ]);\n      invoiceStmt.dispose();\n\n      // 2. Insert line items\n      final itemStmt = _db.prepare('''\n        INSERT INTO invoice_items (\n          id, invoice_id, description, quantity, unit_price_cents, total_cents, created_at\n        ) VALUES (?, ?, ?, ?, ?, ?, ?)\n      ''');\n      for (final item in items) {\n        final itemId = generateUniqueId();\n        itemStmt.execute([\n          itemId,\n          invoiceId,\n          item.description,\n          item.quantity,\n          item.unitPriceCents,\n          item.totalCents,\n          createdAt,\n        ]);\n      }\n      itemStmt.dispose();\n\n      _db.execute('COMMIT;');\n    } catch (e) {\n      _db.execute('ROLLBACK;');\n      rethrow;\n    }\n\n    loadInvoices();\n  }\n}\n\nfinal invoicesProvider = StateNotifierProvider<InvoicesNotifier, List<InvoiceRecord>>((ref) {\n  return InvoicesNotifier(ref.watch(databaseProvider));\n});\n",
  "lib/features/business_profile/models/business_profile.dart": "import 'package:sqlite3/sqlite3.dart' hide Row;\nimport 'package:sqlite3/sqlite3.dart' as sql show Row;\n\nclass BusinessProfile {\n  final String id;\n  final String businessName;\n  final String email;\n  final String phone;\n  final String address;\n  final String taxId;\n  final String paymentDetails;\n\n  const BusinessProfile({\n    required this.id,\n    required this.businessName,\n    required this.email,\n    required this.phone,\n    required this.address,\n    required this.taxId,\n    required this.paymentDetails,\n  });\n\n  factory BusinessProfile.fromRow(sql.Row row) {\n    return BusinessProfile(\n      id: row['id'] as String? ?? 'default',\n      businessName: row['business_name'] as String? ?? 'My Studio',\n      email: row['email'] as String? ?? '',\n      phone: row['phone'] as String? ?? '',\n      address: row['address'] as String? ?? '',\n      taxId: row['tax_id'] as String? ?? '',\n      paymentDetails: row['payment_details'] as String? ?? '',\n    );\n  }\n\n  BusinessProfile copyWith({\n    String? id,\n    String? businessName,\n    String? email,\n    String? phone,\n    String? address,\n    String? taxId,\n    String? paymentDetails,\n  }) {\n    return BusinessProfile(\n      id: id ?? this.id,\n      businessName: businessName ?? this.businessName,\n      email: email ?? this.email,\n      phone: phone ?? this.phone,\n      address: address ?? this.address,\n      taxId: taxId ?? this.taxId,\n      paymentDetails: paymentDetails ?? this.paymentDetails,\n    );\n  }\n\n  Map<String, dynamic> toMap() {\n    return {\n      'id': id,\n      'business_name': businessName,\n      'email': email,\n      'phone': phone,\n      'address': address,\n      'tax_id': taxId,\n      'payment_details': paymentDetails,\n    };\n  }\n}\n",
  "lib/features/business_profile/providers/business_profile_provider.dart": "import 'package:flutter_riverpod/flutter_riverpod.dart';\nimport 'package:sqlite3/sqlite3.dart';\n\nimport '../../../core/database/database_provider.dart';\nimport '../models/business_profile.dart';\n\nclass BusinessProfileNotifier extends StateNotifier<BusinessProfile> {\n  final Database _db;\n\n  BusinessProfileNotifier(this._db)\n      : super(\n          const BusinessProfile(\n            id: 'default',\n            businessName: 'My Freelance Studio',\n            email: 'billing@studio.com',\n            phone: '+1 (555) 019-2834',\n            address: '100 Tech Plaza, Suite 400, San Francisco, CA 94107',\n            taxId: 'US-EIN-987654321',\n            paymentDetails:\n                'Bank: Silicon Valley Bank\\nAccount: 987654321098\\nRouting / SWIFT: SVB12345\\nPayPal / UPI: pay@studio.com',\n          ),\n        ) {\n    _loadProfile();\n  }\n\n  void _loadProfile() {\n    try {\n      final ResultSet result = _db.select(\n        \"SELECT * FROM business_profile WHERE id = 'default' LIMIT 1;\",\n      );\n      if (result.isNotEmpty) {\n        state = BusinessProfile.fromRow(result.first);\n      }\n    } catch (_) {\n      // In case table is still initializing or during tests, keep default state\n    }\n  }\n\n  void updateProfile({\n    required String businessName,\n    required String email,\n    required String phone,\n    required String address,\n    required String taxId,\n    required String paymentDetails,\n  }) {\n    _db.execute(\n      '''\n      UPDATE business_profile\n      SET business_name = ?,\n          email = ?,\n          phone = ?,\n          address = ?,\n          tax_id = ?,\n          payment_details = ?\n      WHERE id = 'default';\n      ''',\n      [businessName, email, phone, address, taxId, paymentDetails],\n    );\n\n    state = state.copyWith(\n      businessName: businessName,\n      email: email,\n      phone: phone,\n      address: address,\n      taxId: taxId,\n      paymentDetails: paymentDetails,\n    );\n  }\n}\n\nfinal businessProfileProvider =\n    StateNotifierProvider<BusinessProfileNotifier, BusinessProfile>((ref) {\n  final db = ref.watch(databaseProvider);\n  return BusinessProfileNotifier(db);\n});\n",
  "lib/features/business_profile/presentation/business_profile_dialog.dart": "import 'package:flutter/material.dart';\nimport 'package:flutter_riverpod/flutter_riverpod.dart';\n\nimport '../providers/business_profile_provider.dart';\n\nclass BusinessProfileDialog extends ConsumerStatefulWidget {\n  const BusinessProfileDialog({super.key});\n\n  @override\n  ConsumerState<BusinessProfileDialog> createState() => _BusinessProfileDialogState();\n}\n\nclass _BusinessProfileDialogState extends ConsumerState<BusinessProfileDialog> {\n  final _formKey = GlobalKey<FormState>();\n\n  late final TextEditingController _businessNameController;\n  late final TextEditingController _emailController;\n  late final TextEditingController _phoneController;\n  late final TextEditingController _addressController;\n  late final TextEditingController _taxIdController;\n  late final TextEditingController _paymentDetailsController;\n\n  @override\n  void initState() {\n    super.initState();\n    final profile = ref.read(businessProfileProvider);\n    _businessNameController = TextEditingController(text: profile.businessName);\n    _emailController = TextEditingController(text: profile.email);\n    _phoneController = TextEditingController(text: profile.phone);\n    _addressController = TextEditingController(text: profile.address);\n    _taxIdController = TextEditingController(text: profile.taxId);\n    _paymentDetailsController = TextEditingController(text: profile.paymentDetails);\n  }\n\n  @override\n  void dispose() {\n    _businessNameController.dispose();\n    _emailController.dispose();\n    _phoneController.dispose();\n    _addressController.dispose();\n    _taxIdController.dispose();\n    _paymentDetailsController.dispose();\n    super.dispose();\n  }\n\n  void _handleSave() {\n    if (!_formKey.currentState!.validate()) return;\n\n    ref.read(businessProfileProvider.notifier).updateProfile(\n          businessName: _businessNameController.text.trim(),\n          email: _emailController.text.trim(),\n          phone: _phoneController.text.trim(),\n          address: _addressController.text.trim(),\n          taxId: _taxIdController.text.trim(),\n          paymentDetails: _paymentDetailsController.text.trim(),\n        );\n\n    Navigator.of(context).pop();\n\n    ScaffoldMessenger.of(context).showSnackBar(\n      const SnackBar(\n        content: Text('Business profile & payment details saved to local SQLite.'),\n      ),\n    );\n  }\n\n  @override\n  Widget build(BuildContext context) {\n    return AlertDialog(\n      title: const Row(\n        children: [\n          Icon(Icons.business_outlined),\n          SizedBox(width: 10),\n          Expanded(\n            child: Text(\n              'Business Profile & Payment Details',\n              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),\n            ),\n          ),\n        ],\n      ),\n      content: SizedBox(\n        width: 500,\n        child: SingleChildScrollView(\n          child: Form(\n            key: _formKey,\n            child: Column(\n              mainAxisSize: MainAxisSize.min,\n              crossAxisAlignment: CrossAxisAlignment.start,\n              children: [\n                const Text(\n                  'These details appear on your printed A4 PDF invoices and payment instructions.',\n                  style: TextStyle(fontSize: 12, color: Colors.grey),\n                ),\n                const SizedBox(height: 16),\n                TextFormField(\n                  controller: _businessNameController,\n                  decoration: const InputDecoration(\n                    labelText: 'Business / Studio Name *',\n                    hintText: 'e.g. My Freelance Studio',\n                    prefixIcon: Icon(Icons.storefront_outlined, size: 20),\n                  ),\n                  validator: (value) {\n                    if (value == null || value.trim().isEmpty) {\n                      return 'Please enter your business or freelancer name';\n                    }\n                    return null;\n                  },\n                ),\n                const SizedBox(height: 12),\n                Row(\n                  children: [\n                    Expanded(\n                      child: TextFormField(\n                        controller: _emailController,\n                        decoration: const InputDecoration(\n                          labelText: 'Billing Email',\n                          hintText: 'billing@studio.com',\n                          prefixIcon: Icon(Icons.email_outlined, size: 20),\n                        ),\n                        keyboardType: TextInputType.emailAddress,\n                      ),\n                    ),\n                    const SizedBox(width: 12),\n                    Expanded(\n                      child: TextFormField(\n                        controller: _phoneController,\n                        decoration: const InputDecoration(\n                          labelText: 'Phone',\n                          hintText: '+1 555-0199',\n                          prefixIcon: Icon(Icons.phone_outlined, size: 20),\n                        ),\n                        keyboardType: TextInputType.phone,\n                      ),\n                    ),\n                  ],\n                ),\n                const SizedBox(height: 12),\n                TextFormField(\n                  controller: _addressController,\n                  decoration: const InputDecoration(\n                    labelText: 'Business Address',\n                    hintText: '100 Tech Plaza, Suite 400, San Francisco, CA',\n                    prefixIcon: Icon(Icons.location_on_outlined, size: 20),\n                  ),\n                ),\n                const SizedBox(height: 12),\n                TextFormField(\n                  controller: _taxIdController,\n                  decoration: const InputDecoration(\n                    labelText: 'Tax ID / VAT / GSTIN / EIN',\n                    hintText: 'e.g. US-EIN-123456789 or GSTIN29ABCDE1234F1Z5',\n                    prefixIcon: Icon(Icons.badge_outlined, size: 20),\n                  ),\n                ),\n                const SizedBox(height: 16),\n                const Text(\n                  'Payment Instructions & Remittance Details',\n                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),\n                ),\n                const SizedBox(height: 6),\n                TextFormField(\n                  controller: _paymentDetailsController,\n                  maxLines: 4,\n                  decoration: const InputDecoration(\n                    hintText:\n                        'Bank: ACME Bank\\nAccount: 123456789\\nRouting / IFSC / SWIFT: ACM00123\\nPayPal / UPI: pay@studio.com',\n                    alignLabelWithHint: true,\n                  ),\n                ),\n              ],\n            ),\n          ),\n        ),\n      ),\n      actions: [\n        TextButton(\n          onPressed: () => Navigator.of(context).pop(),\n          child: const Text('Cancel'),\n        ),\n        FilledButton.icon(\n          onPressed: _handleSave,\n          icon: const Icon(Icons.save_outlined, size: 18),\n          label: const Text('Save Profile'),\n        ),\n      ],\n    );\n  }\n}\n",
  "lib/features/billing/presentation/widgets/client_selection_card.dart": "import 'package:flutter/material.dart';\nimport 'package:flutter_riverpod/flutter_riverpod.dart';\n\nimport '../../../clients/providers/clients_provider.dart';\n\nclass ClientSelectionCard extends ConsumerWidget {\n  final TextEditingController newClientController;\n  final String? selectedClientId;\n  final ValueChanged<String?> onClientSelected;\n  final VoidCallback onAddClient;\n\n  const ClientSelectionCard({\n    super.key,\n    required this.newClientController,\n    required this.selectedClientId,\n    required this.onClientSelected,\n    required this.onAddClient,\n  });\n\n  @override\n  Widget build(BuildContext context, WidgetRef ref) {\n    final clients = ref.watch(clientsProvider);\n\n    return Card(\n      elevation: 0,\n      shape: RoundedRectangleBorder(\n        side: BorderSide(color: Theme.of(context).dividerColor),\n        borderRadius: BorderRadius.circular(8),\n      ),\n      child: Padding(\n        padding: const EdgeInsets.all(16.0),\n        child: Column(\n          crossAxisAlignment: CrossAxisAlignment.start,\n          children: [\n            Text(\n              '1. Client Selection',\n              style: Theme.of(context).textTheme.titleMedium?.copyWith(\n                    fontWeight: FontWeight.bold,\n                  ),\n            ),\n            const SizedBox(height: 12),\n            Row(\n              children: [\n                Expanded(\n                  flex: 3,\n                  child: TextField(\n                    controller: newClientController,\n                    decoration: const InputDecoration(\n                      labelText: 'New Client Name',\n                      hintText: 'e.g. Acme Corp',\n                    ),\n                  ),\n                ),\n                const SizedBox(width: 8),\n                FilledButton.tonal(\n                  onPressed: onAddClient,\n                  child: const Text('Add Client'),\n                ),\n                const SizedBox(width: 16),\n                Expanded(\n                  flex: 4,\n                  child: DropdownButtonFormField<String>(\n                    value: selectedClientId,\n                    decoration: const InputDecoration(\n                      labelText: 'Select Saved Client',\n                    ),\n                    items: clients.map((c) {\n                      return DropdownMenuItem<String>(\n                        value: c.id,\n                        child: Text(c.name),\n                      );\n                    }).toList(),\n                    onChanged: onClientSelected,\n                    hint: const Text('Choose a client'),\n                  ),\n                ),\n              ],\n            ),\n          ],\n        ),\n      ),\n    );\n  }\n}\n",
  "lib/features/billing/presentation/widgets/invoice_inputs_card.dart": "import 'package:flutter/material.dart';\n\nimport '../../../../core/utils/money_utils.dart';\nimport '../../../invoices/providers/invoices_provider.dart';\n\nclass InvoiceInputsCard extends StatefulWidget {\n  final String nextInvoiceNumber;\n  final void Function(List<DraftItem> items, int taxPercentage) onSaveInvoice;\n\n  const InvoiceInputsCard({\n    super.key,\n    required this.nextInvoiceNumber,\n    required this.onSaveInvoice,\n  });\n\n  @override\n  State<InvoiceInputsCard> createState() => _InvoiceInputsCardState();\n}\n\nclass _InvoiceInputsCardState extends State<InvoiceInputsCard> {\n  final _descriptionController = TextEditingController();\n  final _priceController = TextEditingController();\n  final _quantityController = TextEditingController(text: '1');\n  final _taxPercentageController = TextEditingController(text: '10');\n\n  final List<DraftItem> _draftItems = [];\n\n  @override\n  void dispose() {\n    _descriptionController.dispose();\n    _priceController.dispose();\n    _quantityController.dispose();\n    _taxPercentageController.dispose();\n    super.dispose();\n  }\n\n  void _handleAddLineItem() {\n    final description = _descriptionController.text.trim();\n    if (description.isEmpty) {\n      ScaffoldMessenger.of(context).showSnackBar(\n        const SnackBar(content: Text('Please enter an item description.')),\n      );\n      return;\n    }\n\n    final unitPriceCents = parsePriceToCents(_priceController.text);\n    if (unitPriceCents <= 0) {\n      ScaffoldMessenger.of(context).showSnackBar(\n        const SnackBar(content: Text('Please enter a valid unit price.')),\n      );\n      return;\n    }\n\n    final quantity = int.tryParse(_quantityController.text.trim()) ?? 1;\n    if (quantity <= 0) {\n      ScaffoldMessenger.of(context).showSnackBar(\n        const SnackBar(content: Text('Quantity must be at least 1.')),\n      );\n      return;\n    }\n\n    final totalCents = unitPriceCents * quantity;\n\n    setState(() {\n      _draftItems.add(DraftItem(\n        description: description,\n        unitPriceCents: unitPriceCents,\n        quantity: quantity,\n        totalCents: totalCents,\n      ));\n      _descriptionController.clear();\n      _priceController.clear();\n      _quantityController.text = '1';\n    });\n  }\n\n  void _handleRemoveItem(int index) {\n    setState(() {\n      _draftItems.removeAt(index);\n    });\n  }\n\n  void _handleSave() {\n    if (_draftItems.isEmpty) {\n      ScaffoldMessenger.of(context).showSnackBar(\n        const SnackBar(content: Text('Add at least one line item before saving.')),\n      );\n      return;\n    }\n\n    final taxPercentage = int.tryParse(_taxPercentageController.text.trim()) ?? 0;\n    widget.onSaveInvoice(List.from(_draftItems), taxPercentage);\n\n    setState(() {\n      _draftItems.clear();\n    });\n  }\n\n  @override\n  Widget build(BuildContext context) {\n    final subtotalCents = _draftItems.fold<int>(0, (sum, item) => sum + item.totalCents);\n    final taxPercentage = int.tryParse(_taxPercentageController.text.trim()) ?? 0;\n    final taxCents = calculateTaxCents(subtotalCents, taxPercentage);\n    final totalCents = subtotalCents + taxCents;\n\n    return Card(\n      elevation: 0,\n      shape: RoundedRectangleBorder(\n        side: BorderSide(color: Theme.of(context).dividerColor),\n        borderRadius: BorderRadius.circular(8),\n      ),\n      child: Padding(\n        padding: const EdgeInsets.all(16.0),\n        child: Column(\n          crossAxisAlignment: CrossAxisAlignment.start,\n          children: [\n            // Card Header\n            Row(\n              mainAxisAlignment: MainAxisAlignment.spaceBetween,\n              children: [\n                Text(\n                  '2. Invoice Line Items (Cart)',\n                  style: Theme.of(context).textTheme.titleMedium?.copyWith(\n                        fontWeight: FontWeight.bold,\n                      ),\n                ),\n                Text(\n                  'Next: ${widget.nextInvoiceNumber}',\n                  style: TextStyle(\n                    fontFamily: 'monospace',\n                    fontWeight: FontWeight.bold,\n                    color: Theme.of(context).colorScheme.primary,\n                  ),\n                ),\n              ],\n            ),\n            const SizedBox(height: 14),\n\n            // Item Input Row\n            Row(\n              children: [\n                Expanded(\n                  flex: 5,\n                  child: TextField(\n                    controller: _descriptionController,\n                    decoration: const InputDecoration(\n                      labelText: 'Item Description',\n                      hintText: 'e.g. Website Consulting',\n                    ),\n                  ),\n                ),\n                const SizedBox(width: 12),\n                Expanded(\n                  flex: 2,\n                  child: TextField(\n                    controller: _priceController,\n                    keyboardType: TextInputType.number,\n                    decoration: const InputDecoration(\n                      labelText: 'Price (\\$)',\n                      hintText: '25.00',\n                    ),\n                  ),\n                ),\n                const SizedBox(width: 12),\n                Expanded(\n                  flex: 2,\n                  child: TextField(\n                    controller: _quantityController,\n                    keyboardType: TextInputType.number,\n                    decoration: const InputDecoration(\n                      labelText: 'Qty',\n                      hintText: '1',\n                    ),\n                  ),\n                ),\n                const SizedBox(width: 12),\n                FilledButton.tonalIcon(\n                  onPressed: _handleAddLineItem,\n                  icon: const Icon(Icons.add_shopping_cart, size: 18),\n                  label: const Text('Add Item'),\n                ),\n              ],\n            ),\n\n            const SizedBox(height: 16),\n\n            // Cart Table / Empty state\n            if (_draftItems.isEmpty)\n              Container(\n                width: double.infinity,\n                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),\n                decoration: BoxDecoration(\n                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),\n                  borderRadius: BorderRadius.circular(6),\n                  border: Border.all(color: Theme.of(context).dividerColor),\n                ),\n                child: const Center(\n                  child: Text(\n                    'No items in this invoice yet. Enter item details above and click \"Add Item\".',\n                    style: TextStyle(color: Colors.grey, fontSize: 13),\n                  ),\n                ),\n              )\n            else\n              Container(\n                decoration: BoxDecoration(\n                  border: Border.all(color: Theme.of(context).dividerColor),\n                  borderRadius: BorderRadius.circular(6),\n                ),\n                child: Column(\n                  children: [\n                    Container(\n                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),\n                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),\n                      child: const Row(\n                        children: [\n                          Expanded(flex: 5, child: Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),\n                          Expanded(flex: 2, child: Text('Qty', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),\n                          Expanded(flex: 2, child: Text('Unit Price', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),\n                          Expanded(flex: 2, child: Text('Total', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),\n                          SizedBox(width: 48),\n                        ],\n                      ),\n                    ),\n                    ListView.separated(\n                      shrinkWrap: true,\n                      physics: const NeverScrollableScrollPhysics(),\n                      itemCount: _draftItems.length,\n                      separatorBuilder: (_, __) => const Divider(height: 1),\n                      itemBuilder: (context, index) {\n                        final item = _draftItems[index];\n                        return Padding(\n                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),\n                          child: Row(\n                            children: [\n                              Expanded(flex: 5, child: Text(item.description, style: const TextStyle(fontWeight: FontWeight.w500))),\n                              Expanded(flex: 2, child: Text('${item.quantity}', textAlign: TextAlign.center)),\n                              Expanded(flex: 2, child: Text(formatCents(item.unitPriceCents), textAlign: TextAlign.right)),\n                              Expanded(\n                                flex: 2,\n                                child: Text(\n                                  formatCents(item.totalCents),\n                                  textAlign: TextAlign.right,\n                                  style: const TextStyle(fontWeight: FontWeight.w600),\n                                ),\n                              ),\n                              SizedBox(\n                                width: 48,\n                                child: IconButton(\n                                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),\n                                  onPressed: () => _handleRemoveItem(index),\n                                  tooltip: 'Remove Item',\n                                ),\n                              ),\n                            ],\n                          ),\n                        );\n                      },\n                    ),\n                  ],\n                ),\n              ),\n\n            const SizedBox(height: 16),\n\n            // Tax & Summary Row\n            Row(\n              children: [\n                SizedBox(\n                  width: 140,\n                  child: TextField(\n                    controller: _taxPercentageController,\n                    keyboardType: TextInputType.number,\n                    decoration: const InputDecoration(\n                      labelText: 'Tax %',\n                      hintText: '10',\n                      suffixText: '%',\n                    ),\n                    onChanged: (_) => setState(() {}),\n                  ),\n                ),\n                const SizedBox(width: 24),\n                Expanded(\n                  child: Row(\n                    mainAxisAlignment: MainAxisAlignment.end,\n                    children: [\n                      Text(\n                        'Items: ${_draftItems.length} | '\n                        'Subtotal: ${formatCents(subtotalCents)} | '\n                        'Tax: ${formatCents(taxCents)} | ',\n                        style: const TextStyle(fontSize: 13, color: Colors.grey),\n                      ),\n                      Text(\n                        'Total: ${formatCents(totalCents)}',\n                        style: TextStyle(\n                          fontSize: 16,\n                          fontWeight: FontWeight.bold,\n                          color: Theme.of(context).colorScheme.primary,\n                        ),\n                      ),\n                    ],\n                  ),\n                ),\n                const SizedBox(width: 16),\n                FilledButton.icon(\n                  onPressed: _draftItems.isEmpty ? null : _handleSave,\n                  icon: const Icon(Icons.save),\n                  label: const Text('Save Invoice Locally'),\n                ),\n              ],\n            ),\n          ],\n        ),\n      ),\n    );\n  }\n}\n",
  "lib/features/billing/services/invoice_pdf_service.dart": "import 'dart:typed_data';\nimport 'package:pdf/pdf.dart';\nimport 'package:pdf/widgets.dart' as pw;\n\nimport '../../../../core/utils/money_utils.dart';\nimport '../../../business_profile/models/business_profile.dart';\nimport '../../../invoices/models/invoice_item.dart';\nimport '../../../invoices/models/invoice_record.dart';\n\nclass InvoicePdfService {\n  /// Generates a print-ready A4 PDF invoice document adhering to strict financial formatting.\n  static Future<Uint8List> generateInvoicePdf({\n    required InvoiceRecord invoice,\n    required List<InvoiceItem> items,\n    required String clientName,\n    required BusinessProfile businessProfile,\n  }) async {\n    final pdf = pw.Document(\n      title: 'Invoice ${invoice.invoiceNumber}',\n      author: businessProfile.businessName,\n    );\n\n    // Format date nicely from ISO string\n    String formattedDate = invoice.createdAt;\n    try {\n      final parsed = DateTime.parse(invoice.createdAt);\n      formattedDate =\n          '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';\n    } catch (_) {}\n\n    pdf.addPage(\n      pw.Page(\n        pageFormat: PdfPageFormat.a4,\n        margin: const pw.EdgeInsets.all(36),\n        build: (pw.Context context) {\n          return pw.Column(\n            crossAxisAlignment: pw.CrossAxisAlignment.start,\n            children: [\n              // =============================================================\n              // HEADER\n              // =============================================================\n              pw.Row(\n                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,\n                crossAxisAlignment: pw.CrossAxisAlignment.start,\n                children: [\n                  pw.Column(\n                    crossAxisAlignment: pw.CrossAxisAlignment.start,\n                    children: [\n                      pw.Text(\n                        'INVOICE',\n                        style: pw.TextStyle(\n                          fontSize: 28,\n                          fontWeight: pw.FontWeight.bold,\n                          color: PdfColor.fromHex('#1E293B'),\n                        ),\n                      ),\n                      pw.SizedBox(height: 4),\n                      pw.Text(\n                        invoice.invoiceNumber,\n                        style: pw.TextStyle(\n                          fontSize: 14,\n                          fontWeight: pw.FontWeight.bold,\n                          color: PdfColor.fromHex('#4F46E5'),\n                        ),\n                      ),\n                    ],\n                  ),\n                  pw.Column(\n                    crossAxisAlignment: pw.CrossAxisAlignment.end,\n                    children: [\n                      pw.Container(\n                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),\n                        decoration: pw.BoxDecoration(\n                          color: PdfColor.fromHex('#ECFDF5'),\n                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),\n                          border: pw.Border.all(color: PdfColor.fromHex('#10B981'), width: 1),\n                        ),\n                        child: pw.Text(\n                          invoice.status,\n                          style: pw.TextStyle(\n                            fontSize: 11,\n                            fontWeight: pw.FontWeight.bold,\n                            color: PdfColor.fromHex('#047857'),\n                          ),\n                        ),\n                      ),\n                      pw.SizedBox(height: 6),\n                      pw.Text(\n                        'Date: $formattedDate',\n                        style: pw.TextStyle(\n                          fontSize: 10,\n                          color: PdfColor.fromHex('#64748B'),\n                        ),\n                      ),\n                    ],\n                  ),\n                ],\n              ),\n\n              pw.SizedBox(height: 20),\n              pw.Divider(color: PdfColor.fromHex('#E2E8F0'), thickness: 1),\n              pw.SizedBox(height: 16),\n\n              // =============================================================\n              // BILLED FROM / BILLED TO ADDRESS BLOCK\n              // =============================================================\n              pw.Row(\n                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,\n                crossAxisAlignment: pw.CrossAxisAlignment.start,\n                children: [\n                  pw.Column(\n                    crossAxisAlignment: pw.CrossAxisAlignment.start,\n                    children: [\n                      pw.Text(\n                        'BILLED FROM',\n                        style: pw.TextStyle(\n                          fontSize: 9,\n                          fontWeight: pw.FontWeight.bold,\n                          color: PdfColor.fromHex('#94A3B8'),\n                        ),\n                      ),\n                      pw.SizedBox(height: 4),\n                      pw.Text(\n                        businessProfile.businessName,\n                        style: pw.TextStyle(\n                          fontSize: 12,\n                          fontWeight: pw.FontWeight.bold,\n                          color: PdfColor.fromHex('#1E293B'),\n                        ),\n                      ),\n                      if (businessProfile.email.isNotEmpty) ...[\n                        pw.SizedBox(height: 2),\n                        pw.Text(\n                          businessProfile.email,\n                          style: pw.TextStyle(\n                            fontSize: 10,\n                            color: PdfColor.fromHex('#475569'),\n                          ),\n                        ),\n                      ],\n                      if (businessProfile.phone.isNotEmpty) ...[\n                        pw.SizedBox(height: 2),\n                        pw.Text(\n                          businessProfile.phone,\n                          style: pw.TextStyle(\n                            fontSize: 9,\n                            color: PdfColor.fromHex('#64748B'),\n                          ),\n                        ),\n                      ],\n                      if (businessProfile.address.isNotEmpty) ...[\n                        pw.SizedBox(height: 2),\n                        pw.Text(\n                          businessProfile.address,\n                          style: pw.TextStyle(\n                            fontSize: 9,\n                            color: PdfColor.fromHex('#64748B'),\n                          ),\n                        ),\n                      ],\n                      if (businessProfile.taxId.isNotEmpty) ...[\n                        pw.SizedBox(height: 2),\n                        pw.Text(\n                          'Tax ID / EIN: ${businessProfile.taxId}',\n                          style: pw.TextStyle(\n                            fontSize: 9,\n                            fontWeight: pw.FontWeight.bold,\n                            color: PdfColor.fromHex('#64748B'),\n                          ),\n                        ),\n                      ],\n                    ],\n                  ),\n                  pw.Column(\n                    crossAxisAlignment: pw.CrossAxisAlignment.end,\n                    children: [\n                      pw.Text(\n                        'BILLED TO',\n                        style: pw.TextStyle(\n                          fontSize: 9,\n                          fontWeight: pw.FontWeight.bold,\n                          color: PdfColor.fromHex('#94A3B8'),\n                        ),\n                      ),\n                      pw.SizedBox(height: 4),\n                      pw.Text(\n                        clientName,\n                        style: pw.TextStyle(\n                          fontSize: 12,\n                          fontWeight: pw.FontWeight.bold,\n                          color: PdfColor.fromHex('#1E293B'),\n                        ),\n                      ),\n                      pw.SizedBox(height: 2),\n                      pw.Text(\n                        'Client ID: ${invoice.clientId}',\n                        style: pw.TextStyle(\n                          fontSize: 9,\n                          color: PdfColor.fromHex('#94A3B8'),\n                        ),\n                      ),\n                    ],\n                  ),\n                ],\n              ),\n\n              pw.SizedBox(height: 24),\n\n              // =============================================================\n              // LINE ITEMS TABLE\n              // =============================================================\n              pw.Table(\n                columnWidths: {\n                  0: const pw.FlexColumnWidth(5),\n                  1: const pw.FlexColumnWidth(1.5),\n                  2: const pw.FlexColumnWidth(2),\n                  3: const pw.FlexColumnWidth(2),\n                },\n                children: [\n                  // Table Header\n                  pw.TableRow(\n                    decoration: pw.BoxDecoration(\n                      color: PdfColor.fromHex('#F1F5F9'),\n                      border: pw.Border(\n                        bottom: pw.BorderSide(color: PdfColor.fromHex('#CBD5E1'), width: 1),\n                      ),\n                    ),\n                    children: [\n                      pw.Padding(\n                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),\n                        child: pw.Text(\n                          'DESCRIPTION',\n                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#475569')),\n                        ),\n                      ),\n                      pw.Padding(\n                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),\n                        child: pw.Text(\n                          'QTY',\n                          textAlign: pw.TextAlign.center,\n                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#475569')),\n                        ),\n                      ),\n                      pw.Padding(\n                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),\n                        child: pw.Text(\n                          'UNIT PRICE',\n                          textAlign: pw.TextAlign.right,\n                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#475569')),\n                        ),\n                      ),\n                      pw.Padding(\n                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),\n                        child: pw.Text(\n                          'TOTAL',\n                          textAlign: pw.TextAlign.right,\n                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#475569')),\n                        ),\n                      ),\n                    ],\n                  ),\n\n                  // Table Body\n                  ...items.asMap().entries.map((entry) {\n                    final idx = entry.key;\n                    final item = entry.value;\n                    final isEven = idx % 2 == 0;\n\n                    return pw.TableRow(\n                      decoration: pw.BoxDecoration(\n                        color: isEven ? PdfColors.white : PdfColor.fromHex('#F8FAFC'),\n                        border: pw.Border(\n                          bottom: pw.BorderSide(color: PdfColor.fromHex('#E2E8F0'), width: 0.5),\n                        ),\n                      ),\n                      children: [\n                        pw.Padding(\n                          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),\n                          child: pw.Text(\n                            item.description,\n                            style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#1E293B')),\n                          ),\n                        ),\n                        pw.Padding(\n                          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),\n                          child: pw.Text(\n                            '${item.quantity}',\n                            textAlign: pw.TextAlign.center,\n                            style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#475569')),\n                          ),\n                        ),\n                        pw.Padding(\n                          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),\n                          child: pw.Text(\n                            formatCents(item.unitPriceCents),\n                            textAlign: pw.TextAlign.right,\n                            style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#475569')),\n                          ),\n                        ),\n                        pw.Padding(\n                          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),\n                          child: pw.Text(\n                            formatCents(item.totalCents),\n                            textAlign: pw.TextAlign.right,\n                            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1E293B')),\n                          ),\n                        ),\n                      ],\n                    );\n                  }),\n                ],\n              ),\n\n              pw.SizedBox(height: 18),\n\n              // =============================================================\n              // TOTALS BREAKDOWN (Right) & PAYMENT INSTRUCTIONS (Left)\n              // =============================================================\n              pw.Row(\n                crossAxisAlignment: pw.CrossAxisAlignment.start,\n                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,\n                children: [\n                  // Payment Details Box on Left\n                  pw.Expanded(\n                    child: pw.Container(\n                      margin: const pw.EdgeInsets.only(right: 16),\n                      padding: const pw.EdgeInsets.all(10),\n                      decoration: pw.BoxDecoration(\n                        color: PdfColor.fromHex('#F8FAFC'),\n                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),\n                        border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),\n                      ),\n                      child: pw.Column(\n                        crossAxisAlignment: pw.CrossAxisAlignment.start,\n                        children: [\n                          pw.Text(\n                            'PAYMENT INSTRUCTIONS & BANK DETAILS',\n                            style: pw.TextStyle(\n                              fontSize: 8.5,\n                              fontWeight: pw.FontWeight.bold,\n                              color: PdfColor.fromHex('#475569'),\n                            ),\n                          ),\n                          pw.SizedBox(height: 6),\n                          pw.Text(\n                            businessProfile.paymentDetails.isNotEmpty\n                                ? businessProfile.paymentDetails\n                                : 'Please remit payment within 14 days.\\nThank you for prompt settlement.',\n                            style: pw.TextStyle(\n                              fontSize: 9,\n                              color: PdfColor.fromHex('#334155'),\n                              lineSpacing: 2,\n                            ),\n                          ),\n                        ],\n                      ),\n                    ),\n                  ),\n\n                  // Financial summary card on Right\n                  pw.Container(\n                    width: 200,\n                    padding: const pw.EdgeInsets.all(12),\n                    decoration: pw.BoxDecoration(\n                      color: PdfColor.fromHex('#F8FAFC'),\n                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),\n                      border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),\n                    ),\n                    child: pw.Column(\n                      children: [\n                        pw.Row(\n                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,\n                          children: [\n                            pw.Text('Subtotal:', style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#64748B'))),\n                            pw.Text(formatCents(invoice.subtotalCents), style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#1E293B'))),\n                          ],\n                        ),\n                        pw.SizedBox(height: 4),\n                        pw.Row(\n                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,\n                          children: [\n                            pw.Text('Tax:', style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#64748B'))),\n                            pw.Text(formatCents(invoice.taxCents), style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#1E293B'))),\n                          ],\n                        ),\n                        pw.SizedBox(height: 6),\n                        pw.Divider(color: PdfColor.fromHex('#CBD5E1'), thickness: 0.5),\n                        pw.SizedBox(height: 4),\n                        pw.Row(\n                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,\n                          children: [\n                            pw.Text('Grand Total:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1E293B'))),\n                            pw.Text(\n                              formatCents(invoice.totalCents),\n                              style: pw.TextStyle(\n                                fontSize: 13,\n                                fontWeight: pw.FontWeight.bold,\n                                color: PdfColor.fromHex('#4F46E5'),\n                              ),\n                            ),\n                          ],\n                        ),\n                      ],\n                    ),\n                  ),\n                ],\n              ),\n\n              pw.Spacer(),\n\n              // =============================================================\n              // FOOTER\n              // =============================================================\n              pw.Divider(color: PdfColor.fromHex('#E2E8F0'), thickness: 1),\n              pw.SizedBox(height: 8),\n              pw.Center(\n                child: pw.Text(\n                  'Thank you for your business! Payment due within 14 days.',\n                  style: pw.TextStyle(\n                    fontSize: 10,\n                    fontStyle: pw.FontStyle.italic,\n                    color: PdfColor.fromHex('#94A3B8'),\n                  ),\n                ),\n              ),\n            ],\n          );\n        },\n      ),\n    );\n\n    return pdf.save();\n  }\n}\n",
  "lib/features/billing/presentation/widgets/offline_invoices_list.dart": "import 'package:flutter/material.dart';\nimport 'package:flutter_riverpod/flutter_riverpod.dart';\nimport 'package:printing/printing.dart';\n\nimport '../../../../core/utils/money_utils.dart';\nimport '../../../business_profile/providers/business_profile_provider.dart';\nimport '../../../invoices/models/invoice_item.dart';\nimport '../../../invoices/models/invoice_record.dart';\nimport '../../../invoices/providers/invoices_provider.dart';\nimport '../../services/invoice_pdf_service.dart';\n\nclass OfflineInvoicesList extends ConsumerWidget {\n  const OfflineInvoicesList({super.key});\n\n  void _handlePrint(BuildContext context, WidgetRef ref, InvoiceRecord inv) async {\n    final items = ref.read(invoicesProvider.notifier).getInvoiceItems(inv.id);\n    final businessProfile = ref.read(businessProfileProvider);\n\n    try {\n      await Printing.layoutPdf(\n        onLayout: (format) => InvoicePdfService.generateInvoicePdf(\n          invoice: inv,\n          items: items,\n          clientName: inv.clientName,\n          businessProfile: businessProfile,\n        ),\n        name: '${inv.invoiceNumber}.pdf',\n      );\n    } catch (e) {\n      if (context.mounted) {\n        ScaffoldMessenger.of(context).showSnackBar(\n          SnackBar(content: Text('Print/PDF Error: $e')),\n        );\n      }\n    }\n  }\n\n  @override\n  Widget build(BuildContext context, WidgetRef ref) {\n    final invoices = ref.watch(invoicesProvider);\n\n    return Column(\n      crossAxisAlignment: CrossAxisAlignment.start,\n      children: [\n        Text(\n          'Offline Invoices (${invoices.length})',\n          style: Theme.of(context).textTheme.titleLarge?.copyWith(\n                fontWeight: FontWeight.bold,\n              ),\n        ),\n        const SizedBox(height: 12),\n        if (invoices.isEmpty)\n          Container(\n            width: double.infinity,\n            padding: const EdgeInsets.all(32),\n            decoration: BoxDecoration(\n              border: Border.all(color: Theme.of(context).dividerColor),\n              borderRadius: BorderRadius.circular(8),\n            ),\n            child: const Center(\n              child: Text(\n                'No invoices saved in local SQLite yet.\\nCreate your first client and invoice above.',\n                textAlign: TextAlign.center,\n                style: TextStyle(color: Colors.grey),\n              ),\n            ),\n          )\n        else\n          Card(\n            elevation: 0,\n            shape: RoundedRectangleBorder(\n              side: BorderSide(color: Theme.of(context).dividerColor),\n              borderRadius: BorderRadius.circular(8),\n            ),\n            child: ListView.separated(\n              shrinkWrap: true,\n              physics: const NeverScrollableScrollPhysics(),\n              itemCount: invoices.length,\n              separatorBuilder: (_, __) => const Divider(height: 1),\n              itemBuilder: (context, index) {\n                final inv = invoices[index];\n                return ExpansionTile(\n                  key: PageStorageKey('invoice_${inv.id}'),\n                  leading: Container(\n                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),\n                    decoration: BoxDecoration(\n                      color: Theme.of(context).colorScheme.primaryContainer,\n                      borderRadius: BorderRadius.circular(4),\n                    ),\n                    child: Text(\n                      inv.invoiceNumber,\n                      style: TextStyle(\n                        fontWeight: FontWeight.bold,\n                        color: Theme.of(context).colorScheme.onPrimaryContainer,\n                      ),\n                    ),\n                  ),\n                  title: Text(\n                    inv.clientName,\n                    style: const TextStyle(fontWeight: FontWeight.w600),\n                  ),\n                  subtitle: Text(\n                    'Subtotal: ${formatCents(inv.subtotalCents)} | Tax: ${formatCents(inv.taxCents)} | Status: ${inv.status}',\n                    style: const TextStyle(fontSize: 12),\n                  ),\n                  trailing: Row(\n                    mainAxisSize: MainAxisSize.min,\n                    children: [\n                      Text(\n                        formatCents(inv.totalCents),\n                        style: Theme.of(context).textTheme.titleMedium?.copyWith(\n                              fontWeight: FontWeight.bold,\n                              color: Theme.of(context).colorScheme.primary,\n                            ),\n                      ),\n                      const SizedBox(width: 12),\n                      // Prominent, unmissable PDF / Print action button on every card\n                      FilledButton.tonalIcon(\n                        icon: const Icon(Icons.picture_as_pdf, size: 16),\n                        label: const Text('PDF / Print', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),\n                        style: FilledButton.styleFrom(\n                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),\n                          visualDensity: VisualDensity.compact,\n                        ),\n                        onPressed: () => _handlePrint(context, ref, inv),\n                      ),\n                    ],\n                  ),\n                  children: [\n                    _InvoiceItemsBreakdown(\n                      invoice: inv,\n                      onPrint: () => _handlePrint(context, ref, inv),\n                    ),\n                  ],\n                );\n              },\n            ),\n          ),\n      ],\n    );\n  }\n}\n\nclass _InvoiceItemsBreakdown extends ConsumerWidget {\n  final InvoiceRecord invoice;\n  final VoidCallback onPrint;\n\n  const _InvoiceItemsBreakdown({\n    required this.invoice,\n    required this.onPrint,\n  });\n\n  @override\n  Widget build(BuildContext context, WidgetRef ref) {\n    final items = ref.read(invoicesProvider.notifier).getInvoiceItems(invoice.id);\n\n    return Container(\n      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),\n      padding: const EdgeInsets.all(12.0),\n      decoration: BoxDecoration(\n        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),\n        borderRadius: BorderRadius.circular(6),\n        border: Border.all(color: Theme.of(context).dividerColor),\n      ),\n      child: Column(\n        crossAxisAlignment: CrossAxisAlignment.start,\n        children: [\n          Row(\n            mainAxisAlignment: MainAxisAlignment.spaceBetween,\n            children: [\n              const Text(\n                'Line Items Breakdown:',\n                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),\n              ),\n              FilledButton.icon(\n                onPressed: onPrint,\n                icon: const Icon(Icons.picture_as_pdf, size: 16),\n                label: const Text('Print / Save PDF', style: TextStyle(fontSize: 12)),\n              ),\n            ],\n          ),\n          const SizedBox(height: 8),\n          if (items.isEmpty)\n            const Padding(\n              padding: EdgeInsets.symmetric(vertical: 8.0),\n              child: Text(\n                'No line items recorded for this invoice.',\n                style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 12),\n              ),\n            )\n          else\n            ListView.builder(\n              shrinkWrap: true,\n              physics: const NeverScrollableScrollPhysics(),\n              itemCount: items.length,\n              itemBuilder: (context, idx) {\n                final InvoiceItem item = items[idx];\n                return Padding(\n                  padding: const EdgeInsets.symmetric(vertical: 4.0),\n                  child: Row(\n                    children: [\n                      Expanded(\n                        flex: 5,\n                        child: Text(\n                          '• ${item.description}',\n                          style: const TextStyle(fontSize: 13),\n                        ),\n                      ),\n                      Expanded(\n                        flex: 2,\n                        child: Text(\n                          'Qty: ${item.quantity}',\n                          textAlign: TextAlign.center,\n                          style: const TextStyle(fontSize: 12, color: Colors.grey),\n                        ),\n                      ),\n                      Expanded(\n                        flex: 2,\n                        child: Text(\n                          formatCents(item.unitPriceCents),\n                          textAlign: TextAlign.right,\n                          style: const TextStyle(fontSize: 12, color: Colors.grey),\n                        ),\n                      ),\n                      Expanded(\n                        flex: 2,\n                        child: Text(\n                          formatCents(item.totalCents),\n                          textAlign: TextAlign.right,\n                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),\n                        ),\n                      ),\n                    ],\n                  ),\n                );\n              },\n            ),\n        ],\n      ),\n    );\n  }\n}\n",
  "lib/features/billing/presentation/billing_dashboard_screen.dart": "import 'package:flutter/material.dart';\nimport 'package:flutter_riverpod/flutter_riverpod.dart';\n\nimport '../../../core/theme/app_theme.dart';\nimport '../../../core/theme/theme_provider.dart';\nimport '../../business_profile/presentation/business_profile_dialog.dart';\nimport '../../clients/providers/clients_provider.dart';\nimport '../../invoices/providers/invoices_provider.dart';\nimport 'widgets/client_selection_card.dart';\nimport 'widgets/invoice_inputs_card.dart';\nimport 'widgets/offline_invoices_list.dart';\n\nclass BillingDashboardScreen extends ConsumerStatefulWidget {\n  const BillingDashboardScreen({super.key});\n\n  @override\n  ConsumerState<BillingDashboardScreen> createState() => _BillingDashboardScreenState();\n}\n\nclass _BillingDashboardScreenState extends ConsumerState<BillingDashboardScreen> {\n  final _newClientController = TextEditingController();\n  String? _selectedClientId;\n\n  @override\n  void dispose() {\n    _newClientController.dispose();\n    super.dispose();\n  }\n\n  void _handleAddClient() {\n    final name = _newClientController.text.trim();\n    if (name.isEmpty) return;\n\n    ref.read(clientsProvider.notifier).addClient(name);\n    _newClientController.clear();\n\n    final clients = ref.read(clientsProvider);\n    final found = clients.where((c) => c.name == name);\n    if (found.isNotEmpty) {\n      setState(() {\n        _selectedClientId = found.first.id;\n      });\n    }\n\n    ScaffoldMessenger.of(context).showSnackBar(\n      SnackBar(content: Text('Client \"$name\" added locally to SQLite.')),\n    );\n  }\n\n  void _handleSaveInvoice(List<DraftItem> items, int taxPercentage) {\n    if (_selectedClientId == null) {\n      ScaffoldMessenger.of(context).showSnackBar(\n        const SnackBar(content: Text('Please select or add a client first.')),\n      );\n      return;\n    }\n\n    ref.read(invoicesProvider.notifier).saveInvoice(\n          clientId: _selectedClientId!,\n          items: items,\n          taxPercentage: taxPercentage,\n        );\n\n    ScaffoldMessenger.of(context).showSnackBar(\n      SnackBar(content: Text('Invoice saved locally with ${items.length} line item(s)!')),\n    );\n  }\n\n  IconData _getThemeModeIcon(ThemeMode mode) {\n    switch (mode) {\n      case ThemeMode.system:\n        return Icons.brightness_auto;\n      case ThemeMode.light:\n        return Icons.light_mode;\n      case ThemeMode.dark:\n        return Icons.dark_mode;\n    }\n  }\n\n  String _getThemeModeTooltip(ThemeMode mode) {\n    switch (mode) {\n      case ThemeMode.system:\n        return 'Theme: System Auto (click to switch to Light)';\n      case ThemeMode.light:\n        return 'Theme: Light Mode (click to switch to Dark)';\n      case ThemeMode.dark:\n        return 'Theme: Dark Mode (click to switch to System)';\n    }\n  }\n\n  @override\n  Widget build(BuildContext context) {\n    final nextInvoiceNumber = ref.watch(invoicesProvider.notifier).getNextInvoiceNumber();\n    final themeMode = ref.watch(themeModeProvider);\n    final currentAccent = ref.watch(accentColorProvider);\n\n    return Scaffold(\n      appBar: AppBar(\n        title: const Text('Local Billing (Offline Desktop Skeleton)'),\n        elevation: 0,\n        actions: [\n          // Business Profile & Payment Details Settings Dialog\n          IconButton(\n            tooltip: 'Business Profile & Payment Details',\n            icon: const Icon(Icons.business_outlined),\n            onPressed: () {\n              showDialog(\n                context: context,\n                builder: (context) => const BusinessProfileDialog(),\n              );\n            },\n          ),\n\n          // Accent Color Palette Picker\n          PopupMenuButton<Color>(\n            tooltip: 'Accent Color',\n            icon: Icon(Icons.palette_outlined, color: currentAccent),\n            onSelected: (color) {\n              ref.read(accentColorProvider.notifier).setAccentColor(color);\n            },\n            itemBuilder: (context) {\n              return AppTheme.presetAccents.map((color) {\n                final isSelected = color.value == currentAccent.value;\n                return PopupMenuItem<Color>(\n                  value: color,\n                  child: Row(\n                    children: [\n                      Container(\n                        width: 18,\n                        height: 18,\n                        decoration: BoxDecoration(\n                          color: color,\n                          shape: BoxShape.circle,\n                        ),\n                      ),\n                      const SizedBox(width: 10),\n                      Text(\n                        _getColorName(color),\n                        style: TextStyle(\n                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,\n                        ),\n                      ),\n                      if (isSelected) ...[\n                        const Spacer(),\n                        const Icon(Icons.check, size: 16),\n                      ],\n                    ],\n                  ),\n                );\n              }).toList();\n            },\n          ),\n\n          // Theme Mode Toggle (System -> Light -> Dark)\n          IconButton(\n            tooltip: _getThemeModeTooltip(themeMode),\n            icon: Icon(_getThemeModeIcon(themeMode)),\n            onPressed: () {\n              ref.read(themeModeProvider.notifier).cycleThemeMode();\n            },\n          ),\n          const SizedBox(width: 8),\n        ],\n      ),\n      body: SingleChildScrollView(\n        padding: const EdgeInsets.all(24.0),\n        child: Column(\n          crossAxisAlignment: CrossAxisAlignment.start,\n          children: [\n            ClientSelectionCard(\n              newClientController: _newClientController,\n              selectedClientId: _selectedClientId,\n              onClientSelected: (val) => setState(() => _selectedClientId = val),\n              onAddClient: _handleAddClient,\n            ),\n            const SizedBox(height: 20),\n            InvoiceInputsCard(\n              nextInvoiceNumber: nextInvoiceNumber,\n              onSaveInvoice: _handleSaveInvoice,\n            ),\n            const SizedBox(height: 24),\n            const OfflineInvoicesList(),\n          ],\n        ),\n      ),\n    );\n  }\n\n  String _getColorName(Color color) {\n    if (color == const Color(0xFF4F46E5)) return 'Indigo';\n    if (color == const Color(0xFF059669)) return 'Emerald';\n    if (color == const Color(0xFF2563EB)) return 'Royal Blue';\n    if (color == const Color(0xFFE11D48)) return 'Rose';\n    if (color == const Color(0xFFD97706)) return 'Amber';\n    if (color == const Color(0xFF475569)) return 'Slate';\n    return 'Custom';\n  }\n}\n",
  ".github/workflows/build.yml": "name: Build Desktop & Mobile Apps\r\n\r\non:\r\n  push:\r\n    branches: [ main, master ]\r\n  workflow_dispatch: # Allows you to manually click \"Run workflow\"\r\n\r\njobs:\r\n  # =========================================================================\r\n  # 1. BUILD WINDOWS .EXE\r\n  # =========================================================================\r\n  build-windows:\r\n    name: Build Windows Release (.exe)\r\n    runs-on: windows-latest\r\n\r\n    steps:\r\n      - name: Checkout Code\r\n        uses: actions/checkout@v5\r\n\r\n      - name: Setup Flutter\r\n        uses: subosito/flutter-action@v2\r\n        with:\r\n          channel: 'stable'\r\n          cache: true\r\n\r\n      - name: Enable Windows Desktop Support\r\n        run: flutter config --enable-windows-desktop\r\n\r\n      # THIS STEP CREATES THE MISSING WINDOWS FOLDER AUTOMATICALLY\r\n      - name: Generate Windows Scaffolding\r\n        run: flutter create --platforms=windows .\r\n\r\n      - name: Install Dependencies\r\n        run: flutter pub get\r\n\r\n      - name: Build Windows Executable\r\n        run: flutter build windows --release\r\n\r\n      - name: Package Windows Release as Zip\r\n        run: |\r\n          Compress-Archive -Path build\\windows\\x64\\runner\\Release\\* -DestinationPath billing_app_windows.zip\r\n\r\n      - name: Upload Windows Executable Artifact\r\n        uses: actions/upload-artifact@v6\r\n        with:\r\n          name: billing-app-windows-x64\r\n          path: billing_app_windows.zip\r\n          retention-days: 7\r\n\r\n  # =========================================================================\r\n  # 2. BUILD ANDROID .APK\r\n  # =========================================================================\r\n  build-android:\r\n    name: Build Android Release (.apk)\r\n    runs-on: ubuntu-24.04\r\n\r\n    steps:\r\n      - name: Checkout Code\r\n        uses: actions/checkout@v5\r\n\r\n      - name: Setup Java\r\n        uses: actions/setup-java@v5\r\n        with:\r\n          distribution: 'temurin'\r\n          java-version: '17'\r\n\r\n      - name: Setup Flutter\r\n        uses: subosito/flutter-action@v2\r\n        with:\r\n          channel: 'stable'\r\n          cache: true\r\n\r\n      # THIS STEP CREATES THE MISSING ANDROID FOLDER AUTOMATICALLY\r\n      - name: Generate Android Scaffolding\r\n        run: flutter create --platforms=android .\r\n\r\n      - name: Install Dependencies\r\n        run: flutter pub get\r\n\r\n      - name: Build Android APK\r\n        run: flutter build apk --release\r\n\r\n      - name: Upload Android APK Artifact\r\n        uses: actions/upload-artifact@v6\r\n        with:\r\n          name: billing-app-android\r\n          path: build/app/outputs/flutter-apk/app-release.apk\r\n          retention-days: 7\r"
};

export default function App() {
  const [activeTab, setActiveTab] = useState<'app' | 'flutter_code' | 'schema'>('app');
  const [selectedFile, setSelectedFile] = useState<string>('lib/main.dart');

  // Business Profile state backed by local storage mimicking SQLite business_profile table
  const [businessProfile, setBusinessProfile] = useState<BusinessProfile>(() => {
    try {
      const saved = localStorage.getItem('sqlite_business_profile');
      if (saved) return JSON.parse(saved);
    } catch {
      // fallback
    }
    return DEFAULT_BUSINESS_PROFILE;
  });

  const [isProfileModalOpen, setIsProfileModalOpen] = useState(false);
  const [profileForm, setProfileForm] = useState<BusinessProfile>(businessProfile);

  // Local storage backed state mimicking SQLite tables
  const [clients, setClients] = useState<Client[]>(() => {
    try {
      const saved = localStorage.getItem('sqlite_clients');
      if (saved) return JSON.parse(saved);
    } catch {
      // fallback
    }
    return [
      { id: '1714000000000-101', name: 'Acme Global Corp', created_at: '2026-10-26T10:00:00Z' },
      { id: '1714000000000-102', name: 'Apex Design Studio', created_at: '2026-10-26T11:00:00Z' },
    ];
  });

  const [invoices, setInvoices] = useState<InvoiceRecord[]>(() => {
    try {
      const saved = localStorage.getItem('sqlite_invoices');
      if (saved) return JSON.parse(saved);
    } catch {
      // fallback
    }
    return [
      {
        id: '1714000000000-201',
        client_id: '1714000000000-101',
        client_name: 'Acme Global Corp',
        invoice_number: 'INV-0001',
        subtotal_cents: 22500, // $225.00
        tax_cents: 2250,       // $22.50
        total_cents: 24750,    // $247.50
        status: 'PAID',
        created_at: '2026-10-26T12:00:00Z',
      },
    ];
  });

  const [invoiceItems, setInvoiceItems] = useState<StoredInvoiceItem[]>(() => {
    try {
      const saved = localStorage.getItem('sqlite_invoice_items');
      if (saved) return JSON.parse(saved);
    } catch {
      // fallback
    }
    return [
      {
        id: '1714000000000-301',
        invoice_id: '1714000000000-201',
        description: 'System Architecture Consultation',
        quantity: 2,
        unit_price_cents: 10000,
        total_cents: 20000,
        created_at: '2026-10-26T12:00:00Z',
      },
      {
        id: '1714000000000-302',
        invoice_id: '1714000000000-201',
        description: 'SSL Certificate & Domain Setup',
        quantity: 1,
        unit_price_cents: 2500,
        total_cents: 2500,
        created_at: '2026-10-26T12:00:00Z',
      },
    ];
  });

  // Client Selection State
  const [newClientName, setNewClientName] = useState('');
  const [selectedClientId, setSelectedClientId] = useState<string>('1714000000000-101');

  // Cart / Line Items Input State
  const [cartItems, setCartItems] = useState<DraftLineItem[]>([
    { description: 'Cloud Infrastructure Setup', unitPriceCents: 15000, quantity: 1, totalCents: 15000 },
    { description: 'Monthly Maintenance Service', unitPriceCents: 3500, quantity: 2, totalCents: 7000 },
  ]);
  const [itemDescription, setItemDescription] = useState('');
  const [priceInput, setPriceInput] = useState('');
  const [quantityInput, setQuantityInput] = useState('1');
  const [taxPctInput, setTaxPctInput] = useState('10');

  // Expanded Invoices State
  const [expandedInvoiceIds, setExpandedInvoiceIds] = useState<Set<string>>(new Set(['1714000000000-201']));

  // Feedback states
  const [copiedKey, setCopiedKey] = useState<string | null>(null);
  const [toastMessage, setToastMessage] = useState<string | null>(null);

  // PDF Preview Modal State
  const [previewInvoice, setPreviewInvoice] = useState<{
    invoice: InvoiceRecord;
    items: StoredInvoiceItem[];
  } | null>(null);

  // Persist to local storage mimicking SQLite
  useEffect(() => {
    try {
      localStorage.setItem('sqlite_clients', JSON.stringify(clients));
    } catch (e) {
      console.error(e);
    }
  }, [clients]);

  useEffect(() => {
    try {
      localStorage.setItem('sqlite_invoices', JSON.stringify(invoices));
    } catch (e) {
      console.error(e);
    }
  }, [invoices]);

  useEffect(() => {
    try {
      localStorage.setItem('sqlite_invoice_items', JSON.stringify(invoiceItems));
    } catch (e) {
      console.error(e);
    }
  }, [invoiceItems]);

  useEffect(() => {
    try {
      localStorage.setItem('sqlite_business_profile', JSON.stringify(businessProfile));
    } catch (e) {
      console.error(e);
    }
  }, [businessProfile]);

  const showToast = (msg: string) => {
    setToastMessage(msg);
    setTimeout(() => setToastMessage(null), 3000);
  };

  const handleCopy = (text: string, key: string) => {
    navigator.clipboard.writeText(text);
    setCopiedKey(key);
    showToast(`Copied ${key} to clipboard!`);
    setTimeout(() => setCopiedKey(null), 2000);
  };

  const handleDownload = (filepath: string, content: string) => {
    const filename = filepath.split('/').pop() || 'file';
    const blob = new Blob([content], { type: 'text/plain;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    a.click();
    URL.revokeObjectURL(url);
    showToast(`Downloaded ${filename}`);
  };

  const handleSaveProfile = (e: React.FormEvent) => {
    e.preventDefault();
    if (!profileForm.business_name.trim()) {
      alert('Business name is required.');
      return;
    }
    setBusinessProfile(profileForm);
    setIsProfileModalOpen(false);
    showToast('Business Profile & Payment Details updated in local SQLite!');
  };

  const handlePrintInvoice = () => {
    window.print();
  };

  const handleDownloadInvoiceDocument = (invoice: InvoiceRecord, items: StoredInvoiceItem[]) => {
    const htmlContent = `<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>${invoice.invoice_number} - Invoice</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; margin: 0; padding: 40px; color: #1e293b; background: #fff; }
    .header { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 25px; }
    .title { font-size: 28px; font-weight: 800; letter-spacing: -0.5px; margin: 0; }
    .inv-num { font-size: 14px; font-weight: 700; color: #4f46e5; margin-top: 4px; }
    .badge { display: inline-block; padding: 4px 10px; border-radius: 4px; font-size: 11px; font-weight: 700; background: #ecfdf5; color: #047857; border: 1px solid #10b981; }
    .address-grid { display: flex; justify-content: space-between; margin-bottom: 30px; }
    .label { font-size: 9px; font-weight: 700; color: #94a3b8; text-transform: uppercase; margin-bottom: 4px; }
    .name { font-size: 13px; font-weight: 700; color: #1e293b; }
    .subtext { font-size: 11px; color: #475569; margin-top: 2px; }
    table { width: 100%; border-collapse: collapse; margin-bottom: 20px; }
    th { background: #f1f5f9; text-align: left; padding: 10px; font-size: 10px; font-weight: 700; color: #475569; border-bottom: 1px solid #cbd5e1; }
    th.right { text-align: right; }
    th.center { text-align: center; }
    td { padding: 10px; font-size: 11px; border-bottom: 1px solid #e2e8f0; color: #1e293b; }
    td.right { text-align: right; }
    td.center { text-align: center; }
    tr:nth-child(even) td { background: #f8fafc; }
    .bottom-section { display: flex; justify-content: space-between; gap: 24px; margin-bottom: 30px; }
    .payment-box { flex: 1; padding: 14px; background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 6px; }
    .totals-box { width: 230px; padding: 14px; background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 6px; }
    .total-row { display: flex; justify-content: space-between; font-size: 11px; margin-bottom: 6px; }
    .total-row.grand { font-size: 13px; font-weight: 800; border-top: 1px solid #cbd5e1; padding-top: 6px; color: #4f46e5; margin-bottom: 0; }
    .footer { border-top: 1px solid #e2e8f0; padding-top: 15px; text-align: center; font-size: 10px; font-style: italic; color: #94a3b8; }
    @media print {
      body { padding: 15mm; }
    }
  </style>
</head>
<body>
  <div class="header">
    <div>
      <h1 class="title">INVOICE</h1>
      <div class="inv-num">${invoice.invoice_number}</div>
    </div>
    <div style="text-align: right;">
      <div class="badge">${invoice.status}</div>
      <div class="subtext" style="margin-top: 6px;">Date: ${invoice.created_at.split('T')[0]}</div>
    </div>
  </div>

  <div class="address-grid">
    <div>
      <div class="label">Billed From</div>
      <div class="name">${businessProfile.business_name}</div>
      ${businessProfile.email ? `<div class="subtext">${businessProfile.email}</div>` : ''}
      ${businessProfile.phone ? `<div class="subtext">${businessProfile.phone}</div>` : ''}
      ${businessProfile.address ? `<div class="subtext">${businessProfile.address}</div>` : ''}
      ${businessProfile.tax_id ? `<div class="subtext" style="font-weight: 700; color: #64748b; margin-top: 4px;">Tax ID: ${businessProfile.tax_id}</div>` : ''}
    </div>
    <div style="text-align: right;">
      <div class="label">Billed To</div>
      <div class="name">${invoice.client_name}</div>
      <div class="subtext">Client ID: ${invoice.client_id}</div>
    </div>
  </div>

  <table>
    <thead>
      <tr>
        <th>DESCRIPTION</th>
        <th class="center" style="width: 50px;">QTY</th>
        <th class="right" style="width: 90px;">UNIT PRICE</th>
        <th class="right" style="width: 90px;">TOTAL</th>
      </tr>
    </thead>
    <tbody>
      ${items.map(it => `
        <tr>
          <td>${it.description}</td>
          <td class="center">${it.quantity}</td>
          <td class="right">${formatCents(it.unit_price_cents)}</td>
          <td class="right" style="font-weight: 700;">${formatCents(it.total_cents)}</td>
        </tr>
      `).join('')}
    </tbody>
  </table>

  <div class="bottom-section">
    <div class="payment-box">
      <div class="label">Payment Instructions & Bank Details</div>
      <div style="font-size: 11px; white-space: pre-line; color: #334155; line-height: 1.5; margin-top: 4px;">${businessProfile.payment_details || 'Please remit payment within 14 days.'}</div>
    </div>
    <div class="totals-box">
      <div class="total-row"><span>Subtotal:</span><span>${formatCents(invoice.subtotal_cents)}</span></div>
      <div class="total-row"><span>Tax:</span><span>${formatCents(invoice.tax_cents)}</span></div>
      <div class="total-row grand"><span>Grand Total:</span><span>${formatCents(invoice.total_cents)}</span></div>
    </div>
  </div>

  <div class="footer">
    Thank you for your business! Payment due within 14 days.
  </div>
</body>
</html>`;

    const blob = new Blob([htmlContent], { type: 'text/html;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `${invoice.invoice_number}.html`;
    a.click();
    URL.revokeObjectURL(url);
    showToast(`Downloaded printable ${invoice.invoice_number} document!`);
  };

  // Cart calculations
  const cartSubtotalCents = cartItems.reduce((acc, item) => acc + item.totalCents, 0);
  const taxPct = parseInt(taxPctInput, 10) || 0;
  const cartCalculations = calculateCartTotals(cartSubtotalCents, taxPct);

  // Add line item to cart
  const handleAddLineItem = (e: React.FormEvent) => {
    e.preventDefault();
    const desc = itemDescription.trim();
    if (!desc) {
      alert('Please enter an item description.');
      return;
    }
    const unitPrice = parsePriceToCents(priceInput);
    if (unitPrice <= 0) {
      alert('Please enter a valid price.');
      return;
    }
    const qty = parseInt(quantityInput, 10) || 1;
    if (qty <= 0) {
      alert('Quantity must be at least 1.');
      return;
    }
    const totalCents = unitPrice * qty;
    setCartItems((prev) => [
      ...prev,
      {
        description: desc,
        unitPriceCents: unitPrice,
        quantity: qty,
        totalCents,
      },
    ]);
    setItemDescription('');
    setPriceInput('');
    setQuantityInput('1');
    showToast(`Added "${desc}" to cart!`);
  };

  const handleRemoveLineItem = (index: number) => {
    setCartItems((prev) => prev.filter((_, i) => i !== index));
  };

  // Add client
  const handleAddClient = (e: React.FormEvent) => {
    e.preventDefault();
    const trimmed = newClientName.trim();
    if (!trimmed) return;
    const newId = `${Date.now()}-${Math.floor(Math.random() * 900000 + 100000)}`;
    const newClient: Client = {
      id: newId,
      name: trimmed,
      created_at: new Date().toISOString(),
    };
    setClients((prev) => [...prev, newClient]);
    setSelectedClientId(newId);
    setNewClientName('');
    showToast(`Client "${trimmed}" committed to local SQLite!`);
  };

  // Save Invoice (Commit Cart to SQLite tables in atomic transaction)
  const handleSaveInvoice = () => {
    if (!selectedClientId) {
      alert('Please select or create a client first.');
      return;
    }
    if (cartItems.length === 0) {
      alert('Add at least one line item to the cart before saving.');
      return;
    }

    const client = clients.find((c) => c.id === selectedClientId);
    const nextInvoiceNumber = formatNextInvoiceNumber(invoices.length);
    const invoiceId = `${Date.now()}-${Math.floor(Math.random() * 900000 + 100000)}`;
    const now = new Date().toISOString();

    const newInvoice: InvoiceRecord = {
      id: invoiceId,
      client_id: selectedClientId,
      client_name: client ? client.name : 'Unknown Client',
      invoice_number: nextInvoiceNumber,
      subtotal_cents: cartCalculations.subtotalCents,
      tax_cents: cartCalculations.taxCents,
      total_cents: cartCalculations.totalCents,
      status: 'PAID',
      created_at: now,
    };

    const newItems: StoredInvoiceItem[] = cartItems.map((item, idx) => ({
      id: `${Date.now()}-${idx}-${Math.floor(Math.random() * 900000 + 100000)}`,
      invoice_id: invoiceId,
      description: item.description,
      quantity: item.quantity,
      unit_price_cents: item.unitPriceCents,
      total_cents: item.totalCents,
      created_at: now,
    }));

    setInvoices((prev) => [newInvoice, ...prev]);
    setInvoiceItems((prev) => [...newItems, ...prev]);
    setExpandedInvoiceIds((prev) => new Set([...prev, invoiceId]));
    setCartItems([]);
    showToast(`Invoice ${nextInvoiceNumber} committed with ${newItems.length} line items!`);
  };

  const toggleInvoiceExpansion = (id: string) => {
    setExpandedInvoiceIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  return (
    <div className="min-h-screen bg-slate-900 text-slate-100 flex flex-col font-sans antialiased">
      {/* Toast Notification */}
      {toastMessage && (
        <div className="fixed bottom-5 right-5 z-50 bg-emerald-600 text-white px-4 py-2.5 rounded-lg shadow-xl text-sm font-medium flex items-center gap-2 transition-all">
          <Check className="w-4 h-4" />
          <span>{toastMessage}</span>
        </div>
      )}

      {/* Top Header */}
      <header className="border-b border-slate-800 bg-slate-950/80 backdrop-blur sticky top-0 z-40">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 py-3.5 flex flex-wrap items-center justify-between gap-4">
          <div className="flex items-center gap-3">
            <div className="w-9 h-9 rounded-lg bg-indigo-600/20 border border-indigo-500/40 flex items-center justify-center text-indigo-400">
              <HardDrive className="w-5 h-5" />
            </div>
            <div>
              <div className="flex items-center gap-2">
                <h1 className="text-base font-bold text-white tracking-tight">Offline Billing Foundation</h1>
                <span className="px-2 py-0.5 rounded text-[11px] font-semibold bg-emerald-500/10 text-emerald-400 border border-emerald-500/30">
                  100% Local SQLite
                </span>
                <span className="px-2 py-0.5 rounded text-[11px] font-semibold bg-indigo-500/10 text-indigo-400 border border-indigo-500/30">
                  Sprint 1: Profile & PDF
                </span>
              </div>
              <p className="text-xs text-slate-400">
                PONYTAIL / YAGNI • Strict 64-bit integer cents • Local Profile & Bank Remittance • Instant A4 PDF
              </p>
            </div>
          </div>

          {/* Header Actions */}
          <div className="flex items-center gap-2">
            <button
              onClick={() => {
                setProfileForm(businessProfile);
                setIsProfileModalOpen(true);
              }}
              className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-semibold bg-indigo-600/20 hover:bg-indigo-600/30 text-indigo-300 border border-indigo-500/40 transition cursor-pointer"
              title="Configure Business Profile, Tax ID & Payment Details"
            >
              <Building2 className="w-3.5 h-3.5 text-indigo-400" />
              <span className="hidden sm:inline">Business Profile & Bank Info</span>
              <span className="sm:hidden">Profile</span>
            </button>

            {/* Navigation Tabs */}
            <div className="flex items-center gap-1.5 bg-slate-900 border border-slate-800 p-1 rounded-lg">
              <button
                onClick={() => setActiveTab('app')}
                className={`flex items-center gap-2 px-3.5 py-1.5 rounded-md text-xs font-semibold transition ${
                  activeTab === 'app'
                    ? 'bg-indigo-600 text-white shadow-sm'
                    : 'text-slate-400 hover:text-slate-200 hover:bg-slate-800/60'
                }`}
              >
                <Monitor className="w-3.5 h-3.5" />
                Interactive App
              </button>
              <button
                onClick={() => setActiveTab('flutter_code')}
                className={`flex items-center gap-2 px-3.5 py-1.5 rounded-md text-xs font-semibold transition ${
                  activeTab === 'flutter_code'
                    ? 'bg-indigo-600 text-white shadow-sm'
                    : 'text-slate-400 hover:text-slate-200 hover:bg-slate-800/60'
                }`}
              >
                <FolderTree className="w-3.5 h-3.5" />
                Modular Files Explorer
              </button>
              <button
                onClick={() => setActiveTab('schema')}
                className={`flex items-center gap-2 px-3.5 py-1.5 rounded-md text-xs font-semibold transition ${
                  activeTab === 'schema'
                    ? 'bg-indigo-600 text-white shadow-sm'
                    : 'text-slate-400 hover:text-slate-200 hover:bg-slate-800/60'
                }`}
              >
                <Database className="w-3.5 h-3.5" />
                SQLite Schema
              </button>
            </div>
          </div>
        </div>
      </header>

      {/* Main Body */}
      <main className="flex-1 max-w-7xl mx-auto w-full px-4 sm:px-6 py-6">
        {activeTab === 'app' && (
          <div className="space-y-6">
            {/* Business Profile Active Banner */}
            <div className="bg-slate-950 border border-slate-800 rounded-xl p-4 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3">
              <div className="flex items-center gap-3">
                <div className="w-8 h-8 rounded-lg bg-indigo-500/10 border border-indigo-500/30 flex items-center justify-center text-indigo-400 shrink-0">
                  <Building2 className="w-4 h-4" />
                </div>
                <div>
                  <div className="flex items-center gap-2">
                    <span className="text-xs font-bold text-slate-200">{businessProfile.business_name}</span>
                    {businessProfile.tax_id && (
                      <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-slate-900 text-slate-400 border border-slate-800">
                        Tax ID: {businessProfile.tax_id}
                      </span>
                    )}
                  </div>
                  <p className="text-[11px] text-slate-400 mt-0.5 truncate max-w-xl">
                    {businessProfile.email} • {businessProfile.address || 'Address configured'} • Invoices print with this profile
                  </p>
                </div>
              </div>
              <button
                type="button"
                onClick={() => {
                  setProfileForm(businessProfile);
                  setIsProfileModalOpen(true);
                }}
                className="text-xs font-medium text-indigo-400 hover:text-indigo-300 hover:underline cursor-pointer whitespace-nowrap self-end sm:self-center"
              >
                Edit Business & Bank Details &rarr;
              </button>
            </div>

            {/* 1. Client Selection Card */}
            <div className="bg-slate-950 border border-slate-800 rounded-xl p-5 shadow-sm">
              <div className="flex items-center justify-between mb-4 pb-3 border-b border-slate-800/80">
                <div className="flex items-center gap-2">
                  <Building2 className="w-4 h-4 text-indigo-400" />
                  <h2 className="text-sm font-bold text-slate-100 uppercase tracking-wider">1. Client Selection</h2>
                </div>
                <span className="text-xs text-slate-400">
                  {clients.length} client{clients.length === 1 ? '' : 's'} in SQLite
                </span>
              </div>

              <div className="grid grid-cols-1 lg:grid-cols-12 gap-4 items-end">
                <form onSubmit={handleAddClient} className="lg:col-span-6 flex items-end gap-2">
                  <div className="flex-1">
                    <label htmlFor="new-client-name" className="block text-xs font-medium text-slate-400 mb-1.5">
                      New Client Name
                    </label>
                    <input
                      id="new-client-name"
                      type="text"
                      value={newClientName}
                      onChange={(e) => setNewClientName(e.target.value)}
                      placeholder="e.g. Acme Corporation"
                      className="w-full bg-slate-900 border border-slate-700/80 rounded-lg px-3 py-2 text-sm text-slate-100 placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
                    />
                  </div>
                  <button
                    type="submit"
                    className="inline-flex items-center gap-1.5 bg-slate-800 hover:bg-slate-700 text-slate-100 border border-slate-700 px-3.5 py-2 rounded-lg text-sm font-medium transition cursor-pointer"
                  >
                    <Plus className="w-4 h-4" />
                    Add Client
                  </button>
                </form>

                <div className="lg:col-span-6">
                  <label htmlFor="select-client" className="block text-xs font-medium text-slate-400 mb-1.5">
                    Select Saved Client
                  </label>
                  <select
                    id="select-client"
                    value={selectedClientId}
                    onChange={(e) => setSelectedClientId(e.target.value)}
                    className="w-full bg-slate-900 border border-slate-700/80 rounded-lg px-3 py-2 text-sm text-slate-100 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
                  >
                    <option value="">-- Choose a client from SQLite --</option>
                    {clients.map((c) => (
                      <option key={c.id} value={c.id}>
                        {c.name}
                      </option>
                    ))}
                  </select>
                </div>
              </div>
            </div>

            {/* 2. Multi-Line Item Invoice Cart Builder */}
            <div className="bg-slate-950 border border-slate-800 rounded-xl p-5 shadow-sm">
              <div className="flex items-center justify-between mb-4 pb-3 border-b border-slate-800/80">
                <div className="flex items-center gap-2">
                  <FileText className="w-4 h-4 text-indigo-400" />
                  <h2 className="text-sm font-bold text-slate-100 uppercase tracking-wider">
                    2. Invoice Items Builder (Cart)
                  </h2>
                </div>
                <div className="flex items-center gap-2">
                  <span className="text-xs font-mono text-slate-400">Target Invoice:</span>
                  <span className="font-mono text-xs font-bold text-indigo-400 bg-indigo-500/10 px-2 py-0.5 rounded border border-indigo-500/20">
                    {formatNextInvoiceNumber(invoices.length)}
                  </span>
                </div>
              </div>

              {/* Add item to cart form */}
              <form onSubmit={handleAddLineItem} className="grid grid-cols-1 md:grid-cols-12 gap-3 mb-5 items-end">
                <div className="md:col-span-6">
                  <label htmlFor="item-desc" className="block text-xs font-medium text-slate-400 mb-1">
                    Line Item Description *
                  </label>
                  <input
                    id="item-desc"
                    type="text"
                    value={itemDescription}
                    onChange={(e) => setItemDescription(e.target.value)}
                    placeholder="e.g. Backend API Architecture & Security"
                    className="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-2 text-sm text-slate-100 placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-indigo-500"
                  />
                </div>

                <div className="md:col-span-2">
                  <label htmlFor="item-qty" className="block text-xs font-medium text-slate-400 mb-1">
                    Quantity
                  </label>
                  <input
                    id="item-qty"
                    type="number"
                    min="1"
                    value={quantityInput}
                    onChange={(e) => setQuantityInput(e.target.value)}
                    className="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-2 text-sm text-slate-100 focus:outline-none focus:ring-2 focus:ring-indigo-500"
                  />
                </div>

                <div className="md:col-span-2">
                  <label htmlFor="item-price" className="block text-xs font-medium text-slate-400 mb-1">
                    Price ($)
                  </label>
                  <input
                    id="item-price"
                    type="text"
                    value={priceInput}
                    onChange={(e) => setPriceInput(e.target.value)}
                    placeholder="e.g. 150.00"
                    className="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-2 text-sm text-slate-100 placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-indigo-500"
                  />
                </div>

                <div className="md:col-span-2">
                  <button
                    type="submit"
                    className="w-full inline-flex items-center justify-center gap-1.5 bg-slate-800 hover:bg-slate-700 text-slate-100 border border-slate-700 py-2 px-3 rounded-lg text-sm font-medium transition cursor-pointer"
                  >
                    <Plus className="w-4 h-4" />
                    Add Item
                  </button>
                </div>
              </form>

              {/* Cart Table */}
              <div className="border border-slate-800 rounded-lg overflow-hidden bg-slate-900/30">
                <div className="bg-slate-900/80 px-4 py-2 text-xs font-semibold uppercase tracking-wider text-slate-400 flex justify-between">
                  <span>Cart Items ({cartItems.length})</span>
                  <span>Amount (Integer Cents)</span>
                </div>

                {cartItems.length === 0 ? (
                  <div className="py-6 text-center text-xs text-slate-500 italic">
                    Your cart is empty. Add services or products above.
                  </div>
                ) : (
                  <div className="divide-y divide-slate-800/60">
                    {cartItems.map((item, idx) => (
                      <div key={idx} className="px-4 py-2.5 flex items-center justify-between text-xs hover:bg-slate-900/40">
                        <div className="flex-1 min-w-0 pr-4">
                          <p className="font-medium text-slate-200 truncate">{item.description}</p>
                          <p className="text-slate-500 text-[11px]">
                            {item.quantity} × {formatCents(item.unitPriceCents)} each
                          </p>
                        </div>
                        <div className="flex items-center gap-4">
                          <span className="font-mono font-bold text-slate-200">
                            {formatCents(item.totalCents)}
                          </span>
                          <button
                            onClick={() => handleRemoveLineItem(idx)}
                            className="text-rose-400 hover:text-rose-300 p-1 rounded hover:bg-rose-500/10 cursor-pointer transition"
                            title="Remove item"
                          >
                            <Trash2 className="w-4 h-4" />
                          </button>
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>

              {/* Summary and Commit Footer */}
              <div className="bg-slate-900 border border-slate-800 rounded-lg p-4 flex flex-col md:flex-row md:items-center justify-between gap-4 mt-4">
                <div className="flex items-center gap-3">
                  <label htmlFor="tax-pct" className="text-xs font-medium text-slate-400 whitespace-nowrap">
                    Tax %:
                  </label>
                  <div className="relative w-24">
                    <input
                      id="tax-pct"
                      type="number"
                      min="0"
                      max="100"
                      value={taxPctInput}
                      onChange={(e) => setTaxPctInput(e.target.value)}
                      className="w-full bg-slate-950 border border-slate-700 rounded-md pr-6 pl-2.5 py-1.5 text-xs text-slate-100 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                    />
                    <span className="absolute right-2.5 top-1.5 text-slate-500 text-xs">%</span>
                  </div>
                </div>

                <div className="flex items-center gap-4 text-xs sm:text-sm">
                  <div className="text-slate-400">
                    <span>Subtotal:</span>{' '}
                    <strong className="text-slate-200">{formatCents(cartCalculations.subtotalCents)}</strong>
                  </div>
                  <span className="text-slate-600">+</span>
                  <div className="text-slate-400">
                    <span>Tax:</span>{' '}
                    <strong className="text-slate-200">{formatCents(cartCalculations.taxCents)}</strong>
                  </div>
                  <span className="text-slate-600">=</span>
                  <div className="text-indigo-400 text-base font-bold">
                    <span>Total: {formatCents(cartCalculations.totalCents)}</span>
                  </div>
                </div>

                <button
                  type="button"
                  onClick={handleSaveInvoice}
                  disabled={cartItems.length === 0}
                  className={`inline-flex items-center justify-center gap-2 font-medium px-5 py-2.5 rounded-lg text-sm transition shadow-sm ${
                    cartItems.length > 0
                      ? 'bg-indigo-600 hover:bg-indigo-500 text-white cursor-pointer'
                      : 'bg-slate-800 text-slate-500 cursor-not-allowed border border-slate-700/50'
                  }`}
                >
                  <Save className="w-4 h-4" />
                  Save Invoice Locally
                </button>
              </div>
            </div>

            {/* 3. Offline Invoices List with Expansion */}
            <div className="bg-slate-950 border border-slate-800 rounded-xl p-5 shadow-sm">
              <div className="flex flex-col sm:flex-row sm:items-center justify-between pb-3 mb-4 border-b border-slate-800/80 gap-2">
                <div className="flex items-center gap-2">
                  <HardDrive className="w-4 h-4 text-emerald-400" />
                  <h2 className="text-sm font-bold text-slate-100 uppercase tracking-wider">
                    Offline Invoices ({invoices.length})
                  </h2>
                </div>
                <div className="flex items-center gap-3 text-xs">
                  <span className="text-slate-400">
                    Total Value:{' '}
                    <span className="font-bold text-emerald-400">
                      {formatCents(invoices.reduce((acc, inv) => acc + inv.total_cents, 0))}
                    </span>
                  </span>
                  <span className="text-slate-500">•</span>
                  <span className="text-indigo-400 font-medium">Click "PDF / Print" on any invoice</span>
                </div>
              </div>

              {invoices.length === 0 ? (
                <div className="text-center py-12 border border-dashed border-slate-800 rounded-lg text-slate-500 text-sm">
                  No invoices saved in local SQLite yet. Add line items to your cart and save.
                </div>
              ) : (
                <div className="space-y-2">
                  {invoices.map((inv) => {
                    const isExpanded = expandedInvoiceIds.has(inv.id);
                    const items = invoiceItems.filter((item) => item.invoice_id === inv.id);

                    return (
                      <div
                        key={inv.id}
                        className="border border-slate-800 rounded-lg overflow-hidden bg-slate-900/40 hover:bg-slate-900/70 transition"
                      >
                        <div
                          onClick={() => toggleInvoiceExpansion(inv.id)}
                          className="p-4 flex flex-wrap sm:flex-nowrap items-center justify-between cursor-pointer select-none gap-3"
                        >
                          <div className="flex items-center gap-3">
                            <span className="font-mono font-bold text-xs bg-indigo-500/10 text-indigo-400 border border-indigo-500/30 px-2.5 py-1 rounded">
                              {inv.invoice_number}
                            </span>
                            <div>
                              <p className="font-semibold text-sm text-slate-200">{inv.client_name}</p>
                              <p className="text-xs text-slate-400">
                                Subtotal: {formatCents(inv.subtotal_cents)} • Tax: {formatCents(inv.tax_cents)} • {items.length} item{items.length === 1 ? '' : 's'}
                              </p>
                            </div>
                          </div>

                          <div className="flex items-center gap-3 ml-auto">
                            <span className="text-base font-bold font-mono text-emerald-400">
                              {formatCents(inv.total_cents)}
                            </span>
                            <span className="px-2 py-0.5 rounded text-[11px] font-semibold bg-emerald-500/10 text-emerald-400 border border-emerald-500/30">
                              {inv.status}
                            </span>

                            {/* PROMINENT, DIRECTLY ACCESSIBLE PDF / PRINT BUTTON */}
                            <button
                              type="button"
                              onClick={(e) => {
                                e.stopPropagation();
                                setPreviewInvoice({ invoice: inv, items });
                              }}
                              className="inline-flex items-center gap-1.5 px-3.5 py-1.5 rounded-lg text-xs font-bold bg-indigo-600 hover:bg-indigo-500 text-white shadow-md shadow-indigo-600/30 transition cursor-pointer shrink-0"
                              title="View & Print A4 PDF Invoice"
                            >
                              <Printer className="w-3.5 h-3.5" />
                              <span>PDF / Print</span>
                            </button>

                            <div className="text-slate-400">
                              {isExpanded ? <ChevronUp className="w-4 h-4" /> : <ChevronDown className="w-4 h-4" />}
                            </div>
                          </div>
                        </div>

                        {/* Expandable Line Items View */}
                        {isExpanded && (
                          <div className="border-t border-slate-800/80 bg-slate-950/60 p-4">
                            <div className="flex items-center justify-between mb-2">
                              <h4 className="text-xs font-bold text-slate-300 uppercase tracking-wider">
                                Line Items Breakdown:
                              </h4>
                              <button
                                type="button"
                                onClick={() => setPreviewInvoice({ invoice: inv, items })}
                                className="inline-flex items-center gap-1.5 px-3 py-1 rounded-md text-xs font-semibold bg-indigo-500/10 text-indigo-400 border border-indigo-500/30 hover:bg-indigo-500/20 transition cursor-pointer"
                              >
                                <Printer className="w-3.5 h-3.5" />
                                <span>A4 PDF Document</span>
                              </button>
                            </div>

                            <div className="space-y-1.5">
                              {items.length === 0 ? (
                                <p className="text-xs text-slate-500 italic">No line items recorded.</p>
                              ) : (
                                items.map((it) => (
                                  <div
                                    key={it.id}
                                    className="flex items-center justify-between text-xs py-1.5 px-2.5 rounded bg-slate-900/40 border border-slate-800/60"
                                  >
                                    <div className="flex-1">
                                      <span className="text-slate-200 font-medium">• {it.description}</span>
                                    </div>
                                    <div className="flex items-center gap-6 font-mono text-slate-400">
                                      <span>Qty: {it.quantity}</span>
                                      <span>{formatCents(it.unit_price_cents)}</span>
                                      <span className="font-bold text-slate-100 min-w-16 text-right">
                                        {formatCents(it.total_cents)}
                                      </span>
                                    </div>
                                  </div>
                                ))
                              )}
                            </div>
                          </div>
                        )}
                      </div>
                    );
                  })}
                </div>
              )}
            </div>
          </div>
        )}

        {/* Modular Files Explorer Tab */}
        {activeTab === 'flutter_code' && (
          <div className="space-y-6">
            <div className="bg-slate-950 border border-slate-800 rounded-xl p-5 shadow-sm">
              <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-4 border-b border-slate-800">
                <div>
                  <h2 className="text-base font-bold text-white flex items-center gap-2">
                    <FolderTree className="w-5 h-5 text-indigo-400" />
                    Modular Flutter Architecture (Sprint 1: Profile & PDF)
                  </h2>
                  <p className="text-xs text-slate-400 mt-0.5">
                    Includes <code className="text-indigo-300">BusinessProfile</code>, local SQLite persistence, payment remittance details, and unmissable PDF button.
                  </p>
                </div>

                <div className="flex items-center gap-2">
                  <button
                    onClick={() => handleDownload(selectedFile, MODULAR_FILES[selectedFile])}
                    className="inline-flex items-center gap-1.5 bg-slate-800 hover:bg-slate-700 text-slate-200 px-3 py-1.5 rounded-lg text-xs font-medium border border-slate-700 cursor-pointer"
                  >
                    <Download className="w-3.5 h-3.5" />
                    Download File
                  </button>

                  <button
                    onClick={() => handleCopy(MODULAR_FILES[selectedFile], selectedFile)}
                    className="inline-flex items-center gap-1.5 bg-indigo-600 hover:bg-indigo-500 text-white px-3 py-1.5 rounded-lg text-xs font-medium cursor-pointer"
                  >
                    {copiedKey ? <Check className="w-3.5 h-3.5" /> : <Copy className="w-3.5 h-3.5" />}
                    Copy Code
                  </button>
                </div>
              </div>

              {/* Two-column layout: file tree on the left, code on the right */}
              <div className="grid grid-cols-1 lg:grid-cols-12 gap-4 mt-4">
                {/* File list tree */}
                <div className="lg:col-span-4 bg-slate-900/90 border border-slate-800 rounded-lg p-3 text-xs space-y-1 max-h-[580px] overflow-y-auto">
                  <div className="text-[11px] font-bold uppercase tracking-wider text-slate-400 px-2 py-1">
                    Workspace Files ({Object.keys(MODULAR_FILES).length})
                  </div>
                  {Object.keys(MODULAR_FILES).map((path) => (
                    <button
                      key={path}
                      onClick={() => setSelectedFile(path)}
                      className={`w-full text-left px-2.5 py-1.5 rounded flex items-center gap-2 transition font-mono ${
                        selectedFile === path
                          ? 'bg-indigo-600 text-white font-semibold'
                          : 'text-slate-300 hover:bg-slate-800 hover:text-white'
                      }`}
                    >
                      <FileCode className="w-3.5 h-3.5 shrink-0 opacity-70" />
                      <span className="truncate">{path}</span>
                    </button>
                  ))}
                </div>

                {/* File viewer */}
                <div className="lg:col-span-8 flex flex-col">
                  <div className="bg-slate-900 border border-slate-800 rounded-t-lg px-4 py-2 flex items-center justify-between text-xs text-slate-400 font-mono">
                    <span>{selectedFile}</span>
                    <span className="text-[11px] text-slate-500">
                      {MODULAR_FILES[selectedFile]?.split('\n').length || 0} lines
                    </span>
                  </div>
                  <div className="bg-slate-950 border-x border-b border-slate-800 rounded-b-lg p-4 font-mono text-xs overflow-x-auto text-slate-200 max-h-[540px] leading-relaxed">
                    <pre>{MODULAR_FILES[selectedFile] || ''}</pre>
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* Schema Tab */}
        {activeTab === 'schema' && (
          <div className="space-y-6">
            <div className="bg-slate-950 border border-slate-800 rounded-xl p-5 shadow-sm">
              <div className="flex items-center justify-between pb-4 border-b border-slate-800">
                <div>
                  <h2 className="text-base font-bold text-white">Local SQLite Database Specifications</h2>
                  <p className="text-xs text-slate-400 mt-0.5">
                    File: <code className="text-indigo-300">billing_local.db</code> in <code className="text-indigo-300">getApplicationDocumentsDirectory()</code>
                  </p>
                </div>
                <button
                  onClick={() => {
                    localStorage.removeItem('sqlite_clients');
                    localStorage.removeItem('sqlite_invoices');
                    localStorage.removeItem('sqlite_invoice_items');
                    localStorage.removeItem('sqlite_business_profile');
                    setClients([]);
                    setInvoices([]);
                    setInvoiceItems([]);
                    setBusinessProfile(DEFAULT_BUSINESS_PROFILE);
                    showToast('Local database reset to defaults!');
                  }}
                  className="inline-flex items-center gap-1.5 text-xs text-rose-400 hover:text-rose-300 bg-rose-500/10 hover:bg-rose-500/20 border border-rose-500/30 px-3 py-1.5 rounded-lg cursor-pointer transition"
                >
                  <RefreshCw className="w-3.5 h-3.5" />
                  Reset / Clear DB
                </button>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mt-5">
                <div className="bg-slate-900 border border-slate-800 rounded-lg p-4">
                  <h3 className="text-xs font-bold text-indigo-400 font-mono mb-2">TABLE business_profile</h3>
                  <div className="bg-slate-950 p-3 rounded font-mono text-[11px] text-slate-300 overflow-x-auto">
                    <pre>{`CREATE TABLE IF NOT EXISTS business_profile (
  id TEXT PRIMARY KEY DEFAULT 'default',
  business_name TEXT NOT NULL,
  email TEXT DEFAULT '',
  phone TEXT DEFAULT '',
  address TEXT DEFAULT '',
  tax_id TEXT DEFAULT '',
  payment_details TEXT DEFAULT ''
);`}</pre>
                  </div>
                  <div className="mt-3 text-[11px] text-slate-400">
                    Stores company identity, tax ID, and remittance instructions.
                  </div>
                </div>

                <div className="bg-slate-900 border border-slate-800 rounded-lg p-4">
                  <h3 className="text-xs font-bold text-indigo-400 font-mono mb-2">TABLE clients</h3>
                  <div className="bg-slate-950 p-3 rounded font-mono text-[11px] text-slate-300 overflow-x-auto">
                    <pre>{`CREATE TABLE IF NOT EXISTS clients (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  created_at TEXT NOT NULL
);`}</pre>
                  </div>
                  <div className="mt-3 text-[11px] text-slate-400">
                    Stores client master records with ISO8601 timestamps.
                  </div>
                </div>

                <div className="bg-slate-900 border border-slate-800 rounded-lg p-4">
                  <h3 className="text-xs font-bold text-indigo-400 font-mono mb-2">TABLE invoices</h3>
                  <div className="bg-slate-950 p-3 rounded font-mono text-[11px] text-slate-300 overflow-x-auto">
                    <pre>{`CREATE TABLE IF NOT EXISTS invoices (
  id TEXT PRIMARY KEY,
  client_id TEXT NOT NULL,
  invoice_number TEXT NOT NULL UNIQUE,
  subtotal_cents INTEGER NOT NULL,
  tax_cents INTEGER NOT NULL,
  total_cents INTEGER NOT NULL,
  status TEXT NOT NULL,
  created_at TEXT NOT NULL,
  FOREIGN KEY (client_id) REFERENCES clients (id)
);`}</pre>
                  </div>
                  <div className="mt-3 text-[11px] text-slate-400">
                    Summary table for invoice totals in 64-bit integer cents.
                  </div>
                </div>

                <div className="bg-slate-900 border border-slate-800 rounded-lg p-4">
                  <h3 className="text-xs font-bold text-emerald-400 font-mono mb-2">TABLE invoice_items</h3>
                  <div className="bg-slate-950 p-3 rounded font-mono text-[11px] text-slate-300 overflow-x-auto">
                    <pre>{`CREATE TABLE IF NOT EXISTS invoice_items (
  id TEXT PRIMARY KEY,
  invoice_id TEXT NOT NULL,
  description TEXT NOT NULL,
  quantity INTEGER NOT NULL DEFAULT 1,
  unit_price_cents INTEGER NOT NULL,
  total_cents INTEGER NOT NULL,
  created_at TEXT NOT NULL,
  FOREIGN KEY (invoice_id) REFERENCES invoices (id) ON DELETE CASCADE
);`}</pre>
                  </div>
                  <div className="mt-3 text-[11px] text-slate-400">
                    Line item records connected via cascading delete.
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}
      </main>

      {/* Business Profile Modal Dialog */}
      {isProfileModalOpen && (
        <div className="fixed inset-0 z-50 bg-black/70 backdrop-blur-sm flex items-center justify-center p-4 overflow-y-auto">
          <div className="bg-slate-900 border border-slate-800 rounded-xl shadow-2xl max-w-lg w-full p-6 text-slate-100 my-8">
            <div className="flex items-center justify-between pb-3 border-b border-slate-800">
              <div className="flex items-center gap-2">
                <Building2 className="w-5 h-5 text-indigo-400" />
                <h3 className="text-base font-bold text-white">Business Profile & Payment Details</h3>
              </div>
              <button
                type="button"
                onClick={() => setIsProfileModalOpen(false)}
                className="p-1 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800 transition cursor-pointer"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleSaveProfile} className="mt-4 space-y-4 text-xs">
              <div>
                <label className="block text-slate-400 font-medium mb-1">
                  Business / Studio Name *
                </label>
                <input
                  type="text"
                  required
                  value={profileForm.business_name}
                  onChange={(e) => setProfileForm({ ...profileForm, business_name: e.target.value })}
                  placeholder="e.g. My Freelance Studio"
                  className="w-full bg-slate-950 border border-slate-700 rounded-lg px-3 py-2 text-slate-100 placeholder-slate-500 focus:outline-none focus:ring-1 focus:ring-indigo-500 text-xs"
                />
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label className="block text-slate-400 font-medium mb-1">Billing Email</label>
                  <input
                    type="email"
                    value={profileForm.email}
                    onChange={(e) => setProfileForm({ ...profileForm, email: e.target.value })}
                    placeholder="billing@studio.com"
                    className="w-full bg-slate-950 border border-slate-700 rounded-lg px-3 py-2 text-slate-100 placeholder-slate-500 focus:outline-none focus:ring-1 focus:ring-indigo-500 text-xs"
                  />
                </div>
                <div>
                  <label className="block text-slate-400 font-medium mb-1">Phone Number</label>
                  <input
                    type="text"
                    value={profileForm.phone}
                    onChange={(e) => setProfileForm({ ...profileForm, phone: e.target.value })}
                    placeholder="+1 (555) 019-2834"
                    className="w-full bg-slate-950 border border-slate-700 rounded-lg px-3 py-2 text-slate-100 placeholder-slate-500 focus:outline-none focus:ring-1 focus:ring-indigo-500 text-xs"
                  />
                </div>
              </div>

              <div>
                <label className="block text-slate-400 font-medium mb-1">Business Address</label>
                <input
                  type="text"
                  value={profileForm.address}
                  onChange={(e) => setProfileForm({ ...profileForm, address: e.target.value })}
                  placeholder="100 Tech Plaza, Suite 400, San Francisco, CA"
                  className="w-full bg-slate-950 border border-slate-700 rounded-lg px-3 py-2 text-slate-100 placeholder-slate-500 focus:outline-none focus:ring-1 focus:ring-indigo-500 text-xs"
                />
              </div>

              <div>
                <label className="block text-slate-400 font-medium mb-1">Tax ID / VAT / GSTIN / EIN</label>
                <input
                  type="text"
                  value={profileForm.tax_id}
                  onChange={(e) => setProfileForm({ ...profileForm, tax_id: e.target.value })}
                  placeholder="e.g. US-EIN-987654321 or GSTIN29ABCDE1234F1Z5"
                  className="w-full bg-slate-950 border border-slate-700 rounded-lg px-3 py-2 text-slate-100 placeholder-slate-500 focus:outline-none focus:ring-1 focus:ring-indigo-500 text-xs"
                />
              </div>

              <div>
                <label className="block text-slate-400 font-medium mb-1">
                  Payment Instructions & Remittance Details
                </label>
                <textarea
                  rows={4}
                  value={profileForm.payment_details}
                  onChange={(e) => setProfileForm({ ...profileForm, payment_details: e.target.value })}
                  placeholder="Bank: Silicon Valley Bank\nAccount: 987654321098\nRouting / SWIFT: SVB12345\nPayPal / UPI: pay@studio.com"
                  className="w-full bg-slate-950 border border-slate-700 rounded-lg px-3 py-2 text-slate-100 placeholder-slate-500 focus:outline-none focus:ring-1 focus:ring-indigo-500 text-xs font-mono leading-relaxed"
                />
                <p className="text-[11px] text-slate-500 mt-1">
                  These remittance instructions will be printed in the A4 invoice footer.
                </p>
              </div>

              <div className="flex justify-end gap-2 pt-3 border-t border-slate-800">
                <button
                  type="button"
                  onClick={() => setIsProfileModalOpen(false)}
                  className="px-3.5 py-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 text-xs font-medium cursor-pointer"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-4 py-1.5 rounded-lg bg-indigo-600 hover:bg-indigo-500 text-white text-xs font-semibold shadow-sm cursor-pointer"
                >
                  Save Profile Locally
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Printable A4 PDF Invoice Preview Modal */}
      {previewInvoice && (
        <div className="fixed inset-0 z-50 bg-black/80 backdrop-blur-sm flex flex-col items-center justify-start p-4 sm:p-6 overflow-y-auto">
          {/* Action Toolbar */}
          <div className="max-w-[760px] w-full flex items-center justify-between pb-4 pt-2 border-b border-slate-800 mb-6 sticky top-0 bg-slate-900/90 backdrop-blur z-10 px-2 rounded-t-lg">
            <div className="flex items-center gap-2">
              <Printer className="w-5 h-5 text-indigo-400" />
              <div>
                <h3 className="text-sm font-bold text-white flex items-center gap-2">
                  Invoice {previewInvoice.invoice.invoice_number}
                  <span className="text-[10px] bg-emerald-500/20 text-emerald-300 border border-emerald-500/40 px-2 py-0.5 rounded font-mono">
                    Ready for Print / PDF
                  </span>
                </h3>
                <p className="text-[11px] text-slate-400">
                  Swiss typography • Strict 64-bit integer cents calculations • Dynamic Business Profile
                </p>
              </div>
            </div>

            <div className="flex items-center gap-2">
              <button
                type="button"
                onClick={handlePrintInvoice}
                className="inline-flex items-center gap-1.5 px-3.5 py-1.5 rounded-lg text-xs font-semibold bg-indigo-600 hover:bg-indigo-500 text-white shadow-sm transition cursor-pointer"
              >
                <Printer className="w-3.5 h-3.5" />
                <span>Print / Save as PDF</span>
              </button>
              <button
                type="button"
                onClick={() =>
                  handleDownloadInvoiceDocument(
                    previewInvoice.invoice,
                    previewInvoice.items
                  )
                }
                className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-medium bg-slate-800 hover:bg-slate-700 text-slate-200 border border-slate-700 transition cursor-pointer"
              >
                <Download className="w-3.5 h-3.5" />
                <span className="hidden sm:inline">Download HTML</span>
              </button>
              <button
                type="button"
                onClick={() => setPreviewInvoice(null)}
                className="p-1.5 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800 transition cursor-pointer"
                title="Close Preview"
              >
                <X className="w-5 h-5" />
              </button>
            </div>
          </div>

          {/* Printable A4 Document Sheet */}
          <div
            id="printable-invoice"
            className="max-w-[760px] w-full bg-white text-slate-900 rounded-xl shadow-2xl p-8 sm:p-12 mb-8 border border-slate-200 font-sans"
          >
            {/* Header */}
            <div className="flex items-start justify-between border-b border-slate-200 pb-6 mb-6">
              <div>
                <h1 className="text-3xl font-extrabold tracking-tight text-slate-900">
                  INVOICE
                </h1>
                <div className="text-sm font-bold text-indigo-600 font-mono mt-1">
                  {previewInvoice.invoice.invoice_number}
                </div>
              </div>
              <div className="text-right">
                <span className="inline-block px-3 py-1 rounded text-xs font-bold uppercase tracking-wider bg-emerald-50 text-emerald-700 border border-emerald-300">
                  {previewInvoice.invoice.status}
                </span>
                <p className="text-xs text-slate-500 mt-2">
                  Date: {previewInvoice.invoice.created_at.split('T')[0]}
                </p>
              </div>
            </div>

            {/* Address Columns */}
            <div className="grid grid-cols-2 gap-8 mb-8">
              <div>
                <div className="text-[10px] font-bold text-slate-400 uppercase tracking-wider mb-1">
                  Billed From
                </div>
                <div className="text-sm font-bold text-slate-900">
                  {businessProfile.business_name}
                </div>
                {businessProfile.email && (
                  <div className="text-xs text-slate-600 mt-0.5">
                    {businessProfile.email}
                  </div>
                )}
                {businessProfile.phone && (
                  <div className="text-xs text-slate-500 mt-0.5">
                    {businessProfile.phone}
                  </div>
                )}
                {businessProfile.address && (
                  <div className="text-xs text-slate-500 mt-0.5">
                    {businessProfile.address}
                  </div>
                )}
                {businessProfile.tax_id && (
                  <div className="text-xs font-bold text-slate-600 mt-1 font-mono">
                    Tax ID: {businessProfile.tax_id}
                  </div>
                )}
              </div>
              <div className="text-right">
                <div className="text-[10px] font-bold text-slate-400 uppercase tracking-wider mb-1">
                  Billed To
                </div>
                <div className="text-sm font-bold text-slate-900">
                  {previewInvoice.invoice.client_name}
                </div>
                <div className="text-xs text-slate-500 mt-0.5 font-mono">
                  Client ID: {previewInvoice.invoice.client_id}
                </div>
              </div>
            </div>

            {/* Line Items Table */}
            <div className="border border-slate-200 rounded-lg overflow-hidden mb-6">
              <table className="w-full text-left border-collapse">
                <thead>
                  <tr className="bg-slate-100 text-[10px] font-bold uppercase tracking-wider text-slate-600 border-b border-slate-200">
                    <th className="py-2.5 px-4">Description</th>
                    <th className="py-2.5 px-4 text-center w-16">Qty</th>
                    <th className="py-2.5 px-4 text-right w-28">Unit Price</th>
                    <th className="py-2.5 px-4 text-right w-28">Total</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100 text-xs">
                  {previewInvoice.items.length === 0 ? (
                    <tr>
                      <td colSpan={4} className="py-4 text-center text-slate-400 italic">
                        No line items recorded for this invoice.
                      </td>
                    </tr>
                  ) : (
                    previewInvoice.items.map((item, idx) => (
                      <tr
                        key={item.id}
                        className={idx % 2 === 0 ? 'bg-white' : 'bg-slate-50/60'}
                      >
                        <td className="py-3 px-4 font-medium text-slate-800">
                          {item.description}
                        </td>
                        <td className="py-3 px-4 text-center text-slate-600 font-mono">
                          {item.quantity}
                        </td>
                        <td className="py-3 px-4 text-right text-slate-600 font-mono">
                          {formatCents(item.unit_price_cents)}
                        </td>
                        <td className="py-3 px-4 text-right font-bold text-slate-900 font-mono">
                          {formatCents(item.total_cents)}
                        </td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>

            {/* Bottom Row: Payment Instructions Box & Financial Summary Box */}
            <div className="grid grid-cols-1 md:grid-cols-12 gap-6 mb-8 items-start">
              {/* Payment Instructions & Bank Details */}
              <div className="md:col-span-7 bg-slate-50 border border-slate-200 rounded-lg p-4">
                <div className="text-[10px] font-bold text-slate-600 uppercase tracking-wider mb-1.5 flex items-center gap-1.5">
                  <CreditCard className="w-3.5 h-3.5 text-indigo-600" />
                  <span>Payment Instructions & Bank Remittance</span>
                </div>
                <div className="text-xs text-slate-700 whitespace-pre-line leading-relaxed font-sans">
                  {businessProfile.payment_details || 'Please remit payment within 14 days.'}
                </div>
              </div>

              {/* Financial Totals Breakdown */}
              <div className="md:col-span-5 bg-slate-50 border border-slate-200 rounded-lg p-4 space-y-2 text-xs">
                <div className="flex justify-between text-slate-600">
                  <span>Subtotal:</span>
                  <span className="font-mono text-slate-800">
                    {formatCents(previewInvoice.invoice.subtotal_cents)}
                  </span>
                </div>
                <div className="flex justify-between text-slate-600">
                  <span>Tax:</span>
                  <span className="font-mono text-slate-800">
                    {formatCents(previewInvoice.invoice.tax_cents)}
                  </span>
                </div>
                <div className="border-t border-slate-200 pt-2 flex justify-between font-bold text-sm">
                  <span className="text-slate-900">Grand Total:</span>
                  <span className="font-mono text-indigo-600">
                    {formatCents(previewInvoice.invoice.total_cents)}
                  </span>
                </div>
              </div>
            </div>

            {/* Footer */}
            <div className="border-t border-slate-200 pt-6 text-center text-xs text-slate-400 italic">
              Thank you for your business! Payment due within 14 days.
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
