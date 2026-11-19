import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:billing_app/features/clients/presentation/clients_tab.dart';
import 'package:billing_app/features/clients/providers/clients_provider.dart';
import 'package:billing_app/features/estimates/presentation/offline_estimates_list.dart';
import 'package:billing_app/features/estimates/providers/estimates_provider.dart';
import 'package:billing_app/features/invoices/presentation/invoice_editor_screen.dart';
import 'package:billing_app/features/invoices/providers/invoices_provider.dart';
import 'package:billing_app/features/billing/presentation/widgets/offline_invoices_list.dart';

class SalesTab extends ConsumerStatefulWidget {
  final int initialSubTab;
  const SalesTab({super.key, this.initialSubTab = 0});

  @override
  ConsumerState<SalesTab> createState() => _SalesTabState();
}

class _SalesTabState extends ConsumerState<SalesTab> {
  late int _subTab = widget.initialSubTab; // 0 = Invoices, 1 = Estimates, 2 = Clients CRM

  // Filter & Search state
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'All'; // 'All', 'Pending', 'Partially Paid', 'Paid', 'Overdue', 'Void'
  String _dateFilter = 'All Time'; // 'All Time', 'This Month', 'This Quarter'

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(invoicesProvider);
    ref.watch(estimatesProvider);
    final clients = ref.watch(clientsProvider);

    final isWide = MediaQuery.sizeOf(context).width >= 900;
    final pagePadding = isWide ? 24.0 : 16.0;

    final salesHeader = Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sales & Clients CRM',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              'Manage client invoices, proposals, and customer dossiers in one place',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ToggleButtons(
                isSelected: [_subTab == 0, _subTab == 1, _subTab == 2],
                onPressed: (index) {
                  setState(() {
                    _subTab = index;
                    _statusFilter = 'All';
                  });
                },
                borderRadius: BorderRadius.circular(12),
                constraints: const BoxConstraints(minHeight: 36, minWidth: 90),
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        Icon(Icons.receipt_outlined, size: 16),
                        SizedBox(width: 6),
                        Text('Invoices', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        Icon(Icons.request_quote_outlined, size: 16),
                        SizedBox(width: 6),
                        Text('Quotes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.people_outline, size: 16),
                        const SizedBox(width: 6),
                        Text('Clients (${clients.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_subTab == 0)
              FilledButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Create Invoice'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const InvoiceEditorScreen(isQuote: false),
                    ),
                  );
                },
              )
            else if (_subTab == 1)
              FilledButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New Quote'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const InvoiceEditorScreen(isQuote: true),
                    ),
                  );
                },
              ),
          ],
        ),
      ],
    );

    if (_subTab == 2) {
      if (isWide) {
        return Padding(
          padding: EdgeInsets.all(pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              salesHeader,
              const SizedBox(height: 20),
              const Expanded(child: ClientsTab()),
            ],
          ),
        );
      }
      return ClientsTab(
        leadingSlivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(pagePadding, pagePadding, pagePadding, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  salesHeader,
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final leadingSlivers = [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(pagePadding, pagePadding, pagePadding, 0),
        sliver: SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              salesHeader,
              const SizedBox(height: 20),
              _buildFilterHeader(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    ];

    if (_subTab == 0) {
      return OfflineInvoicesList(
        searchQuery: _searchController.text,
        statusFilter: _statusFilter,
        dateFilter: _dateFilter,
        leadingSlivers: leadingSlivers,
      );
    }

    return OfflineEstimatesList(
      searchQuery: _searchController.text,
      statusFilter: _statusFilter,
      dateFilter: _dateFilter,
      leadingSlivers: leadingSlivers,
      onViewInvoice: (invNum) {
        setState(() {
          _subTab = 0;
          _searchController.text = invNum;
        });
      },
    );
  }

  Widget _buildFilterHeader() {
    final searchField = TextField(
      controller: _searchController,
      decoration: const InputDecoration(
        labelText: 'Search Invoices / Estimates by Client or #',
        hintText: 'e.g. INV-0001 or Acme',
        prefixIcon: Icon(Icons.search, size: 18),
        isDense: true,
        border: OutlineInputBorder(),
      ),
      onChanged: (_) => setState(() {}),
    );

    Widget buildDateDropdown({bool isExpanded = false}) => DropdownButton<String>(
          value: _dateFilter,
          isExpanded: isExpanded,
          underline: const SizedBox(),
          items: const [
            DropdownMenuItem(value: 'All Time', child: Text('All Time', style: TextStyle(fontSize: 13))),
            DropdownMenuItem(value: 'This Month', child: Text('This Month', style: TextStyle(fontSize: 13))),
            DropdownMenuItem(value: 'This Quarter', child: Text('This Quarter', style: TextStyle(fontSize: 13))),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _dateFilter = val);
          },
        );

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 460) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      searchField,
                      const SizedBox(height: 8),
                      buildDateDropdown(isExpanded: true),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: searchField),
                    const SizedBox(width: 12),
                    buildDateDropdown(),
                  ],
                );
              },
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: (_subTab == 0
                        ? ['All', 'Draft', 'Pending', 'Partially Paid', 'Paid', 'Overdue', 'Void']
                        : ['All', 'Draft', 'Pending', 'Accepted', 'Declined', 'Converted'])
                    .map((status) {
                  final isSelected = _statusFilter == status;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(status, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _statusFilter = status),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
