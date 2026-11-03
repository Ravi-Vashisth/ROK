import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../estimates/presentation/offline_estimates_list.dart';
import '../../estimates/providers/estimates_provider.dart';
import '../../invoices/presentation/invoice_editor_screen.dart';
import '../../invoices/providers/invoices_provider.dart';
import 'widgets/offline_invoices_list.dart';

class SalesTab extends ConsumerStatefulWidget {
  final int initialSubTab;
  const SalesTab({super.key, this.initialSubTab = 0});

  @override
  ConsumerState<SalesTab> createState() => _SalesTabState();
}

class _SalesTabState extends ConsumerState<SalesTab> {
  late int _subTab = widget.initialSubTab; // 0 = Invoices, 1 = Estimates

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sales & Proposals Hub',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Manage client invoices, proposals, and track receivables',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ToggleButtons(
                  isSelected: [_subTab == 0, _subTab == 1],
                  onPressed: (index) {
                    setState(() => _subTab = index);
                  },
                  borderRadius: BorderRadius.circular(8),
                  constraints: const BoxConstraints(minHeight: 36, minWidth: 100),
                  children: const [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Icon(Icons.receipt_outlined, size: 16),
                          SizedBox(width: 6),
                          Text('Invoices', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Icon(Icons.request_quote_outlined, size: 16),
                          SizedBox(width: 6),
                          Text('Estimates', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
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
                else
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
        ),
        const SizedBox(height: 20),
        _buildFilterHeader(),
        const SizedBox(height: 16),
        if (_subTab == 0)
          OfflineInvoicesList(
            searchQuery: _searchController.text,
            statusFilter: _statusFilter,
            dateFilter: _dateFilter,
          )
        else
          OfflineEstimatesList(
            searchQuery: _searchController.text,
            statusFilter: _statusFilter,
            dateFilter: _dateFilter,
            onViewInvoice: (invNum) {
              setState(() {
                _subTab = 0;
                _searchController.text = invNum;
              });
            },
          ),
      ],
    );
  }

  Widget _buildFilterHeader() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Search Invoices / Estimates by Client or #',
                      hintText: 'e.g. INV-0001 or Acme',
                      prefixIcon: Icon(Icons.search, size: 18),
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _dateFilter,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 'All Time', child: Text('All Time', style: TextStyle(fontSize: 13))),
                    DropdownMenuItem(value: 'This Month', child: Text('This Month', style: TextStyle(fontSize: 13))),
                    DropdownMenuItem(value: 'This Quarter', child: Text('This Quarter', style: TextStyle(fontSize: 13))),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _dateFilter = val);
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['All', 'Draft', 'Pending', 'Partially Paid', 'Paid', 'Overdue', 'Void'].map((status) {
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
