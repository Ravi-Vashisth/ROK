import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/money_utils.dart';
import '../../invoices/models/invoice_record.dart';
import '../../invoices/providers/invoices_provider.dart';

class RecordPaymentDialog extends ConsumerStatefulWidget {
  final InvoiceRecord invoice;

  const RecordPaymentDialog({
    super.key,
    required this.invoice,
  });

  @override
  ConsumerState<RecordPaymentDialog> createState() => _RecordPaymentDialogState();
}

class _RecordPaymentDialogState extends ConsumerState<RecordPaymentDialog> {
  final _amountReceivedController = TextEditingController();
  final _tdsController = TextEditingController(text: '0.00');
  final _refNumberController = TextEditingController();
  final _notesController = TextEditingController();
  String _selectedMethod = 'Bank Wire';
  late DateTime _selectedDate;
  String? _errorMessage;

  final List<String> _methods = const [
    'Bank Wire',
    'Credit Card',
    'Cash',
    'UPI / PayPal',
    'Check',
  ];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    // Default to the remaining balance due
    final initialDollars = (widget.invoice.balanceDueCents / 100.0).toStringAsFixed(2);
    _amountReceivedController.text = initialDollars;
  }

  @override
  void dispose() {
    _amountReceivedController.dispose();
    _tdsController.dispose();
    _refNumberController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _applyPresetAmount(int cents) {
    setState(() {
      _amountReceivedController.text = (cents / 100.0).toStringAsFixed(2);
      _tdsController.text = '0.00';
      _errorMessage = null;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _submitPayment() {
    final amountReceivedCents = parsePriceToCents(_amountReceivedController.text);
    final tdsCents = parsePriceToCents(_tdsController.text);
    final totalCreditCents = amountReceivedCents + tdsCents;

    if (totalCreditCents <= 0) {
      setState(() {
        _errorMessage = 'Total payment credit (Amount Received + TDS) must be greater than zero.';
      });
      return;
    }

    if (totalCreditCents > widget.invoice.balanceDueCents) {
      setState(() {
        _errorMessage =
            'Total credit (${formatCents(totalCreditCents)}) cannot exceed remaining balance due (${formatCents(widget.invoice.balanceDueCents)}).';
      });
      return;
    }

    try {
      ref.read(invoicesProvider.notifier).recordPayment(
            invoiceId: widget.invoice.id,
            amountCents: totalCreditCents,
            amountReceivedCents: amountReceivedCents,
            tdsCents: tdsCents,
            referenceNumber: _refNumberController.text.trim(),
            paymentMethod: _selectedMethod,
            paymentDate: _selectedDate,
            notes: _notesController.text.trim(),
          );

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Recorded ${formatCents(amountReceivedCents)} received${tdsCents > 0 ? " (+${formatCents(tdsCents)} TDS)" : ""}. Total credit: ${formatCents(totalCreditCents)}.',
          ),
          backgroundColor: Colors.green.shade800,
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to record payment: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inv = widget.invoice;
    final dateDisplay =
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Record Payment & TDS',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${inv.invoiceNumber} • ${inv.clientName}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Balance summary card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _SummaryColumn(
                      label: 'Invoice Total',
                      value: formatCents(inv.totalCents),
                      color: theme.colorScheme.onSurface,
                    ),
                    _SummaryColumn(
                      label: 'Credited to Date',
                      value: formatCents(inv.paidCents),
                      color: Colors.green.shade700,
                    ),
                    _SummaryColumn(
                      label: 'Balance Due',
                      value: formatCents(inv.balanceDueCents),
                      color: inv.balanceDueCents > 0 ? Colors.indigo.shade700 : Colors.green.shade700,
                      isBold: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Quick Preset Buttons
              if (inv.balanceDueCents > 0) ...[
                Text(
                  'Quick Presets:',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.check_circle_outline, size: 16),
                      label: Text('Full Balance (${formatCents(inv.balanceDueCents)})'),
                      onPressed: () => _applyPresetAmount(inv.balanceDueCents),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.pie_chart_outline, size: 16),
                      label: Text('50% Deposit (${formatCents((inv.balanceDueCents / 2).round())})'),
                      onPressed: () => _applyPresetAmount((inv.balanceDueCents / 2).round()),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // Amount Received & TDS Fields Row
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _amountReceivedController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Amount Received in Bank *',
                        hintText: '0.00',
                        border: const OutlineInputBorder(),
                        errorText: _errorMessage != null ? '' : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _tdsController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'TDS / Tax Withheld',
                        hintText: '0.00',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 6),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
              const SizedBox(height: 16),

              // Payment Method & Reference Number
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<String>(
                      value: _selectedMethod,
                      decoration: const InputDecoration(
                        labelText: 'Payment Method *',
                        border: OutlineInputBorder(),
                      ),
                      items: _methods.map((method) {
                        return DropdownMenuItem(
                          value: method,
                          child: Text(method),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedMethod = val);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _refNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Bank Ref / UTR No.',
                        hintText: 'e.g. UTR982310',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Payment Date Picker
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Payment Date',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    dateDisplay,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Notes / Reference Field
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes / Payment Remarks (Optional)',
                  hintText: 'e.g., Client deducted 10% TDS under Sec 194J',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    icon: const Icon(Icons.payment),
                    label: const Text('Record Payment & Credit Ledger'),
                    onPressed: _submitPayment,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isBold;

  const _SummaryColumn({
    required this.label,
    required this.value,
    required this.color,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            color: color,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
