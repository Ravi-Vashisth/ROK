import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money_utils.dart';
import '../../business_profile/providers/business_profile_provider.dart';
import '../providers/expenses_provider.dart';

class ExpenseDrawer extends ConsumerStatefulWidget {
  final VoidCallback onSaved;

  const ExpenseDrawer({super.key, required this.onSaved});

  @override
  ConsumerState<ExpenseDrawer> createState() => _ExpenseDrawerState();
}

class _ExpenseDrawerState extends ConsumerState<ExpenseDrawer> {
  final _vendorController = TextEditingController();
  final _amountController = TextEditingController();
  final _taxController = TextEditingController(text: '0');
  final _notesController = TextEditingController();
  String _category = 'Software';
  String _receiptBase64 = '';
  String? _receiptName;

  static const List<String> _categories = [
    'Software',
    'Hardware',
    'Office',
    'Travel',
    'Subcontracting',
    'Other',
  ];

  @override
  void dispose() {
    _vendorController.dispose();
    _amountController.dispose();
    _taxController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickReceipt() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp', 'pdf'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final picked = result.files.single;
      final bytes = picked.bytes ??
          (picked.path != null ? await File(picked.path!).readAsBytes() : null);
      if (bytes == null) return;

      final ext = (picked.extension ?? 'png').toLowerCase();
      final mime = ext == 'pdf' ? 'application/pdf' : 'image/$ext';
      if (!mounted) return;
      setState(() {
        _receiptBase64 = 'data:$mime;base64,${base64Encode(bytes)}';
        _receiptName = picked.name;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to attach receipt: $e')),
        );
      }
    }
  }

  void _applyTenPercentTax(int decimals) {
    final baseUnits = parsePriceToUnits(_amountController.text.trim(), decimals);
    final taxUnits = calculateTaxCents(baseUnits, 10);
    setState(() {
      _taxController.text = formatDecimalUnits(taxUnits, decimals);
    });
  }

  void _handleSave(int decimals) {
    final vendor = _vendorController.text.trim();
    if (vendor.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a vendor name.')),
      );
      return;
    }

    final amountUnits = parsePriceToUnits(_amountController.text.trim(), decimals);
    if (amountUnits <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid expense amount greater than zero.')),
      );
      return;
    }

    final taxUnits = parsePriceToUnits(_taxController.text.trim(), decimals);
    final now = DateTime.now();
    final expenseDate =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    ref.read(expensesProvider.notifier).addExpense(
          category: _category,
          vendor: vendor,
          amountCents: amountUnits,
          taxCents: taxUnits,
          expenseDate: expenseDate,
          notes: _notesController.text.trim(),
          receiptBase64: _receiptBase64,
          receiptName: _receiptName ?? '',
        );

    widget.onSaved();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(businessProfileProvider);
    final decimals = profile.currencyDecimals;
    final symbol = profile.currencySymbol;
    final hintAmount = decimals == 0 ? '5000' : '50.00';
    final hintTax = decimals == 0 ? '0' : '0.00';

    return Drawer(
      child: SafeArea(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Log New Expense',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _vendorController,
                  decoration: const InputDecoration(
                    labelText: 'Vendor / Payee *',
                    hintText: 'e.g. AWS, Adobe, Apple',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _category,
                  items: _categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _category = val);
                  },
                  decoration: const InputDecoration(labelText: 'Category'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _amountController,
                  decoration: InputDecoration(
                    labelText: 'Base Amount ($symbol) *',
                    hintText: hintAmount,
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: decimals > 0),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _taxController,
                        decoration: InputDecoration(
                          labelText: 'Tax Amount ($symbol)',
                          hintText: hintTax,
                        ),
                        keyboardType: TextInputType.numberWithOptions(decimal: decimals > 0),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ActionChip(
                      label: const Text('10% Tax'),
                      onPressed: () => _applyTenPercentTax(decimals),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes / Purpose',
                    hintText: 'Project hosting...',
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  icon: const Icon(Icons.attach_file, size: 18),
                  label: Text(
                    _receiptName ?? 'Attach Receipt (Image/PDF)',
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed: _pickReceipt,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => _handleSave(decimals),
                    child: const Text('Save Expense'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
