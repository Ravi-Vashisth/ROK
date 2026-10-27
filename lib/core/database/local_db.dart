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

  // 3. Invoice Items Table (Multi-Line Items / Cart)
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
      payment_details TEXT DEFAULT ''
    );
  ''');

  // Seed default business profile record if not already present
  db.execute('''
    INSERT OR IGNORE INTO business_profile (
      id, business_name, email, phone, address, tax_id, payment_details
    ) VALUES (
      'default',
      'My Freelance Studio',
      'billing@studio.com',
      '+1 (555) 019-2834',
      '100 Tech Plaza, Suite 400, San Francisco, CA 94107',
      'US-EIN-987654321',
      'Bank: Silicon Valley Bank\\nAccount: 987654321098\\nRouting / SWIFT: SVB12345\\nPayPal / UPI: pay@studio.com'
    );
  ''');

  return db;
}
