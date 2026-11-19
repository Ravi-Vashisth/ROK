import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:billing_app/core/theme/app_theme.dart';
import 'package:billing_app/core/utils/money_utils.dart';
import 'package:billing_app/features/billing/presentation/widgets/pdf_preview_dialog.dart';
import 'package:billing_app/features/billing/services/invoice_pdf_service.dart';
import 'package:billing_app/features/business_profile/providers/business_profile_provider.dart';
import 'package:billing_app/features/clients/models/client.dart';
import 'package:billing_app/features/clients/providers/clients_provider.dart';
import 'package:billing_app/features/invoices/presentation/invoice_editor_screen.dart';
import 'package:billing_app/features/invoices/providers/invoices_provider.dart';
import 'package:billing_app/features/estimates/providers/estimates_provider.dart';

class OfflineEstimatesList extends ConsumerWidget {
  final String searchQuery;
  final String statusFilter;
  final String dateFilter;
  final Function(String invoiceNumber)? onViewInvoice;
  final List<Widget> leadingSlivers;

  const OfflineEstimatesList({
    super.key,
    this.searchQuery = '',
    this.statusFilter = 'All',
    this.dateFilter = 'All Time',
    this.onViewInvoice,
    this.leadingSlivers = const [],
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estimates = ref.watch(estimatesProvider);
    final clients = ref.watch(clientsProvider);
    final businessProfile = ref.watch(businessProfileProvider);
    final invoices = ref.watch(invoicesProvider);
    final sym = businessProfile.currencySymbol;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final brightness = theme.brightness;
    final successTone = AppSemanticColors.resolve(brightness, SemanticStatus.success);
    final warningTone = AppSemanticColors.resolve(brightness, SemanticStatus.warning);

    // Filter estimates
    final filtered = estimates.where((est) {
      if (searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase();
        final matchName = est.clientName.toLowerCase().contains(q);
        final matchNum = est.estimateNumber.toLowerCase().contains(q);
        if (!matchName && !matchNum) return false;
      }

      if (statusFilter != 'All') {
        final filterUpper = statusFilter.toUpperCase();
        final estStatusUpper = est.status.toUpperCase();
        if (filterUpper == 'DRAFT' && estStatusUpper != 'DRAFT') return false;
        if (filterUpper == 'PENDING' && (estStatusUpper != 'PENDING' || est.isConverted)) return false;
        if (filterUpper == 'ACCEPTED' && estStatusUpper != 'ACCEPTED') return false;
        if (filterUpper == 'DECLINED' && estStatusUpper != 'DECLINED') return false;
        if (filterUpper == 'CONVERTED' && !est.isConverted && estStatusUpper != 'CONVERTED') return false;
      }

      if (!matchesDateFilter(est.issueDate, dateFilter)) return false;
      return true;
    }).toList();

    final pagePadding = MediaQuery.sizeOf(context).width >= 900 ? 24.0 : 16.0;

    if (estimates.isEmpty) {
      return CustomScrollView(
        slivers: [
          ...leadingSlivers,
          SliverPadding(
            padding: EdgeInsets.fromLTRB(pagePadding, 0, pagePadding, pagePadding),
            sliver: SliverToBoxAdapter(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      Icon(Icons.request_quote_outlined, size: 48, color: colorScheme.onSurfaceVariant),
                      const SizedBox(height: 12),
                      const Text('No Estimates / Proposals Found', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text('Create an estimate above to send project quotes to clients.', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return CustomScrollView(
      slivers: [
        ...leadingSlivers,
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: pagePadding),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.list_alt_outlined, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Saved Estimates (${filtered.length} of ${estimates.length})',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        if (filtered.isEmpty)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(pagePadding, 0, pagePadding, pagePadding),
            sliver: SliverToBoxAdapter(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.dividerColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text('No estimates match your current search and filter criteria.', style: TextStyle(color: colorScheme.onSurfaceVariant)),
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
                  final est = filtered[index];
                  final isConverted = est.isConverted;
                  final isLast = index == filtered.length - 1;
                  final convertedInvoice = isConverted && est.convertedInvoiceId.isNotEmpty
                      ? invoices.cast<dynamic>().firstWhere(
                          (i) => i?.id == est.convertedInvoiceId,
                          orElse: () => null,
                        )
                      : null;

                  return Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
                    child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: colorScheme.primary.withValues(alpha: 0.35)),
                            ),
                            child: Text(
                              est.estimateNumber,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: colorScheme.onPrimaryContainer),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(est.clientName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isConverted ? successTone.background : warningTone.background,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: isConverted ? successTone.border : warningTone.border),
                            ),
                            child: Text(
                              est.status,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isConverted ? successTone.text : warningTone.text,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Issue: ${est.issueDate} • Valid Until: ${est.expiryDate}', style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
                      if (isConverted && convertedInvoice != null) ...[
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () {
                            if (onViewInvoice != null) {
                              onViewInvoice!(convertedInvoice.invoiceNumber);
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: successTone.background,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: successTone.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.receipt_outlined, size: 14, color: successTone.icon),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'View Invoice: ${convertedInvoice.invoiceNumber}',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: successTone.text),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.arrow_forward, size: 13, color: successTone.icon),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        runSpacing: 10,
                        children: [
                          Text(
                            'Total: ${formatCents(est.totalCents, symbol: est.currencySymbol.isNotEmpty ? est.currencySymbol : sym, decimals: est.currencyCode.isNotEmpty ? est.currencyDecimals : businessProfile.currencyDecimals)}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              fontFeatures: const [FontFeature.tabularFigures()],
                              color: colorScheme.primary,
                            ),
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (est.status == 'DRAFT') ...[
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.edit_outlined, size: 16),
                                  label: const Text('Edit Draft', style: TextStyle(fontSize: 12)),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => InvoiceEditorScreen(
                                          isQuote: true,
                                          existingEstimate: est,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: colorScheme.primary,
                                    foregroundColor: colorScheme.onPrimary,
                                  ),
                                  icon: const Icon(Icons.check_circle_outline, size: 16),
                                  label: const Text('Finalize Quote', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  onPressed: () {
                                    ref.read(estimatesProvider.notifier).finalizeDraftEstimate(est.id);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Quote ${est.estimateNumber} finalized and issued!')),
                                    );
                                  },
                                ),
                              ] else if (!isConverted) ...[
                                FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: brightness == Brightness.dark
                                        ? const Color(0xFF15803D)
                                        : const Color(0xFF16A34A),
                                    foregroundColor: Colors.white,
                                  ),
                                  icon: const Icon(Icons.receipt_long, size: 16),
                                  label: const Text('Convert to Invoice', style: TextStyle(fontSize: 12)),
                                  onPressed: () {
                                    ref.read(estimatesProvider.notifier).convertEstimateToInvoice(est.id);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Estimate ${est.estimateNumber} converted into live invoice!')),
                                    );
                                  },
                                ),
                              ],
                              OutlinedButton.icon(
                                icon: const Icon(Icons.picture_as_pdf, size: 16),
                                label: const Text('PDF / Print', style: TextStyle(fontSize: 12)),
                                onPressed: () {
                                  final client = clients.firstWhere(
                                    (c) => c.id == est.clientId,
                                    orElse: () => Client(id: est.clientId, name: est.clientName, email: '', phone: '', address: '', taxId: '', createdAt: ''),
                                  );
                                  final items = ref.read(estimatesProvider.notifier).getEstimateItems(est.id);
                                  showDialog(
                                    context: context,
                                    builder: (_) => PdfPreviewDialog(
                                      title: 'Estimate ${est.estimateNumber}',
                                      buildPdf: () => InvoicePdfService.generateEstimatePdf(
                                        estimate: est,
                                        items: items,
                                        client: client,
                                        businessProfile: businessProfile,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                tooltip: 'Delete Quote',
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Delete Quote'),
                                      content: Text('Are you sure you want to delete quote ${est.estimateNumber}?'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                                        FilledButton(
                                          style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                          onPressed: () {
                                            ref.read(estimatesProvider.notifier).deleteEstimate(est.id);
                                            Navigator.pop(ctx);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Quote ${est.estimateNumber} deleted.')),
                                            );
                                          },
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
                },
                childCount: filtered.length,
              ),
            ),
          ),
      ],
    );
  }
}
