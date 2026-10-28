import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

class PdfPreviewDialog extends StatelessWidget {
  final String title;
  final Future<Uint8List> Function() buildPdf;

  const PdfPreviewDialog({
    super.key,
    required this.title,
    required this.buildPdf,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 900,
          height: 750,
          child: Scaffold(
            appBar: AppBar(
              title: Text(title),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close Preview',
                ),
              ],
            ),
            body: PdfPreview(
              build: (format) => buildPdf(),
              allowPrinting: true,
              allowSharing: true,
              canChangePageFormat: false,
              canChangeOrientation: false,
              pdfFileName: '${title.replaceAll(' ', '_').toLowerCase()}.pdf',
            ),
          ),
        ),
      ),
    );
  }
}
