import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ExportFileHelper {
  /// Saves non-PDF export bytes (.csv, .json) via native FilePicker save dialog,
  /// falling back to Documents/exports/<filename> only if native saveFile fails.
  /// Returns the saved path/URI, or null if the user cancelled the picker.
  static Future<String?> saveExportFile({
    required List<int> bytes,
    required String filename,
    required String extension,
    required String dialogTitle,
  }) async {
    final payload = Uint8List.fromList(bytes);
    try {
      final selectedPath = await FilePicker.platform.saveFile(
        dialogTitle: dialogTitle,
        fileName: filename,
        type: FileType.custom,
        allowedExtensions: [extension],
        bytes: payload,
      );
      if (selectedPath == null) {
        return null;
      }
      if (!Platform.isAndroid && !Platform.isIOS) {
        await File(selectedPath).writeAsBytes(payload, flush: true);
      }
      return selectedPath;
    } catch (_) {
      final docsDir = await getApplicationDocumentsDirectory();
      final exportsDir = Directory(p.join(docsDir.path, 'exports'));
      if (!await exportsDir.exists()) {
        await exportsDir.create(recursive: true);
      }
      final fallbackPath = p.join(exportsDir.path, filename);
      await File(fallbackPath).writeAsBytes(payload, flush: true);
      return fallbackPath;
    }
  }
}
