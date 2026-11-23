import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:billing_app/core/theme/app_theme.dart';

class PdfPreviewDialog extends StatelessWidget {
  final String title;
  final Future<Uint8List> Function() buildPdf;
  final String? scriptWarning;

  const PdfPreviewDialog({
    super.key,
    required this.title,
    required this.buildPdf,
    this.scriptWarning,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final infoTone = AppSemanticColors.resolve(
      Theme.of(context).brightness,
      SemanticStatus.info,
    );
    final warningText = scriptWarning?.trim() ?? '';

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
            body: Column(
              children: [
                if (warningText.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: infoTone.background,
                      border: Border(bottom: BorderSide(color: infoTone.border)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, size: 18, color: infoTone.icon),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            warningText,
                            style: TextStyle(fontSize: 12, color: infoTone.text),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: PdfPreview(
                    build: (format) => buildPdf(),
                    allowPrinting: true,
                    allowSharing: true,
                    canChangePageFormat: false,
                    canChangeOrientation: false,
                    pdfFileName: '${title.replaceAll(' ', '_').toLowerCase()}.pdf',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
