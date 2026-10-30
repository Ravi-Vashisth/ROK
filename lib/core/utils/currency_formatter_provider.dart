import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/business_profile/providers/business_profile_provider.dart';
import 'money_utils.dart';

final currencyFormatterProvider = Provider<String Function(int)>((ref) {
  final profile = ref.watch(businessProfileProvider);
  final symbol = profile.currencySymbol;
  final decimals = profile.currencyDecimals;
  return (int cents) {
    return formatMoney(cents, symbol: symbol, decimals: decimals);
  };
});
