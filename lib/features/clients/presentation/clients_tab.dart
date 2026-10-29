import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/currency_formatter_provider.dart';
import '../../../core/utils/money_utils.dart';
import '../../invoices/providers/invoices_provider.dart';
import '../models/client.dart';
import '../providers/clients_provider.dart';
import 'client_statement_dialog.dart';

class ClientsTab extends ConsumerStatefulWidget {
  const ClientsTab({super.key});

  @override
  ConsumerState<ClientsTab> createState() => _ClientsTabState();
}

class _ClientsTabState extends ConsumerState<ClientsTab> {
  String? _selectedClientId;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddClientDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final taxIdCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Client'),
        content: SizedBox(
          width: 440,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Client / Company Name *'),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a name' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(labelText: 'Billing Email'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(labelText: 'Phone Number'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: addressCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Billing Address'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: taxIdCtrl,
                    decoration: const InputDecoration(labelText: 'GSTIN / Tax ID'),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              ref.read(clientsProvider.notifier).addClient(
                    name: nameCtrl.text.trim(),
                    email: emailCtrl.text.trim(),
                    phone: phoneCtrl.text.trim(),
                    address: addressCtrl.text.trim(),
                    taxId: taxIdCtrl.text.trim(),
                  );
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Client added successfully!')),
              );
            },
            child: const Text('Save Client'),
          ),
        ],
      ),
    );
  }

  void _showEditClientDialog(Client client) {
    final nameCtrl = TextEditingController(text: client.name);
    final emailCtrl = TextEditingController(text: client.email);
    final phoneCtrl = TextEditingController(text: client.phone);
    final addressCtrl = TextEditingController(text: client.address);
    final taxIdCtrl = TextEditingController(text: client.taxId);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Client Details'),
        content: SizedBox(
          width: 440,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Client Name *'),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a name' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(labelText: 'Billing Email'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(labelText: 'Phone Number'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: addressCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Billing Address'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: taxIdCtrl,
                    decoration: const InputDecoration(labelText: 'GSTIN / Tax ID'),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              ref.read(clientsProvider.notifier).updateClient(
                    id: client.id,
                    name: nameCtrl.text.trim(),
                    email: emailCtrl.text.trim(),
                    phone: phoneCtrl.text.trim(),
                    address: addressCtrl.text.trim(),
                    taxId: taxIdCtrl.text.trim(),
                  );
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Client details updated!')),
              );
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  void _handleDeleteClient(Client client) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Client'),
        content: Text('Are you sure you want to delete client "${client.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              final deleted = ref.read(clientsProvider.notifier).deleteClient(client.id);
              if (!deleted) {
                showDialog(
                  context: context,
                  builder: (warnCtx) => AlertDialog(
                    title: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.amber),
                        SizedBox(width: 8),
                        Text('Cannot Delete Client'),
                      ],
                    ),
                    content: Text(
                      'Cannot delete "${client.name}" because existing invoices are attached to this client. Please void or settle all invoices first.',
                    ),
                    actions: [
                      FilledButton(onPressed: () => Navigator.pop(warnCtx), child: const Text('OK')),
                    ],
                  ),
                );
              } else {
                setState(() => _selectedClientId = null);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Client "${client.name}" deleted.')),
                );
              }
            },
            child: const Text('Delete Client'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clients = ref.watch(clientsProvider);
    final constraints = MediaQuery.of(context).size;
    final isWide = constraints.width >= 900;

    final filteredClients = clients.where((c) {
      if (_searchController.text.isEmpty) return true;
      final q = _searchController.text.toLowerCase();
      return c.name.toLowerCase().contains(q) || c.email.toLowerCase().contains(q);
    }).toList();

    if (_selectedClientId == null && clients.isNotEmpty) {
      _selectedClientId = clients.first.id;
    }

    if (!isWide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildClientListHeader(),
          const SizedBox(height: 12),
          _buildClientListView(filteredClients, (id) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: const Text('Client Dossier')),
                  body: _buildDetailPane(id),
                ),
              ),
            );
          }),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildClientListHeader(),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'Search clients...',
                          prefixIcon: Icon(Icons.search, size: 18),
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 10),
                      _buildClientListView(filteredClients, (id) => setState(() => _selectedClientId = id)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 7,
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: _buildDetailPane(_selectedClientId),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildClientListHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Client CRM & Statements',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Text(
              'Directory of accounts, billing history, and statements of account',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        FilledButton.icon(
          icon: const Icon(Icons.add, size: 16),
          label: const Text('+ Add Client'),
          onPressed: _showAddClientDialog,
        ),
      ],
    );
  }

  Widget _buildClientListView(List<Client> clients, Function(String) onSelect) {
    if (clients.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24.0),
        child: Center(child: Text('No clients found.', style: TextStyle(color: Colors.grey))),
      );
    }

    final invoices = ref.watch(invoicesProvider);
    final formatCurrency = ref.watch(currencyFormatterProvider);

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: clients.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final c = clients[i];
        final isSelected = _selectedClientId == c.id;
        final clientInvoices = invoices.where((inv) => inv.clientId == c.id).toList();
        final balanceDue = clientInvoices.fold(0, (sum, inv) => sum + inv.balanceDueCents);

        return ListTile(
          selected: isSelected,
          selectedTileColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          subtitle: Text(c.email.isNotEmpty ? c.email : (c.phone.isNotEmpty ? c.phone : 'No contact info'), style: const TextStyle(fontSize: 11)),
          trailing: Text(
            balanceDue > 0 ? '${formatCurrency(balanceDue)} Due' : '✓ Settled',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: balanceDue > 0 ? Colors.amber.shade900 : Colors.green.shade700,
            ),
          ),
          onTap: () => onSelect(c.id),
        );
      },
    );
  }

  Widget _buildDetailPane(String? id) {
    if (id == null) {
      return const Center(child: Text('Select a client to view their account dossier.'));
    }

    final clients = ref.watch(clientsProvider);
    final client = clients.firstWhere(
      (c) => c.id == id,
      orElse: () => Client(id: '', name: 'Client Not Found', createdAt: ''),
    );

    if (client.id.isEmpty) {
      return const Center(child: Text('Client not found.'));
    }

    final invoices = ref.watch(invoicesProvider).where((i) => i.clientId == client.id).toList();
    final formatCurrency = ref.watch(currencyFormatterProvider);

    int totalBilled = 0;
    int totalPaid = 0;
    for (final inv in invoices) {
      totalBilled += inv.totalCents;
      totalPaid += inv.paidCents;
    }
    final balanceDue = totalBilled - totalPaid;

    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Client Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(client.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      '${client.email.isNotEmpty ? client.email : "No Email"} • ${client.phone.isNotEmpty ? client.phone : "No Phone"} • Tax ID: ${client.taxId.isNotEmpty ? client.taxId : "None"}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    if (client.address.isNotEmpty)
                      Text(client.address, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.edit_outlined, size: 14),
                    label: const Text('Edit Client', style: TextStyle(fontSize: 12)),
                    onPressed: () => _showEditClientDialog(client),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Delete Client',
                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                    onPressed: () => _handleDeleteClient(client),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 3 Financial Metric Cards
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Lifetime Billed', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text(formatCurrency(totalBilled), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Collected', style: TextStyle(fontSize: 11, color: Colors.green)),
                      const SizedBox(height: 4),
                      Text(formatCurrency(totalPaid), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: balanceDue > 0 ? Colors.amber.shade50.withValues(alpha: 0.4) : Colors.green.shade50.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: balanceDue > 0 ? Colors.amber.shade300 : Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Outstanding Balance', style: TextStyle(fontSize: 11, color: balanceDue > 0 ? Colors.amber.shade900 : Colors.green)),
                      const SizedBox(height: 4),
                      Text(
                        formatCurrency(balanceDue),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: balanceDue > 0 ? Colors.amber.shade900 : Colors.green.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Sub-tabs: Invoices, Statements, Notes
          const TabBar(
            tabs: [
              Tab(text: 'Invoices & Billing'),
              Tab(text: 'Statement of Account'),
              Tab(text: 'Internal Notes'),
            ],
          ),
          const SizedBox(height: 12),

          SizedBox(
            height: 380,
            child: TabBarView(
              children: [
                // Invoices List
                invoices.isEmpty
                    ? const Center(child: Text('No invoices issued to this client yet.', style: TextStyle(color: Colors.grey)))
                    : ListView.separated(
                        itemCount: invoices.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final inv = invoices[i];
                          return ListTile(
                            leading: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: inv.isFullyPaid ? Colors.green.shade50 : Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: inv.isFullyPaid ? Colors.green.shade300 : Colors.amber.shade300),
                              ),
                              child: Text(inv.invoiceNumber, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: inv.isFullyPaid ? Colors.green.shade800 : Colors.amber.shade900)),
                            ),
                            title: Text(inv.issueDate, style: const TextStyle(fontSize: 12)),
                            subtitle: Text('Terms: ${inv.paymentTerms} • Due: ${inv.dueDate}', style: const TextStyle(fontSize: 11)),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(formatCurrency(inv.totalCents), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                Text(
                                  inv.balanceDueCents > 0 ? 'Bal: ${formatCurrency(inv.balanceDueCents)}' : '✓ Paid',
                                  style: TextStyle(fontSize: 11, color: inv.balanceDueCents > 0 ? Colors.red.shade700 : Colors.green.shade700, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                // Statement of Account View
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Itemized Account Ledger', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        FilledButton.tonalIcon(
                          icon: const Icon(Icons.picture_as_pdf, size: 15),
                          label: const Text('Download Statement PDF', style: TextStyle(fontSize: 12)),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => ClientStatementDialog(client: client),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: invoices.isEmpty
                          ? const Center(child: Text('No transactions to show.', style: TextStyle(color: Colors.grey)))
                          : ListView.separated(
                              itemCount: invoices.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, i) {
                                final inv = invoices[i];
                                return ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.receipt_long, size: 18),
                                  title: Text('Invoice ${inv.invoiceNumber}'),
                                  subtitle: Text(inv.issueDate),
                                  trailing: Text(formatCurrency(inv.totalCents), style: const TextStyle(fontWeight: FontWeight.bold)),
                                );
                              },
                            ),
                    ),
                  ],
                ),

                // Client Notes
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Client Account Terms & Internal Notes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      Text(
                        'Client ID: ${client.id}\nCreated: ${client.createdAt}\nAddress: ${client.address.isNotEmpty ? client.address : "Not provided"}\nTax ID: ${client.taxId.isNotEmpty ? client.taxId : "Not provided"}',
                        style: const TextStyle(fontSize: 12, height: 1.6, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
