import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

/// Opens and configures the local SQLite database file in the application documents directory.
Future<Database> openLocalDatabase() async {
  final docsDir = await getApplicationDocumentsDirectory();
  final dbPath = p.join(docsDir.path, 'billing_local.db');
  final db = sqlite3.open(dbPath);

  // Enable WAL mode and foreign keys for durability and cascading deletions
  db.execute('PRAGMA foreign_keys = ON;');
  db.execute('PRAGMA journal_mode = WAL;');

  // 1. Clients Table
  db.execute('''
    CREATE TABLE IF NOT EXISTS clients (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      email TEXT DEFAULT '',
      phone TEXT DEFAULT '',
      address TEXT DEFAULT '',
      tax_id TEXT DEFAULT '',
      created_at TEXT NOT NULL
    );
  ''');

  for (final col in [
    'email TEXT DEFAULT \'\'',
    'phone TEXT DEFAULT \'\'',
    'address TEXT DEFAULT \'\'',
    'tax_id TEXT DEFAULT \'\'',
  ]) {
    try {
      db.execute('ALTER TABLE clients ADD COLUMN $col;');
    } catch (_) {}
  }

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
      issue_date TEXT NOT NULL DEFAULT '',
      due_date TEXT NOT NULL DEFAULT '',
      payment_terms TEXT NOT NULL DEFAULT 'Due on Receipt',
      created_at TEXT NOT NULL,
      FOREIGN KEY (client_id) REFERENCES clients (id) ON DELETE RESTRICT
    );
  ''');

  for (final col in [
    'issue_date TEXT NOT NULL DEFAULT \'\'',
    'due_date TEXT NOT NULL DEFAULT \'\'',
    'payment_terms TEXT NOT NULL DEFAULT \'Due on Receipt\'',
  ]) {
    try {
      db.execute('ALTER TABLE invoices ADD COLUMN $col;');
    } catch (_) {}
  }

  // 3. Invoice Items Table
  db.execute('''
    CREATE TABLE IF NOT EXISTS invoice_items (
      id TEXT PRIMARY KEY,
      invoice_id TEXT NOT NULL,
      description TEXT NOT NULL,
      quantity INTEGER NOT NULL DEFAULT 1,
      unit_price_cents INTEGER NOT NULL,
      total_cents INTEGER NOT NULL,
      created_at TEXT NOT NULL,
      FOREIGN KEY (invoice_id) REFERENCES invoices (id) ON DELETE CASCADE
    );
  ''');

  // 4. Business Profile & Payment Details Table
  db.execute('''
    CREATE TABLE IF NOT EXISTS business_profile (
      id TEXT PRIMARY KEY DEFAULT 'default',
      business_name TEXT NOT NULL DEFAULT 'My Studio',
      email TEXT DEFAULT '',
      phone TEXT DEFAULT '',
      address TEXT DEFAULT '',
      tax_id TEXT DEFAULT '',
      payment_details TEXT DEFAULT '',
      currency_symbol TEXT DEFAULT '\$'
    );
  ''');

  try {
    db.execute('ALTER TABLE business_profile ADD COLUMN currency_symbol TEXT DEFAULT \'$\';');
  } catch (_) {}

  // Seed default business profile record
  db.execute('''
    INSERT OR IGNORE INTO business_profile (
      id, business_name, email, phone, address, tax_id, payment_details, currency_symbol
    ) VALUES (
      'default',
      'My Freelance Studio',
      'billing@studio.com',
      '+1 (555) 019-2834',
      '100 Tech Plaza, Suite 400, San Francisco, CA 94107',
      'US-EIN-987654321',
      'Bank: Silicon Valley Bank\\nAccount: 987654321098\\nRouting / SWIFT: SVB12345\\nPayPal / UPI: pay@studio.com',
      '\$'
    );
  ''');

  // 5. Payments Table (Sprint 3: Partial Payments & Deposit Tracking)
  db.execute('''
    CREATE TABLE IF NOT EXISTS payments (
      id TEXT PRIMARY KEY,
      invoice_id TEXT NOT NULL,
      amount_cents INTEGER NOT NULL,
      payment_method TEXT NOT NULL,
      payment_date TEXT NOT NULL,
      notes TEXT DEFAULT '',
      created_at TEXT NOT NULL,
      FOREIGN KEY (invoice_id) REFERENCES invoices (id) ON DELETE CASCADE
    );
  ''');

  db.execute('''
    CREATE INDEX IF NOT EXISTS idx_payments_invoice_id ON payments (invoice_id);
  ''');

  // 6. Estimates / Quotes Table (Sprint 4)
  db.execute('''
    CREATE TABLE IF NOT EXISTS estimates (
      id TEXT PRIMARY KEY,
      client_id TEXT NOT NULL,
      estimate_number TEXT NOT NULL UNIQUE,
      subtotal_cents INTEGER NOT NULL,
      tax_cents INTEGER NOT NULL,
      total_cents INTEGER NOT NULL,
      status TEXT NOT NULL DEFAULT 'PENDING',
      issue_date TEXT NOT NULL,
      expiry_date TEXT NOT NULL,
      converted_invoice_id TEXT DEFAULT '',
      created_at TEXT NOT NULL,
      FOREIGN KEY (client_id) REFERENCES clients (id) ON DELETE RESTRICT
    );
  ''');

  // 7. Estimate Items Table (Sprint 4)
  db.execute('''
    CREATE TABLE IF NOT EXISTS estimate_items (
      id TEXT PRIMARY KEY,
      estimate_id TEXT NOT NULL,
      description TEXT NOT NULL,
      quantity INTEGER NOT NULL DEFAULT 1,
      unit_price_cents INTEGER NOT NULL,
      total_cents INTEGER NOT NULL,
      created_at TEXT NOT NULL,
      FOREIGN KEY (estimate_id) REFERENCES estimates (id) ON DELETE CASCADE
    );
  ''');

  db.execute('''
    CREATE INDEX IF NOT EXISTS idx_estimate_items_estimate_id ON estimate_items (estimate_id);
  ''');

  return db;
}
