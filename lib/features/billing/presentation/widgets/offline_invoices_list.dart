import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:billing_app/core/theme/app_theme.dart';
import 'package:billing_app/core/utils/money_utils.dart';
import 'package:billing_app/features/business_profile/providers/business_profile_provider.dart';
import 'package:billing_app/features/clients/models/client.dart';
import 'package:billing_app/features/clients/providers/clients_provider.dart';
import 'package:billing_app/features/invoices/models/invoice_record.dart';
import 'package:billing_app/features/invoices/providers/invoices_provider.dart';
import 'package:billing_app/features/payments/presentation/record_payment_dialog.dart';
import 'package:billing_app/features/invoices/presentation/invoice_editor_screen.dart';
import 'package:billing_app/features/billing/services/invoice_pdf_service.dart';
import 'package:billing_app/features/billing/presentation/widgets/payment_reminder_modal.dart';
import 'package:billing_app/features/billing/presentation/widgets/pdf_preview_dialog.dart';

class OfflineInvoicesList extends ConsumerWidget {
  final String searchQuery;
  final String statusFilter;
  final String dateFilter;
  final List<Widget> leadingSlivers;

  const OfflineInvoicesList({
    super.key,
    this.searchQuery = '',
    this.statusFilter = 'All',
    this.dateFilter = 'All Time',
    this.leadingSlivers = const [],
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
          backgroundColor: Theme.of(context).colorScheme.primary,
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final brightness = theme.brightness;
    final dangerTone = AppSemanticColors.resolve(brightness, SemanticStatus.danger);
    final successTone = AppSemanticColors.resolve(brightness, SemanticStatus.success);
    final warningTone = AppSemanticColors.resolve(brightness, SemanticStatus.warning);
    final neutralTone = AppSemanticColors.resolve(brightness, SemanticStatus.neutral);

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
        if (statusFilter == 'Pending' && (inv.isFullyPaid || inv.isPartiallyPaid || inv.isOverdue || inv.status == 'VOID' || inv.isDraft)) return false;
        if (statusFilter == 'Draft' && !inv.isDraft) return false;
        if (statusFilter == 'Void' && inv.status != 'VOID') return false;
      }

      if (!matchesDateFilter(inv.issueDate, dateFilter)) return false;
      return true;
    }).toList();

    final isCompact = MediaQuery.sizeOf(context).width < 900;
    final pagePadding = isCompact ? 16.0 : 24.0;

    return CustomScrollView(
      slivers: [
        ...leadingSlivers,
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: pagePadding),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Text(
                      'Offline Invoices (${filtered.length} of ${invoices.length})',
                      style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (invoices.any((i) => i.isPartiallyPaid))
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: warningTone.background,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: warningTone.border),
                            ),
                            child: Text(
                              '${invoices.where((i) => i.isPartiallyPaid).length} Partial',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: warningTone.text,
                              ),
                            ),
                          ),
                        if (invoices.any((i) => i.isOverdue))
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: dangerTone.background,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: dangerTone.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.warning_amber_rounded, size: 14, color: dangerTone.icon),
                                const SizedBox(width: 4),
                                Text(
                                  '${invoices.where((i) => i.isOverdue).length} Overdue',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: dangerTone.text,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
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
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.dividerColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    'No invoices match your current search and filter criteria.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
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
                  final inv = filtered[index];
                  final isPaid = inv.isFullyPaid;
                  final isPartial = inv.isPartiallyPaid;
                  final isOverdue = inv.isOverdue;
                  final isLast = index == filtered.length - 1;

                  return Card(
                    elevation: 0,
                    margin: EdgeInsets.only(bottom: isLast ? 0 : 8),
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: theme.dividerColor),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: ExpansionTile(
                        key: PageStorageKey('invoice_${inv.id}'),
                        shape: const Border(),
                        collapsedShape: const Border(),
                        leading: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: (inv.isVoid || inv.status == 'VOID')
                          ? neutralTone.background
                          : (isPaid
                              ? successTone.background
                              : (isOverdue
                                  ? dangerTone.background
                                  : (isPartial
                                      ? warningTone.background
                                      : colorScheme.primaryContainer))),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: (inv.isVoid || inv.status == 'VOID')
                            ? neutralTone.border
                            : (isPaid
                                ? successTone.border
                                : (isOverdue
                                    ? dangerTone.border
                                    : (isPartial
                                        ? warningTone.border
                                        : Colors.transparent))),
                      ),
                    ),
                    child: Text(
                      inv.invoiceNumber,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: (inv.isVoid || inv.status == 'VOID')
                            ? neutralTone.text
                            : (isPaid
                                ? successTone.text
                                : (isOverdue
                                    ? dangerTone.text
                                    : (isPartial
                                        ? warningTone.text
                                        : colorScheme.onPrimaryContainer))),
                      ),
                    ),
                  ),
                  title: Builder(builder: (context) {
                    final invSym = inv.currencySymbol.isNotEmpty ? inv.currencySymbol : sym;
                    final invDec = inv.currencyCode.isNotEmpty ? inv.currencyDecimals : profile.currencyDecimals;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          inv.clientName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        // Status Badge (VOID / DRAFT / PAID / PARTIALLY PAID / OVERDUE / PENDING)
                        if (inv.isVoid || inv.status == 'VOID')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: neutralTone.background,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: neutralTone.border),
                            ),
                            child: Text(
                              'VOID',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: neutralTone.text,
                              ),
                            ),
                          )
                        else if (inv.isDraft)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: neutralTone.background,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: neutralTone.border),
                            ),
                            child: Text(
                              'DRAFT',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: neutralTone.text,
                              ),
                            ),
                          )
                        else if (isPaid)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: successTone.background,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: successTone.border),
                            ),
                            child: Text(
                              'PAID',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: successTone.text,
                              ),
                            ),
                          )
                        else if (isPartial)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: warningTone.background,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: warningTone.border),
                            ),
                            child: Text(
                              'PARTIAL (${formatCents(inv.paidCents, symbol: invSym, decimals: invDec)} / ${formatCents(inv.totalCents, symbol: invSym, decimals: invDec)})',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: warningTone.text,
                              ),
                            ),
                          )
                        else if (isOverdue)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: dangerTone.background,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: dangerTone.border),
                            ),
                            child: Text(
                              'OVERDUE (${inv.daysOverdue}d late)',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: dangerTone.text,
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: neutralTone.background,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: neutralTone.border),
                            ),
                            child: Text(
                              'Due: ${inv.dueDate}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: neutralTone.text,
                              ),
                            ),
                          ),
                      ],
                    );
                  }),
                  subtitle: Text(
                    '${inv.poNumber.isNotEmpty ? 'PO: ${inv.poNumber} • ' : ''}Terms: ${inv.paymentTerms} • Issued: ${inv.issueDate} • Due: ${inv.dueDate}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: isCompact ? 116 : 160),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              formatCents(inv.totalCents, symbol: inv.currencySymbol.isNotEmpty ? inv.currencySymbol : sym, decimals: inv.currencyCode.isNotEmpty ? inv.currencyDecimals : profile.currencyDecimals),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                    color: isPaid
                                        ? successTone.text
                                        : (isOverdue ? dangerTone.text : null),
                                  ),
                            ),
                            Text(
                              (inv.isVoid || inv.status == 'VOID')
                                  ? 'Voided'
                                  : (inv.balanceDueCents > 0
                                      ? 'Bal: ${formatCents(inv.balanceDueCents, symbol: inv.currencySymbol.isNotEmpty ? inv.currencySymbol : sym, decimals: inv.currencyCode.isNotEmpty ? inv.currencyDecimals : profile.currencyDecimals)}'
                                      : '✓ Settled'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                fontFeatures: const [FontFeature.tabularFigures()],
                                color: (inv.isVoid || inv.status == 'VOID')
                                    ? colorScheme.onSurfaceVariant
                                    : (inv.balanceDueCents > 0
                                        ? (isOverdue ? dangerTone.text : colorScheme.primary)
                                        : successTone.text),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (!isCompact) ...[
                        // Edit and Finalize Draft buttons for DRAFT status
                        if (inv.isDraft) ...[
                          OutlinedButton.icon(
                            icon: const Icon(Icons.edit_outlined, size: 15),
                            label: const Text('Edit Draft', style: TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => InvoiceEditorScreen(
                                    isQuote: false,
                                    existingInvoice: inv,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 6),
                          FilledButton.icon(
                            icon: const Icon(Icons.check_circle_outline, size: 15),
                            label: const Text('Finalize', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            style: FilledButton.styleFrom(
                              backgroundColor: colorScheme.primary,
                              foregroundColor: colorScheme.onPrimary,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () {
                              ref.read(invoicesProvider.notifier).finalizeDraftInvoice(inv.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Invoice ${inv.invoiceNumber} finalized and issued!')),
                              );
                            },
                          ),
                          const SizedBox(width: 6),
                        ],
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
                        // Record Payment Action Button
                        if (inv.balanceDueCents > 0 && inv.status != 'VOID' && !inv.isDraft) ...[
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
                        const SizedBox(width: 4),
                      ],
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, size: 18),
                        tooltip: 'More actions',
                        onSelected: (val) {
                          if (val == 'edit_draft') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => InvoiceEditorScreen(
                                  isQuote: false,
                                  existingInvoice: inv,
                                ),
                              ),
                            );
                          } else if (val == 'duplicate') {
                            _handleDuplicate(context, ref, inv);
                          } else if (val == 'pay') {
                            _openRecordPayment(context, inv);
                          } else if (val == 'pdf') {
                            _handlePrint(context, ref, inv);
                          } else if (val == 'finalize') {
                            ref.read(invoicesProvider.notifier).finalizeDraftInvoice(inv.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Invoice ${inv.invoiceNumber} finalized and issued!')),
                            );
                          } else if (val == 'reminder') {
                            showDialog(
                              context: context,
                              builder: (_) => PaymentReminderModal(invoice: inv),
                            );
                          } else if (val == 'delete') {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete Invoice'),
                                content: Text('Are you sure you want to delete invoice ${inv.invoiceNumber}?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                                  FilledButton(
                                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                    onPressed: () {
                                      ref.read(invoicesProvider.notifier).deleteInvoice(inv.id);
                                      Navigator.pop(ctx);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Invoice ${inv.invoiceNumber} deleted.')),
                                      );
                                    },
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                          } else if (val == 'void') {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Void Invoice'),
                                content: Text('Are you sure you want to void invoice ${inv.invoiceNumber}? This action cannot be undone.'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                                  FilledButton(
                                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                    onPressed: () {
                                      ref.read(invoicesProvider.notifier).voidInvoice(inv.id);
                                      Navigator.pop(ctx);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Invoice ${inv.invoiceNumber} marked as VOID.')),
                                      );
                                    },
                                    child: const Text('Void Invoice'),
                                  ),
                                ],
                              ),
                            );
                          }
                        },
                        itemBuilder: (_) => [
                          if (isCompact && inv.isDraft)
                            const PopupMenuItem(
                              value: 'edit_draft',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined, size: 16),
                                  SizedBox(width: 8),
                                  Text('Edit Draft', style: TextStyle(fontSize: 13)),
                                ],
                              ),
                            ),
                          if (inv.isDraft)
                            PopupMenuItem(
                              value: 'finalize',
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle_outline, size: 16, color: colorScheme.primary),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Finalize & Issue',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (isCompact && inv.balanceDueCents > 0 && inv.status != 'VOID' && !inv.isDraft)
                            const PopupMenuItem(
                              value: 'pay',
                              child: Row(
                                children: [
                                  Icon(Icons.add_card, size: 16),
                                  SizedBox(width: 8),
                                  Text('Record Payment', style: TextStyle(fontSize: 13)),
                                ],
                              ),
                            ),
                          if (isCompact)
                            const PopupMenuItem(
                              value: 'pdf',
                              child: Row(
                                children: [
                                  Icon(Icons.picture_as_pdf, size: 16),
                                  SizedBox(width: 8),
                                  Text('PDF / Print', style: TextStyle(fontSize: 13)),
                                ],
                              ),
                            ),
                          if (isCompact)
                            const PopupMenuItem(
                              value: 'duplicate',
                              child: Row(
                                children: [
                                  Icon(Icons.copy_outlined, size: 16),
                                  SizedBox(width: 8),
                                  Text('Duplicate', style: TextStyle(fontSize: 13)),
                                ],
                              ),
                            ),
                          if (inv.balanceDueCents > 0 && !inv.isDraft && inv.status != 'VOID')
                            PopupMenuItem(
                              value: 'reminder',
                              child: Row(
                                children: [
                                  Icon(Icons.send_outlined, size: 16, color: warningTone.icon),
                                  const SizedBox(width: 8),
                                  const Text('Send Reminder', style: TextStyle(fontSize: 13)),
                                ],
                              ),
                            ),
                          if (inv.status != 'VOID' && !inv.isDraft)
                            PopupMenuItem(
                              value: 'void',
                              child: Row(
                                children: [
                                  Icon(Icons.block, size: 16, color: dangerTone.icon),
                                  const SizedBox(width: 8),
                                  Text('Void / Cancel Invoice', style: TextStyle(color: dangerTone.icon, fontSize: 13)),
                                ],
                              ),
                            ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, size: 16, color: dangerTone.icon),
                                const SizedBox(width: 8),
                                Text('Delete Invoice', style: TextStyle(color: dangerTone.icon, fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  children: [
                    _InvoiceItemsBreakdown(
                      invoice: inv,
                      onPrint: () => _handlePrint(context, ref, inv),
                      onRecordPayment: () => _openRecordPayment(context, inv),
                      onDuplicate: () => _handleDuplicate(context, ref, inv),
                      onFinalize: inv.isDraft
                          ? () {
                              ref.read(invoicesProvider.notifier).finalizeDraftInvoice(inv.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Invoice ${inv.invoiceNumber} finalized and issued!')),
                              );
                            }
                          : null,
                    ),
                  ],
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

class _InvoiceItemsBreakdown extends ConsumerWidget {
  final InvoiceRecord invoice;
  final VoidCallback onPrint;
  final VoidCallback onRecordPayment;
  final VoidCallback onDuplicate;
  final VoidCallback? onFinalize;

  const _InvoiceItemsBreakdown({
    required this.invoice,
    required this.onPrint,
    required this.onRecordPayment,
    required this.onDuplicate,
    this.onFinalize,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.read(invoicesProvider.notifier).getInvoiceItems(invoice.id);
    final payments = ref.read(invoicesProvider.notifier).getInvoicePayments(invoice.id);
    final profile = ref.watch(businessProfileProvider);
    final sym = invoice.currencySymbol.isNotEmpty ? invoice.currencySymbol : profile.currencySymbol;
    final dec = invoice.currencyCode.isNotEmpty ? invoice.currencyDecimals : profile.currencyDecimals;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final brightness = theme.brightness;
    final successTone = AppSemanticColors.resolve(brightness, SemanticStatus.success);
    final dangerTone = AppSemanticColors.resolve(brightness, SemanticStatus.danger);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Text(
                'Line Items Breakdown (${invoice.paymentTerms} • Due: ${invoice.dueDate}):',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (invoice.isDraft && onFinalize != null)
                    FilledButton.icon(
                      icon: const Icon(Icons.check_circle_outline, size: 15),
                      label: const Text('Finalize Draft', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: onFinalize,
                    ),
                  OutlinedButton.icon(
                    onPressed: onDuplicate,
                    icon: const Icon(Icons.copy_outlined, size: 15),
                    label: const Text('Duplicate / Re-bill', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  if (invoice.balanceDueCents > 0 && !invoice.isDraft)
                    FilledButton.icon(
                      icon: const Icon(Icons.payment, size: 15),
                      label: const Text('Record Payment', style: TextStyle(fontSize: 12)),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: onRecordPayment,
                    ),
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

          // Items Table (horizontally scrollable on narrow screens)
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: constraints.maxWidth,
                    maxWidth: math.max(constraints.maxWidth, 460),
                  ),
                  child: Table(
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
                              child: Text('${item.quantity}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontFeatures: [FontFeature.tabularFigures()])),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Text(formatCents(item.unitPriceCents, symbol: sym, decimals: dec), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, fontFeatures: [FontFeature.tabularFigures()])),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Text(formatCents(item.totalCents, symbol: sym, decimals: dec), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()])),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Invoice Notes & Terms display if present
          if (invoice.terms.isNotEmpty || invoice.notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (invoice.terms.isNotEmpty)
                    Text(
                      'Terms: ${invoice.terms}',
                      style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: colorScheme.onSurface),
                    ),
                  if (invoice.notes.isNotEmpty)
                    Text(
                      'Notes: ${invoice.notes}',
                      style: TextStyle(fontSize: 11, color: colorScheme.onSurface),
                    ),
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
                color: successTone.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: successTone.border),
              ),
              padding: const EdgeInsets.all(8),
              child: Column(
                children: payments.map((p) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(Icons.check_circle_outline, size: 14, color: successTone.icon),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  '${p.paymentDate} • ${p.paymentMethod}${p.notes.isNotEmpty ? " (${p.notes})" : ""}',
                                  style: TextStyle(fontSize: 11, color: successTone.text),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formatCents(p.amountCents, symbol: sym, decimals: dec),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: successTone.text,
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
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: Column(
                children: [
                  _SummaryRow(label: 'Subtotal:', value: formatCents(invoice.subtotalCents, symbol: sym, decimals: dec)),
                  _SummaryRow(label: 'Tax:', value: formatCents(invoice.taxCents, symbol: sym, decimals: dec)),
                  _SummaryRow(label: 'Total:', value: formatCents(invoice.totalCents, symbol: sym, decimals: dec), isBold: true),
                  if (invoice.paidCents > 0) ...[
                    _SummaryRow(
                      label: 'Less Payments:',
                      value: '-${formatCents(invoice.paidCents, symbol: sym, decimals: dec)}',
                      textColor: successTone.text,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    decoration: BoxDecoration(
                      color: invoice.balanceDueCents == 0
                          ? successTone.background
                          : (invoice.isOverdue ? dangerTone.background : colorScheme.primaryContainer),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _SummaryRow(
                      label: 'Balance Due:',
                      value: formatCents(invoice.balanceDueCents, symbol: sym, decimals: dec),
                      isBold: true,
                      textColor: invoice.balanceDueCents == 0
                          ? successTone.text
                          : (invoice.isOverdue ? dangerTone.text : colorScheme.onPrimaryContainer),
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
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: textColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
