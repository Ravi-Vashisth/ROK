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
      // In case table is still initializing or during tests, keep default state
    }
  }

  void updateProfile({
    required String businessName,
    required String email,
    required String phone,
    required String address,
    required String taxId,
    required String paymentDetails,
  }) {
    _db.execute(
      '''
      UPDATE business_profile
      SET business_name = ?,
          email = ?,
          phone = ?,
          address = ?,
          tax_id = ?,
          payment_details = ?
      WHERE id = 'default';
      ''',
      [businessName, email, phone, address, taxId, paymentDetails],
    );

    state = state.copyWith(
      businessName: businessName,
      email: email,
      phone: phone,
      address: address,
      taxId: taxId,
      paymentDetails: paymentDetails,
    );
  }
}

final businessProfileProvider =
    StateNotifierProvider<BusinessProfileNotifier, BusinessProfile>((ref) {
  final db = ref.watch(databaseProvider);
  return BusinessProfileNotifier(db);
});
