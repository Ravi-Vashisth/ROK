import 'package:flutter/material.dart';

import '../../../../core/utils/money_utils.dart';

class InvoiceInputsCard extends StatelessWidget {
  final TextEditingController descriptionController;
  final TextEditingController priceController;
  final TextEditingController quantityController;
  final TextEditingController taxPercentageController;
  final VoidCallback onSaveInvoice;
  final VoidCallback onValuesChanged;
  final String nextInvoiceNumber;

  const InvoiceInputsCard({
    super.key,
    required this.descriptionController,
    required this.priceController,
    required this.quantityController,
    required this.taxPercentageController,
    required this.onSaveInvoice,
    required this.onValuesChanged,
    required this.nextInvoiceNumber,
  });

  @override
  Widget build(BuildContext context) {
    final priceCents = parsePriceToCents(priceController.text);
    final quantity = int.tryParse(quantityController.text.trim()) ?? 1;
    final taxPercentage = int.tryParse(taxPercentageController.text.trim()) ?? 0;

    final subtotalCents = priceCents * (quantity > 0 ? quantity : 1);
    final taxCents = calculateTaxCents(subtotalCents, taxPercentage);
    final totalCents = subtotalCents + taxCents;

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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '2. Invoice Inputs',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  'Next: $nextInvoiceNumber',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 4,
                  child: TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Item Description',
                      hintText: 'e.g. Software Consultation',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Price (\$)',
                      hintText: '15.50',
                    ),
                    onChanged: (_) => onValuesChanged(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      hintText: '1',
                    ),
                    onChanged: (_) => onValuesChanged(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: taxPercentageController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Tax %',
                      hintText: '10',
                    ),
                    onChanged: (_) => onValuesChanged(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Calculated Total: ${formatCents(totalCents)} '
                  '(Subtotal: ${formatCents(subtotalCents)}, Tax: ${formatCents(taxCents)})',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                FilledButton.icon(
                  onPressed: onSaveInvoice,
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
