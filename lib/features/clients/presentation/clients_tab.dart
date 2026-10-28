import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/currency_formatter_provider.dart';
import '../../invoices/providers/invoices_provider.dart';
import '../models/client.dart';
import '../providers/clients_provider.dart';
import 'client_statement_dialog.dart';

class ClientsTab extends ConsumerWidget {
  const ClientsTab({super.key});

  void _showEditClientDialog(BuildContext context, WidgetRef ref, Client client) {
    final nameController = TextEditingController(text: client.name);
    final emailController = TextEditingController(text: client.email);
    final phoneController = TextEditingController(text: client.phone);
    final addressController = TextEditingController(text: client.address);
    final taxIdController = TextEditingController(text: client.taxId);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.edit_outlined),
            SizedBox(width: 8),
            Text('Edit Client Profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Client / Company Name *'),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a name' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Billing Email'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneController,
                    decoration: const InputDecoration(labelText: 'Phone Number'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: addressController,
                    decoration: const InputDecoration(labelText: 'Billing Address'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: taxIdController,
                    decoration: const InputDecoration(labelText: 'Tax ID / VAT / GSTIN'),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.check, size: 16),
            label: const Text('Save Changes'),
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              ref.read(clientsProvider.notifier).updateClient(
                    id: client.id,
                    name: nameController.text.trim(),
                    email: emailController.text.trim(),
                    phone: phoneController.text.trim(),
                    address: addressController.text.trim(),
                    taxId: taxIdController.text.trim(),
                  );
              Navigator.of(dialogCtx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Client details updated successfully.')),
              );
            },
          ),
        ],
      ),
    );
  }

  void _handleDeleteClient(BuildContext context, WidgetRef ref, Client client) {
    final invoices = ref.read(invoicesProvider);
    final hasInvoices = invoices.any((i) => i.clientId == client.id);

    if (hasInvoices) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('Cannot Delete Client'),
            ],
          ),
          content: Text(
            'Client "${client.name}" has recorded invoices associated with their account.\n\nTo preserve financial audit integrity, clients with billing history cannot be deleted. You may edit their details instead.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Understood'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Client?'),
        content: Text('Are you sure you want to delete client "${client.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ref.read(clientsProvider.notifier).deleteClient(client.id);
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Client "${client.name}" removed.')),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

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
            Text(
              'Client Ledger & Statements (${clients.length})',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (clients.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text(
                'No clients saved yet. Add clients in the Sales & Proposals section.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;

              if (isWide) {
                // High-density widescreen data table
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                          Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                        ),
                        columns: const [
                          DataColumn(label: Text('Client Name', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Email', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Phone', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Tax ID / GSTIN', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Total Invoiced', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Balance Due', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: clients.map((client) {
                          final clientInvoices = invoices.where((i) => i.clientId == client.id).toList();
                          int totalInvoiced = 0;
                          int totalPaid = 0;
                          for (final inv in clientInvoices) {
                            totalInvoiced += inv.totalCents;
                            totalPaid += inv.paidCents;
                          }
                          final balanceDue = totalInvoiced - totalPaid;

                          return DataRow(
                            cells: [
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                      child: Text(
                                        client.name.isNotEmpty ? client.name[0].toUpperCase() : 'C',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(client.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              DataCell(Text(client.email.isNotEmpty ? client.email : '—')),
                              DataCell(Text(client.phone.isNotEmpty ? client.phone : '—')),
                              DataCell(Text(client.taxId.isNotEmpty ? client.taxId : '—')),
                              DataCell(
                                Text(
                                  formatCurrency(totalInvoiced),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              DataCell(
                                Text(
                                  balanceDue > 0 ? formatCurrency(balanceDue) : '✓ Settled',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: balanceDue > 0 ? Colors.red.shade700 : Colors.green.shade700,
                                  ),
                                ),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Edit Client',
                                      icon: const Icon(Icons.edit_outlined, size: 18),
                                      onPressed: () => _showEditClientDialog(context, ref, client),
                                    ),
                                    FilledButton.tonal(
                                      style: FilledButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (_) => ClientStatementDialog(client: client),
                                        );
                                      },
                                      child: const Text('Statement', style: TextStyle(fontSize: 12)),
                                    ),
                                    IconButton(
                                      tooltip: 'Delete Client',
                                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                      onPressed: () => _handleDeleteClient(context, ref, client),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                );
              }

              // Responsive Compact Card View
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(12),
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
                        child: Text(
                          client.name.isNotEmpty ? client.name[0].toUpperCase() : 'C',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      title: Text(client.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        'Email: ${client.email.isNotEmpty ? client.email : "N/A"} • Phone: ${client.phone.isNotEmpty ? client.phone : "N/A"} • Invoices: ${clientInvoices.length}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Invoiced: ${formatCurrency(totalInvoiced)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              Text(
                                balanceDue > 0 ? 'Balance Due: ${formatCurrency(balanceDue)}' : '✓ Settled',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: balanceDue > 0 ? Colors.red.shade700 : Colors.green.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'Edit Client',
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            onPressed: () => _showEditClientDialog(context, ref, client),
                          ),
                          FilledButton.tonal(
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (_) => ClientStatementDialog(client: client),
                              );
                            },
                            child: const Text('Statement', style: TextStyle(fontSize: 12)),
                          ),
                          IconButton(
                            tooltip: 'Delete Client',
                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                            onPressed: () => _handleDeleteClient(context, ref, client),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
      ],
    );
  }
}
