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
  Code2, 
  Calculator,
  RefreshCw,
  HardDrive,
  FolderTree,
  FileCode
} from 'lucide-react';
import {
  parsePriceToCents,
  calculateInvoice,
  formatNextInvoiceNumber,
  formatCents,
} from './billingRules';

interface Client {
  id: string;
  name: string;
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

const MODULAR_FILES: Record<string, string> = {
  'lib/main.dart': `import 'package:flutter/material.dart';
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
}`,

  'lib/app.dart': `import 'package:flutter/material.dart';

import 'features/billing/presentation/billing_dashboard_screen.dart';

class BillingDesktopApp extends StatelessWidget {
  const BillingDesktopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Local Billing',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
      home: const BillingDashboardScreen(),
    );
  }
}`,

  'lib/core/utils/money_utils.dart': `import 'package:intl/intl.dart';

final NumberFormat _currencyFormatter = NumberFormat.currency(symbol: '\\$');

int parsePriceToCents(String input) {
  final cleaned = input.trim().replaceAll(RegExp(r'[^\\d.]'), '');
  if (cleaned.isEmpty) return 0;
  final parts = cleaned.split('.');
  final dollars = int.tryParse(parts[0]) ?? 0;
  int cents = 0;
  if (parts.length > 1) {
    final centsPart = parts[1].padRight(2, '0').substring(0, 2);
    cents = int.tryParse(centsPart) ?? 0;
  }
  return (dollars * 100) + cents;
}

String formatCents(int cents) {
  return _currencyFormatter.format(cents / 100.0);
}

int calculateTaxCents(int subtotalCents, int taxPercentage) {
  final safePercentage = taxPercentage < 0 ? 0 : taxPercentage;
  return (subtotalCents * safePercentage + 50) ~/ 100;
}`,

  'lib/core/utils/id_generator.dart': `import 'dart:math';

String generateUniqueId() {
  final timestamp = DateTime.now().microsecondsSinceEpoch;
  final random = Random().nextInt(999999).toString().padLeft(6, '0');
  return '\$timestamp-\$random';
}`,

  'lib/core/database/local_db.dart': `import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

Future<Database> openLocalDatabase() async {
  final docsDir = await getApplicationDocumentsDirectory();
  final dbPath = p.join(docsDir.path, 'billing_local.db');
  final db = sqlite3.open(dbPath);

  db.execute('PRAGMA foreign_keys = ON;');
  db.execute('PRAGMA journal_mode = WAL;');

  db.execute('''
    CREATE TABLE IF NOT EXISTS clients (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      created_at TEXT NOT NULL
    );
  ''');

  db.execute('''
    CREATE TABLE IF NOT EXISTS invoices (
      id TEXT PRIMARY KEY,
      client_id TEXT NOT NULL,
      invoice_number TEXT NOT NULL UNIQUE,
      subtotal_cents INTEGER NOT NULL,
      tax_cents INTEGER NOT NULL,
      total_cents INTEGER NOT NULL,
      status TEXT NOT NULL,
      created_at TEXT NOT NULL,
      FOREIGN KEY (client_id) REFERENCES clients (id) ON DELETE RESTRICT
    );
  ''');

  return db;
}`,

  'lib/core/database/database_provider.dart': `import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqlite3/sqlite3.dart';

final databaseProvider = Provider<Database>((ref) {
  throw UnimplementedError('Database must be provided at startup');
});`,

  'lib/features/clients/models/client.dart': `import 'package:sqlite3/sqlite3.dart' hide Row;
import 'package:sqlite3/sqlite3.dart' as sql show Row;

class Client {
  final String id;
  final String name;
  final String createdAt;

  const Client({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  factory Client.fromRow(sql.Row row) {
    return Client(
      id: row['id'] as String,
      name: row['name'] as String,
      createdAt: row['created_at'] as String,
    );
  }
}`,

  'lib/features/clients/providers/clients_provider.dart': `import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  void addClient(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final id = generateUniqueId();
    final createdAt = DateTime.now().toUtc().toIso8601String();

    final stmt = _db.prepare('INSERT INTO clients (id, name, created_at) VALUES (?, ?, ?)');
    stmt.execute([id, trimmed, createdAt]);
    stmt.dispose();

    loadClients();
  }
}

final clientsProvider = StateNotifierProvider<ClientsNotifier, List<Client>>((ref) {
  return ClientsNotifier(ref.watch(databaseProvider));
});`,

  'lib/features/invoices/models/invoice_record.dart': `import 'package:sqlite3/sqlite3.dart' hide Row;
import 'package:sqlite3/sqlite3.dart' as sql show Row;

class InvoiceRecord {
  final String id;
  final String clientId;
  final String clientName;
  final String invoiceNumber;
  final int subtotalCents;
  final int taxCents;
  final int totalCents;
  final String status;
  final String createdAt;

  const InvoiceRecord({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.invoiceNumber,
    required this.subtotalCents,
    required this.taxCents,
    required this.totalCents,
    required this.status,
    required this.createdAt,
  });

  factory InvoiceRecord.fromRow(sql.Row row) {
    return InvoiceRecord(
      id: row['id'] as String,
      clientId: row['client_id'] as String,
      clientName: (row['client_name'] as String?) ?? 'Unknown Client',
      invoiceNumber: row['invoice_number'] as String,
      subtotalCents: row['subtotal_cents'] as int,
      taxCents: row['tax_cents'] as int,
      totalCents: row['total_cents'] as int,
      status: row['status'] as String,
      createdAt: row['created_at'] as String,
    );
  }
}`,

  'lib/features/invoices/providers/invoices_provider.dart': `import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/utils/id_generator.dart';
import '../models/invoice_record.dart';

class InvoicesNotifier extends StateNotifier<List<InvoiceRecord>> {
  final Database _db;

  InvoicesNotifier(this._db) : super([]) {
    loadInvoices();
  }

  void loadInvoices() {
    final ResultSet results = _db.select('''
      SELECT 
        i.id,
        i.client_id,
        c.name AS client_name,
        i.invoice_number,
        i.subtotal_cents,
        i.tax_cents,
        i.total_cents,
        i.status,
        i.created_at
      FROM invoices i
      LEFT JOIN clients c ON i.client_id = c.id
      ORDER BY i.created_at DESC
    ''');

    state = results.map((row) => InvoiceRecord.fromRow(row)).toList();
  }

  String getNextInvoiceNumber() {
    final result = _db.select('SELECT COUNT(*) AS total FROM invoices');
    final count = (result.first['total'] as int?) ?? 0;
    final nextNumber = count + 1;
    return 'INV-\${nextNumber.toString().padLeft(4, '0')}';
  }

  void saveInvoice({
    required String clientId,
    required int subtotalCents,
    required int taxCents,
    required int totalCents,
  }) {
    final id = generateUniqueId();
    final invoiceNumber = getNextInvoiceNumber();
    final createdAt = DateTime.now().toUtc().toIso8601String();
    const status = 'PAID';

    final stmt = _db.prepare('''
      INSERT INTO invoices (
        id, client_id, invoice_number, subtotal_cents, tax_cents, total_cents, status, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ''');

    stmt.execute([
      id,
      clientId,
      invoiceNumber,
      subtotalCents,
      taxCents,
      totalCents,
      status,
      createdAt,
    ]);
    stmt.dispose();

    loadInvoices();
  }
}

final invoicesProvider = StateNotifierProvider<InvoicesNotifier, List<InvoiceRecord>>((ref) {
  return InvoicesNotifier(ref.watch(databaseProvider));
});`,

  'lib/features/billing/presentation/widgets/client_selection_card.dart': `import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../clients/providers/clients_provider.dart';

class ClientSelectionCard extends ConsumerWidget {
  final TextEditingController newClientController;
  final String? selectedClientId;
  final ValueChanged<String?> onClientSelected;
  final VoidCallback onAddClient;

  const ClientSelectionCard({
    super.key,
    required this.newClientController,
    required this.selectedClientId,
    required this.onClientSelected,
    required this.onAddClient,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clients = ref.watch(clientsProvider);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '1. Client Selection',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: newClientController,
                    decoration: const InputDecoration(
                      labelText: 'New Client Name',
                      hintText: 'e.g. Acme Corp',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: onAddClient,
                  child: const Text('Add Client'),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 4,
                  child: DropdownButtonFormField<String>(
                    value: selectedClientId,
                    decoration: const InputDecoration(
                      labelText: 'Select Saved Client',
                    ),
                    items: clients.map((c) {
                      return DropdownMenuItem<String>(
                        value: c.id,
                        child: Text(c.name),
                      );
                    }).toList(),
                    onChanged: onClientSelected,
                    hint: const Text('Choose a client'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}`,

  'lib/features/billing/presentation/widgets/invoice_inputs_card.dart': `import 'package:flutter/material.dart';

import '../../../../core/utils/money_utils.dart';

class InvoiceInputsCard extends StatelessWidget {
  final TextEditingController descriptionController;
  final TextEditingController priceController;
  final TextEditingController quantityController;
  final TextEditingController taxPercentageController;
  final VoidCallback onSaveInvoice;
  final VoidCallback onValuesChanged;
  final String nextInvoiceNumber;

  const InvoiceInputsCard({
    super.key,
    required this.descriptionController,
    required this.priceController,
    required this.quantityController,
    required this.taxPercentageController,
    required this.onSaveInvoice,
    required this.onValuesChanged,
    required this.nextInvoiceNumber,
  });

  @override
  Widget build(BuildContext context) {
    final priceCents = parsePriceToCents(priceController.text);
    final quantity = int.tryParse(quantityController.text.trim()) ?? 1;
    final taxPercentage = int.tryParse(taxPercentageController.text.trim()) ?? 0;

    final subtotalCents = priceCents * (quantity > 0 ? quantity : 1);
    final taxCents = calculateTaxCents(subtotalCents, taxPercentage);
    final totalCents = subtotalCents + taxCents;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '2. Invoice Inputs',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  'Next: \$nextInvoiceNumber',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 4,
                  child: TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Item Description',
                      hintText: 'e.g. Software Consultation',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Price (\\$)',
                      hintText: '15.50',
                    ),
                    onChanged: (_) => onValuesChanged(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      hintText: '1',
                    ),
                    onChanged: (_) => onValuesChanged(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: taxPercentageController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Tax %',
                      hintText: '10',
                    ),
                    onChanged: (_) => onValuesChanged(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Calculated Total: \${formatCents(totalCents)} '
                  '(Subtotal: \${formatCents(subtotalCents)}, Tax: \${formatCents(taxCents)})',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                FilledButton.icon(
                  onPressed: onSaveInvoice,
                  icon: const Icon(Icons.save),
                  label: const Text('Save Invoice Locally'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}`,

  'lib/features/billing/presentation/widgets/offline_invoices_list.dart': `import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/money_utils.dart';
import '../../../invoices/providers/invoices_provider.dart';

class OfflineInvoicesList extends ConsumerWidget {
  const OfflineInvoicesList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoices = ref.watch(invoicesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Offline Invoices (\${invoices.length})',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        if (invoices.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text(
                'No invoices saved in local SQLite yet.\\nCreate your first client and invoice above.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: invoices.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final inv = invoices[index];
                return ListTile(
                  leading: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      inv.invoiceNumber,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  title: Text(
                    inv.clientName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Subtotal: \${formatCents(inv.subtotalCents)} | Tax: \${formatCents(inv.taxCents)} | Status: \${inv.status}',
                  ),
                  trailing: Text(
                    formatCents(inv.totalCents),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}`,

  'lib/features/billing/presentation/billing_dashboard_screen.dart': `import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money_utils.dart';
import '../../clients/providers/clients_provider.dart';
import '../../invoices/providers/invoices_provider.dart';
import 'widgets/client_selection_card.dart';
import 'widgets/invoice_inputs_card.dart';
import 'widgets/offline_invoices_list.dart';

class BillingDashboardScreen extends ConsumerStatefulWidget {
  const BillingDashboardScreen({super.key});

  @override
  ConsumerState<BillingDashboardScreen> createState() => _BillingDashboardScreenState();
}

class _BillingDashboardScreenState extends ConsumerState<BillingDashboardScreen> {
  final _newClientController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _taxPercentageController = TextEditingController(text: '10');

  String? _selectedClientId;

  @override
  void dispose() {
    _newClientController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _taxPercentageController.dispose();
    super.dispose();
  }

  void _handleAddClient() {
    final name = _newClientController.text.trim();
    if (name.isEmpty) return;

    ref.read(clientsProvider.notifier).addClient(name);
    _newClientController.clear();

    final clients = ref.read(clientsProvider);
    final found = clients.where((c) => c.name == name);
    if (found.isNotEmpty) {
      setState(() {
        _selectedClientId = found.first.id;
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Client "\$name" added locally to SQLite.')),
    );
  }

  void _handleSaveInvoice() {
    if (_selectedClientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or add a client first.')),
      );
      return;
    }

    final priceCents = parsePriceToCents(_priceController.text);
    if (priceCents <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid price.')),
      );
      return;
    }

    final quantity = int.tryParse(_quantityController.text.trim()) ?? 1;
    if (quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quantity must be at least 1.')),
      );
      return;
    }

    final taxPercentage = int.tryParse(_taxPercentageController.text.trim()) ?? 0;
    final subtotalCents = priceCents * quantity;
    final taxCents = calculateTaxCents(subtotalCents, taxPercentage);
    final totalCents = subtotalCents + taxCents;

    ref.read(invoicesProvider.notifier).saveInvoice(
          clientId: _selectedClientId!,
          subtotalCents: subtotalCents,
          taxCents: taxCents,
          totalCents: totalCents,
        );

    _descriptionController.clear();
    _priceController.clear();
    _quantityController.text = '1';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Invoice saved locally! Total: \${formatCents(totalCents)}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nextInvoiceNumber = ref.watch(invoicesProvider.notifier).getNextInvoiceNumber();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Local Billing (Offline Desktop Skeleton)'),
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClientSelectionCard(
              newClientController: _newClientController,
              selectedClientId: _selectedClientId,
              onClientSelected: (val) => setState(() => _selectedClientId = val),
              onAddClient: _handleAddClient,
            ),
            const SizedBox(height: 20),
            InvoiceInputsCard(
              descriptionController: _descriptionController,
              priceController: _priceController,
              quantityController: _quantityController,
              taxPercentageController: _taxPercentageController,
              onSaveInvoice: _handleSaveInvoice,
              onValuesChanged: () => setState(() {}),
              nextInvoiceNumber: nextInvoiceNumber,
            ),
            const SizedBox(height: 24),
            const OfflineInvoicesList(),
          ],
        ),
      ),
    );
  }
}`,

  'pubspec.yaml': `name: billing_app
description: Minimal 100% offline foundational walking-skeleton for desktop billing.
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.6.1
  sqlite3: ^2.4.6
  sqlite3_flutter_libs: ^0.5.24
  path_provider: ^2.1.4
  path: ^1.9.0
  intl: ^0.19.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0

flutter:
  uses-material-design: true`,

  '.github/workflows/build.yml': `name: Build Desktop & Mobile Apps

on:
  push:
    branches: [ main, master ]
  workflow_dispatch: # Allows you to manually click "Run workflow"

jobs:
  build-windows:
    name: Build Windows Release (.exe)
    runs-on: windows-latest

    steps:
      - name: Checkout Code
        uses: actions/checkout@v5

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: 'stable'
          cache: true

      - name: Enable Windows Desktop Support
        run: flutter config --enable-windows-desktop

      - name: Generate Windows Scaffolding
        run: flutter create --platforms=windows .

      - name: Install Dependencies
        run: flutter pub get

      - name: Build Windows Executable
        run: flutter build windows --release

      - name: Package Windows Release as Zip
        run: |
          Compress-Archive -Path build\\windows\\x64\\runner\\Release\\* -DestinationPath billing_app_windows.zip

      - name: Upload Windows Executable Artifact
        uses: actions/upload-artifact@v5
        with:
          name: billing-app-windows-x64
          path: billing_app_windows.zip
          retention-days: 7

  build-android:
    name: Build Android Release (.apk)
    runs-on: ubuntu-24.04

    steps:
      - name: Checkout Code
        uses: actions/checkout@v5

      - name: Setup Java
        uses: actions/setup-java@v5
        with:
          distribution: 'temurin'
          java-version: '17'

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: 'stable'
          cache: true

      - name: Generate Android Scaffolding
        run: flutter create --platforms=android .

      - name: Install Dependencies
        run: flutter pub get

      - name: Build Android APK
        run: flutter build apk --release

      - name: Upload Android APK Artifact
        uses: actions/upload-artifact@v5
        with:
          name: billing-app-android
          path: build/app/outputs/flutter-apk/app-release.apk
          retention-days: 7`
};

export default function App() {
  const [activeTab, setActiveTab] = useState<'app' | 'flutter_code' | 'schema'>('app');
  const [selectedFile, setSelectedFile] = useState<string>('lib/main.dart');

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
        subtotal_cents: 15500, // $155.00
        tax_cents: 1550,       // $15.50
        total_cents: 17050,    // $170.50
        status: 'PAID',
        created_at: '2026-10-26T12:00:00Z',
      },
    ];
  });

  // Form Inputs
  const [newClientName, setNewClientName] = useState('');
  const [selectedClientId, setSelectedClientId] = useState<string>('1714000000000-101');
  const [itemDescription, setItemDescription] = useState('Quarterly Software License');
  const [priceInput, setPriceInput] = useState('15.50');
  const [quantityInput, setQuantityInput] = useState('10');
  const [taxPctInput, setTaxPctInput] = useState('10');

  // Feedback states
  const [copiedKey, setCopiedKey] = useState<string | null>(null);
  const [toastMessage, setToastMessage] = useState<string | null>(null);

  // Persist to local storage
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

  // Financial Calculations for current input
  const priceCents = parsePriceToCents(priceInput);
  const qty = parseInt(quantityInput, 10) || 1;
  const taxPct = parseInt(taxPctInput, 10) || 0;
  const calculation = calculateInvoice(priceCents, qty, taxPct);

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

  // Save Invoice
  const handleSaveInvoice = (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedClientId) {
      alert('Please select or create a client first.');
      return;
    }
    if (priceCents <= 0) {
      alert('Please enter a valid price.');
      return;
    }

    const client = clients.find((c) => c.id === selectedClientId);
    const nextInvoiceNumber = formatNextInvoiceNumber(invoices.length);
    const newId = `${Date.now()}-${Math.floor(Math.random() * 900000 + 100000)}`;

    const newInvoice: InvoiceRecord = {
      id: newId,
      client_id: selectedClientId,
      client_name: client ? client.name : 'Unknown Client',
      invoice_number: nextInvoiceNumber,
      subtotal_cents: calculation.subtotalCents,
      tax_cents: calculation.taxCents,
      total_cents: calculation.totalCents,
      status: 'PAID',
      created_at: new Date().toISOString(),
    };

    setInvoices((prev) => [newInvoice, ...prev]);
    showToast(`Invoice ${nextInvoiceNumber} saved! Total: ${formatCents(calculation.totalCents)}`);
    setItemDescription('');
    setPriceInput('');
    setQuantityInput('1');
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
                  Modular Refactored
                </span>
              </div>
              <p className="text-xs text-slate-400">
                PONYTAIL / YAGNI • Strict 64-bit integer cents • Modular clean architecture
              </p>
            </div>
          </div>

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
      </header>

      {/* Main Body */}
      <main className="flex-1 max-w-7xl mx-auto w-full px-4 sm:px-6 py-6">
        {activeTab === 'app' && (
          <div className="space-y-6">
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

            {/* 2. Invoice Inputs Card */}
            <div className="bg-slate-950 border border-slate-800 rounded-xl p-5 shadow-sm">
              <div className="flex items-center justify-between mb-4 pb-3 border-b border-slate-800/80">
                <div className="flex items-center gap-2">
                  <FileText className="w-4 h-4 text-indigo-400" />
                  <h2 className="text-sm font-bold text-slate-100 uppercase tracking-wider">2. Invoice Inputs</h2>
                </div>
                <div className="text-xs text-indigo-400 font-mono">
                  Next Invoice #: <span className="font-bold">{formatNextInvoiceNumber(invoices.length)}</span>
                </div>
              </div>

              <form onSubmit={handleSaveInvoice} className="space-y-4">
                <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-12 gap-4">
                  <div className="lg:col-span-5">
                    <label htmlFor="item-desc" className="block text-xs font-medium text-slate-400 mb-1.5">
                      Item Description
                    </label>
                    <input
                      id="item-desc"
                      type="text"
                      value={itemDescription}
                      onChange={(e) => setItemDescription(e.target.value)}
                      placeholder="e.g. Consultation & Strategy"
                      className="w-full bg-slate-900 border border-slate-700/80 rounded-lg px-3 py-2 text-sm text-slate-100 placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-indigo-500"
                    />
                  </div>

                  <div className="lg:col-span-3">
                    <label htmlFor="item-price" className="block text-xs font-medium text-slate-400 mb-1.5">
                      Price ($)
                    </label>
                    <div className="relative">
                      <span className="absolute left-3 top-2 text-slate-500 text-sm">$</span>
                      <input
                        id="item-price"
                        type="text"
                        value={priceInput}
                        onChange={(e) => setPriceInput(e.target.value)}
                        placeholder="15.50"
                        className="w-full bg-slate-900 border border-slate-700/80 rounded-lg pl-7 pr-3 py-2 text-sm text-slate-100 placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-indigo-500"
                      />
                    </div>
                    <span className="text-[11px] text-slate-500 mt-1 block">
                      Parsed: {priceCents} integer cents
                    </span>
                  </div>

                  <div className="lg:col-span-2">
                    <label htmlFor="item-qty" className="block text-xs font-medium text-slate-400 mb-1.5">
                      Quantity
                    </label>
                    <input
                      id="item-qty"
                      type="number"
                      min="1"
                      value={quantityInput}
                      onChange={(e) => setQuantityInput(e.target.value)}
                      className="w-full bg-slate-900 border border-slate-700/80 rounded-lg px-3 py-2 text-sm text-slate-100 focus:outline-none focus:ring-2 focus:ring-indigo-500"
                    />
                  </div>

                  <div className="lg:col-span-2">
                    <label htmlFor="item-tax" className="block text-xs font-medium text-slate-400 mb-1.5">
                      Tax %
                    </label>
                    <div className="relative">
                      <input
                        id="item-tax"
                        type="number"
                        min="0"
                        max="100"
                        value={taxPctInput}
                        onChange={(e) => setTaxPctInput(e.target.value)}
                        className="w-full bg-slate-900 border border-slate-700/80 rounded-lg pr-7 pl-3 py-2 text-sm text-slate-100 focus:outline-none focus:ring-2 focus:ring-indigo-500"
                      />
                      <span className="absolute right-3 top-2 text-slate-500 text-sm">%</span>
                    </div>
                  </div>
                </div>

                <div className="bg-slate-900 border border-slate-800 rounded-lg p-4 flex flex-col md:flex-row md:items-center justify-between gap-4 mt-2">
                  <div className="flex items-center gap-4 text-xs sm:text-sm">
                    <div className="flex items-center gap-1.5 text-slate-400">
                      <Calculator className="w-4 h-4 text-indigo-400" />
                      <span>Subtotal:</span>
                      <strong className="text-slate-200">{formatCents(calculation.subtotalCents)}</strong>
                    </div>
                    <span className="text-slate-600">+</span>
                    <div className="text-slate-400">
                      <span>Tax:</span>{' '}
                      <strong className="text-slate-200">{formatCents(calculation.taxCents)}</strong>
                    </div>
                    <span className="text-slate-600">=</span>
                    <div className="text-indigo-400 text-base font-bold">
                      <span>Total: {formatCents(calculation.totalCents)}</span>
                    </div>
                  </div>

                  <button
                    type="submit"
                    className="inline-flex items-center justify-center gap-2 bg-indigo-600 hover:bg-indigo-500 text-white font-medium px-5 py-2.5 rounded-lg text-sm transition shadow-sm cursor-pointer"
                  >
                    <Save className="w-4 h-4" />
                    Save Invoice Locally
                  </button>
                </div>
              </form>
            </div>

            {/* 3. Offline Invoices List */}
            <div className="bg-slate-950 border border-slate-800 rounded-xl p-5 shadow-sm">
              <div className="flex items-center justify-between mb-4 pb-3 border-b border-slate-800/80">
                <div className="flex items-center gap-2">
                  <HardDrive className="w-4 h-4 text-emerald-400" />
                  <h2 className="text-sm font-bold text-slate-100 uppercase tracking-wider">
                    Offline Invoices ({invoices.length})
                  </h2>
                </div>
                <div className="text-xs text-slate-400">
                  Total Value:{' '}
                  <span className="font-bold text-emerald-400">
                    {formatCents(invoices.reduce((acc, inv) => acc + inv.total_cents, 0))}
                  </span>
                </div>
              </div>

              {invoices.length === 0 ? (
                <div className="text-center py-12 border border-dashed border-slate-800 rounded-lg text-slate-500 text-sm">
                  No invoices saved in local SQLite yet. Add a client and click &quot;Save Invoice Locally&quot; above.
                </div>
              ) : (
                <div className="overflow-x-auto">
                  <table className="w-full text-left text-sm">
                    <thead>
                      <tr className="border-b border-slate-800 text-slate-400 text-xs uppercase tracking-wider">
                        <th className="pb-3 font-semibold">Invoice #</th>
                        <th className="pb-3 font-semibold">Client Name</th>
                        <th className="pb-3 font-semibold text-right">Subtotal</th>
                        <th className="pb-3 font-semibold text-right">Tax</th>
                        <th className="pb-3 font-semibold text-right">Total (Formatted)</th>
                        <th className="pb-3 font-semibold text-center">Status</th>
                        <th className="pb-3 font-semibold text-right">Created</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-slate-800/60">
                      {invoices.map((inv) => (
                        <tr key={inv.id} className="hover:bg-slate-900/50 transition">
                          <td className="py-3 font-mono font-bold text-indigo-400 text-xs">
                            <span className="bg-indigo-500/10 px-2 py-0.5 rounded border border-indigo-500/20">
                              {inv.invoice_number}
                            </span>
                          </td>
                          <td className="py-3 font-medium text-slate-200">{inv.client_name}</td>
                          <td className="py-3 text-right font-mono text-slate-400">{formatCents(inv.subtotal_cents)}</td>
                          <td className="py-3 text-right font-mono text-slate-400">{formatCents(inv.tax_cents)}</td>
                          <td className="py-3 text-right font-mono font-bold text-emerald-400">
                            {formatCents(inv.total_cents)}
                          </td>
                          <td className="py-3 text-center">
                            <span className="px-2 py-0.5 rounded text-[11px] font-semibold bg-emerald-500/10 text-emerald-400 border border-emerald-500/30">
                              {inv.status}
                            </span>
                          </td>
                          <td className="py-3 text-right text-xs text-slate-500 font-mono">
                            {new Date(inv.created_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
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
                    Modular Flutter Architecture
                  </h2>
                  <p className="text-xs text-slate-400 mt-0.5">
                    12 single-responsibility files refactored cleanly under <code className="text-indigo-300">lib/</code> with zero unnecessary abstractions.
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
                    Workspace Files
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
                      {MODULAR_FILES[selectedFile].split('\n').length} lines
                    </span>
                  </div>
                  <div className="bg-slate-950 border-x border-b border-slate-800 rounded-b-lg p-4 font-mono text-xs overflow-x-auto text-slate-200 max-h-[540px] leading-relaxed">
                    <pre>{MODULAR_FILES[selectedFile]}</pre>
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
                    File: <code className="text-indigo-300">billing_local.db</code> located in <code className="text-indigo-300">getApplicationDocumentsDirectory()</code>
                  </p>
                </div>
                <button
                  onClick={() => {
                    localStorage.removeItem('sqlite_clients');
                    localStorage.removeItem('sqlite_invoices');
                    setClients([]);
                    setInvoices([]);
                    showToast('Local database cleared!');
                  }}
                  className="inline-flex items-center gap-1.5 text-xs text-rose-400 hover:text-rose-300 bg-rose-500/10 hover:bg-rose-500/20 border border-rose-500/30 px-3 py-1.5 rounded-lg cursor-pointer transition"
                >
                  <RefreshCw className="w-3.5 h-3.5" />
                  Reset / Clear DB
                </button>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mt-5">
                <div className="bg-slate-900 border border-slate-800 rounded-lg p-4">
                  <h3 className="text-sm font-bold text-indigo-400 font-mono mb-2">TABLE clients</h3>
                  <div className="bg-slate-950 p-3 rounded font-mono text-xs text-slate-300 overflow-x-auto">
                    <pre>{`CREATE TABLE IF NOT EXISTS clients (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  created_at TEXT NOT NULL
);`}</pre>
                  </div>
                  <div className="mt-3 text-xs text-slate-400">
                    Stores client master records with ISO8601 timestamps.
                  </div>
                </div>

                <div className="bg-slate-900 border border-slate-800 rounded-lg p-4">
                  <h3 className="text-sm font-bold text-indigo-400 font-mono mb-2">TABLE invoices</h3>
                  <div className="bg-slate-950 p-3 rounded font-mono text-xs text-slate-300 overflow-x-auto">
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
                  <div className="mt-3 text-xs text-slate-400">
                    All monetary amounts are strictly 64-bit integers in minor units (cents).
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}
      </main>
    </div>
  );
}
