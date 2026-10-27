import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../core/utils/money_utils.dart';
import '../../billing/services/invoice_pdf_service.dart';
import '../../business_profile/providers/business_profile_provider.dart';
import '../../clients/providers/clients_provider.dart';
import '../models/estimate_record.dart';
import '../providers/estimates_provider.dart';

class OfflineEstimatesList extends ConsumerWidget {
  const OfflineEstimatesList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estimates = ref.watch(estimatesProvider);
    final clients = ref.watch(clientsProvider);
    final businessProfile = ref.watch(businessProfileProvider);
    final sym = businessProfile.currencySymbol;

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
            Text('Saved Estimates (${estimates.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: estimates.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final est = estimates[index];
            final isConverted = est.isConverted;

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
                            color: isConverted ? Colors.emerald.shade50 : Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: isConverted ? Colors.emerald.shade300 : Colors.amber.shade300),
                          ),
                          child: Text(
                            est.status,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isConverted ? Colors.emerald.shade800 : Colors.amber.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Issue: ${est.issueDate} • Valid Until: ${est.expiryDate}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total: ${formatCents(est.totalCents, symbol: sym)}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.indigo.shade800)),
                        Row(
                          children: [
                            if (!isConverted)
                              FilledButton.icon(
                                style: FilledButton.styleFrom(backgroundColor: Colors.emerald, foregroundColor: Colors.white),
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
                              onPressed: () async {
                                final client = clients.firstWhere(
                                  (c) => c.id == est.clientId,
                                  orElse: () => Client(id: est.clientId, name: est.clientName, email: '', phone: '', address: '', taxId: '', createdAt: ''),
                                );
                                final items = ref.read(estimatesProvider.notifier).getEstimateItems(est.id);
                                final pdfBytes = await InvoicePdfService.generateEstimatePdf(
                                  estimate: est,
                                  items: items,
                                  client: client,
                                  businessProfile: businessProfile,
                                );
                                await Printing.layoutPdf(
                                  onLayout: (_) async => pdfBytes,
                                  name: 'Estimate_${est.estimateNumber}.pdf',
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
