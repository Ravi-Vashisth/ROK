import 'package:intl/intl.dart';

/// Determines decimal exponent (0 or 2) for currency code or symbol.
int getCurrencyDecimals(String codeOrSymbol) {
  final upper = codeOrSymbol.trim().toUpperCase();
  if (upper == 'JPY' ||
      upper == 'KRW' ||
      upper == 'VND' ||
      upper == 'CLP' ||
      upper == '¥' ||
      upper == '₩' ||
      upper == '₫') {
    return 0;
  }
  return 2;
}

/// Parses price input string into minor units based on currency decimals exponent.
/// If decimals == 0: "1500" or "¥1500" parses directly to 1500 minor units.
/// If decimals == 2: "15.50" or "$15.50" parses to 1550 minor units.
int parsePriceToUnits(String input, [int decimals = 2]) {
  final cleaned = input.trim().replaceAll(RegExp(r'[^\d.]'), '');
  if (cleaned.isEmpty) return 0;

  if (decimals == 0) {
    final wholeStr = cleaned.split('.')[0];
    return int.tryParse(wholeStr) ?? 0;
  }

  final parts = cleaned.split('.');
  final dollars = int.tryParse(parts[0]) ?? 0;
  int cents = 0;
  if (parts.length > 1) {
    final centsPart = (parts[1] + '00').substring(0, 2);
    cents = int.tryParse(centsPart) ?? 0;
  }
  return (dollars * 100) + cents;
}

/// Backward compatible alias for parsePriceToUnits.
int parsePriceToCents(String input, [int decimals = 2]) =>
    parsePriceToUnits(input, decimals);

/// Formats minor units as formatted currency string.
/// If decimals == 0: 50000 -> "¥50,000" (no trailing .00).
/// If decimals == 2: 1550 -> "$15.50".
String formatMoney(int units, {String symbol = '\$', int decimals = 2}) {
  if (decimals == 0) {
    final formatter = NumberFormat.currency(symbol: symbol, decimalDigits: 0);
    return formatter.format(units);
  }
  final formatter = NumberFormat.currency(symbol: symbol, decimalDigits: 2);
  return formatter.format(units / 100.0);
}

/// Formats minor units into an input-friendly or CSV decimal string (0 or 2 decimals).
String formatDecimalUnits(int units, [int decimals = 2]) {
  if (decimals == 0) {
    return units.toString();
  }
  return (units / 100.0).toStringAsFixed(2);
}

/// Backward compatible alias for formatMoney.
String formatCents(int cents, {String symbol = '\$', int decimals = 2}) =>
    formatMoney(cents, symbol: symbol, decimals: decimals);

/// Calculates tax in integer minor units using integer round-half-up math:
/// (net_subtotal * tax_percentage + 50) ~/ 100.
int calculateTaxCents(int netSubtotalCents, int taxPercentage) {
  final safeSubtotal = netSubtotalCents < 0 ? 0 : netSubtotalCents;
  final safePercentage = taxPercentage < 0 ? 0 : taxPercentage;
  return (safeSubtotal * safePercentage + 50) ~/ 100;
}

/// Calculates collected tax portion on a payment using integer round-half-up math.
int calculateCollectedTaxPortion(int paidCents, int taxCents, int totalCents) {
  if (totalCents <= 0 || paidCents <= 0 || taxCents <= 0) return 0;
  if (paidCents >= totalCents) return taxCents;
  return (paidCents * taxCents + (totalCents ~/ 2)) ~/ totalCents;
}

/// Extracts numeric sequence for official invoice/estimate numbers matching prefix.
/// Safely returns 0 for DRAFT- entries or mismatched prefixes.
int extractSequenceNumber(String docNumber, String prefix) {
  final trimmed = docNumber.trim();
  if (trimmed.isEmpty || trimmed.toUpperCase().startsWith('DRAFT-')) {
    return 0;
  }
  if (!trimmed.startsWith(prefix)) {
    return 0;
  }
  final numericPart = trimmed.substring(prefix.length);
  return int.tryParse(numericPart) ?? 0;
}

/// Computes the next sequential document number from existing numbers without .length+1 collisions.
String getNextSequentialDocNumber(
  Iterable<String> existingNumbers,
  String prefix, {
  int minNext = 1,
}) {
  int maxSeq = 0;
  for (final numStr in existingNumbers) {
    final seq = extractSequenceNumber(numStr, prefix);
    if (seq > maxSeq) maxSeq = seq;
  }
  final nextNum = (maxSeq + 1) > minNext ? (maxSeq + 1) : minNext;
  return '$prefix${nextNum.toString().padLeft(4, '0')}';
}

/// Computes discount in integer minor units based on type ('none', 'percent', 'flat') and value.
int calculateDiscountCents(int subtotalCents, String discountType, int discountValue) {
  if (subtotalCents <= 0 || discountValue <= 0) return 0;
  if (discountType == 'percent') {
    final safePct = discountValue > 100 ? 100 : (discountValue < 0 ? 0 : discountValue);
    return (subtotalCents * safePct + 50) ~/ 100;
  } else if (discountType == 'flat') {
    return discountValue > subtotalCents ? subtotalCents : discountValue;
  }
  return 0;
}

/// Dynamically constructs standard UPI payment URL or appends invoice reference to payment URLs.
String generateDynamicQrPayload({
  required String rawPayload,
  required String businessName,
  required int balanceDueUnits,
  required int currencyDecimals,
  required String invoiceNumber,
  String currencyCode = 'INR',
}) {
  final trimmed = rawPayload.trim();
  if (trimmed.isEmpty) return '';

  String vpa = '';
  if (trimmed.startsWith('upi://pay')) {
    final uri = Uri.tryParse(trimmed);
    if (uri != null) {
      vpa = uri.queryParameters['pa'] ?? '';
    }
  } else if (trimmed.contains('@') && !trimmed.startsWith('http')) {
    vpa = trimmed;
  }

  if (vpa.isNotEmpty) {
    final encName = Uri.encodeComponent(businessName.trim().isEmpty ? 'Business' : businessName.trim());
    final amountStr = currencyDecimals == 0
        ? (balanceDueUnits > 0 ? balanceDueUnits : 0).toString()
        : ((balanceDueUnits > 0 ? balanceDueUnits : 0) / 100.0).toStringAsFixed(2);
    final safeInv = Uri.encodeComponent('Invoice-$invoiceNumber');
    final safeCu = Uri.encodeComponent(currencyCode.isEmpty ? 'INR' : currencyCode);
    return 'upi://pay?pa=${Uri.encodeComponent(vpa)}&pn=$encName&am=$amountStr&tn=$safeInv&cu=$safeCu';
  }

  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    final uri = Uri.tryParse(trimmed);
    if (uri != null) {
      final query = Map<String, String>.from(uri.queryParameters);
      if (!query.containsKey('ref') && !query.containsKey('invoice')) {
        query['invoice'] = invoiceNumber;
      }
      return uri.replace(queryParameters: query).toString();
    }
  }

  return trimmed;
}
