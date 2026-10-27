import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/utils/money_utils.dart';
import '../../business_profile/models/business_profile.dart';
import '../../clients/models/client.dart';
import '../../estimates/models/estimate_item.dart';
import '../../estimates/models/estimate_record.dart';
import '../../invoices/models/invoice_item.dart';
import '../../invoices/models/invoice_record.dart';
import '../../payments/models/payment_record.dart';

class InvoicePdfService {
  /// Generates a print-ready A4 PDF invoice document adhering to strict financial formatting.
  static Future<Uint8List> generateInvoicePdf({
    required InvoiceRecord invoice,
    required List<InvoiceItem> items,
    required Client client,
    required BusinessProfile businessProfile,
    List<PaymentRecord> payments = const [],
  }) async {
    final pdf = pw.Document(
      title: 'Invoice ${invoice.invoiceNumber}',
      author: businessProfile.businessName,
    );

    final sym = businessProfile.currencySymbol;

    String formattedIssueDate = invoice.issueDate;
    if (formattedIssueDate.isEmpty) {
      formattedIssueDate = invoice.createdAt.split('T').first;
    }

    String formattedDueDate = invoice.dueDate;
    if (formattedDueDate.isEmpty) {
      formattedDueDate = formattedIssueDate;
    }

    final isPaid = invoice.isFullyPaid;
    final isPartial = invoice.isPartiallyPaid;
    final isOverdue = invoice.isOverdue;

    PdfColor statusBgColor = PdfColor.fromHex('#ECFDF5');
    PdfColor statusBorderColor = PdfColor.fromHex('#10B981');
    PdfColor statusTextColor = PdfColor.fromHex('#047857');
    String statusDisplay = 'PAID IN FULL';

    if (isOverdue) {
      statusBgColor = PdfColor.fromHex('#FFF1F2');
      statusBorderColor = PdfColor.fromHex('#F43F5E');
      statusTextColor = PdfColor.fromHex('#BE123C');
      statusDisplay = 'OVERDUE (${invoice.daysOverdue}D)';
    } else if (isPartial) {
      statusBgColor = PdfColor.fromHex('#FFFBEB');
      statusBorderColor = PdfColor.fromHex('#F59E0B');
      statusTextColor = PdfColor.fromHex('#B45309');
      statusDisplay = 'PARTIALLY PAID';
    } else if (!isPaid) {
      statusBgColor = PdfColor.fromHex('#EFF6FF');
      statusBorderColor = PdfColor.fromHex('#3B82F6');
      statusTextColor = PdfColor.fromHex('#1D4ED8');
      statusDisplay = 'PENDING';
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'INVOICE',
                        style: pw.TextStyle(
                          fontSize: 28,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#1E293B'),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        invoice.invoiceNumber,
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#4F46E5'),
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: statusBgColor,
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                          border: pw.Border.all(color: statusBorderColor, width: 1),
                        ),
                        child: pw.Text(
                          statusDisplay,
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: statusTextColor,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        'Issue Date: $formattedIssueDate',
                        style: pw.TextStyle(
                          fontSize: 9.5,
                          color: PdfColor.fromHex('#64748B'),
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Due Date: $formattedDueDate (${invoice.paymentTerms})',
                        style: pw.TextStyle(
                          fontSize: 9.5,
                          fontWeight: pw.FontWeight.bold,
                          color: isOverdue ? PdfColor.fromHex('#BE123C') : PdfColor.fromHex('#1E293B'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 18),
              pw.Divider(color: PdfColor.fromHex('#E2E8F0'), thickness: 1),
              pw.SizedBox(height: 14),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'BILLED FROM',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('#94A3B8'),
                            letterSpacing: 0.5,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          businessProfile.businessName,
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('#0F172A'),
                          ),
                        ),
                        if (businessProfile.email.isNotEmpty) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(
                            businessProfile.email,
                            style: pw.TextStyle(fontSize: 9.5, color: PdfColor.fromHex('#475569')),
                          ),
                        ],
                        if (businessProfile.phone.isNotEmpty) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(
                            businessProfile.phone,
                            style: pw.TextStyle(fontSize: 9.5, color: PdfColor.fromHex('#475569')),
                          ),
                        ],
                        if (businessProfile.address.isNotEmpty) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(
                            businessProfile.address,
                            style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#64748B')),
                          ),
                        ],
                        if (businessProfile.taxId.isNotEmpty) ...[
                          pw.SizedBox(height: 3),
                          pw.Text(
                            'Tax ID / EIN: ${businessProfile.taxId}',
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColor.fromHex('#475569'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  pw.SizedBox(width: 24),

                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'BILLED TO',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('#94A3B8'),
                            letterSpacing: 0.5,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          client.name,
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('#0F172A'),
                          ),
                        ),
                        if (client.email.isNotEmpty) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(
                            client.email,
                            style: pw.TextStyle(fontSize: 9.5, color: PdfColor.fromHex('#475569')),
                          ),
                        ],
                        if (client.phone.isNotEmpty) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(
                            client.phone,
                            style: pw.TextStyle(fontSize: 9.5, color: PdfColor.fromHex('#475569')),
                          ),
                        ],
                        if (client.address.isNotEmpty) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(
                            client.address,
                            style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#64748B')),
                          ),
                        ],
                        if (client.taxId.isNotEmpty) ...[
                          pw.SizedBox(height: 3),
                          pw.Text(
                            'Client VAT / Tax ID: ${client.taxId}',
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColor.fromHex('#475569'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 20),

              pw.Text(
                'LINE ITEMS',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#94A3B8'),
                  letterSpacing: 0.5,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Table(
                columnWidths: {
                  0: const pw.FlexColumnWidth(4.5),
                  1: const pw.FlexColumnWidth(1.2),
                  2: const pw.FlexColumnWidth(2.0),
                  3: const pw.FlexColumnWidth(2.3),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#F8FAFC'),
                      border: pw.Border(
                        bottom: pw.BorderSide(color: PdfColor.fromHex('#CBD5E1'), width: 1),
                        top: pw.BorderSide(color: PdfColor.fromHex('#E2E8F0'), width: 1),
                      ),
                    ),
                    children: [
                      _buildHeaderCell('Description', align: pw.TextAlign.left),
                      _buildHeaderCell('Qty', align: pw.TextAlign.center),
                      _buildHeaderCell('Unit Price', align: pw.TextAlign.right),
                      _buildHeaderCell('Total', align: pw.TextAlign.right),
                    ],
                  ),
                  ...items.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final isEven = index % 2 == 0;
                    return pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: isEven ? PdfColors.white : PdfColor.fromHex('#F8FAFC'),
                        border: pw.Border(
                          bottom: pw.BorderSide(color: PdfColor.fromHex('#F1F5F9'), width: 0.8),
                        ),
                      ),
                      children: [
                        _buildCell(item.description, align: pw.TextAlign.left),
                        _buildCell('${item.quantity}', align: pw.TextAlign.center),
                        _buildCell(formatCents(item.unitPriceCents, symbol: sym),
                            align: pw.TextAlign.right),
                        _buildCell(formatCents(item.totalCents, symbol: sym),
                            align: pw.TextAlign.right, isBold: true),
                      ],
                    );
                  }),
                ],
              ),

              if (payments.isNotEmpty) ...[
                pw.SizedBox(height: 16),
                pw.Text(
                  'PAYMENTS RECEIVED',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#94A3B8'),
                    letterSpacing: 0.5,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Table(
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2.2),
                    1: const pw.FlexColumnWidth(2.5),
                    2: const pw.FlexColumnWidth(3.0),
                    3: const pw.FlexColumnWidth(2.3),
                  },
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#F0FDF4'),
                        border: pw.Border(
                          bottom: pw.BorderSide(color: PdfColor.fromHex('#86EFAC'), width: 0.8),
                          top: pw.BorderSide(color: PdfColor.fromHex('#BBF7D0'), width: 0.8),
                        ),
                      ),
                      children: [
                        _buildHeaderCell('Date', align: pw.TextAlign.left),
                        _buildHeaderCell('Method', align: pw.TextAlign.left),
                        _buildHeaderCell('Notes / Reference', align: pw.TextAlign.left),
                        _buildHeaderCell('Amount Paid', align: pw.TextAlign.right),
                      ],
                    ),
                    ...payments.map((p) {
                      return pw.TableRow(
                        decoration: pw.BoxDecoration(
                          border: pw.Border(
                            bottom: pw.BorderSide(color: PdfColor.fromHex('#DCFCE7'), width: 0.5),
                          ),
                        ),
                        children: [
                          _buildCell(p.paymentDate, align: pw.TextAlign.left),
                          _buildCell(p.paymentMethod, align: pw.TextAlign.left),
                          _buildCell(p.notes.isNotEmpty ? p.notes : '-', align: pw.TextAlign.left),
                          _buildCell(formatCents(p.amountCents, symbol: sym),
                              align: pw.TextAlign.right, isBold: true),
                        ],
                      );
                    }),
                  ],
                ),
              ],

              pw.SizedBox(height: 14),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 250,
                    child: pw.Column(
                      children: [
                        _buildSummaryLine('Subtotal', formatCents(invoice.subtotalCents, symbol: sym)),
                        pw.SizedBox(height: 3),
                        _buildSummaryLine('Tax', formatCents(invoice.taxCents, symbol: sym)),
                        pw.SizedBox(height: 3),
                        pw.Divider(color: PdfColor.fromHex('#E2E8F0'), thickness: 0.8),
                        pw.SizedBox(height: 3),
                        _buildSummaryLine(
                          'Total Invoice Amount',
                          formatCents(invoice.totalCents, symbol: sym),
                          isBold: true,
                          fontSize: 11,
                        ),
                        if (invoice.paidCents > 0) ...[
                          pw.SizedBox(height: 3),
                          _buildSummaryLine(
                            'Less Payments Received',
                            '-${formatCents(invoice.paidCents, symbol: sym)}',
                            color: PdfColor.fromHex('#059669'),
                            isBold: true,
                          ),
                        ],
                        pw.SizedBox(height: 5),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: pw.BoxDecoration(
                            color: isPaid
                                ? PdfColor.fromHex('#ECFDF5')
                                : (isOverdue ? PdfColor.fromHex('#FFF1F2') : PdfColor.fromHex('#EEF2FF')),
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                            border: pw.Border.all(
                              color: isPaid
                                  ? PdfColor.fromHex('#10B981')
                                  : (isOverdue ? PdfColor.fromHex('#F43F5E') : PdfColor.fromHex('#6366F1')),
                              width: 1,
                            ),
                          ),
                          child: _buildSummaryLine(
                            'Balance Due',
                            formatCents(invoice.balanceDueCents, symbol: sym),
                            isBold: true,
                            fontSize: 12,
                            color: isPaid
                                ? PdfColor.fromHex('#047857')
                                : (isOverdue ? PdfColor.fromHex('#BE123C') : PdfColor.fromHex('#4338CA')),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.Spacer(),

              if (isPaid) ...[
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#ECFDF5'),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    border: pw.Border.all(color: PdfColor.fromHex('#10B981'), width: 1.5),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Text(
                        'PAID IN FULL - THANK YOU FOR YOUR BUSINESS!',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#047857'),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (businessProfile.paymentDetails.isNotEmpty) ...[
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#F8FAFC'),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0'), width: 1),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'PAYMENT INSTRUCTIONS',
                        style: pw.TextStyle(
                          fontSize: 8.5,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#64748B'),
                          letterSpacing: 0.5,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        businessProfile.paymentDetails,
                        style: pw.TextStyle(
                          fontSize: 9,
                          color: PdfColor.fromHex('#334155'),
                          lineSpacing: 1.5,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Please remit payment within ${invoice.paymentTerms} (Due: $formattedDueDate).',
                        style: pw.TextStyle(
                          fontSize: 8.5,
                          fontWeight: pw.FontWeight.bold,
                          color: isOverdue ? PdfColor.fromHex('#BE123C') : PdfColor.fromHex('#475569'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Generates a proposal / estimate PDF document titled "ESTIMATE / QUOTE".
  static Future<Uint8List> generateEstimatePdf({
    required EstimateRecord estimate,
    required List<EstimateItem> items,
    required Client client,
    required BusinessProfile businessProfile,
  }) async {
    final pdf = pw.Document(
      title: 'Estimate ${estimate.estimateNumber}',
      author: businessProfile.businessName,
    );

    final sym = businessProfile.currencySymbol;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'ESTIMATE / QUOTE',
                        style: pw.TextStyle(
                          fontSize: 26,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#1E293B'),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        estimate.estimateNumber,
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#4F46E5'),
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: estimate.isConverted
                              ? PdfColor.fromHex('#ECFDF5')
                              : PdfColor.fromHex('#EFF6FF'),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                          border: pw.Border.all(
                            color: estimate.isConverted
                                ? PdfColor.fromHex('#10B981')
                                : PdfColor.fromHex('#3B82F6'),
                            width: 1,
                          ),
                        ),
                        child: pw.Text(
                          estimate.status,
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: estimate.isConverted
                                ? PdfColor.fromHex('#047857')
                                : PdfColor.fromHex('#1D4ED8'),
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        'Issue Date: ${estimate.issueDate}',
                        style: pw.TextStyle(fontSize: 9.5, color: PdfColor.fromHex('#64748B')),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Valid Until: ${estimate.expiryDate}',
                        style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1E293B')),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 18),
              pw.Divider(color: PdfColor.fromHex('#E2E8F0'), thickness: 1),
              pw.SizedBox(height: 14),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'PREPARED BY',
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#94A3B8')),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          businessProfile.businessName,
                          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A')),
                        ),
                        if (businessProfile.email.isNotEmpty)
                          pw.Text(businessProfile.email, style: pw.TextStyle(fontSize: 9.5, color: PdfColor.fromHex('#475569'))),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 24),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'PREPARED FOR',
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#94A3B8')),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          client.name,
                          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A')),
                        ),
                        if (client.email.isNotEmpty)
                          pw.Text(client.email, style: pw.TextStyle(fontSize: 9.5, color: PdfColor.fromHex('#475569'))),
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 20),

              pw.Text(
                'PROPOSED ITEMS & SERVICES',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#94A3B8')),
              ),
              pw.SizedBox(height: 6),
              pw.Table(
                columnWidths: {
                  0: const pw.FlexColumnWidth(4.5),
                  1: const pw.FlexColumnWidth(1.2),
                  2: const pw.FlexColumnWidth(2.0),
                  3: const pw.FlexColumnWidth(2.3),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#F8FAFC'),
                      border: pw.Border(
                        bottom: pw.BorderSide(color: PdfColor.fromHex('#CBD5E1'), width: 1),
                        top: pw.BorderSide(color: PdfColor.fromHex('#E2E8F0'), width: 1),
                      ),
                    ),
                    children: [
                      _buildHeaderCell('Description', align: pw.TextAlign.left),
                      _buildHeaderCell('Qty', align: pw.TextAlign.center),
                      _buildHeaderCell('Unit Price', align: pw.TextAlign.right),
                      _buildHeaderCell('Total', align: pw.TextAlign.right),
                    ],
                  ),
                  ...items.asMap().entries.map((entry) {
                    final item = entry.value;
                    return pw.TableRow(
                      decoration: pw.BoxDecoration(
                        border: pw.Border(bottom: pw.BorderSide(color: PdfColor.fromHex('#F1F5F9'), width: 0.8)),
                      ),
                      children: [
                        _buildCell(item.description, align: pw.TextAlign.left),
                        _buildCell('${item.quantity}', align: pw.TextAlign.center),
                        _buildCell(formatCents(item.unitPriceCents, symbol: sym), align: pw.TextAlign.right),
                        _buildCell(formatCents(item.totalCents, symbol: sym), align: pw.TextAlign.right, isBold: true),
                      ],
                    );
                  }),
                ],
              ),

              pw.SizedBox(height: 14),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 250,
                    child: pw.Column(
                      children: [
                        _buildSummaryLine('Subtotal', formatCents(estimate.subtotalCents, symbol: sym)),
                        pw.SizedBox(height: 3),
                        _buildSummaryLine('Estimated Tax', formatCents(estimate.taxCents, symbol: sym)),
                        pw.SizedBox(height: 3),
                        pw.Divider(color: PdfColor.fromHex('#E2E8F0'), thickness: 0.8),
                        pw.SizedBox(height: 3),
                        _buildSummaryLine(
                          'Estimated Total',
                          formatCents(estimate.totalCents, symbol: sym),
                          isBold: true,
                          fontSize: 12,
                          color: PdfColor.fromHex('#4F46E5'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.Spacer(),

              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F8FAFC'),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0'), width: 1),
                ),
                child: pw.Text(
                  'This quote is valid for 30 days from issue date. Upon acceptance, this quote can be converted directly into a formal invoice.',
                  style: pw.TextStyle(fontSize: 8.5, color: PdfColor.fromHex('#64748B')),
                  textAlign: pw.TextAlign.center,
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeaderCell(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: PdfColor.fromHex('#475569'),
        ),
      ),
    );
  }

  static pw.Widget _buildCell(
    String text, {
    pw.TextAlign align = pw.TextAlign.left,
    bool isBold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 9.5,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isBold ? PdfColor.fromHex('#0F172A') : PdfColor.fromHex('#334155'),
        ),
      ),
    );
  }

  static pw.Widget _buildSummaryLine(
    String label,
    String value, {
    bool isBold = false,
    double fontSize = 9.5,
    PdfColor? color,
  }) {
    final effectiveColor = color ?? (isBold ? PdfColor.fromHex('#0F172A') : PdfColor.fromHex('#64748B'));
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: effectiveColor,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: effectiveColor,
          ),
        ),
      ],
    );
  }
}
