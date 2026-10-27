import 'package:sqlite3/sqlite3.dart' hide Row;
import 'package:sqlite3/sqlite3.dart' as sql show Row;

class BusinessProfile {
  final String id;
  final String businessName;
  final String email;
  final String phone;
  final String address;
  final String taxId;
  final String paymentDetails;
  final String currencySymbol;

  const BusinessProfile({
    required this.id,
    required this.businessName,
    required this.email,
    required this.phone,
    required this.address,
    required this.taxId,
    required this.paymentDetails,
    this.currencySymbol = '\$',
  });

  factory BusinessProfile.fromRow(sql.Row row) {
    return BusinessProfile(
      id: row['id'] as String? ?? 'default',
      businessName: row['business_name'] as String? ?? 'My Studio',
      email: row['email'] as String? ?? '',
      phone: row['phone'] as String? ?? '',
      address: row['address'] as String? ?? '',
      taxId: row['tax_id'] as String? ?? '',
      paymentDetails: row['payment_details'] as String? ?? '',
      currencySymbol: row['currency_symbol'] as String? ?? '\$',
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
    };
  }
}
