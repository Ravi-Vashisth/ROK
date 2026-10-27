import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../clients/models/client.dart';
import '../../../clients/providers/clients_provider.dart';

class ClientSelectionCard extends StatefulWidget {
  final TextEditingController newClientController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final TextEditingController addressController;
  final TextEditingController taxIdController;
  final String? selectedClientId;
  final ValueChanged<String?> onClientSelected;
  final VoidCallback onAddClient;

  const ClientSelectionCard({
    super.key,
    required this.newClientController,
    required this.emailController,
    required this.phoneController,
    required this.addressController,
    required this.taxIdController,
    required this.selectedClientId,
    required this.onClientSelected,
    required this.onAddClient,
  });

  @override
  State<ClientSelectionCard> createState() => _ClientSelectionCardState();
}

class _ClientSelectionCardState extends State<ClientSelectionCard> {
  bool _showAdvancedDetails = false;

  @override
  Widget build(BuildContext context) {
    final clients = ref.watch(clientsProvider);
    final Client? selectedClient = widget.selectedClientId != null
        ? clients.cast<Client?>().firstWhere(
            (c) => c?.id == widget.selectedClientId,
            orElse: () => null,
          )
        : null;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '1. Client Selection & Billing Details',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _showAdvancedDetails = !_showAdvancedDetails;
                    });
                  },
                  icon: Icon(
                    _showAdvancedDetails
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 18,
                  ),
                  label: Text(_showAdvancedDetails
                      ? 'Hide Extra Details'
                      : '+ Client Details (Tax ID, Address)'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Main Client Inputs Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: widget.newClientController,
                    decoration: const InputDecoration(
                      labelText: 'New Client Name *',
                      hintText: 'e.g. Acme Corp',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: FilledButton.tonal(
                    onPressed: widget.onAddClient,
                    child: const Text('Add Client'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 4,
                  child: DropdownButtonFormField<String>(
                    value: widget.selectedClientId,
                    decoration: const InputDecoration(
                      labelText: 'Select Saved Client',
                    ),
                    items: clients.map((c) {
                      return DropdownMenuItem<String>(
                        value: c.id,
                        child: Text(
                          c.taxId.isNotEmpty
                              ? '${c.name} (${c.taxId})'
                              : c.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: widget.onClientSelected,
                    hint: const Text('Choose a client'),
                  ),
                ),
              ],
            ),

            // Optional Advanced Billing Details (Email, Phone, Address, Tax ID)
            if (_showAdvancedDetails) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Optional Client Contact & Tax Information (saved with client):',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: widget.emailController,
                            decoration: const InputDecoration(
                              labelText: 'Client Email',
                              hintText: 'invoices@client.com',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: widget.phoneController,
                            decoration: const InputDecoration(
                              labelText: 'Phone',
                              hintText: '+1 (555) 012-3456',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: widget.taxIdController,
                            decoration: const InputDecoration(
                              labelText: 'Client Tax ID / VAT / GSTIN',
                              hintText: 'e.g. EU123456789 or GSTIN',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: widget.addressController,
                      decoration: const InputDecoration(
                        labelText: 'Billing Address',
                        hintText: 'Suite 200, 456 Enterprise Blvd, Austin, TX 78701',
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Selected Client Details Confirmation Badge
            if (selectedClient != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Selected: ${selectedClient.name}'
                        '${selectedClient.email.isNotEmpty ? " • ${selectedClient.email}" : ""}'
                        '${selectedClient.taxId.isNotEmpty ? " • Tax ID: ${selectedClient.taxId}" : ""}'
                        '${selectedClient.address.isNotEmpty ? " • ${selectedClient.address}" : ""}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
