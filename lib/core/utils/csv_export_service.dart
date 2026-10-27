import '../../features/clients/models/client.dart';
import '../../features/invoices/models/invoice_record.dart';
import 'money_utils.dart';

class CsvExportService {
  static String generateInvoicesCsv({
    required List<InvoiceRecord> invoices,
    required List<Client> clients,
    String currencySymbol = '\$',
  }) {
    final clientTaxMap = {for (var c in clients) c.id: c.taxId};

    final headers = [
      'Invoice Number',
      'Issue Date',
      'Due Date',
      'Client Name',
      'Client Tax ID',
      'Subtotal',
      'Tax',
      'Total',
      'Amount Paid',
      'Balance Due',
      'Status',
    ];

    final rows = <List<String>>[headers];

    for (final inv in invoices) {
      final clientTaxId = clientTaxMap[inv.clientId] ?? '';
      rows.add([
        inv.invoiceNumber,
        inv.issueDate,
        inv.dueDate,
        inv.clientName,
        clientTaxId,
        formatCents(inv.subtotalCents, symbol: currencySymbol),
        formatCents(inv.taxCents, symbol: currencySymbol),
        formatCents(inv.totalCents, symbol: currencySymbol),
        formatCents(inv.paidCents, symbol: currencySymbol),
        formatCents(inv.balanceDueCents, symbol: currencySymbol),
        inv.computedStatus,
      ]);
    }

    return rows.map((row) {
      return row.map((field) {
        final escaped = field.replaceAll('"', '""');
        if (escaped.contains(',') || escaped.contains('"') || escaped.contains('\n')) {
          return '"$escaped"';
        }
        return escaped;
      }).join(',');
    }).join('\n');
  }
}
