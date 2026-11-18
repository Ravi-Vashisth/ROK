import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:billing_app/core/utils/money_utils.dart';
import 'package:billing_app/features/business_profile/providers/business_profile_provider.dart';
import 'package:billing_app/features/expenses/providers/expenses_provider.dart';
import 'package:billing_app/features/invoices/providers/invoices_provider.dart';

class CashFlowMetricsBar extends ConsumerWidget {
  const CashFlowMetricsBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoices = ref.watch(invoicesProvider);
    final expenses = ref.watch(expensesProvider);
    final profile = ref.watch(businessProfileProvider);

    final activeEntries = invoices
        .where((inv) => !inv.isVoid && !inv.isDraft)
        .map((inv) => CurrencyLedgerEntry(
              currencyCode: inv.currencyCode,
              currencySymbol: inv.currencySymbol,
              currencyDecimals: inv.currencyDecimals,
              totalUnits: inv.totalCents,
              paidUnits: inv.paidCents,
              balanceDueUnits: inv.isFullyPaid ? 0 : inv.balanceDueCents,
              taxUnits: inv.taxCents,
              isOverdue: !inv.isFullyPaid && inv.isOverdue,
            ));

    int totalExpensesGrossCents = 0;
    int totalExpenseTaxCents = 0;
    for (final exp in expenses) {
      totalExpensesGrossCents += exp.totalCents;
      totalExpenseTaxCents += exp.taxCents;
    }

    final summary = computeDashboardCashFlow(
      activeEntries,
      expenseGrossUnits: totalExpensesGrossCents,
      expenseTaxUnits: totalExpenseTaxCents,
      defaultCode: profile.currencyCode,
      defaultSymbol: profile.currencySymbol,
      defaultDecimals: profile.currencyDecimals,
    );

    final tiles = [
      _MetricTile(
        title: 'Unpaid Receivables',
        value: summary.formattedUnpaid,
        icon: Icons.warning_amber_outlined,
        iconColor: Colors.red.shade700,
        backgroundColor: Colors.red.shade50.withValues(alpha: 0.5),
        borderColor: Colors.red.shade200,
        textColor: Colors.red.shade900,
        subtitle: 'Overdue: ${summary.formattedOverdue}',
      ),
      _MetricTile(
        title: 'Gross Collected',
        value: summary.formattedCollected,
        icon: Icons.check_circle_outline,
        iconColor: Colors.green.shade700,
        backgroundColor: Colors.green.shade50.withValues(alpha: 0.5),
        borderColor: Colors.green.shade200,
        textColor: Colors.green.shade900,
      ),
      _MetricTile(
        title: 'Tax Liability / GST',
        value: summary.formattedTaxLiability,
        icon: Icons.account_balance_wallet_outlined,
        iconColor: !summary.hasAnyNegativeTaxLiability ? Colors.purple.shade700 : Colors.teal.shade700,
        backgroundColor: Colors.purple.shade50.withValues(alpha: 0.5),
        borderColor: Colors.purple.shade200,
        textColor: Colors.purple.shade900,
      ),
      _MetricTile(
        title: 'Real Net Profit',
        value: summary.formattedNetProfit,
        icon: Icons.pie_chart_outline,
        iconColor: !summary.hasNetLoss ? Colors.blue.shade700 : Colors.red.shade700,
        backgroundColor: !summary.hasNetLoss
            ? Colors.blue.shade50.withValues(alpha: 0.5)
            : Colors.red.shade50.withValues(alpha: 0.5),
        borderColor: !summary.hasNetLoss ? Colors.blue.shade200 : Colors.red.shade200,
        textColor: !summary.hasNetLoss ? Colors.blue.shade900 : Colors.red.shade900,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 460) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < tiles.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                tiles[i],
              ],
            ],
          );
        }

        if (constraints.maxWidth < 900) {
          return Column(
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: tiles[0]),
                    const SizedBox(width: 10),
                    Expanded(child: tiles[1]),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: tiles[2]),
                    const SizedBox(width: 10),
                    Expanded(child: tiles[3]),
                  ],
                ),
              ),
            ],
          );
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < tiles.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: tiles[i]),
              ],
            ],
          ),
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: textColor ?? Colors.grey.shade700,
                  ),
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
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: textColor ?? Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: Colors.red.shade800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
