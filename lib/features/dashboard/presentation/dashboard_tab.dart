import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:billing_app/core/theme/app_theme.dart';
import 'package:billing_app/core/utils/money_utils.dart';
import 'package:billing_app/features/billing/presentation/widgets/cash_flow_metrics_bar.dart';
import 'package:billing_app/features/billing/presentation/widgets/payment_reminder_modal.dart';
import 'package:billing_app/features/business_profile/providers/business_profile_provider.dart';
import 'package:billing_app/features/estimates/providers/estimates_provider.dart';
import 'package:billing_app/features/expenses/providers/expenses_provider.dart';
import 'package:billing_app/features/invoices/providers/invoices_provider.dart';

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
    final profile = ref.watch(businessProfileProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final warningTone = AppSemanticColors.resolve(brightness, SemanticStatus.warning);
    final successTone = AppSemanticColors.resolve(brightness, SemanticStatus.success);
    final dangerTone = AppSemanticColors.resolve(brightness, SemanticStatus.danger);
    final infoTone = AppSemanticColors.resolve(brightness, SemanticStatus.info);

    String fmtDocMoney(int units, String code, String symbol, int decimals) {
      final resolved = resolveEffectiveCurrency(
        recordCode: code,
        recordSymbol: symbol,
        recordDecimals: code.trim().isNotEmpty ? decimals : null,
        defaultCode: profile.currencyCode,
        defaultSymbol: profile.currencySymbol,
        defaultDecimals: profile.currencyDecimals,
      );
      return formatMoney(
        units,
        symbol: resolved.symbol,
        decimals: resolved.decimals,
        currencyCode: resolved.code,
      );
    }

    // Triage items: Overdue active invoices and actionable (PENDING/ACCEPTED) quotes only
    final overdueInvoices = invoices.where((i) => i.isOverdue && i.balanceDueCents > 0 && !i.isDraft && !i.isVoid).toList();
    final actionableEstimates = estimates.where((e) {
      final st = e.status.trim().toUpperCase();
      return st == 'PENDING' || st == 'ACCEPTED';
    }).toList();
    final recentLedgerInvoices = invoices.where((i) => !i.isDraft && !i.isVoid).take(5).toList();

    final pagePadding = MediaQuery.sizeOf(context).width >= 900 ? 24.0 : 16.0;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(pagePadding, pagePadding, pagePadding, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
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
                    side: BorderSide(color: warningTone.border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  color: warningTone.background,
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
                                Icon(Icons.notification_important_outlined, color: warningTone.icon),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Action Required Triage (${overdueInvoices.length + actionableEstimates.length} Pending)',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: warningTone.text),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (overdueInvoices.isEmpty && actionableEstimates.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Text(
                                  'All client balances are up to date. No urgent action required.',
                                  style: TextStyle(color: successTone.icon, fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                              )
                            else ...[
                              ...overdueInvoices.map((inv) {
                                final formattedBalance = fmtDocMoney(
                                  inv.balanceDueCents,
                                  inv.currencyCode,
                                  inv.currencySymbol,
                                  inv.currencyDecimals,
                                );
                                final msg =
                                    'Invoice ${inv.invoiceNumber} for ${inv.clientName} is ${inv.daysOverdue} ${inv.daysOverdue == 1 ? 'day' : 'days'} overdue ($formattedBalance balance due).';
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
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 2),
                                                  child: Icon(Icons.error_outline, size: 16, color: dangerTone.icon),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(child: Text(msg, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colorScheme.onSurface))),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Align(alignment: Alignment.centerRight, child: btn),
                                          ],
                                        )
                                      : Row(
                                          children: [
                                            Icon(Icons.error_outline, size: 16, color: dangerTone.icon),
                                            const SizedBox(width: 8),
                                            Expanded(child: Text(msg, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colorScheme.onSurface))),
                                            const SizedBox(width: 12),
                                            btn,
                                          ],
                                        ),
                                );
                              }),
                              ...actionableEstimates.map((est) {
                                final formattedTotal = fmtDocMoney(
                                  est.totalCents,
                                  est.currencyCode,
                                  est.currencySymbol,
                                  est.currencyDecimals,
                                );
                                final msg =
                                    'Quote ${est.estimateNumber} for ${est.clientName} ($formattedTotal) is ready to be converted.';
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
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 2),
                                                  child: Icon(Icons.assignment_turned_in_outlined, size: 16, color: colorScheme.primary),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(child: Text(msg, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colorScheme.onSurface))),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Align(alignment: Alignment.centerRight, child: btn),
                                          ],
                                        )
                                      : Row(
                                          children: [
                                            Icon(Icons.assignment_turned_in_outlined, size: 16, color: colorScheme.primary),
                                            const SizedBox(width: 8),
                                            Expanded(child: Text(msg, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colorScheme.onSurface))),
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
              ],
            ),
          ),
        ),
        if (recentLedgerInvoices.isEmpty)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(pagePadding, 0, pagePadding, pagePadding),
            sliver: SliverToBoxAdapter(
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Text(
                      'No finalized invoices in recent activity yet.',
                      style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
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
                  final inv = recentLedgerInvoices[index];
                  final isLast = index == recentLedgerInvoices.length - 1;
                  return Card(
                    elevation: 0,
                    margin: EdgeInsets.only(bottom: isLast ? 0 : 8),
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: Theme.of(context).dividerColor),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: inv.isFullyPaid ? successTone.background : infoTone.background,
                        child: Icon(
                          inv.isFullyPaid ? Icons.check : Icons.receipt_long,
                          color: inv.isFullyPaid ? successTone.icon : infoTone.icon,
                          size: 18,
                        ),
                      ),
                      title: Text('${inv.invoiceNumber} • ${inv.clientName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Text('Issued: ${inv.issueDate} • Due: ${inv.dueDate} • Status: ${inv.computedStatus}', style: const TextStyle(fontSize: 11)),
                      trailing: Text(
                        fmtDocMoney(
                          inv.totalCents,
                          inv.currencyCode,
                          inv.currencySymbol,
                          inv.currencyDecimals,
                        ),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: inv.isFullyPaid ? successTone.icon : colorScheme.onSurface,
                        ),
                      ),
                    ),
                  );
                },
                childCount: recentLedgerInvoices.length,
              ),
            ),
          ),
      ],
    );
  }
}
