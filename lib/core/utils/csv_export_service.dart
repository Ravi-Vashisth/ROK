import 'dart:convert';
import 'package:printing/printing.dart';
import '../../features/clients/models/client.dart';
import '../../features/expenses/models/expense_record.dart';
import '../../features/invoices/models/invoice_record.dart';
import 'money_utils.dart';

class CsvExportService {
  static String generateComprehensiveReportCsv({
    required List<InvoiceRecord> invoices,
    required List<ExpenseRecord> expenses,
    required List<Client> clients,
    String currencySymbol = '\$',
  }) {
    final clientTaxMap = {for (var c in clients) c.id: c.taxId};
    final buffer = StringBuffer();

    // SECTION 1: INVOICES
    buffer.writeln('=== SECTION 1: INVOICES ===');
    buffer.writeln('Invoice Number,Issue Date,Due Date,Client Name,Client Tax ID,Subtotal,Tax,Total,Amount Paid,Balance Due,Status');
    for (final inv in invoices) {
      final clientTaxId = clientTaxMap[inv.clientId] ?? '';
      buffer.writeln([
        inv.invoiceNumber,
        inv.issueDate,
        inv.dueDate,
        '"${inv.clientName.replaceAll('"', '""')}"',
        clientTaxId,
        formatCents(inv.subtotalCents, symbol: currencySymbol),
        formatCents(inv.taxCents, symbol: currencySymbol),
        formatCents(inv.totalCents, symbol: currencySymbol),
        formatCents(inv.paidCents, symbol: currencySymbol),
        formatCents(inv.balanceDueCents, symbol: currencySymbol),
        inv.computedStatus,
      ].join(','));
    }

    buffer.writeln();

    // SECTION 2: EXPENSES
    buffer.writeln('=== SECTION 2: EXPENSES ===');
    buffer.writeln('Date,Category,Vendor,Amount,Tax,Total,Notes');
    for (final exp in expenses) {
      buffer.writeln([
        exp.expenseDate,
        '"${exp.category.replaceAll('"', '""')}"',
        '"${exp.vendor.replaceAll('"', '""')}"',
        formatCents(exp.amountCents, symbol: currencySymbol),
        formatCents(exp.taxCents, symbol: currencySymbol),
        formatCents(exp.totalCents, symbol: currencySymbol),
        '"${exp.notes.replaceAll('"', '""')}"',
      ].join(','));
    }

    buffer.writeln();

    // SECTION 3: FINANCIAL SUMMARY
    final totalRevenue = invoices.fold<int>(0, (sum, i) => sum + i.totalCents);
    final totalCollected = invoices.fold<int>(0, (sum, i) => sum + i.paidCents);
    final totalTaxCollected = invoices.fold<int>(0, (sum, i) => sum + i.taxCents);
    final totalExpenses = expenses.fold<int>(0, (sum, e) => sum + e.totalCents);
    final netProfit = totalCollected - totalExpenses;

    buffer.writeln('=== SECTION 3: FINANCIAL SUMMARY ===');
    buffer.writeln('Metric,Amount');
    buffer.writeln('Total Invoiced Revenue,${formatCents(totalRevenue, symbol: currencySymbol)}');
    buffer.writeln('Total Collected Revenue,${formatCents(totalCollected, symbol: currencySymbol)}');
    buffer.writeln('Total Tax Collected,${formatCents(totalTaxCollected, symbol: currencySymbol)}');
    buffer.writeln('Total Business Expenses,${formatCents(totalExpenses, symbol: currencySymbol)}');
    buffer.writeln('Net Profit (Collected - Expenses),${formatCents(netProfit, symbol: currencySymbol)}');

    return buffer.toString();
  }

  static Future<void> downloadCsvFile({
    required List<InvoiceRecord> invoices,
    required List<ExpenseRecord> expenses,
    required List<Client> clients,
    String currencySymbol = '\$',
  }) async {
    final csvContent = generateComprehensiveReportCsv(
      invoices: invoices,
      expenses: expenses,
      clients: clients,
      currencySymbol: currencySymbol,
    );
    final bytes = utf8.encode(csvContent);
    await Printing.sharePdf(bytes: bytes, filename: 'financial_report.csv');
  }

  // Backward compatibility wrapper
  static String generateInvoicesCsv({
    required List<InvoiceRecord> invoices,
    required List<Client> clients,
    String currencySymbol = '\$',
  }) {
    return generateComprehensiveReportCsv(
      invoices: invoices,
      expenses: [],
      clients: clients,
      currencySymbol: currencySymbol,
    );
  }
}
