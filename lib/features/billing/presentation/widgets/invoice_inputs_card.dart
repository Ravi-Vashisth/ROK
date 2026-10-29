import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/money_utils.dart';
import '../../../business_profile/providers/business_profile_provider.dart';
import '../../../invoices/providers/invoices_provider.dart';
import '../../../items/models/saved_item.dart';
import '../../../items/providers/saved_items_provider.dart';

class InvoiceInputsCard extends ConsumerStatefulWidget {
  final String nextInvoiceNumber;
  final void Function({
    required List<DraftItem> items,
    required int taxPercentage,
    required String paymentTerms,
    required String issueDate,
    required String dueDate,
    required String terms,
    required String notes,
    required String discountType,
    required int discountValue,
  }) onSaveInvoice;

  const InvoiceInputsCard({
    super.key,
    required this.nextInvoiceNumber,
    required this.onSaveInvoice,
  });

  @override
  ConsumerState<InvoiceInputsCard> createState() => _InvoiceInputsCardState();
}

class _InvoiceInputsCardState extends ConsumerState<InvoiceInputsCard> {
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _taxPercentageController = TextEditingController(text: '10');
  final _discountValueController = TextEditingController(text: '0');
  late final TextEditingController _issueDateController;
  late final TextEditingController _termsController;
  late final TextEditingController _notesController;

  String _paymentTerms = 'Due on Receipt';
  String _discountType = 'none'; // 'none', 'percent', 'flat'
  bool _saveAsPreset = false;
  SavedItem? _selectedSavedItem;
  final List<DraftItem> _draftItems = [];

  static const List<String> _termsOptions = [
    'Due on Receipt',
    'Net 15 Days',
    'Net 30 Days',
    'Net 60 Days',
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
    _descriptionController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _taxPercentageController.dispose();
    _discountValueController.dispose();
    _issueDateController.dispose();
    _termsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _calculateDueDate() {
    final issueText = _issueDateController.text.trim();
    DateTime issue;
    try {
      issue = DateTime.parse(issueText);
    } catch (_) {
      issue = DateTime.now();
    }

    int days = 0;
    if (_paymentTerms == 'Net 15 Days') days = 15;
    if (_paymentTerms == 'Net 30 Days') days = 30;
    if (_paymentTerms == 'Net 60 Days') days = 60;

    final due = issue.add(Duration(days: days));
    return '${due.year}-${due.month.toString().padLeft(2, '0')}-${due.day.toString().padLeft(2, '0')}';
  }

  void _onSelectSavedItem(SavedItem? item) {
    setState(() {
      _selectedSavedItem = item;
      if (item != null) {
        _descriptionController.text = item.title;
        _priceController.text = (item.defaultPriceCents / 100.0).toStringAsFixed(2);
      }
    });
  }

  void _handleAddLineItem() {
    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an item description.')),
      );
      return;
    }

    final unitPriceCents = parsePriceToCents(_priceController.text);
    if (unitPriceCents <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid unit price.')),
      );
      return;
    }

    final quantity = int.tryParse(_quantityController.text.trim()) ?? 1;
    if (quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quantity must be at least 1.')),
      );
      return;
    }

    final totalCents = unitPriceCents * quantity;

    if (_saveAsPreset) {
      ref.read(savedItemsProvider.notifier).addItem(
            title: description,
            defaultPriceCents: unitPriceCents,
            description: '',
          );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved "$description" as a preset service!')),
      );
    }

    setState(() {
      _draftItems.add(DraftItem(
        description: description,
        unitPriceCents: unitPriceCents,
        quantity: quantity,
        totalCents: totalCents,
      ));
      _descriptionController.clear();
      _priceController.clear();
      _quantityController.text = '1';
      _saveAsPreset = false;
      _selectedSavedItem = null;
    });
  }

  void _handleRemoveItem(int index) {
    setState(() {
      _draftItems.removeAt(index);
    });
  }

  void _handleSave() {
    if (_draftItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one line item before saving.')),
      );
      return;
    }

    final taxPercentage = int.tryParse(_taxPercentageController.text.trim()) ?? 0;
    int discountVal = 0;
    if (_discountType == 'percent') {
      discountVal = int.tryParse(_discountValueController.text.trim()) ?? 0;
    } else if (_discountType == 'flat') {
      discountVal = parsePriceToCents(_discountValueController.text);
    }

    final issueDate = _issueDateController.text.trim();
    final dueDate = _calculateDueDate();

    widget.onSaveInvoice(
      items: List.from(_draftItems),
      taxPercentage: taxPercentage,
      paymentTerms: _paymentTerms,
      issueDate: issueDate,
      dueDate: dueDate,
      terms: _termsController.text.trim(),
      notes: _notesController.text.trim(),
      discountType: _discountType,
      discountValue: discountVal,
    );

    setState(() {
      _draftItems.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(businessProfileProvider);
    final sym = profile.currencySymbol;
    final savedItems = ref.watch(savedItemsProvider);

    final subtotalCents = _draftItems.fold<int>(0, (sum, item) => sum + item.totalCents);
    
    int discountVal = 0;
    if (_discountType == 'percent') {
      discountVal = int.tryParse(_discountValueController.text.trim()) ?? 0;
    } else if (_discountType == 'flat') {
      discountVal = parsePriceToCents(_discountValueController.text);
    }

    final discountCents = calculateDiscountCents(subtotalCents, _discountType, discountVal);
    final netSubtotalCents = (subtotalCents - discountCents) > 0 ? (subtotalCents - discountCents) : 0;
    final taxPercentage = int.tryParse(_taxPercentageController.text.trim()) ?? 0;
    final taxCents = calculateTaxCents(netSubtotalCents, taxPercentage);
    final totalCents = netSubtotalCents + taxCents;
    final computedDueDate = _calculateDueDate();

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
            // Card Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '2. Invoice Line Items & Payment Terms',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  'Next: ${widget.nextInvoiceNumber}',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Payment Terms & Issue Date Row
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _issueDateController,
                    decoration: const InputDecoration(
                      labelText: 'Issue Date (YYYY-MM-DD)',
                      prefixIcon: Icon(Icons.calendar_today, size: 18),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    value: _paymentTerms,
                    decoration: const InputDecoration(
                      labelText: 'Payment Terms',
                      prefixIcon: Icon(Icons.timer_outlined, size: 18),
                    ),
                    items: _termsOptions.map((terms) {
                      return DropdownMenuItem<String>(
                        value: terms,
                        child: Text(terms),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _paymentTerms = val);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.event_available,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Computed Due Date:',
                                style: TextStyle(fontSize: 10, color: Colors.grey),
                              ),
                              Text(
                                computedDueDate,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Quick Select Saved Preset Service Library
            if (savedItems.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bookmark_outline, size: 18, color: Colors.blue),
                    const SizedBox(width: 8),
                    const Text(
                      'Saved Service Library:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<SavedItem>(
                        value: _selectedSavedItem,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          hintText: 'Select a preset service to 1-click auto-fill...',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        items: savedItems.map((item) {
                          return DropdownMenuItem<SavedItem>(
                            value: item,
                            child: Text(
                              '${item.title} (${formatCents(item.defaultPriceCents, symbol: sym)})',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                          );
                        }).toList(),
                        onChanged: _onSelectSavedItem,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Item Input Row
            Row(
              children: [
                Expanded(
                  flex: 5,
                  child: TextField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Item Description',
                      hintText: 'e.g. Website Consulting',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Price ($sym)',
                      hintText: '25.00',
                      prefixText: '$sym ',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Qty',
                      hintText: '1',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.tonalIcon(
                  onPressed: _handleAddLineItem,
                  icon: const Icon(Icons.add_shopping_cart, size: 18),
                  label: const Text('Add Item'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Checkbox(
                  value: _saveAsPreset,
                  onChanged: (v) => setState(() => _saveAsPreset = v ?? false),
                ),
                const Text(
                  'Save as preset service in library for future 1-click use',
                  style: TextStyle(fontSize: 12, color: Colors.black87),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Cart Table / Empty state
            if (_draftItems.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: const Center(
                  child: Text(
                    'No items in this invoice yet. Enter item details above and click "Add Item".',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      child: const Row(
                        children: [
                          Expanded(flex: 5, child: Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          Expanded(flex: 2, child: Text('Qty', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          Expanded(flex: 2, child: Text('Unit Price', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          Expanded(flex: 2, child: Text('Total', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          SizedBox(width: 48),
                        ],
                      ),
                    ),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _draftItems.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = _draftItems[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          child: Row(
                            children: [
                              Expanded(flex: 5, child: Text(item.description, style: const TextStyle(fontWeight: FontWeight.w500))),
                              Expanded(flex: 2, child: Text('${item.quantity}', textAlign: TextAlign.center)),
                              Expanded(flex: 2, child: Text(formatCents(item.unitPriceCents, symbol: sym), textAlign: TextAlign.right)),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  formatCents(item.totalCents, symbol: sym),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                              SizedBox(
                                width: 48,
                                child: IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                  onPressed: () => _handleRemoveItem(index),
                                  tooltip: 'Remove Item',
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // Terms & Notes inputs per invoice
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _termsController,
                    minLines: 3,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    decoration: const InputDecoration(
                      labelText: 'Invoice Payment Terms / Legal Notice',
                      hintText: 'Payment due within agreed terms...',
                      prefixIcon: Icon(Icons.gavel_outlined, size: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _notesController,
                    minLines: 3,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    decoration: const InputDecoration(
                      labelText: 'Invoice Notes / Warranty',
                      hintText: 'Thank you for your business!',
                      prefixIcon: Icon(Icons.notes_outlined, size: 18),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Discount & Tax Row
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    value: _discountType,
                    decoration: const InputDecoration(
                      labelText: 'Discount Type',
                      prefixIcon: Icon(Icons.discount_outlined, size: 18),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'none', child: Text('No Discount')),
                      DropdownMenuItem(value: 'percent', child: Text('% Percentage')),
                      DropdownMenuItem(value: 'flat', child: Text('Flat Amount')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _discountType = val;
                          if (val == 'none') _discountValueController.text = '0';
                        });
                      }
                    },
                  ),
                ),
                if (_discountType != 'none') ...[
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _discountValueController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: _discountType == 'percent' ? 'Discount %' : 'Flat ($sym)',
                        suffixText: _discountType == 'percent' ? '%' : sym,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _taxPercentageController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Tax %',
                      hintText: '10',
                      suffixText: '%',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Financial Summary Row
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 12,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text('Subtotal: ${formatCents(subtotalCents, symbol: sym)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      if (discountCents > 0)
                        Text(
                          'Discount: -${formatCents(discountCents, symbol: sym)}',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange.shade800),
                        ),
                      Text('Tax: ${formatCents(taxCents, symbol: sym)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(
                        'Total: ${formatCents(totalCents, symbol: sym)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                FilledButton.icon(
                  onPressed: _draftItems.isEmpty ? null : _handleSave,
                  icon: const Icon(Icons.save),
                  label: const Text('Save Invoice Locally'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
