import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:billing_app/core/utils/money_utils.dart';
import 'package:billing_app/features/invoices/models/invoice_record.dart';
import 'package:billing_app/features/invoices/providers/invoices_provider.dart';

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

  String get _sym => widget.invoice.currencySymbol.isNotEmpty ? widget.invoice.currencySymbol : '\$';
  int get _dec => widget.invoice.currencyCode.isNotEmpty
      ? widget.invoice.currencyDecimals
      : getCurrencyDecimals(_sym);
  String _fmt(int units) => formatMoney(units, symbol: _sym, decimals: _dec);

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _amountReceivedController.text = formatDecimalUnits(widget.invoice.balanceDueCents, _dec);
    _tdsController.text = formatDecimalUnits(0, _dec);
  }

  @override
  void dispose() {
    _amountReceivedController.dispose();
    _tdsController.dispose();
    _refNumberController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _applyPresetAmount(int units) {
    setState(() {
      _amountReceivedController.text = formatDecimalUnits(units, _dec);
      _tdsController.text = formatDecimalUnits(0, _dec);
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
    final amountReceivedCents = parsePriceToUnits(_amountReceivedController.text, _dec);
    final tdsCents = parsePriceToUnits(_tdsController.text, _dec);
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
            'Total credit (${_fmt(totalCreditCents)}) cannot exceed remaining balance due (${_fmt(widget.invoice.balanceDueCents)}).';
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
            'Recorded ${_fmt(amountReceivedCents)} received${tdsCents > 0 ? " (+${_fmt(tdsCents)} TDS)" : ""}. Total credit: ${_fmt(totalCreditCents)}.',
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

    final screenSize = MediaQuery.sizeOf(context);
    final isCompact = screenSize.width < 600;

    final amountField = TextFormField(
      controller: _amountReceivedController,
      keyboardType: _dec == 0
          ? TextInputType.number
          : const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: 'Amount Received in Bank *',
        hintText: formatDecimalUnits(0, _dec),
        border: const OutlineInputBorder(),
        errorText: _errorMessage != null ? '' : null,
      ),
    );

    final tdsField = TextFormField(
      controller: _tdsController,
      keyboardType: _dec == 0
          ? TextInputType.number
          : const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: 'TDS / Tax Withheld',
        hintText: formatDecimalUnits(0, _dec),
        border: const OutlineInputBorder(),
      ),
    );

    final methodDropdown = DropdownButtonFormField<String>(
      value: _selectedMethod,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Payment Method *',
        border: OutlineInputBorder(),
      ),
      items: _methods.map((method) {
        return DropdownMenuItem(
          value: method,
          child: Text(method, overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: (val) {
        if (val != null) {
          setState(() => _selectedMethod = val);
        }
      },
    );

    final refNumberField = TextFormField(
      controller: _refNumberController,
      decoration: const InputDecoration(
        labelText: 'Bank Ref / UTR No.',
        hintText: 'e.g. UTR982310',
        border: OutlineInputBorder(),
      ),
    );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: EdgeInsets.all(isCompact ? 12 : 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: screenSize.height * 0.88,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isCompact ? 16 : 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
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
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceAround,
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    _SummaryColumn(
                      label: 'Invoice Total',
                      value: _fmt(inv.totalCents),
                      color: theme.colorScheme.onSurface,
                    ),
                    _SummaryColumn(
                      label: 'Credited to Date',
                      value: _fmt(inv.paidCents),
                      color: Colors.green.shade700,
                    ),
                    _SummaryColumn(
                      label: 'Balance Due',
                      value: _fmt(inv.balanceDueCents),
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
                      label: Text('Full Balance (${_fmt(inv.balanceDueCents)})'),
                      onPressed: () => _applyPresetAmount(inv.balanceDueCents),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.pie_chart_outline, size: 16),
                      label: Text('50% Deposit (${_fmt((inv.balanceDueCents + 1) ~/ 2)})'),
                      onPressed: () => _applyPresetAmount((inv.balanceDueCents + 1) ~/ 2),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // Amount Received & TDS Fields Row
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 420) {
                    return Column(
                      children: [
                        amountField,
                        const SizedBox(height: 12),
                        tdsField,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(flex: 3, child: amountField),
                      const SizedBox(width: 12),
                      Expanded(flex: 2, child: tdsField),
                    ],
                  );
                },
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
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 420) {
                    return Column(
                      children: [
                        methodDropdown,
                        const SizedBox(height: 12),
                        refNumberField,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(flex: 3, child: methodDropdown),
                      const SizedBox(width: 12),
                      Expanded(flex: 3, child: refNumberField),
                    ],
                  );
                },
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
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
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
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    FilledButton.icon(
                      icon: const Icon(Icons.payment),
                      label: const Text('Record Payment & Credit Ledger'),
                      onPressed: _submitPayment,
                    ),
                  ],
                ),
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
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
