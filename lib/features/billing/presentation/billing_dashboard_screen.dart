import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:billing_app/core/theme/app_theme.dart';
import 'package:billing_app/core/theme/theme_provider.dart';
import 'package:billing_app/core/utils/csv_export_service.dart';
import 'package:billing_app/features/business_profile/presentation/business_profile_dialog.dart';
import 'package:billing_app/features/business_profile/providers/business_profile_provider.dart';
import 'package:billing_app/features/clients/providers/clients_provider.dart';
import 'package:billing_app/features/dashboard/presentation/dashboard_tab.dart';
import 'package:billing_app/features/expenses/presentation/expenses_tab.dart';
import 'package:billing_app/features/expenses/providers/expenses_provider.dart';
import 'package:billing_app/features/invoices/providers/invoices_provider.dart';
import 'package:billing_app/features/settings/presentation/directory_settings_tab.dart';
import 'package:billing_app/features/billing/presentation/sales_tab.dart';

class BillingDashboardScreen extends ConsumerStatefulWidget {
  const BillingDashboardScreen({super.key});

  @override
  ConsumerState<BillingDashboardScreen> createState() => _BillingDashboardScreenState();
}

class _BillingDashboardScreenState extends ConsumerState<BillingDashboardScreen> {
  int _selectedTab = 0; // 0=Dashboard, 1=Sales & Clients, 2=Expenses, 3=Settings
  int _salesSubTab = 0; // Inside SalesTab: 0=Invoices, 1=Estimates, 2=Clients
  int _settingsSubTab = 0; // Inside DirectorySettingsTab: 0=Profile, 1=Catalog, 2=Banking, 3=Backup

  void _handleExportCsv() {
    final invoices = ref.read(invoicesProvider);
    final expenses = ref.read(expensesProvider);
    final clients = ref.read(clientsProvider);
    final profile = ref.read(businessProfileProvider);

    CsvExportService.showExportModal(
      context: context,
      invoices: invoices,
      expenses: expenses,
      clients: clients,
      currencySymbol: profile.currencySymbol,
    );
  }

  IconData _getThemeModeIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return Icons.brightness_auto;
      case ThemeMode.light:
        return Icons.light_mode;
      case ThemeMode.dark:
        return Icons.dark_mode;
    }
  }

  String _getThemeModeTooltip(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'Theme: System Auto';
      case ThemeMode.light:
        return 'Theme: Light Mode';
      case ThemeMode.dark:
        return 'Theme: Dark Mode';
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final currentAccent = ref.watch(accentColorProvider);
    final profile = ref.watch(businessProfileProvider);

    final desktopTabs = [
      DashboardTab(
        onNavigateToInvoices: () {
          setState(() {
            _selectedTab = 1;
            _salesSubTab = 0;
          });
        },
        onNavigateToEstimates: () {
          setState(() {
            _selectedTab = 1;
            _salesSubTab = 1;
          });
        },
        onNavigateToExpenses: () => setState(() => _selectedTab = 2),
      ),
      SalesTab(initialSubTab: _salesSubTab),
      const ExpensesTab(),
      DirectorySettingsTab(initialSubTab: _settingsSubTab),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;

        if (isWide) {
          // Desktop (width >= 900px) with 220px left NavigationRail
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  extended: true,
                  minExtendedWidth: 220,
                  selectedIndex: _selectedTab < 4 ? _selectedTab : 0,
                  onDestinationSelected: (index) {
                    setState(() {
                      _selectedTab = index;
                      if (index == 1) _salesSubTab = 0;
                      if (index == 3) _settingsSubTab = 0;
                    });
                  },
                  leading: SizedBox(
                    width: 204,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                            child: Text(
                              profile.businessName.isNotEmpty ? profile.businessName[0].toUpperCase() : 'F',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onPrimaryContainer),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              profile.businessName.isNotEmpty ? profile.businessName : 'Freelance',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      selectedIcon: Icon(Icons.dashboard),
                      label: Text('Dashboard'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.receipt_long_outlined),
                      selectedIcon: Icon(Icons.receipt_long),
                      label: Text('Sales'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.account_balance_wallet_outlined),
                      selectedIcon: Icon(Icons.account_balance_wallet),
                      label: Text('Expenses'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.settings_outlined),
                      selectedIcon: Icon(Icons.settings),
                      label: Text('Settings'),
                    ),
                  ],
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(
                  child: Scaffold(
                    appBar: AppBar(
                      title: const SizedBox.shrink(),
                      elevation: 0,
                      actions: [
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                            foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                          icon: const Icon(Icons.file_download, size: 16),
                          label: const Text('Export Accountant CSV', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          onPressed: _handleExportCsv,
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Business Profile Settings',
                          icon: const Icon(Icons.business_outlined),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => const BusinessProfileDialog(),
                            );
                          },
                        ),
                        _buildAccentColorPicker(currentAccent),
                        IconButton(
                          tooltip: _getThemeModeTooltip(themeMode),
                          icon: Icon(_getThemeModeIcon(themeMode)),
                          onPressed: () => ref.read(themeModeProvider.notifier).cycleThemeMode(),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                    body: SingleChildScrollView(
                      padding: const EdgeInsets.all(24.0),
                      child: desktopTabs[_selectedTab < 4 ? _selectedTab : 0],
                    ),
                  ),
                ),
              ],
            ),
          );
        } else {
          // Mobile / Split-Window (< 900px) with 4 NavigationBar destinations & SafeArea
          return Scaffold(
            appBar: AppBar(
              title: Text(
                profile.businessName.isNotEmpty ? profile.businessName : 'Freelance',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              elevation: 0,
              actions: [
                IconButton(
                  tooltip: 'Export Accountant CSV',
                  icon: const Icon(Icons.file_download),
                  onPressed: _handleExportCsv,
                ),
                IconButton(
                  tooltip: 'Business Profile',
                  icon: const Icon(Icons.business_outlined),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => const BusinessProfileDialog(),
                    );
                  },
                ),
                _buildAccentColorPicker(currentAccent),
                IconButton(
                  tooltip: _getThemeModeTooltip(themeMode),
                  icon: Icon(_getThemeModeIcon(themeMode)),
                  onPressed: () => ref.read(themeModeProvider.notifier).cycleThemeMode(),
                ),
              ],
            ),
            body: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: desktopTabs[_selectedTab < 4 ? _selectedTab : 0],
              ),
            ),
            bottomNavigationBar: Container(
              color: Theme.of(context).navigationBarTheme.backgroundColor,
              child: SafeArea(
                top: false,
                child: NavigationBar(
                  selectedIndex: _selectedTab < 4 ? _selectedTab : 0,
                  onDestinationSelected: (index) {
                    setState(() {
                      _selectedTab = index;
                      if (index == 1) _salesSubTab = 0;
                      if (index == 3) _settingsSubTab = 0;
                    });
                  },
                  destinations: const [
                    NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
                    NavigationDestination(icon: Icon(Icons.work_outline), label: 'Sales'),
                    NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), label: 'Expenses'),
                    NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
                  ],
                ),
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildAccentColorPicker(Color currentAccent) {
    return PopupMenuButton<Color>(
      tooltip: 'Accent Color',
      icon: Icon(Icons.palette_outlined, color: currentAccent),
      onSelected: (color) => ref.read(accentColorProvider.notifier).setAccentColor(color),
      itemBuilder: (context) {
        return AppTheme.presetAccents.map((color) {
          final isSelected = color.value == currentAccent.value;
          return PopupMenuItem<Color>(
            value: color,
            child: Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Text(_getColorName(color), style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                if (isSelected) ...[
                  const Spacer(),
                  const Icon(Icons.check, size: 16),
                ],
              ],
            ),
          );
        }).toList();
      },
    );
  }

  String _getColorName(Color color) {
    if (color == AppPalette.indigo) return 'Indigo';
    if (color == AppPalette.emerald) return 'Emerald';
    if (color == AppPalette.royalBlue) return 'Royal Blue';
    if (color == AppPalette.roseRed) return 'Rose Red';
    if (color == AppPalette.amberGold) return 'Amber Gold';
    if (color == AppPalette.slateSteel) return 'Slate Steel';
    return 'Custom';
  }
}
