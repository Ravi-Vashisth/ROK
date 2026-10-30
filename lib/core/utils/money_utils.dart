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
