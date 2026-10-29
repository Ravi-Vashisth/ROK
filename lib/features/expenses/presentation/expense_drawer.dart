import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

class ExpenseDrawer extends ConsumerStatefulWidget {
  final VoidCallback onSaved;

  const ExpenseDrawer({super.key, required this.onSaved});

  @override
  ConsumerState<ExpenseDrawer> createState() => _ExpenseDrawerState();
}

class _ExpenseDrawerState extends ConsumerState<ExpenseDrawer> {
  final _vendorController = TextEditingController();
  final _amountController = TextEditingController();
  final _taxController = TextEditingController();
  String _category = 'Software & Tools';
  String? _receiptName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 400,
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Log New Expense', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          TextField(controller: _vendorController, decoration: const InputDecoration(labelText: 'Vendor')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _category,
            items: ['Software & Tools', 'Cloud Hosting', 'Hardware'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (val) => setState(() => _category = val!),
            decoration: const InputDecoration(labelText: 'Category'),
          ),
          const SizedBox(height: 12),
          TextField(controller: _amountController, decoration: const InputDecoration(labelText: 'Base Amount (Cents)'), keyboardType: TextInputType.number),
          const SizedBox(height: 12),
          TextField(controller: _taxController, decoration: const InputDecoration(labelText: 'Tax Amount (Cents)'), keyboardType: TextInputType.number),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            icon: const Icon(Icons.attach_file),
            label: Text(_receiptName ?? 'Attach Receipt'),
            onPressed: () async {
              final result = await FilePicker.platform.pickFiles();
              if (result != null) setState(() => _receiptName = result.files.single.name);
            },
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () async {
                final amount = int.tryParse(_amountController.text) ?? 0;
                final tax = int.tryParse(_taxController.text) ?? 0;
                
                // Assuming expensesProvider.notifier.addExpense exists or similar
                // For now, call a placeholder or actual method.
                // ref.read(expensesProvider.notifier).addExpense(...);
                
                widget.onSaved();
                Navigator.pop(context);
              },
              child: const Text('Save Expense'),
            ),
          )
        ],
      ),
    );
  }
}
