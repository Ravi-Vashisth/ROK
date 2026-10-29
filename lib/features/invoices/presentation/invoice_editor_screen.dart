import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../billing/presentation/widgets/client_autocomplete_picker.dart';
import '../../billing/services/invoice_pdf_service.dart';
import '../../billing/presentation/widgets/pdf_preview_dialog.dart';
import '../../business_profile/providers/business_profile_provider.dart';
import '../../clients/models/client.dart';
import '../../clients/providers/clients_provider.dart';
import '../../invoices/providers/invoices_provider.dart';
import '../../estimates/providers/estimates_provider.dart';

class InvoiceEditorScreen extends ConsumerStatefulWidget {
  final bool isQuote;

  const InvoiceEditorScreen({super.key, this.isQuote = false});

  @override
  ConsumerState<InvoiceEditorScreen> createState() => _InvoiceEditorScreenState();
}

class _InvoiceEditorScreenState extends ConsumerState<InvoiceEditorScreen> {
  String? _selectedClientId;
  int _mobileTabIndex = 0; // 0 = Editor, 1 = Preview

  List<LineItem> _items = [
    LineItem(description: 'Service Item', sacHsn: '998311', quantity: 1, unitPriceCents: 10000, taxSlab: 18)
  ];

  void _addItem() {
    setState(() => _items.add(LineItem(description: '', sacHsn: '', quantity: 1, unitPriceCents: 0, taxSlab: 18)));
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
  }

  void _updateItem(int index, LineItem item) {
    setState(() => _items[index] = item);
  }

  int get _subtotalCents => _items.fold(0, (sum, item) => sum + (item.unitPriceCents * item.quantity));
  int get _taxCents {
    return _items.fold(0, (sum, item) {
      final itemTotal = item.unitPriceCents * item.quantity;
      return sum + (itemTotal * item.taxSlab ~/ 100);
    });
  }
  int get _totalCents => _subtotalCents + _taxCents;

  @override
  Widget build(BuildContext context) {
    final constraints = MediaQuery.of(context).size;
    final isWide = constraints.width >= 1000;
    final profile = ref.watch(businessProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isQuote ? 'Create Quote' : 'Create Invoice'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () {
            // TODO: Implement save logic
            Navigator.pop(context);
          }, child: const Text('Save')),
        ],
      ),
      body: isWide ? _buildSplitView(profile) : _buildMobileView(profile),
    );
  }

  Widget _buildSplitView(BusinessProfile profile) {
    return Row(
      children: [
        Expanded(child: _buildEditor(profile)),
        const VerticalDivider(width: 1),
        Expanded(child: _buildPreview(profile)),
      ],
    );
  }

  Widget _buildMobileView(BusinessProfile profile) {
    return Column(
      children: [
        Expanded(child: _mobileTabIndex == 0 ? _buildEditor(profile) : _buildPreview(profile)),
        BottomNavigationBar(
          currentIndex: _mobileTabIndex,
          onTap: (i) => setState(() => _mobileTabIndex = i),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.edit), label: 'Editor'),
            BottomNavigationBarItem(icon: Icon(Icons.visibility), label: 'Preview'),
          ],
        )
      ],
    );
  }

  Widget _buildEditor(BusinessProfile profile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClientAutocompletePicker(selectedClientId: _selectedClientId, onClientSelected: (id) => setState(() => _selectedClientId = id)),
          const SizedBox(height: 16),
          // Items Grid
          ..._items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  Expanded(child: TextFormField(initialValue: item.description, onChanged: (v) => _updateItem(index, item.copyWith(description: v)))),
                  const SizedBox(width: 8),
                  SizedBox(width: 60, child: TextFormField(initialValue: item.quantity.toString(), onChanged: (v) => _updateItem(index, item.copyWith(quantity: int.tryParse(v) ?? 0)))),
                  const SizedBox(width: 8),
                  SizedBox(width: 100, child: TextFormField(initialValue: (item.unitPriceCents / 100).toStringAsFixed(2), onChanged: (v) => _updateItem(index, item.copyWith(unitPriceCents: (double.tryParse(v)! * 100).toInt())))),
                  IconButton(icon: const Icon(Icons.delete), onPressed: () => _removeItem(index)),
                ],
              ),
            );
          }),
          TextButton.icon(onPressed: _addItem, icon: const Icon(Icons.add), label: const Text('Add Item')),
          const Divider(),
          Text('Subtotal: ${_subtotalCents / 100}'),
          Text('Tax: ${_taxCents / 100}'),
          Text('Total: ${_totalCents / 100}'),
        ],
      ),
    );
  }

  Widget _buildPreview(BusinessProfile profile) {
    return Container(color: Colors.grey.shade200, child: const Center(child: Text('Live A4 Preview (WYSIWYG)')));
  }
}

class LineItem {
  final String description;
  final String sacHsn;
  final int quantity;
  final int unitPriceCents;
  final int taxSlab;

  LineItem({required this.description, required this.sacHsn, required this.quantity, required this.unitPriceCents, required this.taxSlab});

  LineItem copyWith({String? description, String? sacHsn, int? quantity, int? unitPriceCents, int? taxSlab}) {
    return LineItem(
      description: description ?? this.description,
      sacHsn: sacHsn ?? this.sacHsn,
      quantity: quantity ?? this.quantity,
      unitPriceCents: unitPriceCents ?? this.unitPriceCents,
      taxSlab: taxSlab ?? this.taxSlab,
    );
  }
}
