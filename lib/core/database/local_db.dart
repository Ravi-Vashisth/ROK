import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

/// Inspects `PRAGMA table_info` and adds only genuinely missing columns so real
/// SQLite/disk errors are never masked by silent `catch (_) {}` blocks.
void _ensureColumns(Database db, String table, List<String> columnDefs) {
  final info = db.select('PRAGMA table_info($table);');
  final existingColumns = info
      .map((row) => (row['name'] as String?)?.trim().toLowerCase() ?? '')
      .where((name) => name.isNotEmpty)
      .toSet();

  for (final def in columnDefs) {
    final columnName = def.trim().split(RegExp(r'\s+')).first.toLowerCase();
    if (!existingColumns.contains(columnName)) {
      db.execute('ALTER TABLE $table ADD COLUMN $def;');
      existingColumns.add(columnName);
    }
  }
}

/// Applies schema creation, missing-column migrations, and sync-column backfills
/// on an open [Database] connection.
void initializeLocalSchema(Database db) {
  try {
    db.execute('PRAGMA journal_mode = WAL;');
  } on SqliteException {
    db.execute('PRAGMA journal_mode = DELETE;');
  }

  // Enable foreign keys strictly for referential durability
  db.execute('PRAGMA foreign_keys = ON;');

  // 1. Clients Table
  db.execute('''
    CREATE TABLE IF NOT EXISTS clients (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      email TEXT DEFAULT '',
      phone TEXT DEFAULT '',
      address TEXT DEFAULT '',
      tax_id TEXT DEFAULT '',
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL DEFAULT '',
      deleted_at TEXT DEFAULT NULL
    );
  ''');

  _ensureColumns(db, 'clients', [
    "email TEXT DEFAULT ''",
    "phone TEXT DEFAULT ''",
    "address TEXT DEFAULT ''",
    "tax_id TEXT DEFAULT ''",
    "updated_at TEXT NOT NULL DEFAULT ''",
    "deleted_at TEXT DEFAULT NULL",
  ]);

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
      po_number TEXT DEFAULT '',
      currency_code TEXT DEFAULT '',
      currency_symbol TEXT DEFAULT '',
      currency_decimals INTEGER DEFAULT 2,
      tax_mode TEXT DEFAULT 'standard',
      pst_rate_percentage INTEGER DEFAULT 0,
      tax_exemption_id TEXT DEFAULT '',
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL DEFAULT '',
      deleted_at TEXT DEFAULT NULL,
      FOREIGN KEY (client_id) REFERENCES clients (id) ON DELETE RESTRICT
    );
  ''');

  _ensureColumns(db, 'invoices', [
    "issue_date TEXT NOT NULL DEFAULT ''",
    "due_date TEXT NOT NULL DEFAULT ''",
    "payment_terms TEXT NOT NULL DEFAULT 'Due on Receipt'",
    "terms TEXT DEFAULT ''",
    "notes TEXT DEFAULT ''",
    "discount_type TEXT DEFAULT 'none'",
    "discount_value INTEGER DEFAULT 0",
    "discount_cents INTEGER DEFAULT 0",
    "po_number TEXT DEFAULT ''",
    "currency_code TEXT DEFAULT ''",
    "currency_symbol TEXT DEFAULT ''",
    "currency_decimals INTEGER DEFAULT 2",
    "tax_mode TEXT DEFAULT 'standard'",
    "pst_rate_percentage INTEGER DEFAULT 0",
    "tax_exemption_id TEXT DEFAULT ''",
    "updated_at TEXT NOT NULL DEFAULT ''",
    "deleted_at TEXT DEFAULT NULL",
  ]);

  // 3. Invoice Items Table
  db.execute('''
    CREATE TABLE IF NOT EXISTS invoice_items (
      id TEXT PRIMARY KEY,
      invoice_id TEXT NOT NULL,
      description TEXT NOT NULL,
      sac_hsn TEXT DEFAULT '',
      quantity INTEGER NOT NULL DEFAULT 1,
      unit_price_cents INTEGER NOT NULL,
      tax_rate_percentage INTEGER NOT NULL DEFAULT 0,
      tax_cents INTEGER NOT NULL DEFAULT 0,
      total_cents INTEGER NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL DEFAULT '',
      deleted_at TEXT DEFAULT NULL,
      FOREIGN KEY (invoice_id) REFERENCES invoices (id) ON DELETE CASCADE
    );
  ''');

  _ensureColumns(db, 'invoice_items', [
    "sac_hsn TEXT DEFAULT ''",
    "tax_rate_percentage INTEGER NOT NULL DEFAULT 0",
    "tax_cents INTEGER NOT NULL DEFAULT 0",
    "updated_at TEXT NOT NULL DEFAULT ''",
    "deleted_at TEXT DEFAULT NULL",
  ]);

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
      currency_code TEXT DEFAULT 'USD',
      currency_decimals INTEGER DEFAULT 2,
      default_terms TEXT DEFAULT 'Payment due within agreed terms. Thank you for your business!',
      default_notes TEXT DEFAULT '',
      logo_base64 TEXT DEFAULT '',
      signature_base64 TEXT DEFAULT '',
      signature_label TEXT DEFAULT 'Authorized Signatory',
      invoice_prefix TEXT DEFAULT 'INV-',
      estimate_prefix TEXT DEFAULT 'EST-',
      next_invoice_number INTEGER DEFAULT 1,
      payment_qr_payload TEXT DEFAULT '',
      default_tax_mode TEXT DEFAULT 'standard',
      default_pst_rate_percentage INTEGER DEFAULT 0,
      theme_mode TEXT DEFAULT 'system',
      accent_color INTEGER DEFAULT 4283385573,
      updated_at TEXT NOT NULL DEFAULT '',
      deleted_at TEXT DEFAULT NULL
    );
  ''');

  _ensureColumns(db, 'business_profile', [
    r"currency_symbol TEXT DEFAULT '$'",
    r"currency_code TEXT DEFAULT 'USD'",
    r"currency_decimals INTEGER DEFAULT 2",
    r"default_terms TEXT DEFAULT 'Payment due within agreed terms. Thank you for your business!'",
    r"default_notes TEXT DEFAULT ''",
    r"logo_base64 TEXT DEFAULT ''",
    r"signature_base64 TEXT DEFAULT ''",
    r"signature_label TEXT DEFAULT 'Authorized Signatory'",
    r"invoice_prefix TEXT DEFAULT 'INV-'",
    r"estimate_prefix TEXT DEFAULT 'EST-'",
    r"next_invoice_number INTEGER DEFAULT 1",
    r"payment_qr_payload TEXT DEFAULT ''",
    r"default_tax_mode TEXT DEFAULT 'standard'",
    r"default_pst_rate_percentage INTEGER DEFAULT 0",
    r"theme_mode TEXT DEFAULT 'system'",
    r"accent_color INTEGER DEFAULT 4283385573",
    r"updated_at TEXT NOT NULL DEFAULT ''",
    r"deleted_at TEXT DEFAULT NULL",
  ]);

  // Seed default business profile record
  db.execute(r'''
    INSERT OR IGNORE INTO business_profile (
      id, business_name, email, phone, address, tax_id, payment_details, currency_symbol, currency_code, currency_decimals, default_terms, default_notes, logo_base64, signature_base64, signature_label, invoice_prefix, estimate_prefix, next_invoice_number, payment_qr_payload, default_tax_mode, default_pst_rate_percentage, theme_mode, accent_color, updated_at
    ) VALUES (
      'default',
      'My Freelance Studio',
      'billing@studio.com',
      '+1 (555) 019-2834',
      '100 Tech Plaza, Suite 400, San Francisco, CA 94107',
      'US-EIN-987654321',
      'Bank: Silicon Valley Bank\nAccount: 987654321098\nRouting / SWIFT: SVB12345\nPayPal / UPI: pay@studio.com',
      '$',
      'USD',
      2,
      'Payment due within agreed terms. Thank you for your business!',
      'All work includes 30 days post-delivery support.',
      '',
      '',
      'Authorized Signatory',
      'INV-',
      'EST-',
      1,
      '',
      'standard',
      0,
      'system',
      4283385573,
      strftime('%Y-%m-%dT%H:%M:%SZ', 'now')
    );
  ''');

  // 5. Payments Table
  db.execute('''
    CREATE TABLE IF NOT EXISTS payments (
      id TEXT PRIMARY KEY,
      invoice_id TEXT NOT NULL,
      amount_cents INTEGER NOT NULL,
      amount_received_cents INTEGER NOT NULL DEFAULT 0,
      tds_cents INTEGER NOT NULL DEFAULT 0,
      reference_number TEXT DEFAULT '',
      payment_method TEXT NOT NULL,
      payment_date TEXT NOT NULL,
      notes TEXT DEFAULT '',
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL DEFAULT '',
      deleted_at TEXT DEFAULT NULL,
      FOREIGN KEY (invoice_id) REFERENCES invoices (id) ON DELETE CASCADE
    );
  ''');

  _ensureColumns(db, 'payments', [
    "amount_received_cents INTEGER NOT NULL DEFAULT 0",
    "tds_cents INTEGER NOT NULL DEFAULT 0",
    "reference_number TEXT DEFAULT ''",
    "updated_at TEXT NOT NULL DEFAULT ''",
    "deleted_at TEXT DEFAULT NULL",
  ]);

  // Migration repair: Backfill amount_received_cents for existing payments where amount_received_cents is 0
  db.execute('''
    UPDATE payments
    SET amount_received_cents = amount_cents
    WHERE (amount_received_cents = 0 OR amount_received_cents IS NULL) AND amount_cents > 0;
  ''');

  db.execute('''
    CREATE INDEX IF NOT EXISTS idx_payments_invoice_id ON payments (invoice_id);
  ''');

  // Auto-sync repair: Ensure any invoice marked 'PAID' has a matching RFC-4122 UUIDv4 payment in the ledger
  db.execute('''
    INSERT INTO payments (id, invoice_id, amount_cents, amount_received_cents, tds_cents, reference_number, payment_method, payment_date, notes, created_at, updated_at)
    SELECT
      lower(hex(randomblob(4))) || '-' ||
      lower(hex(randomblob(2))) || '-4' ||
      substr(lower(hex(randomblob(2))), 2, 3) || '-' ||
      substr('89ab', (abs(random()) % 4) + 1, 1) ||
      substr(lower(hex(randomblob(2))), 2, 3) || '-' ||
      lower(hex(randomblob(6))),
      i.id,
      i.total_cents,
      i.total_cents,
      0,
      'AUTO-SETTLE',
      'Settled Ledger',
      COALESCE(NULLIF(i.issue_date, ''), strftime('%Y-%m-%d', 'now')),
      'Initial Settlement Payment',
      COALESCE(NULLIF(i.created_at, ''), strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
      strftime('%Y-%m-%dT%H:%M:%SZ', 'now')
    FROM invoices i
    WHERE i.status = 'PAID'
      AND NOT EXISTS (SELECT 1 FROM payments p WHERE p.invoice_id = i.id);
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
      po_number TEXT DEFAULT '',
      currency_code TEXT DEFAULT '',
      currency_symbol TEXT DEFAULT '',
      currency_decimals INTEGER DEFAULT 2,
      tax_mode TEXT DEFAULT 'standard',
      pst_rate_percentage INTEGER DEFAULT 0,
      tax_exemption_id TEXT DEFAULT '',
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL DEFAULT '',
      deleted_at TEXT DEFAULT NULL,
      FOREIGN KEY (client_id) REFERENCES clients (id) ON DELETE RESTRICT
    );
  ''');

  _ensureColumns(db, 'estimates', [
    "terms TEXT DEFAULT ''",
    "notes TEXT DEFAULT ''",
    "discount_type TEXT DEFAULT 'none'",
    "discount_value INTEGER DEFAULT 0",
    "discount_cents INTEGER DEFAULT 0",
    "po_number TEXT DEFAULT ''",
    "currency_code TEXT DEFAULT ''",
    "currency_symbol TEXT DEFAULT ''",
    "currency_decimals INTEGER DEFAULT 2",
    "tax_mode TEXT DEFAULT 'standard'",
    "pst_rate_percentage INTEGER DEFAULT 0",
    "tax_exemption_id TEXT DEFAULT ''",
    "updated_at TEXT NOT NULL DEFAULT ''",
    "deleted_at TEXT DEFAULT NULL",
  ]);

  // 7. Estimate Items Table
  db.execute('''
    CREATE TABLE IF NOT EXISTS estimate_items (
      id TEXT PRIMARY KEY,
      estimate_id TEXT NOT NULL,
      description TEXT NOT NULL,
      sac_hsn TEXT DEFAULT '',
      quantity INTEGER NOT NULL DEFAULT 1,
      unit_price_cents INTEGER NOT NULL,
      tax_rate_percentage INTEGER NOT NULL DEFAULT 0,
      tax_cents INTEGER NOT NULL DEFAULT 0,
      total_cents INTEGER NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL DEFAULT '',
      deleted_at TEXT DEFAULT NULL,
      FOREIGN KEY (estimate_id) REFERENCES estimates (id) ON DELETE CASCADE
    );
  ''');

  _ensureColumns(db, 'estimate_items', [
    "sac_hsn TEXT DEFAULT ''",
    "tax_rate_percentage INTEGER NOT NULL DEFAULT 0",
    "tax_cents INTEGER NOT NULL DEFAULT 0",
    "updated_at TEXT NOT NULL DEFAULT ''",
    "deleted_at TEXT DEFAULT NULL",
  ]);

  db.execute('''
    CREATE INDEX IF NOT EXISTS idx_estimate_items_estimate_id ON estimate_items (estimate_id);
  ''');

  // 8. Saved Items / Preset Services Table
  db.execute('''
    CREATE TABLE IF NOT EXISTS saved_items (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      sac_hsn TEXT DEFAULT '',
      default_price_cents INTEGER NOT NULL,
      description TEXT DEFAULT '',
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL DEFAULT '',
      deleted_at TEXT DEFAULT NULL
    );
  ''');

  _ensureColumns(db, 'saved_items', [
    "sac_hsn TEXT DEFAULT ''",
    "updated_at TEXT NOT NULL DEFAULT ''",
    "deleted_at TEXT DEFAULT NULL",
  ]);

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
      receipt_base64 TEXT DEFAULT '',
      receipt_name TEXT DEFAULT '',
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL DEFAULT '',
      deleted_at TEXT DEFAULT NULL
    );
  ''');

  _ensureColumns(db, 'expenses', [
    "receipt_base64 TEXT DEFAULT ''",
    "receipt_name TEXT DEFAULT ''",
    "updated_at TEXT NOT NULL DEFAULT ''",
    "deleted_at TEXT DEFAULT NULL",
  ]);

  // Backfill UTC ISO-8601 updated_at timestamps for pre-migration rows across all tables
  const tablesWithCreatedAt = [
    'clients',
    'invoices',
    'invoice_items',
    'payments',
    'estimates',
    'estimate_items',
    'saved_items',
    'expenses',
  ];
  for (final table in tablesWithCreatedAt) {
    db.execute('''
      UPDATE $table
      SET updated_at = CASE
        WHEN created_at IS NOT NULL AND created_at != '' THEN created_at
        ELSE strftime('%Y-%m-%dT%H:%M:%SZ', 'now')
      END
      WHERE updated_at = '' OR updated_at IS NULL;
    ''');
  }
  db.execute('''
    UPDATE business_profile
    SET updated_at = strftime('%Y-%m-%dT%H:%M:%SZ', 'now')
    WHERE updated_at = '' OR updated_at IS NULL;
  ''');
}

/// Opens and configures the local SQLite database file in the application documents directory.
/// Propagates errors cleanly instead of silently falling back to volatile in-memory storage.
Future<Database> openLocalDatabase() async {
  final docsDir = await getApplicationDocumentsDirectory();
  final dbPath = p.join(docsDir.path, 'billing_local.db');
  final Database db = sqlite3.open(dbPath);
  initializeLocalSchema(db);
  return db;
}
