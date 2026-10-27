import 'package:flutter/material.dart';

import '../../../../core/utils/money_utils.dart';
import '../../../invoices/providers/invoices_provider.dart';

class InvoiceInputsCard extends StatefulWidget {
  final String nextInvoiceNumber;
  final void Function({
    required List<DraftItem> items,
    required int taxPercentage,
    required String paymentTerms,
    required String issueDate,
    required String dueDate,
  }) onSaveInvoice;

  const InvoiceInputsCard({
    super.key,
    required this.nextInvoiceNumber,
    required this.onSaveInvoice,
  });

  @override
  State<InvoiceInputsCard> createState() => _InvoiceInputsCardState();
}

class _InvoiceInputsCardState extends State<InvoiceInputsCard> {
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _taxPercentageController = TextEditingController(text: '10');
  late final TextEditingController _issueDateController;

  String _paymentTerms = 'Due on Receipt';
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
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _taxPercentageController.dispose();
    _issueDateController.dispose();
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
    final issueDate = _issueDateController.text.trim();
    final dueDate = _calculateDueDate();

    widget.onSaveInvoice(
      items: List.from(_draftItems),
      taxPercentage: taxPercentage,
      paymentTerms: _paymentTerms,
      issueDate: issueDate,
      dueDate: dueDate,
    );

    setState(() {
      _draftItems.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final subtotalCents = _draftItems.fold<int>(0, (sum, item) => sum + item.totalCents);
    final taxPercentage = int.tryParse(_taxPercentageController.text.trim()) ?? 0;
    final taxCents = calculateTaxCents(subtotalCents, taxPercentage);
    final totalCents = subtotalCents + taxCents;
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
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Price (\$)',
                      hintText: '25.00',
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

            const SizedBox(height: 16),

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
                              Expanded(flex: 2, child: Text(formatCents(item.unitPriceCents), textAlign: TextAlign.right)),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  formatCents(item.totalCents),
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

            // Tax & Summary Row
            Row(
              children: [
                SizedBox(
                  width: 140,
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
                const SizedBox(width: 24),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'Items: ${_draftItems.length} | '
                        'Subtotal: ${formatCents(subtotalCents)} | '
                        'Tax: ${formatCents(taxCents)} | ',
                        style: const TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      Text(
                        'Total: ${formatCents(totalCents)}',
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
