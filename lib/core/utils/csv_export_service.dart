import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../features/clients/models/client.dart';
import '../../features/expenses/models/expense_record.dart';
import '../../features/invoices/models/invoice_record.dart';

class CsvExportService {
  static String formatDecimal(int cents) => (cents / 100).toStringAsFixed(2);
  static String quote(String text) => '"${text.replaceAll('"', '""')}"';

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

    // Rows 2..N: Data
    for (final inv in invoices) {
      final paid = inv.paidCents;
      final total = inv.totalCents;
      final due = total - paid;

      String status;
      if (due <= 0) {
        status = 'PAID';
      } else if (paid > 0) {
        status = 'PARTIALLY_PAID';
      } else if (DateTime.now().isAfter(DateTime.parse(inv.dueDate))) {
        status = 'OVERDUE';
      } else {
        status = 'PENDING';
      }

      final client = clients.firstWhere(
        (c) => c.id == inv.clientId,
        orElse: () => const Client(id: '', name: '', email: '', phone: '', address: '', taxId: '', createdAt: ''),
      );

      buffer.writeln([
        quote(inv.invoiceNumber),
        quote(inv.issueDate),
        quote(inv.dueDate),
        quote(currencyCode),
        quote(inv.clientName),
        quote(client.taxId),
        formatDecimal(inv.subtotalCents),
        formatDecimal(inv.taxCents),
        formatDecimal(inv.totalCents),
        formatDecimal(paid),
        formatDecimal(due),
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

    // Rows 2..N: Data
    for (final exp in expenses) {
      buffer.writeln([
        quote(exp.id),
        quote(exp.expenseDate),
        quote(exp.category),
        quote(exp.vendor),
        quote(currencyCode),
        formatDecimal(exp.amountCents),
        formatDecimal(exp.taxCents),
        formatDecimal(exp.totalCents),
        quote(exp.notes),
      ].join(','));
    }

    return buffer.toString();
  }

  static Future<void> downloadInvoicesCsv({
    required List<InvoiceRecord> invoices,
    required List<Client> clients,
    String currencySymbol = 'USD',
  }) async {
    final csvContent = generateInvoicesCsv(
      invoices: invoices,
      clients: clients,
      currencyCode: currencySymbol,
    );
    final bytes = utf8.encode(csvContent);
    await Printing.sharePdf(bytes: bytes, filename: 'invoices_export.csv');
  }

  static Future<void> downloadExpensesCsv({
    required List<ExpenseRecord> expenses,
    String currencySymbol = 'USD',
  }) async {
    final csvContent = generateExpensesCsv(
      expenses: expenses,
      currencyCode: currencySymbol,
    );
    final bytes = utf8.encode(csvContent);
    await Printing.sharePdf(bytes: bytes, filename: 'expenses_export.csv');
  }

  /// Displays the Export Accounting Data modal allowing single-table CSV selection
  static void showExportModal({
    required BuildContext context,
    required List<InvoiceRecord> invoices,
    required List<ExpenseRecord> expenses,
    required List<Client> clients,
    required String currencySymbol,
  }) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.file_download_outlined, color: Colors.indigo),
            SizedBox(width: 8),
            Text('Export Accounting Data', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select a single-table CSV dataset compliant with Excel, QuickBooks, and accounting software:',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ListTile(
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(8),
              ),
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFEEF2FF),
                child: Icon(Icons.receipt_long, color: Colors.indigo, size: 20),
              ),
              title: const Text('Invoices CSV', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${invoices.length} invoices • headers on row 1 (invoices_export.csv)', style: const TextStyle(fontSize: 11)),
              trailing: const Icon(Icons.download, size: 18),
              onTap: () async {
                Navigator.of(dialogCtx).pop();
                await downloadInvoicesCsv(
                  invoices: invoices,
                  clients: clients,
                  currencySymbol: currencySymbol,
                );
              },
            ),
            const SizedBox(height: 10),
            ListTile(
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(8),
              ),
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFFEF3C7),
                child: Icon(Icons.account_balance_wallet, color: Colors.amber, size: 20),
              ),
              title: const Text('Expenses CSV', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${expenses.length} expenses • headers on row 1 (expenses_export.csv)', style: const TextStyle(fontSize: 11)),
              trailing: const Icon(Icons.download, size: 18),
              onTap: () async {
                Navigator.of(dialogCtx).pop();
                await downloadExpensesCsv(
                  expenses: expenses,
                  currencySymbol: currencySymbol,
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
