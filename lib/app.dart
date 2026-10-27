import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/billing/presentation/billing_dashboard_screen.dart';

class BillingDesktopApp extends ConsumerWidget {
  const BillingDesktopApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final accentColor = ref.watch(accentColorProvider);

    return MaterialApp(
      title: 'Local Billing',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(seed: accentColor),
      darkTheme: AppTheme.darkTheme(seed: accentColor),
      themeMode: themeMode,
      home: const BillingDashboardScreen(),
    );
  }
}
