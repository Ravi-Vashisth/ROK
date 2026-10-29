import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/currency_formatter_provider.dart';
import '../../../core/utils/csv_export_service.dart';
import '../../business_profile/providers/business_profile_provider.dart';
import '../../clients/providers/clients_provider.dart';
import '../../expenses/providers/expenses_provider.dart';
import '../../invoices/providers/invoices_provider.dart';
import '../../billing/presentation/widgets/cash_flow_metrics_bar.dart';

class DashboardTab extends ConsumerWidget {
  final VoidCallback onNavigateToSales;
  final VoidCallback onNavigateToExpenses;

  const DashboardTab({
    super.key,
    required this.onNavigateToSales,
    required this.onNavigateToExpenses,
  });

  void _handleExportCsv(BuildContext context, WidgetRef ref) {
    final invoices = ref.read(invoicesProvider);
    final expenses = ref.read(expensesProvider);
    final clients = ref.read(clientsProvider);
    final profile = ref.read(businessProfileProvider);

    CsvExportService.showExportModal(
      context: context,
      invoices: invoices,
      expenses: expenses,
      clients: clients,
      currencySymbol: profile.currencySymbol,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoices = ref.watch(invoicesProvider);
    final expenses = ref.watch(expensesProvider);
    final formatCurrency = ref.watch(currencyFormatterProvider);

    final recentInvoices = invoices.take(5).toList();
    final recentExpenses = expenses.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Financial Overview & Dashboard',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        CashFlowMetricsBar(),
        const SizedBox(height: 28),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 850;
            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _RecentInvoicesCard(
                      invoices: recentInvoices,
                      formatCurrency: formatCurrency,
                      onViewAll: onNavigateToSales,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _RecentExpensesCard(
                      expenses: recentExpenses,
                      formatCurrency: formatCurrency,
                      onViewAll: onNavigateToExpenses,
                    ),
                  ),
                ],
              );
            } else {
              return Column(
                children: [
                  _RecentInvoicesCard(
                    invoices: recentInvoices,
                    formatCurrency: formatCurrency,
                    onViewAll: onNavigateToSales,
                  ),
                  const SizedBox(height: 20),
                  _RecentExpensesCard(
                    expenses: recentExpenses,
                    formatCurrency: formatCurrency,
                    onViewAll: onNavigateToExpenses,
                  ),
                ],
              );
            }
          },
        ),
      ],
    );
  }
}

class _RecentInvoicesCard extends StatelessWidget {
  final List invoices;
  final String Function(int) formatCurrency;
  final VoidCallback onViewAll;

  const _RecentInvoicesCard({
    required this.invoices,
    required this.formatCurrency,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Recent Invoices', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                TextButton(
                  onPressed: onViewAll,
                  child: const Text('View All'),
                ),
              ],
            ),
            const Divider(height: 12),
            if (invoices.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24.0),
                child: Center(child: Text('No invoices recorded yet.', style: TextStyle(color: Colors.grey))),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: invoices.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final inv = invoices[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${inv.invoiceNumber} • ${inv.clientName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text('Due: ${inv.dueDate} • ${inv.computedStatus}', style: const TextStyle(fontSize: 11)),
                    trailing: Text(
                      formatCurrency(inv.totalCents),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: inv.isFullyPaid ? Colors.green.shade700 : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _RecentExpensesCard extends StatelessWidget {
  final List expenses;
  final String Function(int) formatCurrency;
  final VoidCallback onViewAll;

  const _RecentExpensesCard({
    required this.expenses,
    required this.formatCurrency,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Recent Expenses', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                TextButton(
                  onPressed: onViewAll,
                  child: const Text('View All'),
                ),
              ],
            ),
            const Divider(height: 12),
            if (expenses.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24.0),
                child: Center(child: Text('No expenses recorded yet.', style: TextStyle(color: Colors.grey))),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: expenses.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final exp = expenses[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${exp.vendor} (${exp.category})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text('Date: ${exp.expenseDate}${exp.notes.isNotEmpty ? " • ${exp.notes}" : ""}', style: const TextStyle(fontSize: 11)),
                    trailing: Text(
                      formatCurrency(exp.totalCents),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
