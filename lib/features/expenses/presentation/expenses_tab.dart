import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/currency_formatter_provider.dart';
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

    final amountDouble = double.tryParse(_amountController.text.trim()) ?? 0;
    if (amountDouble <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid expense amount.')),
      );
      return;
    }

    final amountCents = (amountDouble * 100).round();
    final taxDouble = double.tryParse(_taxController.text.trim()) ?? 0;
    final taxCents = (taxDouble * 100).round();

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
        content: SizedBox(
          width: 480,
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
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    base64Decode(item.receiptBase64.split(',').last),
                    maxHeight: 320,
                    fit: BoxFit.contain,
                  ),
                ),
              ] else if (item.receiptBase64.startsWith('data:application/pdf')) ...[
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.slate.shade100,
                    borderRadius: BorderRadius.circular(8),
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
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: const InputDecoration(labelText: 'Category'),
                        items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (v) => setState(() => _selectedCategory = v ?? 'Software'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 4,
                      child: TextField(
                        controller: _vendorController,
                        decoration: const InputDecoration(labelText: 'Vendor / Payee', hintText: 'e.g. AWS, Adobe, Staples'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _dateController,
                        decoration: const InputDecoration(labelText: 'Expense Date (YYYY-MM-DD)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Amount (excl. tax)', hintText: '0.00'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _taxController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Tax Amount', hintText: '0.00'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 4,
                      child: TextField(
                        controller: _notesController,
                        decoration: const InputDecoration(labelText: 'Notes / Purpose', hintText: 'Project hosting...'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickReceiptFile,
                      icon: const Icon(Icons.attach_file, size: 16),
                      label: Text(_receiptName.isNotEmpty ? 'Receipt Attached: $_receiptName' : 'Attach Receipt (Image/PDF)'),
                    ),
                    if (_receiptName.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Remove Attachment',
                        icon: const Icon(Icons.close, color: Colors.red, size: 18),
                        onPressed: () => setState(() {
                          _receiptBase64 = '';
                          _receiptName = '';
                        }),
                      ),
                    ],
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: _handleAddExpense,
                      icon: const Icon(Icons.add),
                      label: const Text('Book Expense'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Expense Ledger (${filtered.length})', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            SizedBox(
              width: 280,
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
                  title: Row(
                    children: [
                      Text('${item.vendor} (${item.category})', style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (item.hasReceipt) ...[
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => _showReceiptDialog(context, item),
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.indigo.shade50,
                              borderRadius: BorderRadius.circular(4),
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
                          Text(formatCurrency(item.totalCents), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          if (item.taxCents > 0)
                            Text('Tax: ${formatCurrency(item.taxCents)}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(width: 8),
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
