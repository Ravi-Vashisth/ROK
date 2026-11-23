import 'package:billing_app/core/utils/money_utils.dart';

class WhatsAppPhoneValidation {
  final bool isValid;
  final String normalizedDigits;
  final String? warningMessage;

  const WhatsAppPhoneValidation({
    required this.isValid,
    required this.normalizedDigits,
    this.warningMessage,
  });
}

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

/// Validates whether a phone number includes an international country code for wa.me links.
/// Flags empty numbers, leading trunk/IDD zeros (0 / 00), and local 10-digit numbers without '+'.
WhatsAppPhoneValidation validateWhatsAppPhone(String phone) {
  final trimmed = phone.trim();
  final digits = buildWhatsAppDigits(trimmed);

  if (digits.isEmpty) {
    return const WhatsAppPhoneValidation(
      isValid: false,
      normalizedDigits: '',
      warningMessage: 'No phone number on file — WhatsApp will open contact picker instead.',
    );
  }

  if (digits.startsWith('0')) {
    return WhatsAppPhoneValidation(
      isValid: false,
      normalizedDigits: digits,
      warningMessage:
          "Number starts with '0'. WhatsApp requires an international country code (e.g. +1 or +91) without leading zeros.",
    );
  }

  if (trimmed.startsWith('+')) {
    if (digits.length < 7) {
      return WhatsAppPhoneValidation(
        isValid: false,
        normalizedDigits: digits,
        warningMessage: 'Phone number looks too short for an international WhatsApp link.',
      );
    }
    return WhatsAppPhoneValidation(
      isValid: true,
      normalizedDigits: digits,
    );
  }

  if (digits.length <= 10) {
    return WhatsAppPhoneValidation(
      isValid: false,
      normalizedDigits: digits,
      warningMessage:
          "Missing '+' country code prefix (e.g. +1 or +91). WhatsApp links may not resolve local-only numbers.",
    );
  }

  return WhatsAppPhoneValidation(
    isValid: true,
    normalizedDigits: digits,
  );
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

/// Builds a mailto: URI, pre-filling recipient email when present and omitting empty query parameters.
Uri buildMailtoUri({
  String email = '',
  String subject = '',
  String body = '',
}) {
  final cleanEmail = email.trim();
  final queryParts = <String>[
    if (subject.trim().isNotEmpty) 'subject=${Uri.encodeComponent(subject)}',
    if (body.trim().isNotEmpty) 'body=${Uri.encodeComponent(body)}',
  ];
  final query = queryParts.isNotEmpty ? '?${queryParts.join('&')}' : '';
  return Uri.parse('mailto:$cleanEmail$query');
}

/// Builds an sms: URI for a normalized recipient phone, or null if no digits exist.
/// Set [isIos] to true on Apple platforms (iOS and macOS) to apply Apple's '&body=' SMS delimiter quirk.
Uri? buildSmsUri({
  String phone = '',
  String body = '',
  bool isIos = false,
}) {
  final normalized = normalizePhoneForUri(phone);
  if (normalized.isEmpty) return null;
  if (body.isEmpty) {
    return Uri.parse('sms:$normalized');
  }
  final delimiter = isIos ? '&' : '?';
  return Uri.parse('sms:$normalized${delimiter}body=${Uri.encodeComponent(body)}');
}

/// Builds an smsto: fallback URI for Android OEM ROMs (MIUI, ColorOS, OneUI) where primary sms: fails.
Uri? buildSmsFallbackUri({
  String phone = '',
  String body = '',
}) {
  final normalized = normalizePhoneForUri(phone);
  if (normalized.isEmpty) return null;
  if (body.isEmpty) {
    return Uri.parse('smsto:$normalized');
  }
  return Uri.parse('smsto:$normalized?body=${Uri.encodeComponent(body)}');
}

/// Builds a 1-tap clipboard bundle containing recipient contact, subject, and reminder body
/// suitable for WeChat, Telegram, SMS, or manual email pasting.
String buildCopyEverythingReminderText({
  required String subject,
  required String message,
  String clientName = '',
  String clientEmail = '',
  String phone = '',
}) {
  final lines = <String>[];
  final contactParts = <String>[
    if (clientName.trim().isNotEmpty) clientName.trim(),
    if (clientEmail.trim().isNotEmpty) clientEmail.trim(),
    if (normalizePhoneForUri(phone).isNotEmpty) normalizePhoneForUri(phone),
  ];
  if (contactParts.isNotEmpty) {
    lines.add('To: ${contactParts.join(' • ')}');
  }
  if (subject.trim().isNotEmpty) {
    lines.add('Subject: ${subject.trim()}');
  }
  if (lines.isNotEmpty && message.trim().isNotEmpty) {
    lines.add('');
  }
  if (message.trim().isNotEmpty) {
    lines.add(message.trim());
  }
  return lines.join('\n');
}

/// Builds a tel: URI for a normalized phone number, or null if no digits exist.
Uri? buildTelUri(String phone) {
  final normalized = normalizePhoneForUri(phone);
  if (normalized.isEmpty) return null;
  return Uri.parse('tel:$normalized');
}

/// Returns cross-platform desktop/web fallback guidance when native SMS/dialer apps are absent.
String getDesktopTelephonyFallbackNote({
  required bool hasPhone,
  required bool hasEmail,
}) {
  if (!hasPhone && !hasEmail) {
    return 'No client phone or email saved. Copy the reminder message above or open WhatsApp to pick a contact.';
  }
  return 'Desktop systems without a registered SMS/dialer app may ignore external links — use Copy Reminder Message as an instant fallback.';
}
