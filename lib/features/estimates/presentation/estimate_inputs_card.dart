import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money_utils.dart';
import '../../../core/utils/tax_compliance_utils.dart';
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
    String taxMode,
    int pstRatePercentage,
    String taxExemptionId,
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
  final _sacHsnController = TextEditingController();
  final _unitPriceController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _taxPercentageController = TextEditingController(text: '10');
  final _discountValueController = TextEditingController(text: '0');
  late final TextEditingController _issueDateController;
  late final TextEditingController _expiryDateController;
  late final TextEditingController _termsController;
  late final TextEditingController _notesController;
  late final TextEditingController _pstRateController;
  late final TextEditingController _exemptionIdController;

  String _discountType = 'none'; // 'none', 'percent', 'flat'
  late String _taxMode;
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
    _taxMode = normalizeTaxMode(profile.defaultTaxMode);
    _pstRateController = TextEditingController(text: profile.defaultPstRatePercentage.toString());
    _exemptionIdController = TextEditingController();

    _cartItems.addAll(const [
      DraftItem(description: 'System Architecture Proposal', sacHsn: '998311', unitPriceCents: 12000, quantity: 1, totalCents: 12000),
      DraftItem(description: 'UI/UX Design Mockups', sacHsn: '998314', unitPriceCents: 8000, quantity: 1, totalCents: 8000),
    ]);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _sacHsnController.dispose();
    _unitPriceController.dispose();
    _quantityController.dispose();
    _taxPercentageController.dispose();
    _discountValueController.dispose();
    _issueDateController.dispose();
    _expiryDateController.dispose();
    _termsController.dispose();
    _notesController.dispose();
    _pstRateController.dispose();
    _exemptionIdController.dispose();
    super.dispose();
  }

  void _onSelectSavedItem(SavedItem? item) {
    final profile = ref.read(businessProfileProvider);
    setState(() {
      _selectedSavedItem = item;
      if (item != null) {
        _descriptionController.text = item.title;
        _sacHsnController.text = item.sacHsn;
        _unitPriceController.text = formatDecimalUnits(item.defaultPriceCents, profile.currencyDecimals);
      }
    });
  }

  void _addCartItem() {
    final desc = _descriptionController.text.trim();
    final sacHsn = _sacHsnController.text.trim();
    if (desc.isEmpty) return;

    final profile = ref.read(businessProfileProvider);
    final unitPriceCents = parsePriceToUnits(_unitPriceController.text, profile.currencyDecimals);
    final quantity = int.tryParse(_quantityController.text) ?? 1;
    if (unitPriceCents <= 0 || quantity <= 0) return;

    if (_saveAsPreset) {
      ref.read(savedItemsProvider.notifier).addItem(
            title: desc,
            sacHsn: sacHsn,
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
          sacHsn: sacHsn,
          unitPriceCents: unitPriceCents,
          quantity: quantity,
          totalCents: unitPriceCents * quantity,
        ),
      );
      _descriptionController.clear();
      _sacHsnController.clear();
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
    final dec = profile.currencyDecimals;
    final savedItems = ref.watch(savedItemsProvider);

    final subtotalCents = _cartItems.fold<int>(0, (sum, i) => sum + i.totalCents);

    int discountVal = 0;
    if (_discountType == 'percent') {
      discountVal = int.tryParse(_discountValueController.text.trim()) ?? 0;
    } else if (_discountType == 'flat') {
      discountVal = parsePriceToUnits(_discountValueController.text, dec);
    }

    final discountCents = calculateDiscountCents(subtotalCents, _discountType, discountVal);
    final netSubtotalCents = (subtotalCents - discountCents) > 0 ? (subtotalCents - discountCents) : 0;
    final taxPct = int.tryParse(_taxPercentageController.text) ?? 0;
    final pstPct = (int.tryParse(_pstRateController.text.trim()) ?? 0).clamp(0, 100);
    final taxCents = computeRegionalTaxCents(
      netSubtotalCents: netSubtotalCents,
      taxMode: _taxMode,
      taxPercentage: taxPct,
      pstRatePercentage: pstPct,
    );
    final breakdown = resolveRegionalTaxBreakdown(
      taxMode: _taxMode,
      netSubtotalCents: netSubtotalCents,
      taxCents: taxCents,
      pstRatePercentage: pstPct,
      taxExemptionId: _exemptionIdController.text,
      businessTaxId: profile.taxId,
    );
    final totalCents = netSubtotalCents + taxCents;

    final descriptionField = TextField(
      controller: _descriptionController,
      decoration: const InputDecoration(
        labelText: 'Item / Service Description',
        hintText: 'e.g. Website Redesign Consultation',
      ),
    );

    final sacHsnField = TextField(
      controller: _sacHsnController,
      decoration: const InputDecoration(
        labelText: 'SAC / HSN',
        hintText: '998311',
      ),
    );

    final priceField = TextField(
      controller: _unitPriceController,
      keyboardType: dec == 0
          ? TextInputType.number
          : const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: 'Price ($sym)',
        prefixText: '$sym ',
      ),
    );

    final quantityField = TextField(
      controller: _quantityController,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(labelText: 'Qty'),
    );

    final addButton = IconButton.filledTonal(
      onPressed: _addCartItem,
      icon: const Icon(Icons.add_shopping_cart),
      tooltip: 'Add Line Item',
    );

    final discountTypeDropdown = DropdownButtonFormField<String>(
      value: _discountType,
      isExpanded: true,
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
    );

    final discountValueField = TextField(
      controller: _discountValueController,
      keyboardType: dec == 0 && _discountType == 'flat'
          ? TextInputType.number
          : const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: _discountType == 'percent' ? 'Discount %' : 'Flat ($sym)',
        suffixText: _discountType == 'percent' ? '%' : sym,
      ),
      onChanged: (_) => setState(() {}),
    );

    final taxPctField = TextField(
      controller: _taxPercentageController,
      enabled: !isZeroRatedTaxMode(_taxMode),
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: _taxMode == TaxMode.caDual ? 'GST %' : 'Tax %'),
      onChanged: (_) => setState(() {}),
    );

    final taxModeDropdown = DropdownButtonFormField<String>(
      value: _taxMode,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Tax Compliance Mode',
        prefixIcon: Icon(Icons.public_outlined, size: 18),
      ),
      items: TaxMode.all.map((mode) {
        return DropdownMenuItem<String>(
          value: mode,
          child: Text(taxModeLabels[mode] ?? mode, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
        );
      }).toList(),
      onChanged: (val) {
        if (val != null) setState(() => _taxMode = val);
      },
    );

    final issueDateField = TextField(
      controller: _issueDateController,
      decoration: const InputDecoration(labelText: 'Issue Date'),
    );

    final expiryDateField = TextField(
      controller: _expiryDateController,
      decoration: const InputDecoration(labelText: 'Expiry Date (Valid Until)'),
    );

    final termsField = TextField(
      controller: _termsController,
      minLines: 3,
      maxLines: null,
      keyboardType: TextInputType.multiline,
      decoration: const InputDecoration(
        labelText: 'Estimate Terms / Proposal Notice',
        hintText: 'Quote valid for 30 days...',
        prefixIcon: Icon(Icons.gavel_outlined, size: 18),
      ),
    );

    final notesField = TextField(
      controller: _notesController,
      minLines: 3,
      maxLines: null,
      keyboardType: TextInputType.multiline,
      decoration: const InputDecoration(
        labelText: 'Estimate Notes / Scope Highlights',
        hintText: 'Includes 30 days post-delivery support.',
        prefixIcon: Icon(Icons.notes_outlined, size: 18),
      ),
    );

    return Card(
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.request_quote_outlined, color: Colors.indigo),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Create Estimate / Quote',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.indigo.shade200),
                  ),
                  child: Text(
                    widget.nextEstimateNumber,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
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
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.indigo.shade200),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const labelRow = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bookmark_outline, size: 18, color: Colors.indigo),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Saved Service Library:',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    );

                    final dropdown = DropdownButtonFormField<SavedItem>(
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
                            '${item.title} (${formatMoney(item.defaultPriceCents, symbol: sym, decimals: dec)})',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        );
                      }).toList(),
                      onChanged: _onSelectSavedItem,
                    );

                    if (constraints.maxWidth < 520) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          labelRow,
                          const SizedBox(height: 8),
                          dropdown,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        labelRow,
                        const SizedBox(width: 12),
                        Expanded(child: dropdown),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],

            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 520) {
                  return Column(
                    children: [
                      descriptionField,
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(flex: 3, child: priceField),
                          const SizedBox(width: 8),
                          Expanded(flex: 2, child: quantityField),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: sacHsnField),
                          const SizedBox(width: 8),
                          addButton,
                        ],
                      ),
                    ],
                  );
                }
                if (constraints.maxWidth < 820) {
                  return Column(
                    children: [
                      descriptionField,
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(flex: 2, child: sacHsnField),
                          const SizedBox(width: 8),
                          Expanded(flex: 2, child: priceField),
                          const SizedBox(width: 8),
                          Expanded(flex: 1, child: quantityField),
                          const SizedBox(width: 8),
                          addButton,
                        ],
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(flex: 3, child: descriptionField),
                    const SizedBox(width: 8),
                    Expanded(flex: 2, child: sacHsnField),
                    const SizedBox(width: 8),
                    Expanded(flex: 2, child: priceField),
                    const SizedBox(width: 8),
                    Expanded(flex: 1, child: quantityField),
                    const SizedBox(width: 8),
                    addButton,
                  ],
                );
              },
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Checkbox(
                  value: _saveAsPreset,
                  onChanged: (v) => setState(() => _saveAsPreset = v ?? false),
                ),
                Expanded(
                  child: Text(
                    'Save as preset service in library for future 1-click use',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),

            if (_cartItems.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Proposed Items:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(12),
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
                      subtitle: Text(
                        '${item.sacHsn.isNotEmpty ? "SAC/HSN: ${item.sacHsn} • " : ""}${item.quantity} × ${formatMoney(item.unitPriceCents, symbol: sym, decimals: dec)}',
                        style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            formatMoney(item.totalCents, symbol: sym, decimals: dec),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
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
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 600) {
                  return Column(
                    children: [
                      discountTypeDropdown,
                      const SizedBox(height: 10),
                      if (_discountType != 'none')
                        Row(
                          children: [
                            Expanded(child: discountValueField),
                            const SizedBox(width: 10),
                            Expanded(child: taxPctField),
                          ],
                        )
                      else
                        taxPctField,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(flex: 3, child: discountTypeDropdown),
                    if (_discountType != 'none') ...[
                      const SizedBox(width: 10),
                      Expanded(flex: 2, child: discountValueField),
                    ],
                    const SizedBox(width: 10),
                    Expanded(flex: 2, child: taxPctField),
                  ],
                );
              },
            ),

            const SizedBox(height: 12),
            taxModeDropdown,
            if (_taxMode == TaxMode.caDual) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _pstRateController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'PST Rate (%)', hintText: '7', suffixText: '%'),
                onChanged: (_) => setState(() {}),
              ),
            ],
            if (_taxMode == TaxMode.usExempt) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _exemptionIdController,
                decoration: const InputDecoration(labelText: 'Tax Exemption Certificate ID (Optional)'),
                onChanged: (_) => setState(() {}),
              ),
            ],

            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 600) {
                  return Column(
                    children: [
                      issueDateField,
                      const SizedBox(height: 12),
                      expiryDateField,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: issueDateField),
                    const SizedBox(width: 12),
                    Expanded(child: expiryDateField),
                  ],
                );
              },
            ),

            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 600) {
                  return Column(
                    children: [
                      termsField,
                      const SizedBox(height: 12),
                      notesField,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: termsField),
                    const SizedBox(width: 12),
                    Expanded(child: notesField),
                  ],
                );
              },
            ),

            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 6,
                children: [
                  Text(
                    'Subtotal: ${formatMoney(subtotalCents, symbol: sym, decimals: dec)}',
                    style: const TextStyle(fontSize: 12, fontFeatures: [FontFeature.tabularFigures()]),
                  ),
                  if (discountCents > 0)
                    Text(
                      'Discount: -${formatMoney(discountCents, symbol: sym, decimals: dec)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade800,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ...breakdown.lines.map((line) => Text(
                        '${line.label}: ${formatMoney(line.cents, symbol: sym, decimals: dec)}',
                        style: const TextStyle(fontSize: 12, fontFeatures: [FontFeature.tabularFigures()]),
                      )),
                  Text(
                    'Total: ${formatMoney(totalCents, symbol: sym, decimals: dec)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
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
                          taxPercentage: isZeroRatedTaxMode(_taxMode) ? 0 : taxPct,
                          issueDate: _issueDateController.text,
                          expiryDate: _expiryDateController.text,
                          terms: _termsController.text.trim(),
                          notes: _notesController.text.trim(),
                          discountType: _discountType,
                          discountValue: discountVal,
                          taxMode: _taxMode,
                          pstRatePercentage: _taxMode == TaxMode.caDual ? pstPct : 0,
                          taxExemptionId: _taxMode == TaxMode.usExempt ? _exemptionIdController.text.trim() : '',
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
