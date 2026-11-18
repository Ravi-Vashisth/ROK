const int maxAttachmentSizeBytes = 5 * 1024 * 1024;
const int maxBackupSizeBytes = 50 * 1024 * 1024;

class FileUploadValidationResult {
  final bool isValid;
  final String? mimeType;
  final String? errorMessage;

  const FileUploadValidationResult({
    required this.isValid,
    this.mimeType,
    this.errorMessage,
  });
}

/// Validates uploaded image/receipt file bytes by checking empty/size bounds
/// and verifying file magic header signatures before base64 encoding.
FileUploadValidationResult validateUploadedFileBytes({
  required List<int> bytes,
  required String filename,
  bool allowPdf = false,
  int maxBytes = maxAttachmentSizeBytes,
}) {
  if (bytes.isEmpty) {
    return const FileUploadValidationResult(
      isValid: false,
      errorMessage: 'Selected file is empty (0 bytes).',
    );
  }

  if (bytes.length > maxBytes) {
    final limitMb = maxBytes ~/ (1024 * 1024);
    return FileUploadValidationResult(
      isValid: false,
      errorMessage: 'File exceeds maximum allowed size of $limitMb MB.',
    );
  }

  final detectedMime = detectMimeFromHeaderBytes(bytes);
  if (detectedMime == 'image/png' ||
      detectedMime == 'image/jpeg' ||
      detectedMime == 'image/webp') {
    return FileUploadValidationResult(isValid: true, mimeType: detectedMime);
  }

  if (allowPdf && detectedMime == 'application/pdf') {
    return const FileUploadValidationResult(
      isValid: true,
      mimeType: 'application/pdf',
    );
  }

  return FileUploadValidationResult(
    isValid: false,
    errorMessage: allowPdf
        ? 'Unsupported or invalid file "$filename". Choose a valid PNG, JPG, WEBP, or PDF.'
        : 'Unsupported or invalid image "$filename". Choose a valid PNG, JPG, or WEBP image.',
  );
}

/// Inspects file header magic bytes to determine real image/PDF MIME type.
String? detectMimeFromHeaderBytes(List<int> bytes) {
  // PNG: 89 50 4E 47
  if (bytes.length >= 4 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return 'image/png';
  }
  // JPEG: FF D8 FF
  if (bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF) {
    return 'image/jpeg';
  }
  // WEBP: RIFF....WEBP
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return 'image/webp';
  }
  // PDF: %PDF-
  if (bytes.length >= 5 &&
      bytes[0] == 0x25 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x44 &&
      bytes[3] == 0x46 &&
      bytes[4] == 0x2D) {
    return 'application/pdf';
  }
  return null;
}
