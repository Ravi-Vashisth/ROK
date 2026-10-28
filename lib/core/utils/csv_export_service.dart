import 'dart:convert';
import 'package:printing/printing.dart';
import '../../features/clients/models/client.dart';
import '../../features/expenses/models/expense_record.dart';
import '../../features/invoices/models/invoice_record.dart';

class CsvExportService {
  static String formatDecimal(int cents) => (cents / 100).toStringAsFixed(2);
  static String quote(String text) => '"${text.replaceAll('"', '""')}"';

  static String generateComprehensiveReportCsv({
    required List<InvoiceRecord> invoices,
    required List<ExpenseRecord> expenses,
    required List<Client> clients,
    String currencyCode = 'USD',
  }) {
    final buffer = StringBuffer();
    // UTF-8 BOM
    buffer.write('\uFEFF');

    // SECTION 1: INVOICES
    buffer.writeln('=== SECTION 1: INVOICES ===');
    buffer.writeln('Invoice Number,Issue Date,Due Date,Currency,Client Name,Client Tax ID,Subtotal,Tax,Total,Amount Paid,Balance Due,Status');
    for (final inv in invoices) {
      final paid = inv.paidCents;
      final total = inv.totalCents;
      final due = total - paid;
      
      // Dynamic status calculation
      String status;
      if (due <= 0) status = 'PAID';
      else if (paid > 0) status = 'PARTIALLY_PAID';
      else if (DateTime.now().isAfter(DateTime.parse(inv.dueDate))) status = 'OVERDUE';
      else status = 'PENDING';

      buffer.writeln([
        inv.invoiceNumber,
        inv.issueDate,
        inv.dueDate,
        currencyCode,
        quote(inv.clientName),
        quote(clients.firstWhere((c) => c.id == inv.clientId, orElse: () => Client(id: '', name: '', email: '', phone: '', address: '', taxId: '', createdAt: '')).taxId),
        formatDecimal(inv.subtotalCents),
        formatDecimal(inv.taxCents),
        formatDecimal(inv.totalCents),
        formatDecimal(paid),
        formatDecimal(due),
        status,
      ].join(','));
    }

    buffer.writeln(',,,,,,,,,,,');

    // SECTION 2: EXPENSES
    buffer.writeln('=== SECTION 2: EXPENSES ===');
    buffer.writeln('Date,Category,Vendor,Currency,Expense Amount,Tax,Total Cost,Notes,,,,');
    for (final exp in expenses) {
      buffer.writeln([
        exp.expenseDate,
        quote(exp.category),
        quote(exp.vendor),
        currencyCode,
        formatDecimal(exp.amountCents),
        formatDecimal(exp.taxCents),
        formatDecimal(exp.totalCents),
        quote(exp.notes),
        '', '', '', '',
      ].join(','));
    }

    buffer.writeln(',,,,,,,,,,,');

    // SECTION 3: FINANCIAL SUMMARY
    final totalInvoiced = invoices.fold<int>(0, (sum, i) => sum + i.totalCents);
    final totalCollected = invoices.fold<int>(0, (sum, i) => sum + i.paidCents);
    final totalExpenses = expenses.fold<int>(0, (sum, e) => sum + e.totalCents);
    final netProfit = totalCollected - totalExpenses;

    buffer.writeln('=== SECTION 3: FINANCIAL SUMMARY ===');
    buffer.writeln('Metric,Amount,Currency,,,,,,,,,,');
    buffer.writeln('Total Invoiced Revenue,${formatDecimal(totalInvoiced)},$currencyCode,,,,,,,,,');
    buffer.writeln('Total Collected Revenue,${formatDecimal(totalCollected)},$currencyCode,,,,,,,,,');
    buffer.writeln('Total Business Expenses,${formatDecimal(totalExpenses)},$currencyCode,,,,,,,,,');
    buffer.writeln('Net Profit (Collected - Expenses),${formatDecimal(netProfit)},$currencyCode,,,,,,,,,');

    return buffer.toString();
  }

  static Future<void> downloadCsvFile({
    required List<InvoiceRecord> invoices,
    required List<ExpenseRecord> expenses,
    required List<Client> clients,
    String currencySymbol = 'USD',
  }) async {
    final csvContent = generateComprehensiveReportCsv(
      invoices: invoices,
      expenses: expenses,
      clients: clients,
      currencyCode: currencySymbol,
    );
    final bytes = utf8.encode(csvContent);
    await Printing.sharePdf(bytes: bytes, filename: 'financial_report.csv');
  }
}
