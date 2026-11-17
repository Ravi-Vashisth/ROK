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
    final screenSize = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: EdgeInsets.all(screenSize.width < 600 ? 12 : 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 900,
            maxHeight: screenSize.height * 0.9,
          ),
          child: Scaffold(
            appBar: AppBar(
              title: Text(title, overflow: TextOverflow.ellipsis),
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
