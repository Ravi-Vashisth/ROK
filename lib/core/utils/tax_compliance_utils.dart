import 'money_utils.dart';

class TaxMode {
  static const String standard = 'standard';
  static const String inIntra = 'in_intra';
  static const String inInter = 'in_inter';
  static const String inLut = 'in_lut';
  static const String euVat = 'eu_vat';
  static const String euReverseCharge = 'eu_reverse_charge';
  static const String caDual = 'ca_dual';
  static const String gulfVat = 'gulf_vat';
  static const String usExempt = 'us_exempt';

  static const List<String> all = [
    standard,
    inIntra,
    inInter,
    inLut,
    euVat,
    euReverseCharge,
    caDual,
    gulfVat,
    usExempt,
  ];
}

const Map<String, String> taxModeLabels = {
  TaxMode.standard: 'Standard Tax',
  TaxMode.inIntra: 'India GST — Intra-State (CGST + SGST)',
  TaxMode.inInter: 'India GST — Inter-State (IGST)',
  TaxMode.inLut: 'India GST — Export under LUT (0%)',
  TaxMode.euVat: 'EU / UK VAT — Standard',
  TaxMode.euReverseCharge: 'EU / UK B2B Reverse Charge (0%)',
  TaxMode.caDual: 'Canada Dual Tax (GST + PST)',
  TaxMode.gulfVat: 'Gulf / GCC VAT (KSA / UAE)',
  TaxMode.usExempt: 'US Sales Tax-Exempt (0%)',
};

class GstSplit {
  final int cgstCents;
  final int sgstCents;
  final int igstCents;

  const GstSplit({
    required this.cgstCents,
    required this.sgstCents,
    required this.igstCents,
  });
}

class CanadaTaxResult {
  final int gstCents;
  final int pstCents;
  final int totalTaxCents;

  const CanadaTaxResult({
    required this.gstCents,
    required this.pstCents,
    required this.totalTaxCents,
  });
}

class TaxBreakdownLine {
  final String label;
  final int cents;

  const TaxBreakdownLine({
    required this.label,
    required this.cents,
  });
}

class RegionalTaxBreakdown {
  final String effectiveMode;
  final List<TaxBreakdownLine> lines;
  final int totalTaxCents;
  final String noticeTitle;
  final String noticeText;
  final bool isZeroRated;

  const RegionalTaxBreakdown({
    required this.effectiveMode,
    required this.lines,
    required this.totalTaxCents,
    required this.noticeTitle,
    required this.noticeText,
    required this.isZeroRated,
  });
}

String normalizeTaxMode(String? raw) {
  final trimmed = (raw ?? '').trim();
  if (TaxMode.all.contains(trimmed)) return trimmed;
  return TaxMode.standard;
}

bool isZeroRatedTaxMode(String? mode) {
  final normalized = normalizeTaxMode(mode);
  return normalized == TaxMode.inLut ||
      normalized == TaxMode.euReverseCharge ||
      normalized == TaxMode.usExempt;
}

/// Computes Indian GST CGST/SGST (50%/50%, SGST absorbs odd unit) or IGST (100%).
GstSplit calculateGstSplit(int totalTaxCents, bool isIntraState) {
  if (totalTaxCents <= 0) {
    return const GstSplit(cgstCents: 0, sgstCents: 0, igstCents: 0);
  }
  if (isIntraState) {
    final cgst = totalTaxCents ~/ 2;
    final sgst = totalTaxCents - cgst;
    return GstSplit(cgstCents: cgst, sgstCents: sgst, igstCents: 0);
  }
  return GstSplit(cgstCents: 0, sgstCents: 0, igstCents: totalTaxCents);
}

/// Returns Indian statutory LUT export notice if zero-rated export under LUT.
String getLutNotice(bool isExportUnderLut) {
  if (!isExportUnderLut) return '';
  return 'SUPPLY MEANT FOR EXPORT UNDER BOND OR LETTER OF UNDERTAKING WITHOUT PAYMENT OF INTEGRATED TAX';
}

/// Returns EU/UK B2B Reverse Charge notice.
String getEuReverseChargeNotice(bool isEuCrossBorderB2B) {
  if (!isEuCrossBorderB2B) return '';
  return 'Reverse charge: Customer to account for VAT under Article 196 of Council Directive 2006/112/EC.';
}

/// Calculates Canadian dual tax (GST + PST) strictly in 64-bit integer minor units.
CanadaTaxResult calculateCanadaTax(
  int subtotalCents,
  int gstRatePct,
  int pstRatePct,
) {
  final safeSubtotal = subtotalCents < 0 ? 0 : subtotalCents;
  final safeGst = gstRatePct < 0 ? 0 : gstRatePct;
  final safePst = pstRatePct < 0 ? 0 : pstRatePct;
  final gstCents = (safeSubtotal * safeGst + 50) ~/ 100;
  final pstCents = (safeSubtotal * safePst + 50) ~/ 100;
  return CanadaTaxResult(
    gstCents: gstCents,
    pstCents: pstCents,
    totalTaxCents: gstCents + pstCents,
  );
}

/// Computes authoritative total tax minor units for a document based on its tax compliance mode.
int computeRegionalTaxCents({
  required int netSubtotalCents,
  required String taxMode,
  required int taxPercentage,
  int pstRatePercentage = 0,
  int itemsTaxSumCents = 0,
}) {
  final mode = normalizeTaxMode(taxMode);
  if (isZeroRatedTaxMode(mode)) return 0;

  if (mode == TaxMode.caDual) {
    final gstCents = itemsTaxSumCents > 0
        ? itemsTaxSumCents
        : calculateTaxCents(netSubtotalCents, taxPercentage);
    final pstCents = calculateTaxCents(netSubtotalCents, pstRatePercentage);
    return gstCents + pstCents;
  }

  return itemsTaxSumCents > 0
      ? itemsTaxSumCents
      : calculateTaxCents(netSubtotalCents, taxPercentage);
}

/// Resolves itemized tax summary lines and statutory compliance banners for UI & PDF rendering.
RegionalTaxBreakdown resolveRegionalTaxBreakdown({
  required String taxMode,
  required int netSubtotalCents,
  required int taxCents,
  int pstRatePercentage = 0,
  String taxExemptionId = '',
  String businessTaxId = '',
  String clientTaxId = '',
  bool fallbackAutoDetect = false,
  String clientAddress = '',
  String notes = '',
  String terms = '',
}) {
  var effectiveMode = normalizeTaxMode(taxMode);

  // Backward-compatible detection ONLY for legacy records saved with 'standard' and 0 tax.
  if (fallbackAutoDetect && effectiveMode == TaxMode.standard && taxCents == 0) {
    final cTax = clientTaxId.trim().toUpperCase();
    final cAddr = clientAddress.trim().toUpperCase();
    final invNotes = notes.toUpperCase();
    final invTerms = terms.toUpperCase();

    final isExport = cAddr.contains('USA') ||
        cAddr.contains('UNITED STATES') ||
        cAddr.contains('EXPORT') ||
        cAddr.contains('INTERNATIONAL') ||
        cAddr.contains('UK') ||
        cAddr.contains('LONDON') ||
        cAddr.contains('DUBAI') ||
        cAddr.contains('SINGAPORE') ||
        cAddr.contains('LUT') ||
        invNotes.contains('EXPORT') ||
        invTerms.contains('EXPORT');

    final isEuVat = cTax.startsWith('GB') ||
        cTax.startsWith('DE') ||
        cTax.startsWith('FR') ||
        cTax.startsWith('NL') ||
        cTax.startsWith('IE') ||
        cTax.startsWith('IT') ||
        cTax.startsWith('ES') ||
        cTax.startsWith('BE') ||
        cTax.startsWith('AT') ||
        cTax.startsWith('SE') ||
        cTax.startsWith('DK') ||
        cTax.startsWith('FI') ||
        cTax.startsWith('PL') ||
        cTax.startsWith('CZ') ||
        cTax.startsWith('PT') ||
        cTax.startsWith('RO') ||
        cTax.startsWith('HU') ||
        cTax.startsWith('GR') ||
        cTax.contains('VAT');

    if (isExport) {
      effectiveMode = TaxMode.inLut;
    } else if (isEuVat) {
      effectiveMode = TaxMode.euReverseCharge;
    }
  }

  final safeTax = taxCents < 0 ? 0 : taxCents;

  switch (effectiveMode) {
    case TaxMode.inIntra:
      if (safeTax == 0) {
        return const RegionalTaxBreakdown(
          effectiveMode: TaxMode.inIntra,
          lines: [TaxBreakdownLine(label: 'CGST / SGST (0%)', cents: 0)],
          totalTaxCents: 0,
          noticeTitle: '',
          noticeText: '',
          isZeroRated: false,
        );
      }
      final split = calculateGstSplit(safeTax, true);
      return RegionalTaxBreakdown(
        effectiveMode: TaxMode.inIntra,
        lines: [
          TaxBreakdownLine(label: 'CGST (50% Split)', cents: split.cgstCents),
          TaxBreakdownLine(label: 'SGST (50% Split)', cents: split.sgstCents),
        ],
        totalTaxCents: safeTax,
        noticeTitle: '',
        noticeText: '',
        isZeroRated: false,
      );

    case TaxMode.inInter:
      final split = calculateGstSplit(safeTax, false);
      return RegionalTaxBreakdown(
        effectiveMode: TaxMode.inInter,
        lines: [
          TaxBreakdownLine(label: 'IGST (100%)', cents: split.igstCents),
        ],
        totalTaxCents: safeTax,
        noticeTitle: '',
        noticeText: '',
        isZeroRated: false,
      );

    case TaxMode.inLut:
      return RegionalTaxBreakdown(
        effectiveMode: TaxMode.inLut,
        lines: const [
          TaxBreakdownLine(label: 'IGST (0% Export LUT)', cents: 0),
        ],
        totalTaxCents: 0,
        noticeTitle: 'EXPORT UNDER LUT (RULE 96A)',
        noticeText: getLutNotice(true),
        isZeroRated: true,
      );

    case TaxMode.euVat:
      return RegionalTaxBreakdown(
        effectiveMode: TaxMode.euVat,
        lines: [
          TaxBreakdownLine(label: safeTax > 0 ? 'VAT' : 'VAT (0%)', cents: safeTax),
        ],
        totalTaxCents: safeTax,
        noticeTitle: '',
        noticeText: '',
        isZeroRated: false,
      );

    case TaxMode.euReverseCharge:
      return RegionalTaxBreakdown(
        effectiveMode: TaxMode.euReverseCharge,
        lines: const [
          TaxBreakdownLine(label: 'VAT (0% Reverse Charge)', cents: 0),
        ],
        totalTaxCents: 0,
        noticeTitle: 'EU / UK B2B REVERSE CHARGE',
        noticeText: getEuReverseChargeNotice(true),
        isZeroRated: true,
      );

    case TaxMode.caDual:
      if (safeTax == 0) {
        return const RegionalTaxBreakdown(
          effectiveMode: TaxMode.caDual,
          lines: [
            TaxBreakdownLine(label: 'GST', cents: 0),
            TaxBreakdownLine(label: 'PST', cents: 0),
          ],
          totalTaxCents: 0,
          noticeTitle: '',
          noticeText: '',
          isZeroRated: false,
        );
      }
      final rawPst = calculateTaxCents(netSubtotalCents, pstRatePercentage);
      final pstCents = rawPst > safeTax ? safeTax : rawPst;
      final gstCents = safeTax - pstCents;
      return RegionalTaxBreakdown(
        effectiveMode: TaxMode.caDual,
        lines: [
          TaxBreakdownLine(label: 'GST', cents: gstCents),
          TaxBreakdownLine(
            label: pstRatePercentage > 0 ? 'PST ($pstRatePercentage%)' : 'PST',
            cents: pstCents,
          ),
        ],
        totalTaxCents: safeTax,
        noticeTitle: '',
        noticeText: '',
        isZeroRated: false,
      );

    case TaxMode.gulfVat:
      final trnParts = <String>[
        if (businessTaxId.trim().isNotEmpty) 'Supplier TRN / VAT ID: ${businessTaxId.trim()}',
        if (clientTaxId.trim().isNotEmpty) 'Customer TRN / VAT ID: ${clientTaxId.trim()}',
      ];
      return RegionalTaxBreakdown(
        effectiveMode: TaxMode.gulfVat,
        lines: [
          TaxBreakdownLine(label: safeTax > 0 ? 'VAT' : 'VAT (0%)', cents: safeTax),
        ],
        totalTaxCents: safeTax,
        noticeTitle: trnParts.isNotEmpty ? 'GCC / GULF TAX INVOICE' : '',
        noticeText: trnParts.join('  •  '),
        isZeroRated: false,
      );

    case TaxMode.usExempt:
      final cleanExemptId = taxExemptionId.trim();
      return RegionalTaxBreakdown(
        effectiveMode: TaxMode.usExempt,
        lines: const [
          TaxBreakdownLine(label: 'Tax (0% Exempt)', cents: 0),
        ],
        totalTaxCents: 0,
        noticeTitle: 'US SALES TAX-EXEMPT SUPPLY',
        noticeText: cleanExemptId.isNotEmpty
            ? 'Tax-Exempt Supply — Client Exemption Certificate ID: $cleanExemptId'
            : 'Tax-Exempt Supply — Zero sales tax assessed.',
        isZeroRated: true,
      );

    case TaxMode.standard:
    default:
      return RegionalTaxBreakdown(
        effectiveMode: TaxMode.standard,
        lines: [
          TaxBreakdownLine(
            label: safeTax > 0 ? 'Tax' : 'Tax (0% / Exempt)',
            cents: safeTax,
          ),
        ],
        totalTaxCents: safeTax,
        noticeTitle: '',
        noticeText: '',
        isZeroRated: false,
      );
  }
}

/// Returns context-aware Tax ID label for a given regional compliance mode.
String getRegionalTaxIdLabel(String? taxMode, {bool isClient = false}) {
  final mode = normalizeTaxMode(taxMode);
  final prefix = isClient ? 'Client ' : '';
  if (mode == TaxMode.inIntra || mode == TaxMode.inInter || mode == TaxMode.inLut) {
    return '${prefix}GSTIN';
  }
  if (mode == TaxMode.gulfVat) {
    return '${prefix}TRN / VAT ID';
  }
  if (mode == TaxMode.euVat || mode == TaxMode.euReverseCharge) {
    return '${prefix}VAT ID';
  }
  return '${prefix}Tax ID';
}
