import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money_utils.dart';
import '../../business_profile/providers/business_profile_provider.dart';
import '../../invoices/providers/invoices_provider.dart';
import '../../items/models/saved_item.dart';
import '../../items/providers/saved_items_provider.dart';

class EstimateInputsCard extends ConsumerStatefulWidget {
  final String nextEstimateNumber;
  final void Function({
    required List<DraftItem> items,
    required int taxPercentage,
    required String issueDate,
    required String expiryDate,
    required String terms,
    required String notes,
    required String discountType,
    required int discountValue,
  }) onSaveEstimate;

  const EstimateInputsCard({
    super.key,
    required this.nextEstimateNumber,
    required this.onSaveEstimate,
  });

  @override
  ConsumerState<EstimateInputsCard> createState() => _EstimateInputsCardState();
}

class _EstimateInputsCardState extends ConsumerState<EstimateInputsCard> {
  final _descriptionController = TextEditingController();
  final _unitPriceController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _taxPercentageController = TextEditingController(text: '10');
  final _discountValueController = TextEditingController(text: '0');
  late final TextEditingController _issueDateController;
  late final TextEditingController _expiryDateController;
  late final TextEditingController _termsController;
  late final TextEditingController _notesController;

  String _discountType = 'none'; // 'none', 'percent', 'flat'
  bool _saveAsPreset = false;
  SavedItem? _selectedSavedItem;
  final List<DraftItem> _cartItems = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final exp = now.add(const Duration(days: 30));
    _issueDateController = TextEditingController(
      text: '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
    );
    _expiryDateController = TextEditingController(
      text: '${exp.year}-${exp.month.toString().padLeft(2, '0')}-${exp.day.toString().padLeft(2, '0')}',
    );

    final profile = ref.read(businessProfileProvider);
    _termsController = TextEditingController(text: profile.defaultTerms);
    _notesController = TextEditingController(text: profile.defaultNotes);

    _cartItems.addAll(const [
      DraftItem(description: 'System Architecture Proposal', unitPriceCents: 12000, quantity: 1, totalCents: 12000),
      DraftItem(description: 'UI/UX Design Mockups', unitPriceCents: 8000, quantity: 1, totalCents: 8000),
    ]);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _unitPriceController.dispose();
    _quantityController.dispose();
    _taxPercentageController.dispose();
    _discountValueController.dispose();
    _issueDateController.dispose();
    _expiryDateController.dispose();
    _termsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onSelectSavedItem(SavedItem? item) {
    setState(() {
      _selectedSavedItem = item;
      if (item != null) {
        _descriptionController.text = item.title;
        _unitPriceController.text = (item.defaultPriceCents / 100.0).toStringAsFixed(2);
      }
    });
  }

  void _addCartItem() {
    final desc = _descriptionController.text.trim();
    if (desc.isEmpty) return;

    final unitPriceCents = parsePriceToCents(_unitPriceController.text);
    final quantity = int.tryParse(_quantityController.text) ?? 1;
    if (unitPriceCents <= 0 || quantity <= 0) return;

    if (_saveAsPreset) {
      ref.read(savedItemsProvider.notifier).addItem(
            title: desc,
            defaultPriceCents: unitPriceCents,
            description: '',
          );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved "$desc" as a preset service!')),
      );
    }

    setState(() {
      _cartItems.add(
        DraftItem(
          description: desc,
          unitPriceCents: unitPriceCents,
          quantity: quantity,
          totalCents: unitPriceCents * quantity,
        ),
      );
      _descriptionController.clear();
      _unitPriceController.clear();
      _quantityController.text = '1';
      _saveAsPreset = false;
      _selectedSavedItem = null;
    });
  }

  void _removeCartItem(int index) {
    setState(() {
      _cartItems.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(businessProfileProvider);
    final sym = profile.currencySymbol;
    final savedItems = ref.watch(savedItemsProvider);

    final subtotalCents = _cartItems.fold<int>(0, (sum, i) => sum + i.totalCents);

    int discountVal = 0;
    if (_discountType == 'percent') {
      discountVal = int.tryParse(_discountValueController.text.trim()) ?? 0;
    } else if (_discountType == 'flat') {
      discountVal = parsePriceToCents(_discountValueController.text);
    }

    final discountCents = calculateDiscountCents(subtotalCents, _discountType, discountVal);
    final netSubtotalCents = (subtotalCents - discountCents) > 0 ? (subtotalCents - discountCents) : 0;
    final taxPct = int.tryParse(_taxPercentageController.text) ?? 0;
    final taxCents = calculateTaxCents(netSubtotalCents, taxPct);
    final totalCents = netSubtotalCents + taxCents;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.request_quote_outlined, color: Colors.indigo),
                const SizedBox(width: 8),
                const Text(
                  'Create Estimate / Quote',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.indigo.shade200),
                  ),
                  child: Text(
                    widget.nextEstimateNumber,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Preset Services Library Dropdown
            if (savedItems.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.indigo.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bookmark_outline, size: 18, color: Colors.indigo),
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

            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Item / Service Description',
                      hintText: 'e.g. Website Redesign Consultation',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _unitPriceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Price ($sym)',
                      prefixText: '$sym ',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Qty'),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  onPressed: _addCartItem,
                  icon: const Icon(Icons.add_shopping_cart),
                  tooltip: 'Add Line Item',
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

            if (_cartItems.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Proposed Items:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _cartItems.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = _cartItems[index];
                    return ListTile(
                      dense: true,
                      title: Text(item.description, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${item.quantity} × ${formatCents(item.unitPriceCents, symbol: sym)}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(formatCents(item.totalCents, symbol: sym), style: const TextStyle(fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16, color: Colors.red),
                            onPressed: () => _removeCartItem(index),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],

            const SizedBox(height: 16),
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
                  const SizedBox(width: 10),
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
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _taxPercentageController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Tax %'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _issueDateController,
                    decoration: const InputDecoration(labelText: 'Issue Date'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _expiryDateController,
                    decoration: const InputDecoration(labelText: 'Expiry Date (Valid Until)'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _termsController,
                    minLines: 3,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    decoration: const InputDecoration(
                      labelText: 'Estimate Terms / Proposal Notice',
                      hintText: 'Quote valid for 30 days...',
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
                      labelText: 'Estimate Notes / Scope Highlights',
                      hintText: 'Includes 30 days post-delivery support.',
                      prefixIcon: Icon(Icons.notes_outlined, size: 18),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Subtotal: ${formatCents(subtotalCents, symbol: sym)}', style: const TextStyle(fontSize: 12)),
                  if (discountCents > 0)
                    Text('Discount: -${formatCents(discountCents, symbol: sym)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange.shade800)),
                  Text('Tax: ${formatCents(taxCents, symbol: sym)}', style: const TextStyle(fontSize: 12)),
                  Text('Total: ${formatCents(totalCents, symbol: sym)}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.indigo.shade700)),
                ],
              ),
            ),

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _cartItems.isEmpty
                    ? null
                    : () {
                        widget.onSaveEstimate(
                          items: List.from(_cartItems),
                          taxPercentage: taxPct,
                          issueDate: _issueDateController.text,
                          expiryDate: _expiryDateController.text,
                          terms: _termsController.text.trim(),
                          notes: _notesController.text.trim(),
                          discountType: _discountType,
                          discountValue: discountVal,
                        );
                      },
                icon: const Icon(Icons.send_outlined),
                label: const Text('Save Estimate / Proposal'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
