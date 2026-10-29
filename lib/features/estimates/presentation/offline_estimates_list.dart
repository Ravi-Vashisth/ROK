import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money_utils.dart';
import '../../billing/presentation/widgets/pdf_preview_dialog.dart';
import '../../billing/services/invoice_pdf_service.dart';
import '../../business_profile/providers/business_profile_provider.dart';
import '../../clients/models/client.dart';
import '../../clients/providers/clients_provider.dart';
import '../../invoices/providers/invoices_provider.dart';
import '../models/estimate_record.dart';
import '../providers/estimates_provider.dart';

class OfflineEstimatesList extends ConsumerWidget {
  final String searchQuery;
  final String statusFilter;
  final String dateFilter;
  final Function(String invoiceNumber)? onViewInvoice;

  const OfflineEstimatesList({
    super.key,
    this.searchQuery = '',
    this.statusFilter = 'All',
    this.dateFilter = 'All Time',
    this.onViewInvoice,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estimates = ref.watch(estimatesProvider);
    final clients = ref.watch(clientsProvider);
    final businessProfile = ref.watch(businessProfileProvider);
    final invoices = ref.watch(invoicesProvider);
    final sym = businessProfile.currencySymbol;

    // Filter estimates
    final filtered = estimates.where((est) {
      if (searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase();
        final matchName = est.clientName.toLowerCase().contains(q);
        final matchNum = est.estimateNumber.toLowerCase().contains(q);
        if (!matchName && !matchNum) return false;
      }

      if (statusFilter != 'All') {
        if (statusFilter.toUpperCase() == 'CONVERTED' && !est.isConverted) return false;
        if (statusFilter.toUpperCase() == 'PENDING' && est.isConverted) return false;
      }
      return true;
    }).toList();

    if (estimates.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              Icon(Icons.request_quote_outlined, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              const Text('No Estimates / Proposals Found', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              const Text('Create an estimate above to send project quotes to clients.', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.list_alt_outlined, size: 20),
            const SizedBox(width: 8),
            Text('Saved Estimates (${filtered.length} of ${estimates.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text('No estimates match your current search and filter criteria.', style: TextStyle(color: Colors.grey)),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final est = filtered[index];
              final isConverted = est.isConverted;
              final convertedInvoice = isConverted && est.convertedInvoiceId.isNotEmpty
                  ? invoices.cast<dynamic?>().firstWhere(
                      (i) => i?.id == est.convertedInvoiceId,
                      orElse: () => null,
                    )
                  : null;

              return Card(
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
                              color: Colors.indigo.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.indigo.shade200),
                            ),
                            child: Text(est.estimateNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.indigo)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(est.clientName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isConverted ? Colors.green.shade50 : Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: isConverted ? Colors.green.shade300 : Colors.amber.shade300),
                            ),
                            child: Text(
                              est.status,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isConverted ? Colors.green.shade800 : Colors.amber.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Issue: ${est.issueDate} • Valid Until: ${est.expiryDate}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      if (isConverted && convertedInvoice != null) ...[
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () {
                            if (onViewInvoice != null) {
                              onViewInvoice!(convertedInvoice.invoiceNumber);
                            }
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.shade300),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.receipt_outlined, size: 14, color: Colors.green.shade800),
                                const SizedBox(width: 6),
                                Text(
                                  'View Invoice: ${convertedInvoice.invoiceNumber}',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.arrow_forward, size: 13, color: Colors.green.shade800),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total: ${formatCents(est.totalCents, symbol: sym)}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.indigo.shade800)),
                          Row(
                            children: [
                              if (!isConverted)
                                FilledButton.icon(
                                  style: FilledButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                  icon: const Icon(Icons.receipt_long, size: 16),
                                  label: const Text('Convert to Invoice', style: TextStyle(fontSize: 12)),
                                  onPressed: () {
                                    ref.read(estimatesProvider.notifier).convertEstimateToInvoice(est.id);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Estimate ${est.estimateNumber} converted into live invoice!')),
                                    );
                                  },
                                ),
                              const SizedBox(width: 8),
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
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
