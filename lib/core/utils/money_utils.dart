import 'package:intl/intl.dart';

/// Parses price input string (e.g. "15.50" or "$15.50") directly into integer cents without float imprecision.
int parsePriceToCents(String input) {
  final cleaned = input.trim().replaceAll(RegExp(r'[^\d.]'), '');
  if (cleaned.isEmpty) return 0;
  final parts = cleaned.split('.');
  final dollars = int.tryParse(parts[0]) ?? 0;
  int cents = 0;
  if (parts.length > 1) {
    final centsPart = parts[1].padRight(2, '0').substring(0, 2);
    cents = int.tryParse(centsPart) ?? 0;
  }
  return (dollars * 100) + cents;
}

/// Formats integer cents as currency with dynamic symbol (e.g. 1550 -> "$15.50").
String formatCents(int cents, {String symbol = '\$'}) {
  final formatter = NumberFormat.currency(symbol: symbol);
  return formatter.format(cents / 100.0);
}

/// Calculates tax in integer cents using integer round-half-up math:
/// (net_subtotal_cents * tax_percentage + 50) ~/ 100.
int calculateTaxCents(int netSubtotalCents, int taxPercentage) {
  final safeSubtotal = netSubtotalCents < 0 ? 0 : netSubtotalCents;
  final safePercentage = taxPercentage < 0 ? 0 : taxPercentage;
  return (safeSubtotal * safePercentage + 50) ~/ 100;
}

/// Computes discount in integer cents based on type ('none', 'percent', 'flat') and value.
/// If percent: (subtotalCents * discountValue + 50) ~/ 100
/// If flat: min(discountValue, subtotalCents)
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
