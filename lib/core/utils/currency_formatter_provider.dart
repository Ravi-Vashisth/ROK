import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:billing_app/features/business_profile/providers/business_profile_provider.dart';
import 'package:billing_app/core/utils/money_utils.dart';

final currencyFormatterProvider = Provider<String Function(int)>((ref) {
  final profile = ref.watch(businessProfileProvider);
  final code = profile.currencyCode;
  final symbol = profile.currencySymbol;
  final decimals = profile.currencyDecimals;
  return (int cents) {
    return formatMoney(cents, symbol: symbol, decimals: decimals, currencyCode: code);
  };
});
