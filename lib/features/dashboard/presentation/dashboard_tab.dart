import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/currency_formatter_provider.dart';
import '../../billing/presentation/widgets/cash_flow_metrics_bar.dart';
import '../../billing/presentation/widgets/payment_reminder_modal.dart';
import '../../estimates/providers/estimates_provider.dart';
import '../../expenses/providers/expenses_provider.dart';
import '../../invoices/providers/invoices_provider.dart';

class DashboardTab extends ConsumerWidget {
  final VoidCallback onNavigateToInvoices;
  final VoidCallback onNavigateToEstimates;
  final VoidCallback onNavigateToExpenses;

  const DashboardTab({
    super.key,
    required this.onNavigateToInvoices,
    required this.onNavigateToEstimates,
    required this.onNavigateToExpenses,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoices = ref.watch(invoicesProvider);
    final estimates = ref.watch(estimatesProvider);
    ref.watch(expensesProvider);
    final formatCurrency = ref.watch(currencyFormatterProvider);

    // Triage items: Overdue invoices, pending/accepted estimates
    final overdueInvoices = invoices.where((i) => i.isOverdue && i.balanceDueCents > 0 && !i.isDraft && !i.isVoid).toList();
    final acceptedEstimates = estimates.where((e) => !e.isConverted).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            Text(
              'Business Pulse & Action Center',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            // Top Quick-Action Bar
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: onNavigateToInvoices,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Create Invoice'),
                ),
                FilledButton.tonalIcon(
                  onPressed: onNavigateToEstimates,
                  icon: const Icon(Icons.request_quote_outlined, size: 16),
                  label: const Text('New Quote'),
                ),
                OutlinedButton.icon(
                  onPressed: onNavigateToExpenses,
                  icon: const Icon(Icons.receipt_long_outlined, size: 16),
                  label: const Text('Log Expense'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),
        const CashFlowMetricsBar(),
        const SizedBox(height: 24),

        // Action Required Triage Inbox
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Colors.amber.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          color: Colors.amber.shade50.withValues(alpha: 0.3),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompactTriage = constraints.maxWidth < 600;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.notification_important_outlined, color: Colors.amber.shade900),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Action Required Triage (${overdueInvoices.length + acceptedEstimates.length} Pending)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.amber.shade900),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (overdueInvoices.isEmpty && acceptedEstimates.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          'All client balances are up to date. No urgent action required.',
                          style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      )
                    else ...[
                      ...overdueInvoices.map((inv) {
                        final msg =
                            'Invoice ${inv.invoiceNumber} for ${inv.clientName} is ${inv.daysOverdue} ${inv.daysOverdue == 1 ? 'day' : 'days'} overdue (${formatCurrency(inv.balanceDueCents)} balance due).';
                        final btn = OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                          onPressed: () => showDialog(
                            context: context,
                            builder: (_) => PaymentReminderModal(invoice: inv),
                          ),
                          icon: const Icon(Icons.send, size: 14),
                          label: const Text('Send Reminder'),
                        );
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: isCompactTriage
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Padding(
                                          padding: EdgeInsets.only(top: 2),
                                          child: Icon(Icons.error_outline, size: 16, color: Colors.red),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(child: Text(msg, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Align(alignment: Alignment.centerRight, child: btn),
                                  ],
                                )
                              : Row(
                                  children: [
                                    const Icon(Icons.error_outline, size: 16, color: Colors.red),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(msg, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                                    const SizedBox(width: 12),
                                    btn,
                                  ],
                                ),
                        );
                      }),
                      ...acceptedEstimates.map((est) {
                        final msg =
                            'Quote ${est.estimateNumber} for ${est.clientName} (${formatCurrency(est.totalCents)}) is ready to be converted.';
                        final btn = FilledButton.icon(
                          style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                          onPressed: () {
                            ref.read(estimatesProvider.notifier).convertEstimateToInvoice(est.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Quote ${est.estimateNumber} converted to live invoice!')),
                            );
                          },
                          icon: const Icon(Icons.arrow_forward, size: 14),
                          label: const Text('Convert to Invoice'),
                        );
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: isCompactTriage
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Padding(
                                          padding: EdgeInsets.only(top: 2),
                                          child: Icon(Icons.assignment_turned_in_outlined, size: 16, color: Colors.indigo),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(child: Text(msg, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Align(alignment: Alignment.centerRight, child: btn),
                                  ],
                                )
                              : Row(
                                  children: [
                                    const Icon(Icons.assignment_turned_in_outlined, size: 16, color: Colors.indigo),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(msg, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                                    const SizedBox(width: 12),
                                    btn,
                                  ],
                                ),
                        );
                      }),
                    ],
                  ],
                );
              },
            ),
          ),
        ),

        const SizedBox(height: 24),
        Text(
          'Recent Activity Ledger',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: invoices.take(5).length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final inv = invoices[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: inv.isFullyPaid ? Colors.green.shade100 : Colors.blue.shade100,
                  child: Icon(
                    inv.isFullyPaid ? Icons.check : Icons.receipt_long,
                    color: inv.isFullyPaid ? Colors.green.shade800 : Colors.blue.shade800,
                    size: 18,
                  ),
                ),
                title: Text('${inv.invoiceNumber} • ${inv.clientName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text('Issued: ${inv.issueDate} • Due: ${inv.dueDate} • Status: ${inv.computedStatus}', style: const TextStyle(fontSize: 11)),
                trailing: Text(
                  formatCurrency(inv.totalCents),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: inv.isFullyPaid ? Colors.green.shade700 : null,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
