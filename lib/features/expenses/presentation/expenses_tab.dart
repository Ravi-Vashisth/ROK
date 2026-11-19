import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:billing_app/core/theme/app_theme.dart';
import 'package:billing_app/core/utils/currency_formatter_provider.dart';
import 'package:billing_app/core/utils/file_validation_utils.dart';
import 'package:billing_app/core/utils/money_utils.dart';
import 'package:billing_app/features/business_profile/providers/business_profile_provider.dart';
import 'package:billing_app/features/expenses/models/expense_record.dart';
import 'package:billing_app/features/expenses/providers/expenses_provider.dart';

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
      text:
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
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
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final picked = result.files.single;
      final bytes = picked.bytes ??
          (picked.path != null ? await File(picked.path!).readAsBytes() : null);
      if (!mounted) return;
      if (bytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read the selected receipt file.')),
        );
        return;
      }

      final validation = validateUploadedFileBytes(
        bytes: bytes,
        filename: picked.name,
        allowPdf: true,
      );
      if (!validation.isValid || validation.mimeType == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(validation.errorMessage ?? 'Invalid receipt file selected.'),
            backgroundColor: Colors.red.shade700,
          ),
        );
        return;
      }

      setState(() {
        _receiptBase64 = 'data:${validation.mimeType};base64,${base64Encode(bytes)}';
        _receiptName = picked.name;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File selection error: $e')),
        );
      }
    }
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final initial = parseLocalCalendarDate(controller.text.trim()) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    controller.text =
        '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
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

    final dateStr = _dateController.text.trim();
    if (!isValidIsoCalendarDate(dateStr)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid expense date (YYYY-MM-DD).')),
      );
      return;
    }

    final taxCents = parsePriceToUnits(_taxController.text.trim(), decimals);

    ref.read(expensesProvider.notifier).addExpense(
          category: _selectedCategory,
          vendor: vendor,
          amountCents: amountCents,
          taxCents: taxCents,
          expenseDate: dateStr,
          notes: _notesController.text.trim(),
          receiptBase64: _receiptBase64,
          receiptName: _receiptName,
        );

    _vendorController.clear();
    _amountController.clear();
    _taxController.text = formatDecimalUnits(0, decimals);
    _notesController.clear();
    setState(() {
      _receiptBase64 = '';
      _receiptName = '';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Expense booked locally successfully!')),
    );
  }

  void _confirmDeleteExpense(BuildContext context, ExpenseRecord item) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Delete Expense'),
        content: Text('Delete expense record from "${item.vendor}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ref.read(expensesProvider.notifier).deleteExpense(item.id);
              Navigator.of(dialogCtx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Deleted expense for ${item.vendor}.')),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showEditExpenseDialog(BuildContext context, ExpenseRecord item) {
    showDialog(
      context: context,
      builder: (_) => _ExpenseEditDialog(expense: item),
    );
  }

  void _showReceiptDialog(BuildContext context, ExpenseRecord item) {
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(Icons.receipt_long, color: colorScheme.primary),
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
                    child: Text(
                      'File: ${item.receiptName}',
                      style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                if (item.receiptBase64.startsWith('data:image')) ...[
                  (() {
                    try {
                      final decoded = base64Decode(item.receiptBase64.split(',').last);
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 280),
                          child: Image.memory(decoded, fit: BoxFit.contain),
                        ),
                      );
                    } catch (_) {
                      return const Text('Unable to decode stored receipt image.');
                    }
                  })(),
                ] else if (item.receiptBase64.startsWith('data:application/pdf')) ...[
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.picture_as_pdf, size: 48, color: colorScheme.error),
                        const SizedBox(height: 8),
                        const Text(
                          'PDF Receipt Document Attached',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  const Text('No receipt image preview available.'),
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
    final profile = ref.watch(businessProfileProvider);
    final decimals = profile.currencyDecimals;
    final formatCurrency = ref.watch(currencyFormatterProvider);
    final query = _searchController.text.toLowerCase();

    final filtered = expenses.where((e) {
      return e.vendor.toLowerCase().contains(query) ||
          e.category.toLowerCase().contains(query) ||
          e.notes.toLowerCase().contains(query);
    }).toList();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final warningTone = AppSemanticColors.resolve(theme.brightness, SemanticStatus.warning);
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 900;
    final zeroHint = formatDecimalUnits(0, decimals);

    final categoryField = DropdownButtonFormField<String>(
      value: _selectedCategory,
      decoration: const InputDecoration(labelText: 'Category'),
      items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
      onChanged: (v) => setState(() => _selectedCategory = v ?? 'Software'),
    );
    final vendorField = TextField(
      controller: _vendorController,
      decoration: const InputDecoration(
        labelText: 'Vendor / Payee',
        hintText: 'e.g. AWS, Adobe, Staples',
      ),
    );
    final dateField = TextField(
      controller: _dateController,
      decoration: InputDecoration(
        labelText: 'Expense Date (YYYY-MM-DD)',
        suffixIcon: IconButton(
          tooltip: 'Pick date',
          icon: const Icon(Icons.calendar_today_outlined, size: 18),
          onPressed: () => _pickDate(_dateController),
        ),
      ),
    );
    final amountField = TextField(
      controller: _amountController,
      keyboardType: TextInputType.numberWithOptions(decimal: decimals > 0),
      decoration: InputDecoration(labelText: 'Amount (excl. tax)', hintText: zeroHint),
    );
    final taxField = TextField(
      controller: _taxController,
      keyboardType: TextInputType.numberWithOptions(decimal: decimals > 0),
      decoration: InputDecoration(labelText: 'Tax Amount', hintText: zeroHint),
    );
    final notesField = TextField(
      controller: _notesController,
      decoration: const InputDecoration(
        labelText: 'Notes / Purpose',
        hintText: 'Project hosting...',
      ),
    );

    final pagePadding = isWide ? 24.0 : 16.0;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(pagePadding, pagePadding, pagePadding, 0),
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
                      Text(
                        'Expense Ledger (${filtered.length})',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
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
              ],
            ),
          ),
        ),
        if (filtered.isEmpty)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(pagePadding, 0, pagePadding, pagePadding),
            sliver: SliverToBoxAdapter(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.dividerColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text('No expenses recorded matching criteria.', style: TextStyle(color: colorScheme.onSurfaceVariant)),
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
                  final item = filtered[index];
                  final isLast = index == filtered.length - 1;
                  return Card(
                    elevation: 0,
                    margin: EdgeInsets.only(bottom: isLast ? 0 : 8),
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: theme.dividerColor),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: warningTone.background,
                        child: Icon(Icons.receipt, color: warningTone.icon, size: 18),
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
                                  color: colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: colorScheme.primary.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.attach_file, size: 12, color: colorScheme.onPrimaryContainer),
                                    const SizedBox(width: 2),
                                    Text(
                                      'Receipt',
                                      style: TextStyle(fontSize: 10, color: colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      subtitle: Text(
                        'Date: ${item.expenseDate}${item.notes.isNotEmpty ? " • ${item.notes}" : ""}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 112),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  formatCurrency(item.totalCents),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    fontFeatures: [FontFeature.tabularFigures()],
                                  ),
                                ),
                                if (item.taxCents > 0)
                                  Text(
                                    'Tax: ${formatCurrency(item.taxCents)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: colorScheme.onSurfaceVariant,
                                      fontFeatures: const [FontFeature.tabularFigures()],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            onPressed: () => _showEditExpenseDialog(context, item),
                            tooltip: 'Edit Expense',
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: Icon(Icons.delete_outline, color: colorScheme.error, size: 18),
                            onPressed: () => _confirmDeleteExpense(context, item),
                            tooltip: 'Delete Expense',
                          ),
                        ],
                      ),
                    ),
                  );
                },
                childCount: filtered.length,
              ),
            ),
          ),
      ],
    );
  }
}

class _ExpenseEditDialog extends ConsumerStatefulWidget {
  final ExpenseRecord expense;

  const _ExpenseEditDialog({required this.expense});

  @override
  ConsumerState<_ExpenseEditDialog> createState() => _ExpenseEditDialogState();
}

class _ExpenseEditDialogState extends ConsumerState<_ExpenseEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _vendorController;
  late final TextEditingController _amountController;
  late final TextEditingController _taxController;
  late final TextEditingController _dateController;
  late final TextEditingController _notesController;
  late String _category;
  late String _receiptBase64;
  late String _receiptName;

  static const List<String> _baseCategories = [
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
    final decimals = ref.read(businessProfileProvider).currencyDecimals;
    _vendorController = TextEditingController(text: widget.expense.vendor);
    _amountController = TextEditingController(
      text: formatDecimalUnits(widget.expense.amountCents, decimals),
    );
    _taxController = TextEditingController(
      text: formatDecimalUnits(widget.expense.taxCents, decimals),
    );
    _dateController = TextEditingController(text: widget.expense.expenseDate);
    _notesController = TextEditingController(text: widget.expense.notes);
    _category = widget.expense.category.isNotEmpty ? widget.expense.category : 'Software';
    _receiptBase64 = widget.expense.receiptBase64;
    _receiptName = widget.expense.receiptName;
  }

  @override
  void dispose() {
    _vendorController.dispose();
    _amountController.dispose();
    _taxController.dispose();
    _dateController.dispose();
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
      if (!mounted) return;
      if (bytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read the selected receipt file.')),
        );
        return;
      }

      final validation = validateUploadedFileBytes(
        bytes: bytes,
        filename: picked.name,
        allowPdf: true,
      );
      if (!validation.isValid || validation.mimeType == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(validation.errorMessage ?? 'Invalid receipt file selected.'),
            backgroundColor: Colors.red.shade700,
          ),
        );
        return;
      }

      setState(() {
        _receiptBase64 = 'data:${validation.mimeType};base64,${base64Encode(bytes)}';
        _receiptName = picked.name;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File selection error: $e')),
        );
      }
    }
  }

  Future<void> _pickDate() async {
    final initial = parseLocalCalendarDate(_dateController.text.trim()) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _dateController.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final decimals = ref.watch(businessProfileProvider).currencyDecimals;
    final categoryChoices = _baseCategories.contains(_category)
        ? _baseCategories
        : [..._baseCategories, _category];

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text('Edit Expense Record'),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 460,
          maxHeight: MediaQuery.sizeOf(context).height * 0.78,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _vendorController,
                  decoration: const InputDecoration(labelText: 'Vendor / Payee *'),
                  validator: (val) =>
                      val == null || val.trim().isEmpty ? 'Please enter a vendor name' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: categoryChoices
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _category = v);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _dateController,
                  decoration: InputDecoration(
                    labelText: 'Expense Date (YYYY-MM-DD) *',
                    suffixIcon: IconButton(
                      tooltip: 'Pick date',
                      icon: const Icon(Icons.calendar_today_outlined, size: 18),
                      onPressed: _pickDate,
                    ),
                  ),
                  validator: (val) => val == null || !isValidIsoCalendarDate(val.trim())
                      ? 'Use YYYY-MM-DD format'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.numberWithOptions(decimal: decimals > 0),
                  decoration: const InputDecoration(labelText: 'Amount (excl. tax) *'),
                  validator: (val) {
                    if (val == null || parsePriceToUnits(val.trim(), decimals) <= 0) {
                      return 'Enter a valid amount greater than zero';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _taxController,
                  keyboardType: TextInputType.numberWithOptions(decimal: decimals > 0),
                  decoration: const InputDecoration(labelText: 'Tax Amount'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Notes / Purpose'),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickReceipt,
                      icon: const Icon(Icons.attach_file, size: 16),
                      label: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 220),
                        child: Text(
                          _receiptName.isNotEmpty
                              ? 'Receipt: $_receiptName'
                              : (_receiptBase64.isNotEmpty
                                  ? 'Replace Attached Receipt'
                                  : 'Attach Receipt (Image/PDF)'),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    if (_receiptBase64.isNotEmpty)
                      TextButton.icon(
                        onPressed: () => setState(() {
                          _receiptBase64 = '';
                          _receiptName = '';
                        }),
                        icon: const Icon(Icons.close, size: 16, color: Colors.red),
                        label: const Text('Remove', style: TextStyle(color: Colors.red)),
                      ),
                  ],
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
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            final amountCents = parsePriceToUnits(_amountController.text.trim(), decimals);
            final taxCents = parsePriceToUnits(_taxController.text.trim(), decimals);
            ref.read(expensesProvider.notifier).updateExpense(
                  id: widget.expense.id,
                  category: _category,
                  vendor: _vendorController.text.trim(),
                  amountCents: amountCents,
                  taxCents: taxCents,
                  expenseDate: _dateController.text.trim(),
                  notes: _notesController.text.trim(),
                  receiptBase64: _receiptBase64,
                  receiptName: _receiptName,
                );
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Expense updated successfully.')),
            );
          },
          child: const Text('Update Expense'),
        ),
      ],
    );
  }
}
