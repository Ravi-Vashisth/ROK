import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/utils/money_utils.dart';
import '../../../business_profile/models/business_profile.dart';
import '../../../invoices/models/invoice_item.dart';
import '../../../invoices/models/invoice_record.dart';

class InvoicePdfService {
  /// Generates a print-ready A4 PDF invoice document adhering to strict financial formatting.
  static Future<Uint8List> generateInvoicePdf({
    required InvoiceRecord invoice,
    required List<InvoiceItem> items,
    required String clientName,
    required BusinessProfile businessProfile,
  }) async {
    final pdf = pw.Document(
      title: 'Invoice ${invoice.invoiceNumber}',
      author: businessProfile.businessName,
    );

    // Format date nicely from ISO string
    String formattedDate = invoice.createdAt;
    try {
      final parsed = DateTime.parse(invoice.createdAt);
      formattedDate =
          '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
    } catch (_) {}

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // =============================================================
              // HEADER
              // =============================================================
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
                          color: PdfColor.fromHex('#ECFDF5'),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                          border: pw.Border.all(color: PdfColor.fromHex('#10B981'), width: 1),
                        ),
                        child: pw.Text(
                          invoice.status,
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('#047857'),
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        'Date: $formattedDate',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColor.fromHex('#64748B'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 20),
              pw.Divider(color: PdfColor.fromHex('#E2E8F0'), thickness: 1),
              pw.SizedBox(height: 16),

              // =============================================================
              // BILLED FROM / BILLED TO ADDRESS BLOCK
              // =============================================================
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'BILLED FROM',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#94A3B8'),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        businessProfile.businessName,
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#1E293B'),
                        ),
                      ),
                      if (businessProfile.email.isNotEmpty) ...[
                        pw.SizedBox(height: 2),
                        pw.Text(
                          businessProfile.email,
                          style: pw.TextStyle(
                            fontSize: 10,
                            color: PdfColor.fromHex('#475569'),
                          ),
                        ),
                      ],
                      if (businessProfile.phone.isNotEmpty) ...[
                        pw.SizedBox(height: 2),
                        pw.Text(
                          businessProfile.phone,
                          style: pw.TextStyle(
                            fontSize: 9,
                            color: PdfColor.fromHex('#64748B'),
                          ),
                        ),
                      ],
                      if (businessProfile.address.isNotEmpty) ...[
                        pw.SizedBox(height: 2),
                        pw.Text(
                          businessProfile.address,
                          style: pw.TextStyle(
                            fontSize: 9,
                            color: PdfColor.fromHex('#64748B'),
                          ),
                        ),
                      ],
                      if (businessProfile.taxId.isNotEmpty) ...[
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Tax ID / EIN: ${businessProfile.taxId}',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('#64748B'),
                          ),
                        ),
                      ],
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'BILLED TO',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#94A3B8'),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        clientName,
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#1E293B'),
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Client ID: ${invoice.clientId}',
                        style: pw.TextStyle(
                          fontSize: 9,
                          color: PdfColor.fromHex('#94A3B8'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 24),

              // =============================================================
              // LINE ITEMS TABLE
              // =============================================================
              pw.Table(
                columnWidths: {
                  0: const pw.FlexColumnWidth(5),
                  1: const pw.FlexColumnWidth(1.5),
                  2: const pw.FlexColumnWidth(2),
                  3: const pw.FlexColumnWidth(2),
                },
                children: [
                  // Table Header
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#F1F5F9'),
                      border: pw.Border(
                        bottom: pw.BorderSide(color: PdfColor.fromHex('#CBD5E1'), width: 1),
                      ),
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        child: pw.Text(
                          'DESCRIPTION',
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#475569')),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        child: pw.Text(
                          'QTY',
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#475569')),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        child: pw.Text(
                          'UNIT PRICE',
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#475569')),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        child: pw.Text(
                          'TOTAL',
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#475569')),
                        ),
                      ),
                    ],
                  ),

                  // Table Body
                  ...items.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final item = entry.value;
                    final isEven = idx % 2 == 0;

                    return pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: isEven ? PdfColors.white : PdfColor.fromHex('#F8FAFC'),
                        border: pw.Border(
                          bottom: pw.BorderSide(color: PdfColor.fromHex('#E2E8F0'), width: 0.5),
                        ),
                      ),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          child: pw.Text(
                            item.description,
                            style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#1E293B')),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          child: pw.Text(
                            '${item.quantity}',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#475569')),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          child: pw.Text(
                            formatCents(item.unitPriceCents),
                            textAlign: pw.TextAlign.right,
                            style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#475569')),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          child: pw.Text(
                            formatCents(item.totalCents),
                            textAlign: pw.TextAlign.right,
                            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1E293B')),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),

              pw.SizedBox(height: 18),

              // =============================================================
              // TOTALS BREAKDOWN (Right) & PAYMENT INSTRUCTIONS (Left)
              // =============================================================
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  // Payment Details Box on Left
                  pw.Expanded(
                    child: pw.Container(
                      margin: const pw.EdgeInsets.only(right: 16),
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#F8FAFC'),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                        border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'PAYMENT INSTRUCTIONS & BANK DETAILS',
                            style: pw.TextStyle(
                              fontSize: 8.5,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColor.fromHex('#475569'),
                            ),
                          ),
                          pw.SizedBox(height: 6),
                          pw.Text(
                            businessProfile.paymentDetails.isNotEmpty
                                ? businessProfile.paymentDetails
                                : 'Please remit payment within 14 days.\nThank you for prompt settlement.',
                            style: pw.TextStyle(
                              fontSize: 9,
                              color: PdfColor.fromHex('#334155'),
                              lineSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Financial summary card on Right
                  pw.Container(
                    width: 200,
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#F8FAFC'),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                      border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Subtotal:', style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#64748B'))),
                            pw.Text(formatCents(invoice.subtotalCents), style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#1E293B'))),
                          ],
                        ),
                        pw.SizedBox(height: 4),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Tax:', style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#64748B'))),
                            pw.Text(formatCents(invoice.taxCents), style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#1E293B'))),
                          ],
                        ),
                        pw.SizedBox(height: 6),
                        pw.Divider(color: PdfColor.fromHex('#CBD5E1'), thickness: 0.5),
                        pw.SizedBox(height: 4),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Grand Total:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1E293B'))),
                            pw.Text(
                              formatCents(invoice.totalCents),
                              style: pw.TextStyle(
                                fontSize: 13,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColor.fromHex('#4F46E5'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.Spacer(),

              // =============================================================
              // FOOTER
              // =============================================================
              pw.Divider(color: PdfColor.fromHex('#E2E8F0'), thickness: 1),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text(
                  'Thank you for your business! Payment due within 14 days.',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontStyle: pw.FontStyle.italic,
                    color: PdfColor.fromHex('#94A3B8'),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }
}
