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

    int totalInvoicedCents = 0;
    int totalCollectedCents = 0;
    int totalExpensesCents = 0;

    for (final inv in invoices) {
      totalInvoicedCents += inv.totalCents;
      totalCollectedCents += inv.paidCents;
    }

    for (final exp in expenses) {
      totalExpensesCents += exp.totalCents;
    }

    final netProfitCents = totalCollectedCents - totalExpensesCents;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 650;

        return GridView.count(
          crossAxisCount: isCompact ? 2 : 4,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          childAspectRatio: isCompact ? 2.2 : 2.5,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _MetricTile(
              title: 'Total Invoiced',
              value: formatCurrency(totalInvoicedCents),
              icon: Icons.receipt_long_outlined,
              iconColor: Colors.indigo,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            ),
            _MetricTile(
              title: 'Total Collected',
              value: formatCurrency(totalCollectedCents),
              icon: Icons.check_circle_outline,
              iconColor: Colors.green,
              backgroundColor: Colors.green.shade50.withValues(alpha: 0.5),
              borderColor: Colors.green.shade200,
              textColor: Colors.green.shade900,
            ),
            _MetricTile(
              title: 'Total Expenses',
              value: formatCurrency(totalExpensesCents),
              icon: Icons.trending_down_outlined,
              iconColor: Colors.orange,
              backgroundColor: Colors.orange.shade50.withValues(alpha: 0.5),
              borderColor: Colors.orange.shade200,
              textColor: Colors.orange.shade900,
            ),
            _MetricTile(
              title: 'Net Profit (Coll. - Exp.)',
              value: formatCurrency(netProfitCents),
              icon: Icons.account_balance_wallet_outlined,
              iconColor: netProfitCents >= 0 ? Colors.blue : Colors.red,
              backgroundColor: netProfitCents >= 0 ? Colors.blue.shade50.withValues(alpha: 0.5) : Colors.red.shade50.withValues(alpha: 0.5),
              borderColor: netProfitCents >= 0 ? Colors.blue.shade200 : Colors.red.shade200,
              textColor: netProfitCents >= 0 ? Colors.blue.shade900 : Colors.red.shade900,
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
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final Color? borderColor;
  final Color? textColor;

  const _MetricTile({
    required this.title,
    required this.value,
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
        borderRadius: BorderRadius.circular(10),
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
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor ?? Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
