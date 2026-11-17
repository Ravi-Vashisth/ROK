import 'money_utils.dart';

/// Normalizes a raw phone string for tel:/sms: URIs.
/// Preserves a single leading '+' for E.164 international numbers and strips
/// spaces, hyphens, parentheses, and non-digit characters.
String normalizePhoneForUri(String phone) {
  final trimmed = phone.trim();
  if (trimmed.isEmpty) return '';
  final hasPlus = trimmed.startsWith('+');
  final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return '';
  return hasPlus ? '+$digits' : digits;
}

/// Returns digits-only phone number for wa.me links (strips leading '+').
String buildWhatsAppDigits(String phone) {
  return phone.replaceAll(RegExp(r'[^0-9]'), '');
}

/// Builds a standardized, currency-aware payment reminder message.
String buildPaymentReminderMessage({
  required String invoiceNumber,
  required String clientName,
  required int balanceDueUnits,
  required String currencySymbol,
  required int currencyDecimals,
  required String dueDate,
  required String businessName,
}) {
  final formattedAmount = formatMoney(
    balanceDueUnits,
    symbol: currencySymbol,
    decimals: currencyDecimals,
  );
  final safeClient = clientName.trim().isNotEmpty ? clientName.trim() : 'Client';
  final safeBusiness = businessName.trim().isNotEmpty ? businessName.trim() : 'Accounts Team';
  final safeDue = dueDate.trim().isNotEmpty ? dueDate.trim() : 'recently';

  return "Hi $safeClient, hope you're doing well! This is a polite note that Invoice $invoiceNumber for $formattedAmount was due on $safeDue. Please let us know if you need any assistance with remittance. Thank you! - $safeBusiness";
}

/// Builds a WhatsApp wa.me URI, pre-filling the normalized recipient phone when present.
Uri buildWhatsAppUri({
  String phone = '',
  required String message,
}) {
  final digits = buildWhatsAppDigits(phone);
  final path = digits.isNotEmpty ? digits : '';
  return Uri.parse('https://wa.me/$path?text=${Uri.encodeComponent(message)}');
}

/// Builds a mailto: URI, pre-filling recipient email when present.
Uri buildMailtoUri({
  String email = '',
  required String subject,
  required String body,
}) {
  final cleanEmail = email.trim();
  return Uri.parse(
    'mailto:$cleanEmail?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
  );
}

/// Builds an sms: URI for a normalized recipient phone, or null if no digits exist.
Uri? buildSmsUri({
  String phone = '',
  String body = '',
}) {
  final normalized = normalizePhoneForUri(phone);
  if (normalized.isEmpty) return null;
  if (body.isEmpty) {
    return Uri.parse('sms:$normalized');
  }
  return Uri.parse('sms:$normalized?body=${Uri.encodeComponent(body)}');
}

/// Builds a tel: URI for a normalized phone number, or null if no digits exist.
Uri? buildTelUri(String phone) {
  final normalized = normalizePhoneForUri(phone);
  if (normalized.isEmpty) return null;
  return Uri.parse('tel:$normalized');
}
