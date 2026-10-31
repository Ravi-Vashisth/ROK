import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/currency_formatter_provider.dart';
import '../../../expenses/providers/expenses_provider.dart';
import '../../../invoices/providers/invoices_provider.dart';

class CashFlowMetricsBar extends ConsumerWidget {
  const CashFlowMetricsBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoices = ref.watch(invoicesProvider);
    final expenses = ref.watch(expensesProvider);
    final formatCurrency = ref.watch(currencyFormatterProvider);

    int totalUnpaidReceivablesCents = 0;
    int totalOverdueReceivablesCents = 0;
    int totalCollectedGrossCents = 0;
    int taxCollectedOnPaymentsCents = 0;

    for (final inv in invoices) {
      if (inv.isVoid || inv.isDraft) continue;
      if (!inv.isFullyPaid) {
        totalUnpaidReceivablesCents += inv.balanceDueCents;
        if (inv.isOverdue) {
          totalOverdueReceivablesCents += inv.balanceDueCents;
        }
      }
      totalCollectedGrossCents += inv.paidCents;
      if (inv.totalCents > 0) {
        taxCollectedOnPaymentsCents += ((inv.paidCents * inv.taxCents) ~/ inv.totalCents);
      }
    }

    int totalExpensesGrossCents = 0;
    int totalExpenseTaxCents = 0;
    for (final exp in expenses) {
      totalExpensesGrossCents += exp.totalCents;
      totalExpenseTaxCents += exp.taxCents;
    }
    final totalExpensesExclTaxCents = (totalExpensesGrossCents - totalExpenseTaxCents).clamp(0, totalExpensesGrossCents);

    final taxLiabilityCents = taxCollectedOnPaymentsCents - totalExpenseTaxCents;
    final netRevenueExclTaxCents = totalCollectedGrossCents - taxCollectedOnPaymentsCents;
    final realNetProfitCents = netRevenueExclTaxCents - totalExpensesExclTaxCents;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 750;

        return GridView.count(
          crossAxisCount: isCompact ? 2 : 4,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          shrinkWrap: true,
          childAspectRatio: isCompact ? 2.1 : 2.2,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _MetricTile(
              title: 'Unpaid Receivables',
              value: formatCurrency(totalUnpaidReceivablesCents),
              icon: Icons.warning_amber_outlined,
              iconColor: Colors.red.shade700,
              backgroundColor: Colors.red.shade50.withValues(alpha: 0.5),
              borderColor: Colors.red.shade200,
              textColor: Colors.red.shade900,
              subtitle: 'Overdue: ${formatCurrency(totalOverdueReceivablesCents)}',
            ),
            _MetricTile(
              title: 'Gross Collected',
              value: formatCurrency(totalCollectedGrossCents),
              icon: Icons.check_circle_outline,
              iconColor: Colors.green.shade700,
              backgroundColor: Colors.green.shade50.withValues(alpha: 0.5),
              borderColor: Colors.green.shade200,
              textColor: Colors.green.shade900,
            ),
            _MetricTile(
              title: 'Tax Liability / GST',
              value: formatCurrency(taxLiabilityCents),
              icon: Icons.account_balance_wallet_outlined,
              iconColor: taxLiabilityCents >= 0 ? Colors.purple.shade700 : Colors.teal.shade700,
              backgroundColor: Colors.purple.shade50.withValues(alpha: 0.5),
              borderColor: Colors.purple.shade200,
              textColor: Colors.purple.shade900,
            ),
            _MetricTile(
              title: 'Real Net Profit',
              value: formatCurrency(realNetProfitCents),
              icon: Icons.pie_chart_outline,
              iconColor: realNetProfitCents >= 0 ? Colors.blue.shade700 : Colors.red.shade700,
              backgroundColor: realNetProfitCents >= 0
                  ? Colors.blue.shade50.withValues(alpha: 0.5)
                  : Colors.red.shade50.withValues(alpha: 0.5),
              borderColor: realNetProfitCents >= 0 ? Colors.blue.shade200 : Colors.red.shade200,
              textColor: realNetProfitCents >= 0 ? Colors.blue.shade900 : Colors.red.shade900,
            ),
          ],
        );
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final Color? borderColor;
  final Color? textColor;

  const _MetricTile({
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    this.borderColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor ?? Theme.of(context).dividerColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: textColor ?? Colors.grey.shade700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor ?? Theme.of(context).colorScheme.onSurface,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.red.shade800),
            ),
        ],
      ),
    );
  }
}
