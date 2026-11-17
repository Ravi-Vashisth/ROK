import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/currency_formatter_provider.dart';
import '../../../core/utils/money_utils.dart';
import '../../business_profile/providers/business_profile_provider.dart';
import '../models/expense_record.dart';
import '../providers/expenses_provider.dart';

class ExpensesTab extends ConsumerStatefulWidget {
  const ExpensesTab({super.key});

  @override
  ConsumerState<ExpensesTab> createState() => _ExpensesTabState();
}

class _ExpensesTabState extends ConsumerState<ExpensesTab> {
  final _vendorController = TextEditingController();
  final _amountController = TextEditingController();
  final _taxController = TextEditingController(text: '0');
  final _notesController = TextEditingController();
  final _searchController = TextEditingController();

  String _selectedCategory = 'Software';
  late TextEditingController _dateController;
  String _receiptBase64 = '';
  String _receiptName = '';

  static const List<String> _categories = [
    'Software',
    'Hardware',
    'Office',
    'Travel',
    'Subcontracting',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateController = TextEditingController(
      text: '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
    );
  }

  @override
  void dispose() {
    _vendorController.dispose();
    _amountController.dispose();
    _taxController.dispose();
    _notesController.dispose();
    _dateController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickReceiptFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp', 'pdf'],
      );
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final bytes = await file.readAsBytes();
        final ext = result.files.single.extension?.toLowerCase() ?? 'png';
        final mime = ext == 'pdf' ? 'application/pdf' : 'image/$ext';
        final b64 = 'data:$mime;base64,${base64Encode(bytes)}';
        setState(() {
          _receiptBase64 = b64;
          _receiptName = result.files.single.name;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File selection error: $e')),
        );
      }
    }
  }

  void _handleAddExpense() {
    final vendor = _vendorController.text.trim();
    if (vendor.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a vendor name.')),
      );
      return;
    }

    final decimals = ref.read(businessProfileProvider).currencyDecimals;
    final amountCents = parsePriceToUnits(_amountController.text.trim(), decimals);
    if (amountCents <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid expense amount.')),
      );
      return;
    }

    final taxCents = parsePriceToUnits(_taxController.text.trim(), decimals);

    ref.read(expensesProvider.notifier).addExpense(
          category: _selectedCategory,
          vendor: vendor,
          amountCents: amountCents,
          taxCents: taxCents,
          expenseDate: _dateController.text.trim(),
          notes: _notesController.text.trim(),
          receiptBase64: _receiptBase64,
          receiptName: _receiptName,
        );

    _vendorController.clear();
    _amountController.clear();
    _taxController.text = '0';
    _notesController.clear();
    setState(() {
      _receiptBase64 = '';
      _receiptName = '';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Expense booked locally successfully!')),
    );
  }

  void _showReceiptDialog(BuildContext context, ExpenseRecord item) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.receipt_long, color: Colors.indigo),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Receipt: ${item.vendor}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 480,
            maxHeight: MediaQuery.sizeOf(context).height * 0.78,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (item.receiptName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Text('File: ${item.receiptName}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ),
                if (item.receiptBase64.startsWith('data:image')) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 280),
                      child: Image.memory(
                        base64Decode(item.receiptBase64.split(',').last),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ] else if (item.receiptBase64.startsWith('data:application/pdf')) ...[
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.picture_as_pdf, size: 48, color: Colors.red),
                        SizedBox(height: 8),
                        Text('PDF Receipt Document Attached', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ] else ...[
                  const Text('No receipt image available preview.'),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final expenses = ref.watch(expensesProvider);
    final formatCurrency = ref.watch(currencyFormatterProvider);
    final query = _searchController.text.toLowerCase();

    final filtered = expenses.where((e) {
      return e.vendor.toLowerCase().contains(query) ||
          e.category.toLowerCase().contains(query) ||
          e.notes.toLowerCase().contains(query);
    }).toList();

    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 900;
    final categoryField = DropdownButtonFormField<String>(
      value: _selectedCategory,
      decoration: const InputDecoration(labelText: 'Category'),
      items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
      onChanged: (v) => setState(() => _selectedCategory = v ?? 'Software'),
    );
    final vendorField = TextField(
      controller: _vendorController,
      decoration: const InputDecoration(labelText: 'Vendor / Payee', hintText: 'e.g. AWS, Adobe, Staples'),
    );
    final dateField = TextField(
      controller: _dateController,
      decoration: const InputDecoration(labelText: 'Expense Date (YYYY-MM-DD)'),
    );
    final amountField = TextField(
      controller: _amountController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(labelText: 'Amount (excl. tax)', hintText: '0.00'),
    );
    final taxField = TextField(
      controller: _taxController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(labelText: 'Tax Amount', hintText: '0.00'),
    );
    final notesField = TextField(
      controller: _notesController,
      decoration: const InputDecoration(labelText: 'Notes / Purpose', hintText: 'Project hosting...'),
    );

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
                  'Book New Business Expense',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),
                if (isWide) ...[
                  Row(
                    children: [
                      Expanded(flex: 3, child: categoryField),
                      const SizedBox(width: 12),
                      Expanded(flex: 4, child: vendorField),
                      const SizedBox(width: 12),
                      Expanded(flex: 3, child: dateField),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(flex: 3, child: amountField),
                      const SizedBox(width: 12),
                      Expanded(flex: 3, child: taxField),
                      const SizedBox(width: 12),
                      Expanded(flex: 4, child: notesField),
                    ],
                  ),
                ] else ...[
                  categoryField,
                  const SizedBox(height: 12),
                  vendorField,
                  const SizedBox(height: 12),
                  dateField,
                  const SizedBox(height: 12),
                  amountField,
                  const SizedBox(height: 12),
                  taxField,
                  const SizedBox(height: 12),
                  notesField,
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _pickReceiptFile,
                            icon: const Icon(Icons.attach_file, size: 16),
                            label: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 210),
                              child: Text(
                                _receiptName.isNotEmpty ? 'Receipt: $_receiptName' : 'Attach Receipt (Image/PDF)',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          if (_receiptName.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            IconButton(
                              tooltip: 'Remove Attachment',
                              icon: const Icon(Icons.close, color: Colors.red, size: 18),
                              onPressed: () => setState(() {
                                _receiptBase64 = '';
                                _receiptName = '';
                              }),
                            ),
                          ],
                        ],
                      ),
                      FilledButton.icon(
                        onPressed: _handleAddExpense,
                        icon: const Icon(Icons.add),
                        label: const Text('Book Expense'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              Text('Expense Ledger (${filtered.length})', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: width < 600 ? double.infinity : 280),
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search vendor or category...',
                    prefixIcon: Icon(Icons.search, size: 18),
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text('No expenses recorded matching criteria.', style: TextStyle(color: Colors.grey)),
            ),
          )
        else
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = filtered[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange.shade100,
                    child: const Icon(Icons.receipt, color: Colors.orange, size: 18),
                  ),
                  title: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text('${item.vendor} (${item.category})', style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (item.hasReceipt)
                        InkWell(
                          onTap: () => _showReceiptDialog(context, item),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.indigo.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.indigo.shade200),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.attach_file, size: 12, color: Colors.indigo),
                                SizedBox(width: 2),
                                Text('Receipt', style: TextStyle(fontSize: 10, color: Colors.indigo, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Text('Date: ${item.expenseDate}${item.notes.isNotEmpty ? " • ${item.notes}" : ""}', style: const TextStyle(fontSize: 12)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formatCurrency(item.totalCents),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          if (item.taxCents > 0)
                            Text(
                              'Tax: ${formatCurrency(item.taxCents)}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                        onPressed: () {
                          ref.read(expensesProvider.notifier).deleteExpense(item.id);
                        },
                        tooltip: 'Delete Expense',
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
