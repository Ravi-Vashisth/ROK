import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/currency_formatter_provider.dart';
import '../../invoices/providers/invoices_provider.dart';
import '../providers/clients_provider.dart';
import 'client_statement_dialog.dart';

class ClientsTab extends ConsumerWidget {
  const ClientsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clients = ref.watch(clientsProvider);
    final invoices = ref.watch(invoicesProvider);
    final formatCurrency = ref.watch(currencyFormatterProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Client Ledger & Statements (${clients.length})', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        if (clients.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text('No clients saved yet. Add clients in the invoice creation section.', style: TextStyle(color: Colors.grey)),
            ),
          )
        else
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: clients.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final client = clients[index];
                final clientInvoices = invoices.where((i) => i.clientId == client.id).toList();

                int totalInvoiced = 0;
                int totalPaid = 0;
                for (final inv in clientInvoices) {
                  totalInvoiced += inv.totalCents;
                  totalPaid += inv.paidCents;
                }
                final balanceDue = totalInvoiced - totalPaid;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Text(client.name.isNotEmpty ? client.name[0].toUpperCase() : 'C', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onPrimaryContainer)),
                  ),
                  title: Text(client.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Email: ${client.email.isNotEmpty ? client.email : "N/A"} • Phone: ${client.phone.isNotEmpty ? client.phone : "N/A"} • Invoices: ${clientInvoices.length}', style: const TextStyle(fontSize: 12)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Invoiced: ${formatCurrency(totalInvoiced)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          Text('Balance Due: ${formatCurrency(balanceDue)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: balanceDue > 0 ? Colors.red.shade700 : Colors.green.shade700)),
                        ],
                      ),
                      const SizedBox(width: 12),
                      FilledButton.tonal(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => ClientStatementDialog(client: client),
                          );
                        },
                        child: const Text('Statement of Account'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
