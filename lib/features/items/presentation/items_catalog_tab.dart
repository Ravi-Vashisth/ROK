import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/currency_formatter_provider.dart';
import '../../../core/utils/money_utils.dart';
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter an item/service title.')));
      return;
    }

    final priceCents = parsePriceToCents(_priceController.text);
    if (priceCents < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid price.')));
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

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved item added to catalog!')));
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
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Add Preset Item / Service to Catalog', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _titleController,
                        decoration: const InputDecoration(labelText: 'Item / Service Title', hintText: 'e.g. Logo Design, API Integration'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _priceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Default Price', hintText: '100.00'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 4,
                      child: TextField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(labelText: 'Description (optional)', hintText: 'Detailed deliverables...'),
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
        Text('Items & Services Catalog (${savedItems.length})', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (savedItems.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(child: Text('No saved items in catalog yet.', style: TextStyle(color: Colors.grey))),
          )
        else
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8),
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
                  subtitle: Text(item.description.isNotEmpty ? item.description : 'Standard preset service', style: const TextStyle(fontSize: 12)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(formatCurrency(item.defaultPriceCents), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                        onPressed: () {
                          ref.read(savedItemsProvider.notifier).deleteItem(item.id);
                        },
                        tooltip: 'Delete Item',
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
