import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:billing_app/core/theme/app_theme.dart';
import 'package:billing_app/features/clients/models/client.dart';
import 'package:billing_app/features/expenses/models/expense_record.dart';
import 'package:billing_app/features/invoices/models/invoice_record.dart';
import 'package:billing_app/core/utils/export_file_helper.dart';
import 'package:billing_app/core/utils/money_utils.dart';

class CsvExportService {
  static String formatDecimal(int units, [int decimals = 2]) => formatDecimalUnits(units, decimals);

  /// Neutralizes spreadsheet formula-injection prefixes (`=`, `+`, `-`, `@`, `\t`, `\r`)
  /// before quoting CSV text cells so Excel, Google Sheets, and LibreOffice treat values as literals.
  static String sanitizeCsvCell(String text) {
    if (text.isEmpty) return text;
    final first = text[0];
    final trimmedLeft = text.trimLeft();
    if (first == '=' ||
        first == '+' ||
        first == '-' ||
        first == '@' ||
        first == '\t' ||
        first == '\r' ||
        (trimmedLeft.isNotEmpty &&
            (trimmedLeft[0] == '=' ||
                trimmedLeft[0] == '+' ||
                trimmedLeft[0] == '-' ||
                trimmedLeft[0] == '@'))) {
      return "'$text";
    }
    return text;
  }

  static String quote(String text) {
    final safe = sanitizeCsvCell(text);
    return '"${safe.replaceAll('"', '""')}"';
  }

  /// Generates 1 uniform single-table CSV for Invoices (Row 1 = headers, Rows 2..N = records)
  static String generateInvoicesCsv({
    required List<InvoiceRecord> invoices,
    required List<Client> clients,
    String currencyCode = 'USD',
  }) {
    final buffer = StringBuffer();
    // UTF-8 BOM so Excel opens with crisp UTF-8 encoding
    buffer.write('\uFEFF');

    // Row 1: Headers
    buffer.writeln('Invoice Number,Issue Date,Due Date,Currency Code,Client Name,Client Tax ID,Subtotal,Tax,Total,Amount Paid,Balance Due,Status');

    final fallbackCode = currencyCode.trim().isNotEmpty ? currencyCode.trim() : 'USD';

    // Rows 2..N: Data (Finalized/issued invoices only - drafts excluded)
    for (final inv in invoices) {
      if (inv.isDraft || inv.status.toUpperCase() == 'DRAFT') continue;

      final isVoid = inv.isVoid || inv.status.toUpperCase() == 'VOID';
      final paid = inv.paidCents;
      final total = inv.totalCents;
      final due = isVoid ? 0 : ((total - paid) > 0 ? (total - paid) : 0);
      final status = isVoid ? 'VOID' : inv.computedStatus;
      final isoCode = inv.currencyCode.trim().isNotEmpty ? inv.currencyCode.trim() : fallbackCode;
      final dec = inv.currencyCode.trim().isNotEmpty ? inv.currencyDecimals : getCurrencyDecimals(isoCode);

      final client = clients.firstWhere(
        (c) => c.id == inv.clientId,
        orElse: () => const Client(id: '', name: '', email: '', phone: '', address: '', taxId: '', createdAt: ''),
      );

      buffer.writeln([
        quote(inv.invoiceNumber),
        quote(inv.issueDate),
        quote(inv.dueDate),
        quote(isoCode),
        quote(inv.clientName),
        quote(client.taxId),
        formatDecimal(inv.subtotalCents, dec),
        formatDecimal(inv.taxCents, dec),
        formatDecimal(inv.totalCents, dec),
        formatDecimal(paid, dec),
        formatDecimal(due, dec),
        quote(status),
      ].join(','));
    }

    return buffer.toString();
  }

  /// Generates 1 uniform single-table CSV for Expenses (Row 1 = headers, Rows 2..N = records)
  static String generateExpensesCsv({
    required List<ExpenseRecord> expenses,
    String currencyCode = 'USD',
  }) {
    final buffer = StringBuffer();
    // UTF-8 BOM
    buffer.write('\uFEFF');

    // Row 1: Headers
    buffer.writeln('Expense ID,Date,Category,Vendor,Currency Code,Amount,Tax,Total,Notes');

    final fallbackCode = currencyCode.trim().isNotEmpty ? currencyCode.trim().toUpperCase() : 'USD';
    final fallbackDec = getCurrencyDecimals(fallbackCode);

    // Rows 2..N: Data
    for (final exp in expenses) {
      final resolved = resolveEffectiveCurrency(
        recordCode: exp.currencyCode,
        recordDecimals: exp.currencyCode.trim().isNotEmpty ? exp.currencyDecimals : null,
        defaultCode: fallbackCode,
        defaultDecimals: fallbackDec,
      );
      buffer.writeln([
        quote(exp.id),
        quote(exp.expenseDate),
        quote(exp.category),
        quote(exp.vendor),
        quote(resolved.code),
        formatDecimal(exp.amountCents, resolved.decimals),
        formatDecimal(exp.taxCents, resolved.decimals),
        formatDecimal(exp.totalCents, resolved.decimals),
        quote(exp.notes),
      ].join(','));
    }

    return buffer.toString();
  }

  static Uint8List _encodeInvoicesCsvBytes(
    List<InvoiceRecord> invoices,
    List<Client> clients,
    String currencyCode,
  ) {
    final csvContent = generateInvoicesCsv(
      invoices: invoices,
      clients: clients,
      currencyCode: currencyCode,
    );
    return Uint8List.fromList(utf8.encode(csvContent));
  }

  static Uint8List _encodeExpensesCsvBytes(
    List<ExpenseRecord> expenses,
    String currencyCode,
  ) {
    final csvContent = generateExpensesCsv(
      expenses: expenses,
      currencyCode: currencyCode,
    );
    return Uint8List.fromList(utf8.encode(csvContent));
  }

  static Future<ExportSaveResult?> downloadInvoicesCsvWithDetails({
    required List<InvoiceRecord> invoices,
    required List<Client> clients,
    String currencyCode = 'USD',
  }) async {
    final invSnapshot = List<InvoiceRecord>.unmodifiable(invoices);
    final clientSnapshot = List<Client>.unmodifiable(clients);
    final bytes = await Isolate.run(
      () => _encodeInvoicesCsvBytes(invSnapshot, clientSnapshot, currencyCode),
    );
    return ExportFileHelper.saveExportFileWithDetails(
      bytes: bytes,
      filename: 'invoices_export.csv',
      extension: 'csv',
      dialogTitle: 'Save Invoices CSV',
    );
  }

  static Future<String?> downloadInvoicesCsv({
    required List<InvoiceRecord> invoices,
    required List<Client> clients,
    String currencyCode = 'USD',
  }) async {
    final res = await downloadInvoicesCsvWithDetails(
      invoices: invoices,
      clients: clients,
      currencyCode: currencyCode,
    );
    return res?.path;
  }

  static Future<ExportSaveResult?> downloadExpensesCsvWithDetails({
    required List<ExpenseRecord> expenses,
    String currencyCode = 'USD',
  }) async {
    final expSnapshot = List<ExpenseRecord>.unmodifiable(expenses);
    final bytes = await Isolate.run(
      () => _encodeExpensesCsvBytes(expSnapshot, currencyCode),
    );
    return ExportFileHelper.saveExportFileWithDetails(
      bytes: bytes,
      filename: 'expenses_export.csv',
      extension: 'csv',
      dialogTitle: 'Save Expenses CSV',
    );
  }

  static Future<String?> downloadExpensesCsv({
    required List<ExpenseRecord> expenses,
    String currencyCode = 'USD',
  }) async {
    final res = await downloadExpensesCsvWithDetails(
      expenses: expenses,
      currencyCode: currencyCode,
    );
    return res?.path;
  }

  /// Displays the Export Accounting Data modal allowing single-table CSV selection
  static void showExportModal({
    required BuildContext context,
    required List<InvoiceRecord> invoices,
    required List<ExpenseRecord> expenses,
    required List<Client> clients,
    required String currencyCode,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (dialogCtx) {
        final theme = Theme.of(dialogCtx);
        final colorScheme = theme.colorScheme;
        final warningTone = AppSemanticColors.resolve(theme.brightness, SemanticStatus.warning);
        final secondaryTextColor = theme.textTheme.bodySmall?.color ?? colorScheme.onSurfaceVariant;
        return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        insetPadding: EdgeInsets.all(MediaQuery.sizeOf(dialogCtx).width < 600 ? 12 : 24),
        title: Row(
          children: [
            Icon(Icons.file_download_outlined, color: colorScheme.primary),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Export Accounting Data',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 440,
            maxHeight: MediaQuery.sizeOf(dialogCtx).height * 0.72,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select a single-table CSV dataset compliant with Excel, QuickBooks, and accounting software:',
                  style: TextStyle(fontSize: 13, color: secondaryTextColor),
                ),
                const SizedBox(height: 16),
                ListTile(
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: theme.dividerColor),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: CircleAvatar(
                    backgroundColor: colorScheme.primaryContainer,
                    child: Icon(Icons.receipt_long, color: colorScheme.primary, size: 20),
                  ),
                  title: const Text('Invoices CSV', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${invoices.where((i) => !i.isDraft && i.status.toUpperCase() != "DRAFT").length} finalized invoices • headers on row 1 (invoices_export.csv)', style: const TextStyle(fontSize: 11)),
                  trailing: const Icon(Icons.download, size: 18),
                  onTap: () async {
                    Navigator.of(dialogCtx).pop();
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Generating Invoices CSV...'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                    try {
                      final saved = await downloadInvoicesCsvWithDetails(
                        invoices: invoices,
                        clients: clients,
                        currencyCode: currencyCode,
                      );
                      messenger.hideCurrentSnackBar();
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            saved == null
                                ? 'CSV export cancelled.'
                                : (saved.usedFallbackDirectory
                                    ? 'OS file picker unavailable — Invoices CSV saved to app exports folder: ${saved.path}'
                                    : 'Invoices CSV saved: ${saved.path}'),
                          ),
                        ),
                      );
                    } catch (e) {
                      messenger.hideCurrentSnackBar();
                      messenger.showSnackBar(
                        SnackBar(content: Text('Failed to export Invoices CSV: $e')),
                      );
                    }
                  },
                ),
                const SizedBox(height: 10),
                ListTile(
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: Theme.of(dialogCtx).dividerColor),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: CircleAvatar(
                    backgroundColor: warningTone.background,
                    child: Icon(Icons.account_balance_wallet, color: warningTone.icon, size: 20),
                  ),
                  title: const Text('Expenses CSV', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${expenses.length} expenses • headers on row 1 (expenses_export.csv)', style: const TextStyle(fontSize: 11)),
                  trailing: const Icon(Icons.download, size: 18),
                  onTap: () async {
                    Navigator.of(dialogCtx).pop();
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Generating Expenses CSV...'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                    try {
                      final saved = await downloadExpensesCsvWithDetails(
                        expenses: expenses,
                        currencyCode: currencyCode,
                      );
                      messenger.hideCurrentSnackBar();
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            saved == null
                                ? 'CSV export cancelled.'
                                : (saved.usedFallbackDirectory
                                    ? 'OS file picker unavailable — Expenses CSV saved to app exports folder: ${saved.path}'
                                    : 'Expenses CSV saved: ${saved.path}'),
                          ),
                        ),
                      );
                    } catch (e) {
                      messenger.hideCurrentSnackBar();
                      messenger.showSnackBar(
                        SnackBar(content: Text('Failed to export Expenses CSV: $e')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
        ],
      );
      },
    );
  }
}
