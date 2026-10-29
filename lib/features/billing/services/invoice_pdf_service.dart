import 'dart:convert';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../../core/utils/money_utils.dart';
import '../../business_profile/models/business_profile.dart';
import '../../clients/models/client.dart';
import '../../estimates/models/estimate_item.dart';
import '../../estimates/models/estimate_record.dart';
import '../../invoices/models/invoice_item.dart';
import '../../invoices/models/invoice_record.dart';
import '../../payments/models/payment_record.dart';

class InvoicePdfService {
  /// Safely decode base64 image bytes or return null on invalid input.
  static Uint8List? _safeDecodeBase64(String input) {
    if (input.trim().isEmpty) return null;
    try {
      final clean = input.contains(',') ? input.split(',').last : input;
      return base64Decode(clean.trim());
    } catch (_) {
      return null;
    }
  }

  /// Safely unescape literal \n into real newlines.
  static String _cleanText(String input) {
    return input.replaceAll(r'\n', '\n').trim();
  }

  /// Generates a print-ready A4 PDF invoice document using Noto Sans for full Unicode symbol support (₹, €, £, $, ¥).
  static Future<Uint8List> generateInvoicePdf({
    required InvoiceRecord invoice,
    required List<InvoiceItem> items,
    required Client client,
    required BusinessProfile businessProfile,
    List<PaymentRecord> payments = const [],
  }) async {
    final fontRegular = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();
    final fontTheme = pw.ThemeData.withFont(base: fontRegular, bold: fontBold);

    final pdf = pw.Document(
      title: 'Invoice ${invoice.invoiceNumber}',
      author: businessProfile.businessName,
      theme: fontTheme,
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

    final effectiveTerms = _cleanText(
      invoice.terms.trim().isNotEmpty ? invoice.terms : businessProfile.defaultTerms,
    );
    final effectiveNotes = _cleanText(
      invoice.notes.trim().isNotEmpty ? invoice.notes : businessProfile.defaultNotes,
    );
    final paymentInstructions = _cleanText(businessProfile.paymentDetails);

    final logoBytes = _safeDecodeBase64(businessProfile.logoBase64);
    final signatureBytes = _safeDecodeBase64(businessProfile.signatureBase64);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        theme: fontTheme,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      if (logoBytes != null) ...[
                        pw.Container(
                          width: 48,
                          height: 48,
                          margin: const pw.EdgeInsets.only(right: 12),
                          child: pw.Image(pw.MemoryImage(logoBytes), fit: pw.BoxFit.contain),
                        ),
                      ],
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'TAX INVOICE',
                            style: pw.TextStyle(
                              fontSize: 26,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColor.fromHex('#1E293B'),
                            ),
                          ),
                          pw.SizedBox(height: 2),
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
                        style: pw.TextStyle(fontSize: 9.5, color: PdfColor.fromHex('#64748B')),
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

              pw.SizedBox(height: 16),
              pw.Divider(color: PdfColor.fromHex('#E2E8F0'), thickness: 1),
              pw.SizedBox(height: 12),

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
                          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A')),
                        ),
                        if (businessProfile.email.isNotEmpty) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(businessProfile.email, style: pw.TextStyle(fontSize: 9.5, color: PdfColor.fromHex('#475569'))),
                        ],
                        if (businessProfile.phone.isNotEmpty) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(businessProfile.phone, style: pw.TextStyle(fontSize: 9.5, color: PdfColor.fromHex('#475569'))),
                        ],
                        if (businessProfile.address.isNotEmpty) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(businessProfile.address, style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#64748B'))),
                        ],
                        if (businessProfile.taxId.isNotEmpty) ...[
                          pw.SizedBox(height: 3),
                          pw.Text(
                            'GSTIN / Tax ID: ${businessProfile.taxId}',
                            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#475569')),
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
                          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0F172A')),
                        ),
                        if (client.email.isNotEmpty) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(client.email, style: pw.TextStyle(fontSize: 9.5, color: PdfColor.fromHex('#475569'))),
                        ],
                        if (client.phone.isNotEmpty) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(client.phone, style: pw.TextStyle(fontSize: 9.5, color: PdfColor.fromHex('#475569'))),
                        ],
                        if (client.address.isNotEmpty) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(client.address, style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#64748B'))),
                        ],
                        if (client.taxId.isNotEmpty) ...[
                          pw.SizedBox(height: 3),
                          pw.Text(
                            'Client GSTIN / Tax ID: ${client.taxId}',
                            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#475569')),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 16),

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
                  0: const pw.FlexColumnWidth(3.8),
                  1: const pw.FlexColumnWidth(1.2),
                  2: const pw.FlexColumnWidth(0.8),
                  3: const pw.FlexColumnWidth(2.0),
                  4: const pw.FlexColumnWidth(2.2),
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
                      _buildHeaderCell('SAC / HSN', align: pw.TextAlign.left),
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
                        _buildCell(_cleanText(item.description), align: pw.TextAlign.left),
                        _buildCell(item.sacHsn.isNotEmpty ? item.sacHsn : '-', align: pw.TextAlign.left),
                        _buildCell('${item.quantity}', align: pw.TextAlign.center),
                        _buildCell(formatCents(item.unitPriceCents, symbol: sym), align: pw.TextAlign.right),
                        _buildCell(formatCents(item.totalCents, symbol: sym), align: pw.TextAlign.right, isBold: true),
                      ],
                    );
                  }),
                ],
              ),

              if (payments.isNotEmpty) ...[
                pw.SizedBox(height: 14),
                pw.Text(
                  'PAYMENTS & CREDIT RECEIVED',
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
                    0: const pw.FlexColumnWidth(2.0),
                    1: const pw.FlexColumnWidth(2.2),
                    2: const pw.FlexColumnWidth(3.5),
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
                        _buildHeaderCell('Remarks / Ref / TDS', align: pw.TextAlign.left),
                        _buildHeaderCell('Total Credited', align: pw.TextAlign.right),
                      ],
                    ),
                    ...payments.map((p) {
                      final details = [
                        if (p.notes.isNotEmpty) _cleanText(p.notes),
                        if (p.referenceNumber.isNotEmpty) 'Ref: ${p.referenceNumber}',
                        if (p.tdsCents > 0) 'TDS: ${formatCents(p.tdsCents, symbol: sym)}',
                      ].join(' • ');

                      return pw.TableRow(
                        decoration: pw.BoxDecoration(
                          border: pw.Border(
                            bottom: pw.BorderSide(color: PdfColor.fromHex('#DCFCE7'), width: 0.5),
                          ),
                        ),
                        children: [
                          _buildCell(p.paymentDate, align: pw.TextAlign.left),
                          _buildCell(p.paymentMethod, align: pw.TextAlign.left),
                          _buildCell(details.isNotEmpty ? details : '-', align: pw.TextAlign.left),
                          _buildCell(formatCents(p.totalCreditCents, symbol: sym), align: pw.TextAlign.right, isBold: true),
                        ],
                      );
                    }),
                  ],
                ),
              ],

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 250,
                    child: pw.Column(
                      children: [
                        _buildSummaryLine('Subtotal', formatCents(invoice.subtotalCents, symbol: sym)),
                        if (invoice.discountCents > 0) ...[
                          pw.SizedBox(height: 3),
                          _buildSummaryLine(
                            'Discount (${invoice.discountType == 'percent' ? '${invoice.discountValue}%' : 'Flat'})',
                            '-${formatCents(invoice.discountCents, symbol: sym)}',
                            color: PdfColor.fromHex('#D97706'),
                            isBold: true,
                          ),
                        ],
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

              if (effectiveTerms.isNotEmpty || effectiveNotes.isNotEmpty) ...[
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#F8FAFC'),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0'), width: 0.8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (effectiveTerms.isNotEmpty)
                        pw.Text(
                          'Terms & Conditions:\n$effectiveTerms',
                          style: pw.TextStyle(fontSize: 8.5, color: PdfColor.fromHex('#475569')),
                        ),
                      if (effectiveNotes.isNotEmpty) ...[
                        pw.SizedBox(height: 3),
                        pw.Text(
                          'Notes:\n$effectiveNotes',
                          style: pw.TextStyle(fontSize: 8.5, color: PdfColor.fromHex('#334155')),
                        ),
                      ],
                    ],
                  ),
                ),
                pw.SizedBox(height: 6),
              ],

              if (signatureBytes != null || businessProfile.signatureLabel.isNotEmpty) ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        if (signatureBytes != null)
                          pw.Container(
                            height: 36,
                            child: pw.Image(pw.MemoryImage(signatureBytes), fit: pw.BoxFit.contain),
                          )
                        else
                          pw.SizedBox(height: 24),
                        pw.Container(width: 140, height: 1, color: PdfColor.fromHex('#94A3B8')),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          businessProfile.signatureLabel.isNotEmpty
                              ? businessProfile.signatureLabel
                              : 'Authorized Signatory',
                          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#64748B')),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 6),
              ],

              if (isPaid) ...[
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(10),
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
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#047857'),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (paymentInstructions.isNotEmpty || businessProfile.paymentQrPayload.trim().isNotEmpty) ...[
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#F8FAFC'),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                    border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0'), width: 1),
                  ),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Expanded(
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
                            if (paymentInstructions.isNotEmpty)
                              pw.Text(
                                paymentInstructions,
                                style: pw.TextStyle(
                                  fontSize: 9,
                                  color: PdfColor.fromHex('#334155'),
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
                      if (businessProfile.paymentQrPayload.trim().isNotEmpty) ...[
                        pw.SizedBox(width: 12),
                        pw.Column(
                          children: [
                            pw.BarcodeWidget(
                              barcode: pw.Barcode.qrCode(),
                              data: businessProfile.paymentQrPayload.trim(),
                              width: 58,
                              height: 58,
                            ),
                            pw.SizedBox(height: 2),
                            pw.Text(
                              'Scan to Pay',
                              style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#64748B')),
                            ),
                          ],
                        ),
                      ],
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
    final fontRegular = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();
    final fontTheme = pw.ThemeData.withFont(base: fontRegular, bold: fontBold);

    final pdf = pw.Document(
      title: 'Estimate ${estimate.estimateNumber}',
      author: businessProfile.businessName,
      theme: fontTheme,
    );

    final sym = businessProfile.currencySymbol;
    final effectiveTerms = _cleanText(
      estimate.terms.trim().isNotEmpty ? estimate.terms : businessProfile.defaultTerms,
    );
    final effectiveNotes = _cleanText(
      estimate.notes.trim().isNotEmpty ? estimate.notes : businessProfile.defaultNotes,
    );

    final logoBytes = _safeDecodeBase64(businessProfile.logoBase64);
    final signatureBytes = _safeDecodeBase64(businessProfile.signatureBase64);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        theme: fontTheme,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      if (logoBytes != null) ...[
                        pw.Container(
                          width: 48,
                          height: 48,
                          margin: const pw.EdgeInsets.only(right: 12),
                          child: pw.Image(pw.MemoryImage(logoBytes), fit: pw.BoxFit.contain),
                        ),
                      ],
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'ESTIMATE / QUOTE',
                            style: pw.TextStyle(
                              fontSize: 24,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColor.fromHex('#1E293B'),
                            ),
                          ),
                          pw.SizedBox(height: 2),
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

              pw.SizedBox(height: 16),
              pw.Divider(color: PdfColor.fromHex('#E2E8F0'), thickness: 1),
              pw.SizedBox(height: 12),

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

              pw.SizedBox(height: 16),

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
                        _buildCell(_cleanText(item.description), align: pw.TextAlign.left),
                        _buildCell('${item.quantity}', align: pw.TextAlign.center),
                        _buildCell(formatCents(item.unitPriceCents, symbol: sym), align: pw.TextAlign.right),
                        _buildCell(formatCents(item.totalCents, symbol: sym), align: pw.TextAlign.right, isBold: true),
                      ],
                    );
                  }),
                ],
              ),

              pw.SizedBox(height: 12),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 250,
                    child: pw.Column(
                      children: [
                        _buildSummaryLine('Subtotal', formatCents(estimate.subtotalCents, symbol: sym)),
                        if (estimate.discountCents > 0) ...[
                          pw.SizedBox(height: 3),
                          _buildSummaryLine(
                            'Discount (${estimate.discountType == 'percent' ? '${estimate.discountValue}%' : 'Flat'})',
                            '-${formatCents(estimate.discountCents, symbol: sym)}',
                            color: PdfColor.fromHex('#D97706'),
                            isBold: true,
                          ),
                        ],
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

              if (effectiveTerms.isNotEmpty || effectiveNotes.isNotEmpty) ...[
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#F8FAFC'),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0'), width: 0.8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (effectiveTerms.isNotEmpty)
                        pw.Text('Proposal Terms:\n$effectiveTerms',
                            style: pw.TextStyle(fontSize: 8.5, color: PdfColor.fromHex('#475569'))),
                      if (effectiveNotes.isNotEmpty) ...[
                        pw.SizedBox(height: 3),
                        pw.Text('Proposal Notes:\n$effectiveNotes',
                            style: pw.TextStyle(fontSize: 8.5, color: PdfColor.fromHex('#334155'))),
                      ],
                    ],
                  ),
                ),
                pw.SizedBox(height: 6),
              ],

              if (signatureBytes != null || businessProfile.signatureLabel.isNotEmpty) ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        if (signatureBytes != null)
                          pw.Container(
                            height: 32,
                            child: pw.Image(pw.MemoryImage(signatureBytes), fit: pw.BoxFit.contain),
                          )
                        else
                          pw.SizedBox(height: 20),
                        pw.Container(width: 140, height: 1, color: PdfColor.fromHex('#94A3B8')),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          businessProfile.signatureLabel.isNotEmpty
                              ? businessProfile.signatureLabel
                              : 'Authorized Signatory',
                          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#64748B')),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 6),
              ],

              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(8),
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
