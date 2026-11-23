import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ExportSaveResult {
  final String path;
  final bool usedFallbackDirectory;

  const ExportSaveResult({
    required this.path,
    required this.usedFallbackDirectory,
  });
}

class ExportFileHelper {
  /// Ensures desktop save paths carry the expected file extension when users omit it.
  static String ensureDesktopExtension(String path, String extension) {
    final cleanExt = extension.startsWith('.') ? extension.substring(1) : extension;
    if (cleanExt.isEmpty) return path;
    final suffix = '.$cleanExt';
    if (path.toLowerCase().endsWith(suffix.toLowerCase())) {
      return path;
    }
    return '$path$suffix';
  }

  /// Saves non-PDF export bytes (.csv, .json) via native FilePicker save dialog,
  /// returning [ExportSaveResult] with [usedFallbackDirectory] = true whenever
  /// scoped-storage/native picker failure forces writing to Documents/exports/.
  /// Returns null if the user cancelled the picker.
  static Future<ExportSaveResult?> saveExportFileWithDetails({
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
      var finalPath = selectedPath;
      if (!Platform.isAndroid && !Platform.isIOS) {
        finalPath = ensureDesktopExtension(selectedPath, extension);
        await File(finalPath).writeAsBytes(payload, flush: true);
      }
      return ExportSaveResult(path: finalPath, usedFallbackDirectory: false);
    } catch (_) {
      final docsDir = await getApplicationDocumentsDirectory();
      final exportsDir = Directory(p.join(docsDir.path, 'exports'));
      if (!await exportsDir.exists()) {
        await exportsDir.create(recursive: true);
      }
      final fallbackPath = p.join(exportsDir.path, filename);
      await File(fallbackPath).writeAsBytes(payload, flush: true);
      return ExportSaveResult(path: fallbackPath, usedFallbackDirectory: true);
    }
  }

  /// Backward-compatible wrapper returning only the saved path/URI, or null if cancelled.
  static Future<String?> saveExportFile({
    required List<int> bytes,
    required String filename,
    required String extension,
    required String dialogTitle,
  }) async {
    final res = await saveExportFileWithDetails(
      bytes: bytes,
      filename: filename,
      extension: extension,
      dialogTitle: dialogTitle,
    );
    return res?.path;
  }
}
