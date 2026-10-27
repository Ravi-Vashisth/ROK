import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../clients/providers/clients_provider.dart';

class ClientSelectionCard extends ConsumerWidget {
  final TextEditingController newClientController;
  final String? selectedClientId;
  final ValueChanged<String?> onClientSelected;
  final VoidCallback onAddClient;

  const ClientSelectionCard({
    super.key,
    required this.newClientController,
    required this.selectedClientId,
    required this.onClientSelected,
    required this.onAddClient,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clients = ref.watch(clientsProvider);

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
            Text(
              '1. Client Selection',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: newClientController,
                    decoration: const InputDecoration(
                      labelText: 'New Client Name',
                      hintText: 'e.g. Acme Corp',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: onAddClient,
                  child: const Text('Add Client'),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 4,
                  child: DropdownButtonFormField<String>(
                    value: selectedClientId,
                    decoration: const InputDecoration(
                      labelText: 'Select Saved Client',
                    ),
                    items: clients.map((c) {
                      return DropdownMenuItem<String>(
                        value: c.id,
                        child: Text(c.name),
                      );
                    }).toList(),
                    onChanged: onClientSelected,
                    hint: const Text('Choose a client'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
