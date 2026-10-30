import 'package:sqlite3/sqlite3.dart' hide Row;
import 'package:sqlite3/sqlite3.dart' as sql show Row;
import '../../../../core/utils/money_utils.dart';

class BusinessProfile {
  final String id;
  final String businessName;
  final String email;
  final String phone;
  final String address;
  final String taxId;
  final String paymentDetails;
  final String currencySymbol;
  final String currencyCode;
  final int currencyDecimals;
  final String defaultTerms;
  final String defaultNotes;
  final String logoBase64;
  final String signatureBase64;
  final String signatureLabel;
  final String invoicePrefix;
  final String estimatePrefix;
  final int nextInvoiceNumber;
  final String paymentQrPayload;

  const BusinessProfile({
    required this.id,
    required this.businessName,
    required this.email,
    required this.phone,
    required this.address,
    required this.taxId,
    required this.paymentDetails,
    this.currencySymbol = '\$',
    this.currencyCode = 'USD',
    this.currencyDecimals = 2,
    this.defaultTerms = 'Payment due within agreed terms. Thank you for your business!',
    this.defaultNotes = '',
    this.logoBase64 = '',
    this.signatureBase64 = '',
    this.signatureLabel = 'Authorized Signatory',
    this.invoicePrefix = 'INV-',
    this.estimatePrefix = 'EST-',
    this.nextInvoiceNumber = 1,
    this.paymentQrPayload = '',
  });

  factory BusinessProfile.fromRow(sql.Row row) {
    final sym = row['currency_symbol'] as String? ?? '\$';
    final code = row['currency_code'] as String? ?? 'USD';
    final dec = row['currency_decimals'] as int? ?? getCurrencyDecimals(code.isNotEmpty ? code : sym);

    return BusinessProfile(
      id: row['id'] as String? ?? 'default',
      businessName: row['business_name'] as String? ?? 'My Studio',
      email: row['email'] as String? ?? '',
      phone: row['phone'] as String? ?? '',
      address: row['address'] as String? ?? '',
      taxId: row['tax_id'] as String? ?? '',
      paymentDetails: row['payment_details'] as String? ?? '',
      currencySymbol: sym,
      currencyCode: code,
      currencyDecimals: dec,
      defaultTerms: row['default_terms'] as String? ??
          'Payment due within agreed terms. Thank you for your business!',
      defaultNotes: row['default_notes'] as String? ?? '',
      logoBase64: row['logo_base64'] as String? ?? '',
      signatureBase64: row['signature_base64'] as String? ?? '',
      signatureLabel: row['signature_label'] as String? ?? 'Authorized Signatory',
      invoicePrefix: row['invoice_prefix'] as String? ?? 'INV-',
      estimatePrefix: row['estimate_prefix'] as String? ?? 'EST-',
      nextInvoiceNumber: row['next_invoice_number'] as int? ?? 1,
      paymentQrPayload: row['payment_qr_payload'] as String? ?? '',
    );
  }

  BusinessProfile copyWith({
    String? id,
    String? businessName,
    String? email,
    String? phone,
    String? address,
    String? taxId,
    String? paymentDetails,
    String? currencySymbol,
    String? currencyCode,
    int? currencyDecimals,
    String? defaultTerms,
    String? defaultNotes,
    String? logoBase64,
    String? signatureBase64,
    String? signatureLabel,
    String? invoicePrefix,
    String? estimatePrefix,
    int? nextInvoiceNumber,
    String? paymentQrPayload,
  }) {
    return BusinessProfile(
      id: id ?? this.id,
      businessName: businessName ?? this.businessName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      taxId: taxId ?? this.taxId,
      paymentDetails: paymentDetails ?? this.paymentDetails,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      currencyCode: currencyCode ?? this.currencyCode,
      currencyDecimals: currencyDecimals ?? this.currencyDecimals,
      defaultTerms: defaultTerms ?? this.defaultTerms,
      defaultNotes: defaultNotes ?? this.defaultNotes,
      logoBase64: logoBase64 ?? this.logoBase64,
      signatureBase64: signatureBase64 ?? this.signatureBase64,
      signatureLabel: signatureLabel ?? this.signatureLabel,
      invoicePrefix: invoicePrefix ?? this.invoicePrefix,
      estimatePrefix: estimatePrefix ?? this.estimatePrefix,
      nextInvoiceNumber: nextInvoiceNumber ?? this.nextInvoiceNumber,
      paymentQrPayload: paymentQrPayload ?? this.paymentQrPayload,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'business_name': businessName,
      'email': email,
      'phone': phone,
      'address': address,
      'tax_id': taxId,
      'payment_details': paymentDetails,
      'currency_symbol': currencySymbol,
      'currency_code': currencyCode,
      'currency_decimals': currencyDecimals,
      'default_terms': defaultTerms,
      'default_notes': defaultNotes,
      'logo_base64': logoBase64,
      'signature_base64': signatureBase64,
      'signature_label': signatureLabel,
      'invoice_prefix': invoicePrefix,
      'estimate_prefix': estimatePrefix,
      'next_invoice_number': nextInvoiceNumber,
      'payment_qr_payload': paymentQrPayload,
    };
  }
}
