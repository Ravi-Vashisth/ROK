import 'package:intl/intl.dart';

/// Determines decimal exponent (0, 2, or 3) for currency code or symbol.
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
  if (upper == 'KWD' ||
      upper == 'BHD' ||
      upper == 'OMR' ||
      upper == 'JOD' ||
      upper == 'TND') {
    return 3;
  }
  return 2;
}

int _clampDecimals(int decimals) {
  if (decimals < 0) return 0;
  if (decimals > 6) return 6;
  return decimals;
}

int _pow10(int decimals) {
  final safe = _clampDecimals(decimals);
  int scale = 1;
  for (int i = 0; i < safe; i++) {
    scale *= 10;
  }
  return scale;
}

/// Parses price input string into minor units based on currency decimals exponent.
/// Rejects negative inputs cleanly (returns 0) and applies round-half-up on extra fractional digits
/// instead of silently truncating.
/// - decimals == 0: "1500" or "¥1500" -> 1500; "10.6" -> 11.
/// - decimals == 2: "15.50" or "$15.50" -> 1550; "10.125" -> 1013.
/// - decimals == 3: "15.500" or "KWD 15.500" -> 15500; "1.2345" -> 1235.
int parsePriceToUnits(String input, [int decimals = 2]) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return 0;

  // Reject negative sign anywhere before digits cleanly
  if (RegExp(r'^[^\d.]*-').hasMatch(trimmed)) return 0;

  final cleaned = trimmed.replaceAll(RegExp(r'[^\d.]'), '');
  if (cleaned.isEmpty) return 0;

  final safeDecimals = _clampDecimals(decimals);
  final dotIdx = cleaned.indexOf('.');
  final wholeStr = dotIdx == -1 ? cleaned : cleaned.substring(0, dotIdx);
  final rawFrac = dotIdx == -1 ? '' : cleaned.substring(dotIdx + 1).replaceAll('.', '');
  final whole = wholeStr.isEmpty ? 0 : (int.tryParse(wholeStr) ?? 0);

  if (safeDecimals == 0) {
    final roundUp = rawFrac.isNotEmpty && rawFrac.codeUnitAt(0) >= 0x35;
    return whole + (roundUp ? 1 : 0);
  }

  final scale = _pow10(safeDecimals);
  final padded = rawFrac.padRight(safeDecimals, '0');
  final fracSlice = padded.substring(0, safeDecimals);
  int fracUnits = int.tryParse(fracSlice) ?? 0;

  // Round half-up on the (decimals + 1)-th fractional digit instead of silent truncation
  if (rawFrac.length > safeDecimals && rawFrac.codeUnitAt(safeDecimals) >= 0x35) {
    fracUnits += 1;
  }

  return (whole * scale) + fracUnits;
}

/// Backward compatible alias for parsePriceToUnits.
int parsePriceToCents(String input, [int decimals = 2]) =>
    parsePriceToUnits(input, decimals);

/// Formats minor units as formatted currency string using pure integer arithmetic.
/// - decimals == 0: 50000 -> "¥50,000" (no trailing decimals).
/// - decimals == 2: 1550 -> "$15.50".
/// - decimals == 3: 15500 -> "KWD15.500".
String formatMoney(int units, {String symbol = '\$', int decimals = 2}) {
  final safeDecimals = _clampDecimals(decimals);
  final isNegative = units < 0;
  final absUnits = isNegative ? -units : units;
  final intFormatter = NumberFormat('#,##0', 'en_US');

  if (safeDecimals == 0) {
    final wholeFormatted = intFormatter.format(absUnits);
    return '${isNegative ? '-' : ''}$symbol$wholeFormatted';
  }

  final scale = _pow10(safeDecimals);
  final whole = absUnits ~/ scale;
  final frac = absUnits % scale;
  final wholeFormatted = intFormatter.format(whole);
  final fracStr = frac.toString().padLeft(safeDecimals, '0');
  return '${isNegative ? '-' : ''}$symbol$wholeFormatted.$fracStr';
}

/// Formats minor units into an input-friendly or CSV decimal string using pure integer arithmetic.
String formatDecimalUnits(int units, [int decimals = 2]) {
  final safeDecimals = _clampDecimals(decimals);
  if (safeDecimals == 0) {
    return units.toString();
  }
  final isNegative = units < 0;
  final absUnits = isNegative ? -units : units;
  final scale = _pow10(safeDecimals);
  final whole = absUnits ~/ scale;
  final frac = absUnits % scale;
  final fracStr = frac.toString().padLeft(safeDecimals, '0');
  return '${isNegative ? '-' : ''}$whole.$fracStr';
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
    final safeUnits = balanceDueUnits > 0 ? balanceDueUnits : 0;
    final amountStr = formatDecimalUnits(safeUnits, currencyDecimals);
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

class ResolvedCurrency {
  final String code;
  final String symbol;
  final int decimals;

  const ResolvedCurrency({
    required this.code,
    required this.symbol,
    required this.decimals,
  });
}

/// Resolves effective currency (code, symbol, decimals) for an invoice/estimate
/// with fallback to the business profile's default currency.
ResolvedCurrency resolveEffectiveCurrency({
  String recordCode = '',
  String recordSymbol = '',
  int? recordDecimals,
  String defaultCode = 'USD',
  String defaultSymbol = '\$',
  int? defaultDecimals,
}) {
  final fallbackCode = defaultCode.trim().isNotEmpty ? defaultCode.trim().toUpperCase() : 'USD';
  final fallbackSym = defaultSymbol.trim().isNotEmpty ? defaultSymbol.trim() : '\$';
  final fallbackDec = defaultDecimals ?? getCurrencyDecimals(fallbackCode);

  final trimmedCode = recordCode.trim().toUpperCase();
  final trimmedSym = recordSymbol.trim();

  final code = trimmedCode.isNotEmpty ? trimmedCode : fallbackCode;
  final symbol = trimmedSym.isNotEmpty ? trimmedSym : fallbackSym;
  final decimals = trimmedCode.isNotEmpty
      ? (recordDecimals ?? getCurrencyDecimals(code))
      : fallbackDec;

  return ResolvedCurrency(code: code, symbol: symbol, decimals: _clampDecimals(decimals));
}

class CurrencyAmount {
  final String code;
  final String symbol;
  final int decimals;
  final int amountUnits;

  const CurrencyAmount({
    required this.code,
    required this.symbol,
    required this.decimals,
    required this.amountUnits,
  });

  String format() => formatMoney(amountUnits, symbol: symbol, decimals: decimals);
}

/// Formats a list of per-currency amounts cleanly (e.g. "$1,500.00 + ¥50,000").
/// Filters out zero-amount currencies when at least one non-zero bucket exists,
/// or returns [emptyFallback] when empty/all-zero.
String formatMultiCurrencyAmounts(
  List<CurrencyAmount> amounts, {
  required String emptyFallback,
  String separator = ' + ',
}) {
  final nonZero = amounts.where((a) => a.amountUnits != 0).toList();
  if (nonZero.isEmpty) return emptyFallback;
  return nonZero.map((a) => a.format()).join(separator);
}

class CurrencyLedgerEntry {
  final String currencyCode;
  final String currencySymbol;
  final int currencyDecimals;
  final int totalUnits;
  final int paidUnits;
  final int balanceDueUnits;
  final int taxUnits;
  final bool isOverdue;

  const CurrencyLedgerEntry({
    this.currencyCode = '',
    this.currencySymbol = '',
    this.currencyDecimals = 2,
    required this.totalUnits,
    this.paidUnits = 0,
    this.balanceDueUnits = 0,
    this.taxUnits = 0,
    this.isOverdue = false,
  });
}

class ClientRollupSummary {
  final List<CurrencyAmount> totalBilledByCurrency;
  final List<CurrencyAmount> totalPaidByCurrency;
  final List<CurrencyAmount> outstandingByCurrency;
  final String formattedTotalBilled;
  final String formattedTotalPaid;
  final String formattedOutstandingBalance;
  final bool hasOutstandingBalance;

  const ClientRollupSummary({
    required this.totalBilledByCurrency,
    required this.totalPaidByCurrency,
    required this.outstandingByCurrency,
    required this.formattedTotalBilled,
    required this.formattedTotalPaid,
    required this.formattedOutstandingBalance,
    required this.hasOutstandingBalance,
  });
}

int _compareCurrencyOrder(String a, String b, String defaultCode) {
  if (a == defaultCode && b != defaultCode) return -1;
  if (b == defaultCode && a != defaultCode) return 1;
  return a.compareTo(b);
}

/// Groups active (non-draft, non-void) client invoices by currencyCode so
/// multi-currency balances are never summed into corrupt scalar totals.
ClientRollupSummary computeClientRollup(
  Iterable<CurrencyLedgerEntry> activeEntries, {
  String defaultCode = 'USD',
  String defaultSymbol = '\$',
  int defaultDecimals = 2,
}) {
  final base = resolveEffectiveCurrency(
    defaultCode: defaultCode,
    defaultSymbol: defaultSymbol,
    defaultDecimals: defaultDecimals,
  );
  final zeroFallback = formatMoney(0, symbol: base.symbol, decimals: base.decimals);

  final Map<String, ResolvedCurrency> meta = {};
  final Map<String, int> billedMap = {};
  final Map<String, int> paidMap = {};
  final Map<String, int> dueMap = {};

  for (final entry in activeEntries) {
    final cur = resolveEffectiveCurrency(
      recordCode: entry.currencyCode,
      recordSymbol: entry.currencySymbol,
      recordDecimals: entry.currencyCode.trim().isNotEmpty ? entry.currencyDecimals : null,
      defaultCode: base.code,
      defaultSymbol: base.symbol,
      defaultDecimals: base.decimals,
    );
    meta[cur.code] = cur;
    billedMap[cur.code] = (billedMap[cur.code] ?? 0) + entry.totalUnits;
    paidMap[cur.code] = (paidMap[cur.code] ?? 0) + entry.paidUnits;
    final unpaid = (entry.totalUnits - entry.paidUnits) > 0 ? (entry.totalUnits - entry.paidUnits) : 0;
    dueMap[cur.code] = (dueMap[cur.code] ?? 0) + unpaid;
  }

  final codes = meta.keys.toList()
    ..sort((a, b) => _compareCurrencyOrder(a, b, base.code));

  final billedList = codes
      .map((c) => CurrencyAmount(
            code: c,
            symbol: meta[c]!.symbol,
            decimals: meta[c]!.decimals,
            amountUnits: billedMap[c] ?? 0,
          ))
      .toList();
  final paidList = codes
      .map((c) => CurrencyAmount(
            code: c,
            symbol: meta[c]!.symbol,
            decimals: meta[c]!.decimals,
            amountUnits: paidMap[c] ?? 0,
          ))
      .toList();
  final dueList = codes
      .map((c) => CurrencyAmount(
            code: c,
            symbol: meta[c]!.symbol,
            decimals: meta[c]!.decimals,
            amountUnits: dueMap[c] ?? 0,
          ))
      .toList();

  return ClientRollupSummary(
    totalBilledByCurrency: billedList,
    totalPaidByCurrency: paidList,
    outstandingByCurrency: dueList,
    formattedTotalBilled: formatMultiCurrencyAmounts(billedList, emptyFallback: zeroFallback),
    formattedTotalPaid: formatMultiCurrencyAmounts(paidList, emptyFallback: zeroFallback),
    formattedOutstandingBalance: formatMultiCurrencyAmounts(dueList, emptyFallback: zeroFallback),
    hasOutstandingBalance: dueList.any((d) => d.amountUnits > 0),
  );
}

class CurrencyDashboardBucket {
  final String code;
  final String symbol;
  final int decimals;
  final int invoicedUnits;
  final int collectedUnits;
  final int pendingBalanceUnits;
  final int overdueAmountUnits;
  final int taxCollectedOnPaymentsUnits;
  final int expenseGrossUnits;
  final int expenseTaxUnits;
  final int netRevenueExclTaxUnits;
  final int netExpenseExclTaxUnits;
  final int taxLiabilityUnits;
  final int netProfitUnits;

  const CurrencyDashboardBucket({
    required this.code,
    required this.symbol,
    required this.decimals,
    required this.invoicedUnits,
    required this.collectedUnits,
    required this.pendingBalanceUnits,
    required this.overdueAmountUnits,
    required this.taxCollectedOnPaymentsUnits,
    required this.expenseGrossUnits,
    required this.expenseTaxUnits,
    required this.netRevenueExclTaxUnits,
    required this.netExpenseExclTaxUnits,
    required this.taxLiabilityUnits,
    required this.netProfitUnits,
  });
}

class DashboardCashFlowSummary {
  final List<CurrencyDashboardBucket> byCurrency;
  final String formattedInvoiced;
  final String formattedUnpaid;
  final String formattedOverdue;
  final String formattedCollected;
  final String formattedTaxLiability;
  final String formattedNetProfit;
  final bool hasAnyNegativeTaxLiability;
  final bool hasNetLoss;

  const DashboardCashFlowSummary({
    required this.byCurrency,
    required this.formattedInvoiced,
    required this.formattedUnpaid,
    required this.formattedOverdue,
    required this.formattedCollected,
    required this.formattedTaxLiability,
    required this.formattedNetProfit,
    required this.hasAnyNegativeTaxLiability,
    required this.hasNetLoss,
  });
}

/// Computes per-currency dashboard cash flow metrics so mixed currencies
/// (USD, JPY, INR, KWD, etc.) are aggregated strictly per currencyCode.
DashboardCashFlowSummary computeDashboardCashFlow(
  Iterable<CurrencyLedgerEntry> activeEntries, {
  int expenseGrossUnits = 0,
  int expenseTaxUnits = 0,
  String defaultCode = 'USD',
  String defaultSymbol = '\$',
  int defaultDecimals = 2,
}) {
  final base = resolveEffectiveCurrency(
    defaultCode: defaultCode,
    defaultSymbol: defaultSymbol,
    defaultDecimals: defaultDecimals,
  );
  final zeroFallback = formatMoney(0, symbol: base.symbol, decimals: base.decimals);

  final Map<String, ResolvedCurrency> meta = {
    if (expenseGrossUnits != 0 || expenseTaxUnits != 0) base.code: base,
  };
  final Map<String, int> invoicedMap = {};
  final Map<String, int> collectedMap = {};
  final Map<String, int> pendingMap = {};
  final Map<String, int> overdueMap = {};
  final Map<String, int> taxCollectedMap = {};

  for (final entry in activeEntries) {
    final cur = resolveEffectiveCurrency(
      recordCode: entry.currencyCode,
      recordSymbol: entry.currencySymbol,
      recordDecimals: entry.currencyCode.trim().isNotEmpty ? entry.currencyDecimals : null,
      defaultCode: base.code,
      defaultSymbol: base.symbol,
      defaultDecimals: base.decimals,
    );
    meta[cur.code] = cur;
    invoicedMap[cur.code] = (invoicedMap[cur.code] ?? 0) + entry.totalUnits;
    collectedMap[cur.code] = (collectedMap[cur.code] ?? 0) + entry.paidUnits;
    if (entry.balanceDueUnits > 0) {
      pendingMap[cur.code] = (pendingMap[cur.code] ?? 0) + entry.balanceDueUnits;
      if (entry.isOverdue) {
        overdueMap[cur.code] = (overdueMap[cur.code] ?? 0) + entry.balanceDueUnits;
      }
    }
    taxCollectedMap[cur.code] = (taxCollectedMap[cur.code] ?? 0) +
        calculateCollectedTaxPortion(entry.paidUnits, entry.taxUnits, entry.totalUnits);
  }

  final codes = meta.keys.toList()
    ..sort((a, b) => _compareCurrencyOrder(a, b, base.code));

  final buckets = <CurrencyDashboardBucket>[];
  for (final code in codes) {
    final cur = meta[code]!;
    final inv = invoicedMap[code] ?? 0;
    final col = collectedMap[code] ?? 0;
    final pend = pendingMap[code] ?? 0;
    final over = overdueMap[code] ?? 0;
    final taxCol = taxCollectedMap[code] ?? 0;
    final expGross = code == base.code ? expenseGrossUnits : 0;
    final expTax = code == base.code ? expenseTaxUnits : 0;
    final netExp = (expGross - expTax).clamp(0, expGross);
    final netRev = col - taxCol;
    final taxLiab = taxCol - expTax;
    final netProfit = netRev - netExp;

    buckets.add(CurrencyDashboardBucket(
      code: code,
      symbol: cur.symbol,
      decimals: cur.decimals,
      invoicedUnits: inv,
      collectedUnits: col,
      pendingBalanceUnits: pend,
      overdueAmountUnits: over,
      taxCollectedOnPaymentsUnits: taxCol,
      expenseGrossUnits: expGross,
      expenseTaxUnits: expTax,
      netRevenueExclTaxUnits: netRev,
      netExpenseExclTaxUnits: netExp,
      taxLiabilityUnits: taxLiab,
      netProfitUnits: netProfit,
    ));
  }

  List<CurrencyAmount> pick(int Function(CurrencyDashboardBucket b) getter) => buckets
      .map((b) => CurrencyAmount(
            code: b.code,
            symbol: b.symbol,
            decimals: b.decimals,
            amountUnits: getter(b),
          ))
      .toList();

  CurrencyDashboardBucket? homeBucket;
  for (final b in buckets) {
    if (b.code == base.code) {
      homeBucket = b;
      break;
    }
  }
  final hasNegativeTax = buckets.any((b) => b.taxLiabilityUnits < 0);
  final hasLoss = homeBucket != null
      ? homeBucket.netProfitUnits < 0
      : buckets.any((b) => b.netProfitUnits < 0);

  return DashboardCashFlowSummary(
    byCurrency: buckets,
    formattedInvoiced: formatMultiCurrencyAmounts(pick((b) => b.invoicedUnits), emptyFallback: zeroFallback),
    formattedUnpaid: formatMultiCurrencyAmounts(pick((b) => b.pendingBalanceUnits), emptyFallback: zeroFallback),
    formattedOverdue: formatMultiCurrencyAmounts(pick((b) => b.overdueAmountUnits), emptyFallback: zeroFallback),
    formattedCollected: formatMultiCurrencyAmounts(pick((b) => b.collectedUnits), emptyFallback: zeroFallback),
    formattedTaxLiability: formatMultiCurrencyAmounts(pick((b) => b.taxLiabilityUnits), emptyFallback: zeroFallback),
    formattedNetProfit: formatMultiCurrencyAmounts(pick((b) => b.netProfitUnits), emptyFallback: zeroFallback),
    hasAnyNegativeTaxLiability: hasNegativeTax,
    hasNetLoss: hasLoss,
  );
}

/// Parses a YYYY-MM-DD string as a local calendar DateTime, rejecting invalid calendar dates (e.g. 2026-02-30).
DateTime? parseLocalCalendarDate(String dateStr) {
  final trimmed = dateStr.trim();
  if (trimmed.isEmpty) return null;

  final ymdMatch = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(trimmed);
  if (ymdMatch != null) {
    final y = int.parse(ymdMatch.group(1)!);
    final m = int.parse(ymdMatch.group(2)!);
    final d = int.parse(ymdMatch.group(3)!);
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    final parsed = DateTime(y, m, d);
    if (parsed.year != y || parsed.month != m || parsed.day != d) {
      return null;
    }
    return parsed;
  }

  final fallback = DateTime.tryParse(trimmed);
  if (fallback == null) return null;
  final local = fallback.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// Returns true only when [dateStr] is strictly formatted as YYYY-MM-DD and represents a real calendar date.
bool isValidIsoCalendarDate(String dateStr) {
  final trimmed = dateStr.trim();
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(trimmed)) return false;
  return parseLocalCalendarDate(trimmed) != null;
}

/// Filters a document's issue date against 'All Time', 'This Month', or 'This Quarter'.
bool matchesDateFilter(
  String isoDateStr,
  String dateFilter, {
  DateTime? referenceNow,
}) {
  final trimmedFilter = dateFilter.trim();
  if (trimmedFilter.isEmpty || trimmedFilter == 'All Time') return true;

  final parsed = parseLocalCalendarDate(isoDateStr);
  if (parsed == null) return false;

  final now = referenceNow ?? DateTime.now();
  if (trimmedFilter == 'This Month') {
    return parsed.year == now.year && parsed.month == now.month;
  }
  if (trimmedFilter == 'This Quarter') {
    final refQuarter = (now.month - 1) ~/ 3;
    final itemQuarter = (parsed.month - 1) ~/ 3;
    return parsed.year == now.year && itemQuarter == refQuarter;
  }
  return true;
}


