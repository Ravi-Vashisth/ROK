import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../clients/models/client.dart';
import '../../../clients/providers/clients_provider.dart';

class ClientAutocompletePicker extends ConsumerStatefulWidget {
  final String? selectedClientId;
  final ValueChanged<String?> onClientSelected;

  const ClientAutocompletePicker({
    super.key,
    required this.selectedClientId,
    required this.onClientSelected,
  });

  @override
  ConsumerState<ClientAutocompletePicker> createState() => _ClientAutocompletePickerState();
}

class _ClientAutocompletePickerState extends ConsumerState<ClientAutocompletePicker> {
  final TextEditingController _searchController = TextEditingController();
  bool _isDropdownOpen = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddClientDialog({String initialName = ''}) {
    final nameController = TextEditingController(text: initialName);
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    final taxIdController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Client'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Client Name *', hintText: 'e.g. Acme Corp'),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email', hintText: 'billing@client.com'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone', hintText: '+1 (555) 012-3456'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: taxIdController,
                decoration: const InputDecoration(labelText: 'Tax ID / GSTIN / VAT', hintText: 'e.g. EU123456789'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressController,
                minLines: 2,
                maxLines: null,
                decoration: const InputDecoration(labelText: 'Billing Address', hintText: 'Suite 200, 456 Enterprise Blvd, Austin, TX'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) return;

              ref.read(clientsProvider.notifier).addClient(
                    name: name,
                    email: emailController.text.trim(),
                    phone: phoneController.text.trim(),
                    address: addressController.text.trim(),
                    taxId: taxIdController.text.trim(),
                  );

              // Find newly created client
              final clients = ref.read(clientsProvider);
              final created = clients.cast<Client?>().firstWhere(
                    (c) => c?.name.toLowerCase() == name.toLowerCase(),
                    orElse: () => null,
                  );

              if (created != null) {
                widget.onClientSelected(created.id);
                _searchController.text = created.name;
              }

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Client "$name" added and selected!')),
              );
            },
            child: const Text('Save Client'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clients = ref.watch(clientsProvider);
    final Client? selectedClient = widget.selectedClientId != null
        ? clients.cast<Client?>().firstWhere(
            (c) => c?.id == widget.selectedClientId,
            orElse: () => null,
          )
        : null;

    if (selectedClient != null && _searchController.text.isEmpty) {
      _searchController.text = selectedClient.name;
    }

    final query = _searchController.text.trim().toLowerCase();
    final filteredClients = query.isEmpty
        ? clients
        : clients.where((c) =>
            c.name.toLowerCase().contains(query) ||
            c.email.toLowerCase().contains(query) ||
            c.taxId.toLowerCase().contains(query)).toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
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
                  onPressed: () => _showAddClientDialog(),
                  icon: const Icon(Icons.person_add_outlined, size: 16),
                  label: const Text('+ Add New Client'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search Client by Name, Email or Tax ID...',
                hintText: 'Type to search or add client...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: widget.selectedClientId != null
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            widget.onClientSelected(null);
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (val) {
                setState(() {
                  _isDropdownOpen = true;
                });
              },
              onTap: () {
                setState(() {
                  _isDropdownOpen = true;
                });
              },
            ),
            if (_isDropdownOpen) ...[
              const SizedBox(height: 4),
              Container(
                constraints: const BoxConstraints(maxHeight: 220),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Theme.of(context).dividerColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ...filteredClients.map((c) => ListTile(
                          dense: true,
                          title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            '${c.email.isNotEmpty ? c.email : 'No email'} ${c.taxId.isNotEmpty ? " • Tax ID: ${c.taxId}" : ""}',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                          onTap: () {
                            widget.onClientSelected(c.id);
                            _searchController.text = c.name;
                            setState(() {
                              _isDropdownOpen = false;
                            });
                          },
                        )),
                    if (query.isNotEmpty) ...[
                      const Divider(height: 1),
                      ListTile(
                        dense: true,
                        leading: Icon(Icons.add_circle_outline, color: Theme.of(context).colorScheme.primary),
                        title: Text(
                          '+ Add new client "$query"',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        onTap: () {
                          setState(() {
                            _isDropdownOpen = false;
                          });
                          _showAddClientDialog(initialName: _searchController.text.trim());
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (selectedClient != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selectedClient.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          if (selectedClient.email.isNotEmpty || selectedClient.phone.isNotEmpty)
                            Text(
                              '${selectedClient.email} ${selectedClient.phone.isNotEmpty ? " • ${selectedClient.phone}" : ""}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          if (selectedClient.taxId.isNotEmpty || selectedClient.address.isNotEmpty)
                            Text(
                              '${selectedClient.taxId.isNotEmpty ? "Tax ID: ${selectedClient.taxId}" : ""} ${selectedClient.address.isNotEmpty ? " • Address: ${selectedClient.address}" : ""}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                        ],
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
