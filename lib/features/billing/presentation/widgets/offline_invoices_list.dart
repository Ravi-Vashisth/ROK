import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../../core/utils/money_utils.dart';
import '../../../business_profile/providers/business_profile_provider.dart';
import '../../../invoices/models/invoice_item.dart';
import '../../../invoices/models/invoice_record.dart';
import '../../../invoices/providers/invoices_provider.dart';
import '../../services/invoice_pdf_service.dart';

class OfflineInvoicesList extends ConsumerWidget {
  const OfflineInvoicesList({super.key});

  void _handlePrint(BuildContext context, WidgetRef ref, InvoiceRecord inv) async {
    final items = ref.read(invoicesProvider.notifier).getInvoiceItems(inv.id);
    final businessProfile = ref.read(businessProfileProvider);

    try {
      await Printing.layoutPdf(
        onLayout: (format) => InvoicePdfService.generateInvoicePdf(
          invoice: inv,
          items: items,
          clientName: inv.clientName,
          businessProfile: businessProfile,
        ),
        name: '${inv.invoiceNumber}.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Print/PDF Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoices = ref.watch(invoicesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Offline Invoices (${invoices.length})',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        if (invoices.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text(
                'No invoices saved in local SQLite yet.\nCreate your first client and invoice above.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: invoices.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final inv = invoices[index];
                return ExpansionTile(
                  key: PageStorageKey('invoice_${inv.id}'),
                  leading: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      inv.invoiceNumber,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  title: Text(
                    inv.clientName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Subtotal: ${formatCents(inv.subtotalCents)} | Tax: ${formatCents(inv.taxCents)} | Status: ${inv.status}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formatCents(inv.totalCents),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                      const SizedBox(width: 12),
                      // Prominent, unmissable PDF / Print action button on every card
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.picture_as_pdf, size: 16),
                        label: const Text('PDF / Print', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => _handlePrint(context, ref, inv),
                      ),
                    ],
                  ),
                  children: [
                    _InvoiceItemsBreakdown(
                      invoice: inv,
                      onPrint: () => _handlePrint(context, ref, inv),
                    ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }
}

class _InvoiceItemsBreakdown extends ConsumerWidget {
  final InvoiceRecord invoice;
  final VoidCallback onPrint;

  const _InvoiceItemsBreakdown({
    required this.invoice,
    required this.onPrint,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.read(invoicesProvider.notifier).getInvoiceItems(invoice.id);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Line Items Breakdown:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              FilledButton.icon(
                onPressed: onPrint,
                icon: const Icon(Icons.picture_as_pdf, size: 16),
                label: const Text('Print / Save PDF', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'No line items recorded for this invoice.',
                style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 12),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              itemBuilder: (context, idx) {
                final InvoiceItem item = items[idx];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: Text(
                          '• ${item.description}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Qty: ${item.quantity}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          formatCents(item.unitPriceCents),
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          formatCents(item.totalCents),
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
