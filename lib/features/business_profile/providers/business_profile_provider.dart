import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../../core/database/database_provider.dart';
import '../models/business_profile.dart';

class BusinessProfileNotifier extends StateNotifier<BusinessProfile> {
  final Database _db;

  BusinessProfileNotifier(this._db)
      : super(
          const BusinessProfile(
            id: 'default',
            businessName: 'My Freelance Studio',
            email: 'billing@studio.com',
            phone: '+1 (555) 019-2834',
            address: '100 Tech Plaza, Suite 400, San Francisco, CA 94107',
            taxId: 'US-EIN-987654321',
            paymentDetails:
                'Bank: Silicon Valley Bank\nAccount: 987654321098\nRouting / SWIFT: SVB12345\nPayPal / UPI: pay@studio.com',
            currencySymbol: '\$',
            defaultTerms:
                'Payment due within agreed terms. Thank you for your business!',
            defaultNotes: 'All work includes 30 days post-delivery support.',
            logoBase64: '',
            signatureBase64: '',
            signatureLabel: 'Authorized Signatory',
          ),
        ) {
    _loadProfile();
  }

  void _loadProfile() {
    try {
      final ResultSet result = _db.select(
        "SELECT * FROM business_profile WHERE id = 'default' LIMIT 1;",
      );
      if (result.isNotEmpty) {
        state = BusinessProfile.fromRow(result.first);
      }
    } catch (_) {
      // Fallback if table initializing
    }
  }

  void updateProfile({
    required String businessName,
    required String email,
    required String phone,
    required String address,
    required String taxId,
    required String paymentDetails,
    String currencySymbol = '\$',
    String currencyCode = 'USD',
    int currencyDecimals = 2,
    String defaultTerms = 'Payment due within agreed terms. Thank you for your business!',
    String defaultNotes = '',
    String logoBase64 = '',
    String signatureBase64 = '',
    String signatureLabel = 'Authorized Signatory',
  }) {
    _db.execute(
      '''
      UPDATE business_profile
      SET business_name = ?,
          email = ?,
          phone = ?,
          address = ?,
          tax_id = ?,
          payment_details = ?,
          currency_symbol = ?,
          currency_code = ?,
          currency_decimals = ?,
          default_terms = ?,
          default_notes = ?,
          logo_base64 = ?,
          signature_base64 = ?,
          signature_label = ?
      WHERE id = 'default';
      ''',
      [
        businessName,
        email,
        phone,
        address,
        taxId,
        paymentDetails,
        currencySymbol,
        currencyCode,
        currencyDecimals,
        defaultTerms,
        defaultNotes,
        logoBase64,
        signatureBase64,
        signatureLabel,
      ],
    );

    state = state.copyWith(
      businessName: businessName,
      email: email,
      phone: phone,
      address: address,
      taxId: taxId,
      paymentDetails: paymentDetails,
      currencySymbol: currencySymbol,
      currencyCode: currencyCode,
      currencyDecimals: currencyDecimals,
      defaultTerms: defaultTerms,
      defaultNotes: defaultNotes,
      logoBase64: logoBase64,
      signatureBase64: signatureBase64,
      signatureLabel: signatureLabel,
    );
  }
}

final businessProfileProvider =
    StateNotifierProvider<BusinessProfileNotifier, BusinessProfile>((ref) {
  final db = ref.watch(databaseProvider);
  return BusinessProfileNotifier(db);
});
