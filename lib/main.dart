import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

// =============================================================================
// DOMAIN MODELS & FINANCIAL HELPERS (Strict Integer Cents)
// =============================================================================

class Client {
  final String id;
  final String name;
  final String createdAt;

  const Client({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  factory Client.fromRow(Row row) {
    return Client(
      id: row['id'] as String,
      name: row['name'] as String,
      createdAt: row['created_at'] as String,
    );
  }
}

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

  factory InvoiceRecord.fromRow(Row row) {
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
}

/// Parses price input (e.g. "15.50") directly into integer cents without float imprecision.
int parsePriceToCents(String input) {
  final cleaned = input.trim().replaceAll(RegExp(r'[^\d.]'), '');
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

/// Formats integer cents strictly at the UI display layer using NumberFormat.currency.
final NumberFormat _currencyFormatter = NumberFormat.currency(symbol: '\$');

String formatCents(int cents) {
  return _currencyFormatter.format(cents / 100.0);
}

/// Pure Dart unique ID generator using timestamp and entropy.
String _generateId() {
  final timestamp = DateTime.now().microsecondsSinceEpoch;
  final random = Random().nextInt(999999).toString().padLeft(6, '0');
  return '$timestamp-$random';
}

// =============================================================================
// DATABASE INITIALIZATION & MIGRATIONS
// =============================================================================

Future<Database> openLocalDatabase() async {
  final docsDir = await getApplicationDocumentsDirectory();
  final dbPath = p.join(docsDir.path, 'billing_local.db');
  final db = sqlite3.open(dbPath);

  db.execute('PRAGMA foreign_keys = ON;');
  db.execute('PRAGMA journal_mode = WAL;');

  // 1. Clients Table
  db.execute('''
    CREATE TABLE IF NOT EXISTS clients (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      created_at TEXT NOT NULL
    );
  ''');

  // 2. Invoices Table
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
}

// =============================================================================
// RIVERPOD STATE MANAGEMENT
// =============================================================================

final databaseProvider = Provider<Database>((ref) {
  throw UnimplementedError('Database must be provided at startup');
});

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

    final id = _generateId();
    final createdAt = DateTime.now().toUtc().toIso8601String();

    final stmt = _db.prepare('INSERT INTO clients (id, name, created_at) VALUES (?, ?, ?)');
    stmt.execute([id, trimmed, createdAt]);
    stmt.dispose();

    loadClients();
  }
}

final clientsProvider = StateNotifierProvider<ClientsNotifier, List<Client>>((ref) {
  return ClientsNotifier(ref.watch(databaseProvider));
});

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
    return 'INV-${nextNumber.toString().padLeft(4, '0')}';
  }

  void saveInvoice({
    required String clientId,
    required int subtotalCents,
    required int taxCents,
    required int totalCents,
  }) {
    final id = _generateId();
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
});

// =============================================================================
// MAIN ENTRY POINT
// =============================================================================

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
}

// =============================================================================
// SCREEN: BILLING DASHBOARD
// =============================================================================

class BillingDashboardScreen extends ConsumerStatefulWidget {
  const BillingDashboardScreen({super.key});

  @override
  ConsumerState<BillingDashboardScreen> createState() => _BillingDashboardScreenState();
}

class _BillingDashboardScreenState extends ConsumerState<BillingDashboardScreen> {
  // Form Controllers
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

    // Auto-select the newly added client if only 1 client or select the matching one
    final clients = ref.read(clientsProvider);
    final found = clients.where((c) => c.name == name);
    if (found.isNotEmpty) {
      setState(() {
        _selectedClientId = found.first.id;
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Client "$name" added locally to SQLite.')),
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

    // Strict integer calculations as mandated:
    // Subtotal = price_cents * quantity
    // Tax = (subtotal * tax_percentage + 50) ~/ 100 (integer round-half-up)
    // Total = subtotal + tax
    final subtotalCents = priceCents * quantity;
    final taxCents = (subtotalCents * taxPercentage + 50) ~/ 100;
    final totalCents = subtotalCents + taxCents;

    ref.read(invoicesProvider.notifier).saveInvoice(
          clientId: _selectedClientId!,
          subtotalCents: subtotalCents,
          taxCents: taxCents,
          totalCents: totalCents,
        );

    // Reset fields for the next invoice entry
    _descriptionController.clear();
    _priceController.clear();
    _quantityController.text = '1';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Invoice saved locally! Total: ${formatCents(totalCents)}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clients = ref.watch(clientsProvider);
    final invoices = ref.watch(invoicesProvider);

    // Live preview calculations for transparency
    final livePriceCents = parsePriceToCents(_priceController.text);
    final liveQuantity = int.tryParse(_quantityController.text.trim()) ?? 1;
    final liveTaxPercentage = int.tryParse(_taxPercentageController.text.trim()) ?? 0;
    final liveSubtotal = livePriceCents * (liveQuantity > 0 ? liveQuantity : 1);
    final liveTax = (liveSubtotal * (liveTaxPercentage >= 0 ? liveTaxPercentage : 0) + 50) ~/ 100;
    final liveTotal = liveSubtotal + liveTax;

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
            // Section 1: Client Management
            Card(
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
                            controller: _newClientController,
                            decoration: const InputDecoration(
                              labelText: 'New Client Name',
                              hintText: 'e.g. Acme Corp',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonal(
                          onPressed: _handleAddClient,
                          child: const Text('Add Client'),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 4,
                          child: DropdownButtonFormField<String>(
                            value: _selectedClientId,
                            decoration: const InputDecoration(
                              labelText: 'Select Saved Client',
                            ),
                            items: clients.map((c) {
                              return DropdownMenuItem<String>(
                                value: c.id,
                                child: Text(c.name),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedClientId = val;
                              });
                            },
                            hint: const Text('Choose a client'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Section 2: Invoice Creation
            Card(
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
                      '2. Invoice Inputs',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: TextField(
                            controller: _descriptionController,
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
                            controller: _priceController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Price (\$)',
                              hintText: '15.50',
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _quantityController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Quantity',
                              hintText: '1',
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _taxPercentageController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Tax %',
                              hintText: '10',
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Calculated Total: ${formatCents(liveTotal)} '
                          '(Subtotal: ${formatCents(liveSubtotal)}, Tax: ${formatCents(liveTax)})',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: _handleSaveInvoice,
                          icon: const Icon(Icons.save),
                          label: const Text('Save Invoice Locally'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Section 3: Offline Invoices List
            Text(
              'Offline Invoices (${invoices.length})',
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
                    'No invoices saved in local SQLite yet.\nCreate your first client and invoice above.',
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
                        'Subtotal: ${formatCents(inv.subtotalCents)} | Tax: ${formatCents(inv.taxCents)} | Status: ${inv.status}',
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
        ),
      ),
    );
  }
}
