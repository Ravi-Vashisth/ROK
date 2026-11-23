import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:billing_app/core/theme/app_theme.dart';
import 'package:billing_app/core/utils/money_utils.dart';
import 'package:billing_app/features/business_profile/providers/business_profile_provider.dart';
import 'package:billing_app/features/items/models/saved_item.dart';
import 'package:billing_app/features/items/providers/saved_items_provider.dart';

class ItemsCatalogTab extends ConsumerStatefulWidget {
  final List<Widget> leadingSlivers;
  const ItemsCatalogTab({super.key, this.leadingSlivers = const []});

  @override
  ConsumerState<ItemsCatalogTab> createState() => _ItemsCatalogTabState();
}

class _ItemsCatalogTabState extends ConsumerState<ItemsCatalogTab> {
  final _titleController = TextEditingController();
  final _sacHsnController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _sacHsnController.dispose();
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

    final profile = ref.read(businessProfileProvider);
    final decimals = profile.currencyDecimals;
    final priceCents = parsePriceToUnits(_priceController.text, decimals);
    if (priceCents < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid price.')),
      );
      return;
    }

    ref.read(savedItemsProvider.notifier).addItem(
          title: title,
          sacHsn: _sacHsnController.text.trim(),
          defaultPriceCents: priceCents,
          description: _descriptionController.text.trim(),
          currencyCode: profile.currencyCode,
          currencyDecimals: profile.currencyDecimals,
        );

    _titleController.clear();
    _sacHsnController.clear();
    _priceController.clear();
    _descriptionController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved item added to catalog!')),
    );
  }

  void _showEditItemDialog(BuildContext context, SavedItem item) {
    showDialog(
      context: context,
      builder: (_) => _EditCatalogItemDialog(item: item),
    );
  }

  void _confirmDeleteItem(BuildContext context, SavedItem item) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete Catalog Item'),
        content: Text('Are you sure you want to delete "${item.title}" from the catalog?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () {
              ref.read(savedItemsProvider.notifier).deleteItem(item.id);
              Navigator.of(dialogCtx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Removed "${item.title}" from catalog.')),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final savedItems = ref.watch(savedItemsProvider);
    final profile = ref.watch(businessProfileProvider);
    final decimals = profile.currencyDecimals;
    final priceHint = decimals == 0 ? '100' : decimals == 3 ? '100.000' : '100.00';

    final isWide = MediaQuery.sizeOf(context).width >= 900;
    final pagePadding = isWide ? 24.0 : 16.0;

    return CustomScrollView(
      slivers: [
        ...widget.leadingSlivers,
        SliverPadding(
          padding: EdgeInsets.fromLTRB(pagePadding, widget.leadingSlivers.isEmpty ? pagePadding : 0, pagePadding, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
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
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final titleField = TextField(
                              controller: _titleController,
                              decoration: const InputDecoration(
                                labelText: 'Item / Service Title',
                                hintText: 'e.g. Logo Design',
                              ),
                            );
                            final sacField = TextField(
                              controller: _sacHsnController,
                              decoration: const InputDecoration(
                                labelText: 'SAC / HSN',
                                hintText: 'e.g. 998311',
                              ),
                            );
                            final priceField = TextField(
                              controller: _priceController,
                              keyboardType: decimals == 0
                                  ? TextInputType.number
                                  : const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Default Price (${profile.currencySymbol})',
                                hintText: priceHint,
                              ),
                            );
                            final descField = TextField(
                              controller: _descriptionController,
                              decoration: const InputDecoration(
                                labelText: 'Description (optional)',
                                hintText: 'Detailed deliverables...',
                              ),
                            );
                            if (MediaQuery.sizeOf(context).width < 900) {
                              return Column(
                                children: [
                                  titleField,
                                  const SizedBox(height: 10),
                                  sacField,
                                  const SizedBox(height: 10),
                                  priceField,
                                  const SizedBox(height: 10),
                                  descField,
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(flex: 3, child: titleField),
                                const SizedBox(width: 8),
                                Expanded(flex: 2, child: sacField),
                                const SizedBox(width: 8),
                                Expanded(flex: 2, child: priceField),
                                const SizedBox(width: 8),
                                Expanded(flex: 3, child: descField),
                              ],
                            );
                          },
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
              ],
            ),
          ),
        ),
        if (savedItems.isEmpty)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(pagePadding, 0, pagePadding, pagePadding),
            sliver: SliverToBoxAdapter(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    'No saved items in catalog yet.',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodySmall?.color ?? Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          )
        else if (isWide)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(pagePadding, 0, pagePadding, pagePadding),
            sliver: SliverToBoxAdapter(
              child: Card(
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
                        final brightness = Theme.of(context).brightness;
                        final infoTone = AppSemanticColors.resolve(brightness, SemanticStatus.info);
                        final neutralTone = AppSemanticColors.resolve(brightness, SemanticStatus.neutral);
                        final resolved = resolveEffectiveCurrency(
                          recordCode: item.currencyCode,
                          recordDecimals: item.currencyCode.trim().isNotEmpty ? item.currencyDecimals : null,
                          defaultCode: profile.currencyCode,
                          defaultSymbol: profile.currencySymbol,
                          defaultDecimals: profile.currencyDecimals,
                        );
                        final formattedPrice = formatMoney(
                          item.defaultPriceCents,
                          symbol: resolved.symbol,
                          decimals: resolved.decimals,
                          currencyCode: resolved.code,
                        );
                        final isForeign = resolved.code != profile.currencyCode.trim().toUpperCase();
                        return DataRow(
                          cells: [
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: infoTone.background,
                                    child: Icon(Icons.inventory_2_outlined, color: infoTone.icon, size: 16),
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
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    formattedPrice,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontFeatures: [FontFeature.tabularFigures()]),
                                  ),
                                  if (isForeign) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      resolved.code,
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: neutralTone.background,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: neutralTone.border),
                                ),
                                child: Text(
                                  'Configurable %',
                                  style: TextStyle(fontSize: 11, color: neutralTone.text, fontWeight: FontWeight.w500),
                                ),
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
                                    icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error, size: 18),
                                    onPressed: () => _confirmDeleteItem(context, item),
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
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(pagePadding, 0, pagePadding, pagePadding),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = savedItems[index];
                  final isLast = index == savedItems.length - 1;
                  final infoTone = AppSemanticColors.resolve(Theme.of(context).brightness, SemanticStatus.info);
                  final resolved = resolveEffectiveCurrency(
                    recordCode: item.currencyCode,
                    recordDecimals: item.currencyCode.trim().isNotEmpty ? item.currencyDecimals : null,
                    defaultCode: profile.currencyCode,
                    defaultSymbol: profile.currencySymbol,
                    defaultDecimals: profile.currencyDecimals,
                  );
                  final formattedPrice = formatMoney(
                    item.defaultPriceCents,
                    symbol: resolved.symbol,
                    decimals: resolved.decimals,
                    currencyCode: resolved.code,
                  );
                  final isForeign = resolved.code != profile.currencyCode.trim().toUpperCase();
                  return Card(
                    elevation: 0,
                    margin: EdgeInsets.only(bottom: isLast ? 0 : 8),
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: Theme.of(context).dividerColor),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: infoTone.background,
                        child: Icon(Icons.inventory_2_outlined, color: infoTone.icon, size: 18),
                      ),
                      title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        item.description.isNotEmpty ? item.description : 'Standard preset deliverable',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                formattedPrice,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                              if (isForeign)
                                Text(
                                  resolved.code,
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                ),
                            ],
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            tooltip: 'Edit Item',
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            onPressed: () => _showEditItemDialog(context, item),
                          ),
                          IconButton(
                            tooltip: 'Delete Item',
                            visualDensity: VisualDensity.compact,
                            icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error, size: 18),
                            onPressed: () => _confirmDeleteItem(context, item),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                childCount: savedItems.length,
              ),
            ),
          ),
      ],
    );
  }
}

class _EditCatalogItemDialog extends ConsumerStatefulWidget {
  final SavedItem item;

  const _EditCatalogItemDialog({required this.item});

  @override
  ConsumerState<_EditCatalogItemDialog> createState() => _EditCatalogItemDialogState();
}

class _EditCatalogItemDialogState extends ConsumerState<_EditCatalogItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _sacHsnController;
  late final TextEditingController _priceController;
  late final TextEditingController _descController;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(businessProfileProvider);
    final resolved = resolveEffectiveCurrency(
      recordCode: widget.item.currencyCode,
      recordDecimals: widget.item.currencyCode.trim().isNotEmpty
          ? widget.item.currencyDecimals
          : null,
      defaultCode: profile.currencyCode,
      defaultSymbol: profile.currencySymbol,
      defaultDecimals: profile.currencyDecimals,
    );
    _titleController = TextEditingController(text: widget.item.title);
    _sacHsnController = TextEditingController(text: widget.item.sacHsn);
    _priceController = TextEditingController(
      text: formatDecimalUnits(widget.item.defaultPriceCents, resolved.decimals),
    );
    _descController = TextEditingController(text: widget.item.description);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _sacHsnController.dispose();
    _priceController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(businessProfileProvider);
    final resolved = resolveEffectiveCurrency(
      recordCode: widget.item.currencyCode,
      recordDecimals: widget.item.currencyCode.trim().isNotEmpty
          ? widget.item.currencyDecimals
          : null,
      defaultCode: profile.currencyCode,
      defaultSymbol: profile.currencySymbol,
      defaultDecimals: profile.currencyDecimals,
    );
    final decimals = resolved.decimals;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Row(
        children: [
          const Icon(Icons.edit_outlined),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Edit Catalog Item (${resolved.code})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 440,
          maxHeight: MediaQuery.sizeOf(context).height * 0.78,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Item / Service Title *'),
                  validator: (val) =>
                      val == null || val.trim().isEmpty ? 'Please enter a title' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _sacHsnController,
                  decoration: const InputDecoration(labelText: 'SAC / HSN Code (e.g. 998311)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _priceController,
                  keyboardType: decimals == 0
                      ? TextInputType.number
                      : const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: 'Default Unit Price (${resolved.symbol}) *'),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Please enter a price';
                    if (parsePriceToUnits(val, decimals) < 0) return 'Invalid price';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.check, size: 16),
          label: const Text('Save Item'),
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            ref.read(savedItemsProvider.notifier).updateItem(
                  id: widget.item.id,
                  title: _titleController.text.trim(),
                  sacHsn: _sacHsnController.text.trim(),
                  defaultPriceCents: parsePriceToUnits(_priceController.text, decimals),
                  description: _descController.text.trim(),
                  currencyCode: resolved.code,
                  currencyDecimals: resolved.decimals,
                );
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Catalog item updated.')),
            );
          },
        ),
      ],
    );
  }
}

