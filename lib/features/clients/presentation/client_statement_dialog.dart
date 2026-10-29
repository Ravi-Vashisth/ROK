import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/currency_formatter_provider.dart';
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
    final invoices = ref.watch(invoicesProvider).where((i) => i.clientId == client.id).toList();
    final formatCurrency = ref.watch(currencyFormatterProvider);

    int totalInvoiced = 0;
    int totalPaid = 0;
    for (final inv in invoices) {
      if (inv.isVoid || inv.status == 'VOID') continue;
      totalInvoiced += inv.totalCents;
      totalPaid += inv.paidCents;
    }
    final balanceDue = totalInvoiced - totalPaid;

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 750,
          height: 650,
          child: Scaffold(
            appBar: AppBar(
              title: Text('Statement of Account: ${client.name}'),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            body: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(client.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          if (client.email.isNotEmpty) Text('Email: ${client.email}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          if (client.phone.isNotEmpty) Text('Phone: ${client.phone}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          if (client.taxId.isNotEmpty) Text('Tax ID: ${client.taxId}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Theme.of(context).dividerColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Total Invoiced: ${formatCurrency(totalInvoiced)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            Text('Total Paid: ${formatCurrency(totalPaid)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                            const Divider(height: 8),
                            Text('Outstanding Balance: ${formatCurrency(balanceDue)}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: balanceDue > 0 ? Colors.red.shade700 : Colors.green.shade700)),
                          ],
                        ),
                      ),
                    ],
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
                                    Text(formatCurrency(inv.totalCents), style: const TextStyle(fontWeight: FontWeight.bold)),
                                    if (inv.balanceDueCents > 0)
                                      Text('Due: ${formatCurrency(inv.balanceDueCents)}', style: TextStyle(fontSize: 11, color: Colors.red.shade700, fontWeight: FontWeight.bold))
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
