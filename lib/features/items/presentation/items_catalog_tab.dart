import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/currency_formatter_provider.dart';
import '../../../core/utils/money_utils.dart';
import '../models/saved_item.dart';
import '../providers/saved_items_provider.dart';

class ItemsCatalogTab extends ConsumerStatefulWidget {
  const ItemsCatalogTab({super.key});

  @override
  ConsumerState<ItemsCatalogTab> createState() => _ItemsCatalogTabState();
}

class _ItemsCatalogTabState extends ConsumerState<ItemsCatalogTab> {
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _handleAddItem() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an item/service title.')),
      );
      return;
    }

    final priceCents = parsePriceToCents(_priceController.text);
    if (priceCents < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid price.')),
      );
      return;
    }

    ref.read(savedItemsProvider.notifier).addItem(
          title: title,
          defaultPriceCents: priceCents,
          description: _descriptionController.text.trim(),
        );

    _titleController.clear();
    _priceController.clear();
    _descriptionController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved item added to catalog!')),
    );
  }

  void _showEditItemDialog(BuildContext context, SavedItem item) {
    final titleCtrl = TextEditingController(text: item.title);
    final priceCtrl = TextEditingController(text: (item.defaultPriceCents / 100).toStringAsFixed(2));
    final descCtrl = TextEditingController(text: item.description);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.edit_outlined),
            SizedBox(width: 8),
            Text('Edit Catalog Item', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Item / Service Title *'),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a title' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Default Unit Price *'),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Please enter a price';
                    if (parsePriceToCents(val) < 0) return 'Invalid price';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.check, size: 16),
            label: const Text('Save Item'),
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              ref.read(savedItemsProvider.notifier).updateItem(
                    id: item.id,
                    title: titleCtrl.text.trim(),
                    defaultPriceCents: parsePriceToCents(priceCtrl.text),
                    description: descCtrl.text.trim(),
                  );
              Navigator.of(dialogCtx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Catalog item updated.')),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final savedItems = ref.watch(savedItemsProvider);
    final formatCurrency = ref.watch(currencyFormatterProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add Preset Item / Service to Catalog',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Item / Service Title',
                          hintText: 'e.g. Logo Design, API Integration',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _priceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Default Price',
                          hintText: '100.00',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 4,
                      child: TextField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description (optional)',
                          hintText: 'Detailed deliverables...',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _handleAddItem,
                    icon: const Icon(Icons.add),
                    label: const Text('Add to Catalog'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Items & Services Catalog (${savedItems.length})',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 14),
        if (savedItems.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text('No saved items in catalog yet.', style: TextStyle(color: Colors.grey)),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;

              if (isWide) {
                // High-density widescreen data table
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                          Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                        ),
                        columns: const [
                          DataColumn(label: Text('Item / Service Title', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Description', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Default Unit Price', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Tax Slab', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: savedItems.map((item) {
                          return DataRow(
                            cells: [
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: Colors.blue.shade100,
                                      child: const Icon(Icons.inventory_2_outlined, color: Colors.blue, size: 16),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 280,
                                  child: Text(
                                    item.description.isNotEmpty ? item.description : 'Standard preset deliverable',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  formatCurrency(item.defaultPriceCents),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.slate.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.slate.shade300),
                                  ),
                                  child: const Text('Configurable %', style: TextStyle(fontSize: 11)),
                                ),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Edit Item',
                                      icon: const Icon(Icons.edit_outlined, size: 18),
                                      onPressed: () => _showEditItemDialog(context, item),
                                    ),
                                    IconButton(
                                      tooltip: 'Delete Item',
                                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                      onPressed: () {
                                        ref.read(savedItemsProvider.notifier).deleteItem(item.id);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Removed "${item.title}" from catalog.')),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                );
              }

              // Responsive Compact Card View
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: savedItems.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = savedItems[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.shade100,
                        child: const Icon(Icons.inventory_2_outlined, color: Colors.blue, size: 18),
                      ),
                      title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        item.description.isNotEmpty ? item.description : 'Standard preset deliverable',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            formatCurrency(item.defaultPriceCents),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'Edit Item',
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            onPressed: () => _showEditItemDialog(context, item),
                          ),
                          IconButton(
                            tooltip: 'Delete Item',
                            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                            onPressed: () {
                              ref.read(savedItemsProvider.notifier).deleteItem(item.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Removed "${item.title}" from catalog.')),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
      ],
    );
  }
}
