import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:billing_app/core/theme/app_theme.dart';
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

    final brightness = Theme.of(context).brightness;
    final dangerTone = AppSemanticColors.resolve(brightness, SemanticStatus.danger);
    final successTone = AppSemanticColors.resolve(brightness, SemanticStatus.success);
    final purpleTone = AppSemanticColors.resolve(brightness, SemanticStatus.purple);
    final infoTone = AppSemanticColors.resolve(brightness, SemanticStatus.info);

    final taxTone = !summary.hasAnyNegativeTaxLiability ? purpleTone : successTone;
    final profitTone = !summary.hasNetLoss ? infoTone : dangerTone;

    final tiles = [
      _MetricTile(
        title: 'Unpaid Receivables',
        value: summary.formattedUnpaid,
        icon: Icons.warning_amber_outlined,
        iconColor: dangerTone.icon,
        backgroundColor: dangerTone.background,
        borderColor: dangerTone.border,
        textColor: dangerTone.text,
        subtitle: 'Overdue: ${summary.formattedOverdue}',
        subtitleColor: dangerTone.text,
      ),
      _MetricTile(
        title: 'Gross Collected',
        value: summary.formattedCollected,
        icon: Icons.check_circle_outline,
        iconColor: successTone.icon,
        backgroundColor: successTone.background,
        borderColor: successTone.border,
        textColor: successTone.text,
      ),
      _MetricTile(
        title: 'Tax Liability / GST',
        value: summary.formattedTaxLiability,
        icon: Icons.account_balance_wallet_outlined,
        iconColor: taxTone.icon,
        backgroundColor: taxTone.background,
        borderColor: taxTone.border,
        textColor: taxTone.text,
      ),
      _MetricTile(
        title: 'Real Net Profit',
        value: summary.formattedNetProfit,
        icon: Icons.pie_chart_outline,
        iconColor: profitTone.icon,
        backgroundColor: profitTone.background,
        borderColor: profitTone.border,
        textColor: profitTone.text,
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
  final Color? subtitleColor;

  const _MetricTile({
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    this.borderColor,
    this.textColor,
    this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
                    color: textColor ?? colorScheme.onSurfaceVariant,
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
                color: textColor ?? colorScheme.onSurface,
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
                color: subtitleColor ?? colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
