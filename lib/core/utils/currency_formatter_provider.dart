import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/business_profile/providers/business_profile_provider.dart';

final currencyFormatterProvider = Provider<String Function(int)>((ref) {
  final profile = ref.watch(businessProfileProvider);
  final symbol = profile.currencySymbol;
  return (int cents) {
    final dollars = cents / 100.0;
    return '$symbol${dollars.toStringAsFixed(2)}';
  };
});
