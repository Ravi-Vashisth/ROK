import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../../../core/utils/currency_formatter_provider.dart';
import '../../business_profile/providers/business_profile_provider.dart';
import '../../billing/services/invoice_pdf_service.dart';
import '../../clients/models/client.dart';
import '../../invoices/providers/invoices_provider.dart';

class ClientStatementDialog extends ConsumerWidget {
  final Client client;

  const ClientStatementDialog({
    super.key,
    required this.client,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoices = ref
        .watch(invoicesProvider)
        .where((i) => i.clientId == client.id && !i.isDraft && !i.isVoid)
        .toList();
    final formatCurrency = ref.watch(currencyFormatterProvider);

    int totalInvoiced = 0;
    int totalPaid = 0;
    for (final inv in invoices) {
      if (inv.isVoid || inv.isDraft || inv.status == 'VOID' || inv.status == 'DRAFT') continue;
      totalInvoiced += inv.totalCents;
      totalPaid += inv.paidCents;
    }
    final balanceDue = totalInvoiced - totalPaid;
    final screenSize = MediaQuery.sizeOf(context);
    final isCompactWidth = screenSize.width < 520;

    Future<void> printStatement() async {
      final businessProfile = ref.read(businessProfileProvider);
      await Printing.layoutPdf(
        onLayout: (format) => InvoicePdfService.generateStatementPdf(
          client: client,
          invoices: invoices,
          businessProfile: businessProfile,
        ),
        name: 'Statement_${client.name.replaceAll(RegExp(r'\s+'), '_')}.pdf',
      );
    }

    return Dialog(
      insetPadding: EdgeInsets.all(screenSize.width < 600 ? 12 : 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 750,
            maxHeight: screenSize.height * 0.88,
          ),
          child: Scaffold(
            appBar: AppBar(
              title: Text(
                'Statement of Account: ${client.name}',
                overflow: TextOverflow.ellipsis,
              ),
              automaticallyImplyLeading: false,
              actions: [
                if (isCompactWidth)
                  IconButton(
                    tooltip: 'Print / Save Statement PDF',
                    icon: const Icon(Icons.print),
                    onPressed: printStatement,
                  )
                else
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.print, size: 16),
                    label: const Text('Print / Save Statement PDF'),
                    onPressed: printStatement,
                  ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            body: Padding(
              padding: EdgeInsets.all(isCompactWidth ? 14.0 : 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final clientCol = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(client.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          if (client.email.isNotEmpty) Text('Email: ${client.email}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          if (client.phone.isNotEmpty) Text('Phone: ${client.phone}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          if (client.taxId.isNotEmpty) Text('Tax ID: ${client.taxId}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      );
                      final summaryBox = Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Theme.of(context).dividerColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Total Invoiced: ${formatCurrency(totalInvoiced)}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFeatures: [FontFeature.tabularFigures()]),
                            ),
                            Text(
                              'Total Paid: ${formatCurrency(totalPaid)}',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFeatures: const [FontFeature.tabularFigures()], color: Colors.green.shade700),
                            ),
                            const Divider(height: 8),
                            Text(
                              'Outstanding Balance: ${formatCurrency(balanceDue)}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                fontFeatures: const [FontFeature.tabularFigures()],
                                color: balanceDue > 0 ? Colors.red.shade700 : Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                      );

                      if (constraints.maxWidth < 560) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            clientCol,
                            const SizedBox(height: 12),
                            summaryBox,
                          ],
                        );
                      }

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: clientCol),
                          const SizedBox(width: 12),
                          summaryBox,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  const Text('Chronological Invoices & Billing History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 10),
                  Expanded(
                    child: invoices.isEmpty
                        ? const Center(child: Text('No invoices recorded for this client yet.', style: TextStyle(color: Colors.grey)))
                        : ListView.separated(
                            itemCount: invoices.length,
                            separatorBuilder: (_, __) => const Divider(),
                            itemBuilder: (context, index) {
                              final inv = invoices[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: inv.isFullyPaid ? Colors.green.shade100 : Colors.indigo.shade100,
                                  child: Icon(
                                    inv.isFullyPaid ? Icons.check : Icons.receipt,
                                    color: inv.isFullyPaid ? Colors.green.shade800 : Colors.indigo.shade800,
                                    size: 18,
                                  ),
                                ),
                                title: Text('Invoice ${inv.invoiceNumber} • Issued: ${inv.issueDate}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('Terms: ${inv.paymentTerms} • Status: ${inv.computedStatus}', style: const TextStyle(fontSize: 12)),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      formatCurrency(inv.totalCents),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontFeatures: [FontFeature.tabularFigures()]),
                                    ),
                                    if (inv.balanceDueCents > 0)
                                      Text(
                                        'Due: ${formatCurrency(inv.balanceDueCents)}',
                                        style: TextStyle(fontSize: 11, color: Colors.red.shade700, fontWeight: FontWeight.bold, fontFeatures: const [FontFeature.tabularFigures()]),
                                      )
                                    else
                                      const Text('Paid in Full', style: TextStyle(fontSize: 11, color: Colors.green)),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
