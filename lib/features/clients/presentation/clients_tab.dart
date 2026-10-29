import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../clients/providers/clients_provider.dart';
import '../../../invoices/providers/invoices_provider.dart';

class ClientsTab extends ConsumerStatefulWidget {
  const ClientsTab({super.key});

  @override
  ConsumerState<ClientsTab> createState() => _ClientsTabState();
}

class _ClientsTabState extends ConsumerState<ClientsTab> {
  String? _selectedClientId;

  @override
  Widget build(BuildContext context) {
    final clients = ref.watch(clientsProvider);
    final constraints = MediaQuery.of(context).size;
    final isWide = constraints.width >= 900;

    if (!isWide) {
      return _buildList(clients, (id) => Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(body: _buildDetail(id)))));
    }

    return Row(
      children: [
        Expanded(flex: 3, child: _buildList(clients, (id) => setState(() => _selectedClientId = id))),
        const VerticalDivider(),
        Expanded(flex: 7, child: _buildDetail(_selectedClientId)),
      ],
    );
  }

  Widget _buildList(List clients, Function(String) onSelect) {
    return ListView.builder(
      itemCount: clients.length,
      itemBuilder: (_, i) => ListTile(
        title: Text(clients[i].name),
        onTap: () => onSelect(clients[i].id),
      ),
    );
  }


  Widget _buildDetail(String? id) {
    if (id == null) return const Center(child: Text('Select a client'));
    final client = ref.read(clientsProvider).firstWhere((c) => c.id == id);
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(client.name, style: Theme.of(context).textTheme.headlineSmall),
                const Spacer(),
                const Text('KPI: \$0.00'), // Placeholder for actual KPI logic
              ],
            ),
          ),
          const TabBar(tabs: [Tab(text: 'Invoices'), Tab(text: 'Statements'), Tab(text: 'Notes')]),
          const Expanded(
            child: TabBarView(
              children: [
                Center(child: Text('Invoices List')),
                Center(child: Text('Statements View')),
                Center(child: Text('Client Notes')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
