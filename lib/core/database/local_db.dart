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
    "email TEXT DEFAULT ''",
    "phone TEXT DEFAULT ''",
    "address TEXT DEFAULT ''",
    "tax_id TEXT DEFAULT ''",
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
      terms TEXT DEFAULT '',
      notes TEXT DEFAULT '',
      discount_type TEXT DEFAULT 'none',
      discount_value INTEGER DEFAULT 0,
      discount_cents INTEGER DEFAULT 0,
      created_at TEXT NOT NULL,
      FOREIGN KEY (client_id) REFERENCES clients (id) ON DELETE RESTRICT
    );
  ''');

  for (final col in [
    "issue_date TEXT NOT NULL DEFAULT ''",
    "due_date TEXT NOT NULL DEFAULT ''",
    "payment_terms TEXT NOT NULL DEFAULT 'Due on Receipt'",
    "terms TEXT DEFAULT ''",
    "notes TEXT DEFAULT ''",
    "discount_type TEXT DEFAULT 'none'",
    "discount_value INTEGER DEFAULT 0",
    "discount_cents INTEGER DEFAULT 0",
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
      tax_rate_percentage INTEGER NOT NULL DEFAULT 0,
      tax_cents INTEGER NOT NULL DEFAULT 0,
      total_cents INTEGER NOT NULL,
      created_at TEXT NOT NULL,
      FOREIGN KEY (invoice_id) REFERENCES invoices (id) ON DELETE CASCADE
    );
  ''');

  for (final col in [
    "tax_rate_percentage INTEGER NOT NULL DEFAULT 0",
    "tax_cents INTEGER NOT NULL DEFAULT 0",
  ]) {
    try {
      db.execute('ALTER TABLE invoice_items ADD COLUMN $col;');
    } catch (_) {}
  }

  // 4. Business Profile & Payment Details Table
  db.execute(r'''
    CREATE TABLE IF NOT EXISTS business_profile (
      id TEXT PRIMARY KEY DEFAULT 'default',
      business_name TEXT NOT NULL DEFAULT 'My Studio',
      email TEXT DEFAULT '',
      phone TEXT DEFAULT '',
      address TEXT DEFAULT '',
      tax_id TEXT DEFAULT '',
      payment_details TEXT DEFAULT '',
      currency_symbol TEXT DEFAULT '$',
      default_terms TEXT DEFAULT 'Payment due within agreed terms. Thank you for your business!',
      default_notes TEXT DEFAULT '',
      logo_base64 TEXT DEFAULT '',
      signature_base64 TEXT DEFAULT '',
      signature_label TEXT DEFAULT 'Authorized Signatory',
      invoice_prefix TEXT DEFAULT 'INV-',
      estimate_prefix TEXT DEFAULT 'EST-',
      next_invoice_number INTEGER DEFAULT 1,
      payment_qr_payload TEXT DEFAULT ''
    );
  ''');

  for (final col in [
    r"currency_symbol TEXT DEFAULT '$'",
    r"default_terms TEXT DEFAULT 'Payment due within agreed terms. Thank you for your business!'",
    r"default_notes TEXT DEFAULT ''",
    r"logo_base64 TEXT DEFAULT ''",
    r"signature_base64 TEXT DEFAULT ''",
    r"signature_label TEXT DEFAULT 'Authorized Signatory'",
    r"invoice_prefix TEXT DEFAULT 'INV-'",
    r"estimate_prefix TEXT DEFAULT 'EST-'",
    r"next_invoice_number INTEGER DEFAULT 1",
    r"payment_qr_payload TEXT DEFAULT ''",
  ]) {
    try {
      db.execute('ALTER TABLE business_profile ADD COLUMN $col;');
    } catch (_) {}
  }

  // Seed default business profile record
  db.execute(r'''
    INSERT OR IGNORE INTO business_profile (
      id, business_name, email, phone, address, tax_id, payment_details, currency_symbol, default_terms, default_notes, logo_base64, signature_base64, signature_label, invoice_prefix, estimate_prefix, next_invoice_number, payment_qr_payload
    ) VALUES (
      'default',
      'My Freelance Studio',
      'billing@studio.com',
      '+1 (555) 019-2834',
      '100 Tech Plaza, Suite 400, San Francisco, CA 94107',
      'US-EIN-987654321',
      'Bank: Silicon Valley Bank\nAccount: 987654321098\nRouting / SWIFT: SVB12345\nPayPal / UPI: pay@studio.com',
      '$',
      'Payment due within agreed terms. Thank you for your business!',
      'All work includes 30 days post-delivery support.',
      '',
      '',
      'Authorized Signatory',
      'INV-',
      'EST-',
      1,
      ''
    );
  ''');

  // 5. Payments Table
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

  // 6. Estimates / Quotes Table
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
      terms TEXT DEFAULT '',
      notes TEXT DEFAULT '',
      discount_type TEXT DEFAULT 'none',
      discount_value INTEGER DEFAULT 0,
      discount_cents INTEGER DEFAULT 0,
      created_at TEXT NOT NULL,
      FOREIGN KEY (client_id) REFERENCES clients (id) ON DELETE RESTRICT
    );
  ''');

  for (final col in [
    "terms TEXT DEFAULT ''",
    "notes TEXT DEFAULT ''",
    "discount_type TEXT DEFAULT 'none'",
    "discount_value INTEGER DEFAULT 0",
    "discount_cents INTEGER DEFAULT 0",
  ]) {
    try {
      db.execute('ALTER TABLE estimates ADD COLUMN $col;');
    } catch (_) {}
  }

  // 7. Estimate Items Table
  db.execute('''
    CREATE TABLE IF NOT EXISTS estimate_items (
      id TEXT PRIMARY KEY,
      estimate_id TEXT NOT NULL,
      description TEXT NOT NULL,
      quantity INTEGER NOT NULL DEFAULT 1,
      unit_price_cents INTEGER NOT NULL,
      tax_rate_percentage INTEGER NOT NULL DEFAULT 0,
      tax_cents INTEGER NOT NULL DEFAULT 0,
      total_cents INTEGER NOT NULL,
      created_at TEXT NOT NULL,
      FOREIGN KEY (estimate_id) REFERENCES estimates (id) ON DELETE CASCADE
    );
  ''');

  for (final col in [
    "tax_rate_percentage INTEGER NOT NULL DEFAULT 0",
    "tax_cents INTEGER NOT NULL DEFAULT 0",
  ]) {
    try {
      db.execute('ALTER TABLE estimate_items ADD COLUMN $col;');
    } catch (_) {}
  }

  db.execute('''
    CREATE INDEX IF NOT EXISTS idx_estimate_items_estimate_id ON estimate_items (estimate_id);
  ''');

  // 8. Saved Items / Preset Services Table
  db.execute('''
    CREATE TABLE IF NOT EXISTS saved_items (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      default_price_cents INTEGER NOT NULL,
      description TEXT DEFAULT '',
      created_at TEXT NOT NULL
    );
  ''');

  // 9. Expenses Table
  db.execute('''
    CREATE TABLE IF NOT EXISTS expenses (
      id TEXT PRIMARY KEY,
      category TEXT NOT NULL,
      vendor TEXT NOT NULL,
      amount_cents INTEGER NOT NULL,
      tax_cents INTEGER DEFAULT 0,
      expense_date TEXT NOT NULL,
      notes TEXT DEFAULT '',
      created_at TEXT NOT NULL
    );
  ''');

  return db;
}
