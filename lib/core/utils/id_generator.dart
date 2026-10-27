import 'dart:math';

/// Generates a local unique ID using timestamp and high-entropy randomness.
String generateUniqueId() {
  final timestamp = DateTime.now().microsecondsSinceEpoch;
  final random = Random().nextInt(999999).toString().padLeft(6, '0');
  return '$timestamp-$random';
}
