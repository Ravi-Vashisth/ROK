import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/money_utils.dart';
import '../../../business_profile/providers/business_profile_provider.dart';
import '../../../clients/models/client.dart';
import '../../../clients/providers/clients_provider.dart';
import '../../../invoices/models/invoice_record.dart';
import '../../../invoices/providers/invoices_provider.dart';
import '../../../payments/presentation/record_payment_dialog.dart';
import '../../services/invoice_pdf_service.dart';
import 'pdf_preview_dialog.dart';

class OfflineInvoicesList extends ConsumerWidget {
  final String searchQuery;
  final String statusFilter;
  final String dateFilter;

  const OfflineInvoicesList({
    super.key,
    this.searchQuery = '',
    this.statusFilter = 'All',
    this.dateFilter = 'All Time',
  });

  void _handlePrint(BuildContext context, WidgetRef ref, InvoiceRecord inv) async {
    final items = ref.read(invoicesProvider.notifier).getInvoiceItems(inv.id);
    final payments = ref.read(invoicesProvider.notifier).getInvoicePayments(inv.id);
    final businessProfile = ref.read(businessProfileProvider);
    final clients = ref.read(clientsProvider);

    final Client client = clients.firstWhere(
      (c) => c.id == inv.clientId,
      orElse: () => Client(
        id: inv.clientId,
        name: inv.clientName,
        createdAt: inv.createdAt,
      ),
    );

    showDialog(
      context: context,
      builder: (_) => PdfPreviewDialog(
        title: 'Invoice ${inv.invoiceNumber}',
        buildPdf: () => InvoicePdfService.generateInvoicePdf(
          invoice: inv,
          items: items,
          payments: payments,
          client: client,
          businessProfile: businessProfile,
        ),
      ),
    );
  }

  void _openRecordPayment(BuildContext context, InvoiceRecord inv) {
    showDialog(
      context: context,
      builder: (_) => RecordPaymentDialog(invoice: inv),
    );
  }

  void _handleDuplicate(BuildContext context, WidgetRef ref, InvoiceRecord inv) {
    try {
      final newNumber = ref.read(invoicesProvider.notifier).duplicateInvoice(inv.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invoice duplicated as $newNumber!'),
          backgroundColor: Colors.indigo.shade800,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error duplicating invoice: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoices = ref.watch(invoicesProvider);
    final profile = ref.watch(businessProfileProvider);
    final sym = profile.currencySymbol;

    // Filter invoices
    final filtered = invoices.where((inv) {
      if (searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase();
        final matchName = inv.clientName.toLowerCase().contains(q);
        final matchNum = inv.invoiceNumber.toLowerCase().contains(q);
        if (!matchName && !matchNum) return false;
      }

      if (statusFilter != 'All') {
        if (statusFilter == 'Paid' && !inv.isFullyPaid) return false;
        if (statusFilter == 'Partially Paid' && !inv.isPartiallyPaid) return false;
        if (statusFilter == 'Overdue' && !inv.isOverdue) return false;
        if (statusFilter == 'Pending' && (inv.isFullyPaid || inv.isPartiallyPaid || inv.isOverdue || inv.status == 'VOID')) return false;
        if (statusFilter == 'Void' && inv.status != 'VOID') return false;
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Offline Invoices (${filtered.length} of ${invoices.length})',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (invoices.any((i) => i.isPartiallyPaid)) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Text(
                      '${invoices.where((i) => i.isPartiallyPaid).length} Partial',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ),
                ],
                if (invoices.any((i) => i.isOverdue)) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 14, color: Colors.red.shade700),
                        const SizedBox(width: 4),
                        Text(
                          '${invoices.where((i) => i.isOverdue).length} Overdue',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text(
                'No invoices match your current search and filter criteria.',
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
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final inv = filtered[index];
                final isPaid = inv.isFullyPaid;
                final isPartial = inv.isPartiallyPaid;
                final isOverdue = inv.isOverdue;

                return ExpansionTile(
                  key: PageStorageKey('invoice_${inv.id}'),
                  leading: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isPaid
                          ? Colors.green.shade50
                          : (isOverdue
                              ? Colors.red.shade100
                              : (isPartial
                                  ? Colors.amber.shade100
                                  : Theme.of(context).colorScheme.primaryContainer)),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isPaid
                            ? Colors.green.shade300
                            : (isOverdue
                                ? Colors.red.shade300
                                : (isPartial
                                    ? Colors.amber.shade400
                                    : Colors.transparent)),
                      ),
                    ),
                    child: Text(
                      inv.invoiceNumber,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isPaid
                            ? Colors.green.shade900
                            : (isOverdue
                                ? Colors.red.shade900
                                : (isPartial
                                    ? Colors.amber.shade900
                                    : Theme.of(context).colorScheme.onPrimaryContainer)),
                      ),
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(
                        inv.clientName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 8),
                      // Status Badge (PAID / PARTIALLY PAID / OVERDUE / PENDING)
                      if (isPaid)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.green.shade300),
                          ),
                          child: Text(
                            'PAID',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade800,
                            ),
                          ),
                        )
                      else if (isPartial)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.amber.shade400),
                          ),
                          child: Text(
                            'PARTIAL (${formatCents(inv.paidCents, symbol: sym)} / ${formatCents(inv.totalCents, symbol: sym)})',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade900,
                            ),
                          ),
                        )
                      else if (isOverdue)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.red.shade400),
                          ),
                          child: Text(
                            'OVERDUE (${inv.daysOverdue}d late)',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade800,
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blueGrey.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.blueGrey.shade300),
                          ),
                          child: Text(
                            'Due: ${inv.dueDate}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.blueGrey.shade800,
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Text(
                    'Terms: ${inv.paymentTerms} • Issued: ${inv.issueDate} • Due: ${inv.dueDate}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formatCents(inv.totalCents, symbol: sym),
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isPaid
                                      ? Colors.green.shade700
                                      : (isOverdue ? Colors.red.shade700 : null),
                                ),
                          ),
                          Text(
                            inv.balanceDueCents > 0
                                ? 'Bal: ${formatCents(inv.balanceDueCents, symbol: sym)}'
                                : '✓ Settled',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: inv.balanceDueCents > 0
                                  ? (isOverdue ? Colors.red.shade700 : Colors.indigo.shade700)
                                  : Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      // 1-Click Duplicate Button
                      OutlinedButton.icon(
                        icon: const Icon(Icons.copy_outlined, size: 15),
                        label: const Text('Duplicate', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => _handleDuplicate(context, ref, inv),
                      ),
                      const SizedBox(width: 6),
                      // Record Payment Action Button (only if balance due is greater than zero)
                      if (inv.balanceDueCents > 0 && inv.status != 'VOID') ...[
                        OutlinedButton.icon(
                          icon: const Icon(Icons.add_card, size: 15),
                          label: const Text('Pay', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () => _openRecordPayment(context, inv),
                        ),
                        const SizedBox(width: 6),
                      ],
                      // PDF / Print action button
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.picture_as_pdf, size: 16),
                        label: const Text('PDF / Print',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => _handlePrint(context, ref, inv),
                      ),
                      if (inv.status != 'VOID' && inv.balanceDueCents > 0) ...[
                        const SizedBox(width: 4),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 18),
                          tooltip: 'More actions',
                          onSelected: (val) {
                            if (val == 'void') {
                              ref.read(invoicesProvider.notifier).voidInvoice(inv.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Invoice ${inv.invoiceNumber} marked as VOID.')),
                              );
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'void',
                              child: Row(
                                children: [
                                  Icon(Icons.block, size: 16, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Void / Cancel Invoice', style: TextStyle(color: Colors.red, fontSize: 13)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  children: [
                    _InvoiceItemsBreakdown(
                      invoice: inv,
                      onPrint: () => _handlePrint(context, ref, inv),
                      onRecordPayment: () => _openRecordPayment(context, inv),
                      onDuplicate: () => _handleDuplicate(context, ref, inv),
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
  final VoidCallback onRecordPayment;
  final VoidCallback onDuplicate;

  const _InvoiceItemsBreakdown({
    required this.invoice,
    required this.onPrint,
    required this.onRecordPayment,
    required this.onDuplicate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.read(invoicesProvider.notifier).getInvoiceItems(invoice.id);
    final payments = ref.read(invoicesProvider.notifier).getInvoicePayments(invoice.id);
    final profile = ref.watch(businessProfileProvider);
    final sym = profile.currencySymbol;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Line Items Breakdown (${invoice.paymentTerms} • Due: ${invoice.dueDate}):',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: onDuplicate,
                    icon: const Icon(Icons.copy_outlined, size: 15),
                    label: const Text('Duplicate / Re-bill', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (invoice.balanceDueCents > 0) ...[
                    FilledButton.icon(
                      icon: const Icon(Icons.payment, size: 15),
                      label: const Text('Record Payment', style: TextStyle(fontSize: 12)),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: onRecordPayment,
                    ),
                    const SizedBox(width: 8),
                  ],
                  OutlinedButton.icon(
                    onPressed: onPrint,
                    icon: const Icon(Icons.print, size: 15),
                    label: const Text('Print / PDF', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Items Table
          Table(
            columnWidths: const {
              0: FlexColumnWidth(4),
              1: FlexColumnWidth(1),
              2: FlexColumnWidth(2),
              3: FlexColumnWidth(2),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
                ),
                children: const [
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 4.0),
                    child: Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 4.0),
                    child: Text('Qty', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 4.0),
                    child: Text('Unit Price', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 4.0),
                    child: Text('Total', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                ],
              ),
              ...items.map(
                (item) => TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Text(item.description, style: const TextStyle(fontSize: 11)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Text('${item.quantity}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Text(formatCents(item.unitPriceCents, symbol: sym), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Text(formatCents(item.totalCents, symbol: sym), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Invoice Notes & Terms display if present
          if (invoice.terms.isNotEmpty || invoice.notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (invoice.terms.isNotEmpty)
                    Text('Terms: ${invoice.terms}', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
                  if (invoice.notes.isNotEmpty)
                    Text('Notes: ${invoice.notes}', style: const TextStyle(fontSize: 11, color: Colors.black87)),
                ],
              ),
            ),
          ],

          // Payments Section (if any payments recorded)
          if (payments.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 6),
            Text(
              'Payments Received (${payments.length}):',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: Colors.green.shade50.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.green.shade200),
              ),
              padding: const EdgeInsets.all(8),
              child: Column(
                children: payments.map((p) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.check_circle_outline, size: 14, color: Colors.green),
                            const SizedBox(width: 6),
                            Text(
                              '${p.paymentDate} • ${p.paymentMethod}${p.notes.isNotEmpty ? " (${p.notes})" : ""}',
                              style: TextStyle(fontSize: 11, color: Colors.green.shade900),
                            ),
                          ],
                        ),
                        Text(
                          formatCents(p.amountCents, symbol: sym),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade900,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          const SizedBox(height: 12),
          const Divider(),

          // Financial Summary
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 260,
              child: Column(
                children: [
                  _SummaryRow(label: 'Subtotal:', value: formatCents(invoice.subtotalCents, symbol: sym)),
                  _SummaryRow(label: 'Tax:', value: formatCents(invoice.taxCents, symbol: sym)),
                  _SummaryRow(label: 'Total:', value: formatCents(invoice.totalCents, symbol: sym), isBold: true),
                  if (invoice.paidCents > 0) ...[
                    _SummaryRow(
                      label: 'Less Payments:',
                      value: '-${formatCents(invoice.paidCents, symbol: sym)}',
                      textColor: Colors.green.shade700,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    decoration: BoxDecoration(
                      color: invoice.balanceDueCents == 0
                          ? Colors.green.shade100
                          : (invoice.isOverdue ? Colors.red.shade100 : Colors.indigo.shade50),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: _SummaryRow(
                      label: 'Balance Due:',
                      value: formatCents(invoice.balanceDueCents, symbol: sym),
                      isBold: true,
                      textColor: invoice.balanceDueCents == 0
                          ? Colors.green.shade900
                          : (invoice.isOverdue ? Colors.red.shade900 : Colors.indigo.shade900),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final Color? textColor;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: textColor,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
