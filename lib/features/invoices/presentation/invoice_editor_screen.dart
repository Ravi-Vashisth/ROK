import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/currency_formatter_provider.dart';
import '../../../core/utils/money_utils.dart';
import '../../billing/presentation/widgets/client_autocomplete_picker.dart';
import '../../business_profile/models/business_profile.dart';
import '../../business_profile/providers/business_profile_provider.dart';
import '../../clients/models/client.dart';
import '../../clients/providers/clients_provider.dart';
import '../../estimates/providers/estimates_provider.dart';
import '../../invoices/providers/invoices_provider.dart';
import '../../items/providers/saved_items_provider.dart';

class LineItemEntry {
  String description;
  String sacHsn;
  int quantity;
  int unitPriceCents;
  int taxSlab;

  LineItemEntry({
    required this.description,
    this.sacHsn = '',
    this.quantity = 1,
    this.unitPriceCents = 0,
    this.taxSlab = 10,
  });

  int get totalCents => quantity * unitPriceCents;
}

class InvoiceEditorScreen extends ConsumerStatefulWidget {
  final bool isQuote;

  const InvoiceEditorScreen({super.key, this.isQuote = false});

  @override
  ConsumerState<InvoiceEditorScreen> createState() => _InvoiceEditorScreenState();
}

class _InvoiceEditorScreenState extends ConsumerState<InvoiceEditorScreen> {
  String? _selectedClientId;
  int _mobileTabIndex = 0; // 0 = Editor, 1 = Preview

  late TextEditingController _issueDateController;
  late TextEditingController _termsController;
  late TextEditingController _notesController;
  String _paymentTerms = 'Due on Receipt';
  String _discountType = 'none'; // 'none', 'percent', 'flat'
  final TextEditingController _discountController = TextEditingController(text: '0');

  final List<LineItemEntry> _items = [
    LineItemEntry(
      description: 'Full-Stack Architecture & Implementation',
      sacHsn: '998311',
      quantity: 1,
      unitPriceCents: 15000,
      taxSlab: 10,
    )
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _issueDateController = TextEditingController(
      text: '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
    );
    final profile = ref.read(businessProfileProvider);
    _termsController = TextEditingController(text: profile.defaultTerms);
    _notesController = TextEditingController(text: profile.defaultNotes);
  }

  @override
  void dispose() {
    _issueDateController.dispose();
    _termsController.dispose();
    _notesController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  void _addItem() {
    setState(() {
      _items.add(LineItemEntry(
        description: '',
        sacHsn: '',
        quantity: 1,
        unitPriceCents: 0,
        taxSlab: 10,
      ));
    });
  }

  void _removeItem(int index) {
    if (_items.length <= 1) return;
    setState(() => _items.removeAt(index));
  }

  int get _subtotalCents => _items.fold(0, (sum, i) => sum + i.totalCents);

  int get _discountCents {
    if (_discountType == 'none') return 0;
    if (_discountType == 'percent') {
      final pct = double.tryParse(_discountController.text.trim()) ?? 0;
      return (_subtotalCents * pct / 100).round();
    }
    return parsePriceToCents(_discountController.text);
  }

  int get _taxCents {
    final subAfterDisc = (_subtotalCents - _discountCents).clamp(0, _subtotalCents);
    return _items.fold(0, (sum, i) {
      if (_subtotalCents <= 0) return sum;
      final lineShare = (i.totalCents * subAfterDisc) ~/ _subtotalCents;
      return sum + (lineShare * i.taxSlab ~/ 100);
    });
  }

  int get _totalCents => (_subtotalCents - _discountCents).clamp(0, _subtotalCents) + _taxCents;

  String _calculateDueDate(String issueDateStr, String terms) {
    try {
      final parts = issueDateStr.split('-');
      if (parts.length != 3) return issueDateStr;
      final issue = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      int addDays = 0;
      if (terms.contains('15')) addDays = 15;
      if (terms.contains('30')) addDays = 30;
      if (terms.contains('60')) addDays = 60;
      final due = issue.add(Duration(days: addDays));
      return '${due.year}-${due.month.toString().padLeft(2, '0')}-${due.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return issueDateStr;
    }
  }

  void _handleSave() {
    if (_selectedClientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a client first.')),
      );
      return;
    }

    if (_items.isEmpty || _items.every((it) => it.description.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one line item with a description.')),
      );
      return;
    }

    final draftItems = _items
        .where((i) => i.description.trim().isNotEmpty)
        .map((i) => DraftItem(
              description: i.description.trim(),
              sacHsn: i.sacHsn.trim(),
              quantity: i.quantity,
              unitPriceCents: i.unitPriceCents,
              totalCents: i.totalCents,
            ))
        .toList();

    final issueDate = _issueDateController.text.trim();
    final dueDate = _calculateDueDate(issueDate, _paymentTerms);

    final discVal = _discountType == 'percent'
        ? (double.tryParse(_discountController.text.trim()) ?? 0).toInt()
        : parsePriceToCents(_discountController.text.trim());

    if (widget.isQuote) {
      ref.read(estimatesProvider.notifier).saveEstimate(
            clientId: _selectedClientId!,
            items: draftItems,
            taxPercentage: _items.isNotEmpty ? _items.first.taxSlab : 10,
            issueDate: issueDate,
            expiryDate: dueDate,
            terms: _termsController.text.trim(),
            notes: _notesController.text.trim(),
            discountType: _discountType,
            discountValue: discVal,
          );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quote saved successfully!')),
      );
    } else {
      ref.read(invoicesProvider.notifier).saveInvoice(
            clientId: _selectedClientId!,
            items: draftItems,
            taxPercentage: _items.isNotEmpty ? _items.first.taxSlab : 10,
            paymentTerms: _paymentTerms,
            issueDate: issueDate,
            dueDate: dueDate,
            terms: _termsController.text.trim(),
            notes: _notesController.text.trim(),
            discountType: _discountType,
            discountValue: discVal,
          );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invoice saved and issued successfully!')),
      );
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final constraints = MediaQuery.of(context).size;
    final isWide = constraints.width >= 1000;
    final profile = ref.watch(businessProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isQuote ? 'Two-Column Live Quote Editor' : 'Two-Column Live Invoice Editor',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel / Back'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            icon: const Icon(Icons.check, size: 16),
            label: Text(widget.isQuote ? 'Save & Issue Quote' : 'Save & Issue Invoice'),
            onPressed: _handleSave,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: isWide ? _buildSplitView(profile) : _buildMobileView(profile),
    );
  }

  Widget _buildSplitView(BusinessProfile profile) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 1,
          child: _buildEditor(profile),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          flex: 1,
          child: _buildPreview(profile),
        ),
      ],
    );
  }

  Widget _buildMobileView(BusinessProfile profile) {
    return Column(
      children: [
        Expanded(
          child: _mobileTabIndex == 0 ? _buildEditor(profile) : _buildPreview(profile),
        ),
        NavigationBar(
          selectedIndex: _mobileTabIndex,
          onDestinationSelected: (i) => setState(() => _mobileTabIndex = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.edit_note), label: 'Editor'),
            NavigationDestination(icon: Icon(Icons.preview_outlined), label: 'Live A4 Preview'),
          ],
        ),
      ],
    );
  }

  Widget _buildEditor(BusinessProfile profile) {
    final catalog = ref.watch(savedItemsProvider);
    final formatCurrency = ref.watch(currencyFormatterProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Client Autocomplete Picker
          Text(
            'Client & Billing Particulars',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          ClientAutocompletePicker(
            selectedClientId: _selectedClientId,
            onClientSelected: (id) => setState(() => _selectedClientId = id),
          ),
          const SizedBox(height: 16),

          // Date & Terms Row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _issueDateController,
                  decoration: const InputDecoration(
                    labelText: 'Issue Date',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _paymentTerms,
                  decoration: const InputDecoration(
                    labelText: 'Payment Terms',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Due on Receipt', child: Text('Due on Receipt')),
                    DropdownMenuItem(value: 'Net 15 Days', child: Text('Net 15 Days')),
                    DropdownMenuItem(value: 'Net 30 Days', child: Text('Net 30 Days')),
                    DropdownMenuItem(value: 'Net 60 Days', child: Text('Net 60 Days')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _paymentTerms = val);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Catalog Quick Insert Dropdown
          if (catalog.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.flash_on, size: 16, color: Colors.amber),
                const SizedBox(width: 6),
                const Text('Quick-Insert from Catalog:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    hint: const Text('Select preset item...', style: TextStyle(fontSize: 12)),
                    underline: const SizedBox(),
                    items: catalog.map((item) {
                      return DropdownMenuItem(
                        value: item.id,
                        child: Text('${item.title} (${formatCurrency(item.defaultPriceCents)})', style: const TextStyle(fontSize: 12)),
                      );
                    }).toList(),
                    onChanged: (itemId) {
                      if (itemId == null) return;
                      final item = catalog.firstWhere((it) => it.id == itemId);
                      setState(() {
                        _items.add(LineItemEntry(
                          description: item.title,
                          sacHsn: item.sacHsn,
                          quantity: 1,
                          unitPriceCents: item.defaultPriceCents,
                          taxSlab: 10,
                        ));
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // Line Items Table
          Text(
            'Line Items',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          ..._items.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            initialValue: item.description,
                            decoration: const InputDecoration(
                              labelText: 'Description *',
                              isDense: true,
                            ),
                            onChanged: (v) => setState(() => item.description = v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 1,
                          child: TextFormField(
                            initialValue: item.sacHsn,
                            decoration: const InputDecoration(
                              labelText: 'SAC/HSN',
                              isDense: true,
                            ),
                            onChanged: (v) => setState(() => item.sacHsn = v),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                          onPressed: () => _removeItem(idx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: item.quantity.toString(),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Qty',
                              isDense: true,
                            ),
                            onChanged: (v) => setState(() => item.quantity = int.tryParse(v) ?? 1),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            initialValue: (item.unitPriceCents / 100).toStringAsFixed(2),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Price',
                              isDense: true,
                            ),
                            onChanged: (v) => setState(() => item.unitPriceCents = parsePriceToCents(v)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: item.taxSlab,
                            decoration: const InputDecoration(
                              labelText: 'Tax Slab',
                              isDense: true,
                            ),
                            items: const [
                              DropdownMenuItem(value: 0, child: Text('0%')),
                              DropdownMenuItem(value: 5, child: Text('5%')),
                              DropdownMenuItem(value: 10, child: Text('10%')),
                              DropdownMenuItem(value: 12, child: Text('12%')),
                              DropdownMenuItem(value: 18, child: Text('18%')),
                            ],
                            onChanged: (v) {
                              if (v != null) setState(() => item.taxSlab = v);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          formatCurrency(item.totalCents),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),

          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Line Item'),
              onPressed: _addItem,
            ),
          ),
          const SizedBox(height: 16),

          // Discount Selector
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _discountType,
                  decoration: const InputDecoration(labelText: 'Discount Type', isDense: true),
                  items: const [
                    DropdownMenuItem(value: 'none', child: Text('None')),
                    DropdownMenuItem(value: 'percent', child: Text('Percentage (%)')),
                    DropdownMenuItem(value: 'flat', child: Text('Flat Amount')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _discountType = val);
                  },
                ),
              ),
              if (_discountType != 'none') ...[
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _discountController,
                    decoration: InputDecoration(
                      labelText: _discountType == 'percent' ? 'Discount %' : 'Discount Amount',
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // Terms & Notes
          TextField(
            controller: _termsController,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Payment Terms / Conditions', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Notes / Remarks', border: OutlineInputBorder()),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(BusinessProfile profile) {
    final clients = ref.watch(clientsProvider);
    final formatCurrency = ref.watch(currencyFormatterProvider);
    final client = _selectedClientId != null
        ? clients.firstWhere(
            (c) => c.id == _selectedClientId,
            orElse: () => Client(id: '', name: 'Selected Client', createdAt: ''),
          )
        : null;

    return Container(
      color: Colors.grey.shade100,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 580,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.businessName.isNotEmpty ? profile.businessName : 'My Freelance Studio',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        if (profile.email.isNotEmpty) Text(profile.email, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        if (profile.phone.isNotEmpty) Text(profile.phone, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        if (profile.taxId.isNotEmpty) Text('Tax ID: ${profile.taxId}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: widget.isQuote ? Colors.amber.shade50 : Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        widget.isQuote ? 'ESTIMATE / QUOTE' : 'TAX INVOICE',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: widget.isQuote ? Colors.amber.shade900 : Colors.indigo.shade900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 28),

                // Bill To & Meta
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('BILL TO:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                        Text(client?.name ?? 'Select a Client', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        if (client != null && client.email.isNotEmpty) Text(client.email, style: const TextStyle(fontSize: 11)),
                        if (client != null && client.taxId.isNotEmpty) Text('Tax ID: ${client.taxId}', style: const TextStyle(fontSize: 11)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Date: ${_issueDateController.text}', style: const TextStyle(fontSize: 11)),
                        Text('Terms: $_paymentTerms', style: const TextStyle(fontSize: 11)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Items Table
                Table(
                  columnWidths: const {
                    0: FlexColumnWidth(4),
                    1: FlexColumnWidth(1),
                    2: FlexColumnWidth(2),
                    3: FlexColumnWidth(2),
                  },
                  children: [
                    const TableRow(
                      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black26))),
                      children: [
                        Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Item', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Qty', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Rate', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Amount', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                      ],
                    ),
                    ..._items.map((i) => TableRow(
                          children: [
                            Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(i.description.isNotEmpty ? i.description : '—', style: const TextStyle(fontSize: 11))),
                            Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text('${i.quantity}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11))),
                            Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(formatCurrency(i.unitPriceCents), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11))),
                            Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(formatCurrency(i.totalCents), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                          ],
                        )),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),

                // Totals
                Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: 220,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Subtotal:', style: TextStyle(fontSize: 11)),
                            Text(formatCurrency(_subtotalCents), style: const TextStyle(fontSize: 11)),
                          ],
                        ),
                        if (_discountCents > 0) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Discount:', style: TextStyle(fontSize: 11, color: Colors.orange)),
                              Text('-${formatCurrency(_discountCents)}', style: const TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Tax:', style: TextStyle(fontSize: 11)),
                            Text(formatCurrency(_taxCents), style: const TextStyle(fontSize: 11)),
                          ],
                        ),
                        const Divider(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            Text(formatCurrency(_totalCents), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                if (profile.paymentDetails.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Payment Instructions:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(profile.paymentDetails, style: const TextStyle(fontSize: 10, color: Colors.black87)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
