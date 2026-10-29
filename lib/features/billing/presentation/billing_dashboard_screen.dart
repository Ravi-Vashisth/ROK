import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/csv_export_service.dart';
import '../../business_profile/presentation/business_profile_dialog.dart';
import '../../business_profile/providers/business_profile_provider.dart';
import '../../clients/presentation/clients_tab.dart';
import '../../clients/providers/clients_provider.dart';
import '../../dashboard/presentation/dashboard_tab.dart';
import '../../estimates/presentation/offline_estimates_list.dart';
import '../../expenses/presentation/expenses_tab.dart';
import '../../expenses/providers/expenses_provider.dart';
import '../../items/presentation/items_catalog_tab.dart';
import '../../settings/presentation/directory_settings_tab.dart';
import '../../invoices/providers/invoices_provider.dart';
import 'sales_tab.dart';

class BillingDashboardScreen extends ConsumerStatefulWidget {
  const BillingDashboardScreen({super.key});

  @override
  ConsumerState<BillingDashboardScreen> createState() => _BillingDashboardScreenState();
}

class _BillingDashboardScreenState extends ConsumerState<BillingDashboardScreen> {
  int _selectedTab = 0; // 0=Dashboard, 1=Invoices, 2=Estimates, 3=Clients, 4=Expenses, 5=Catalog, 6=Settings

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

    final tabs = [
      DashboardTab(
        onNavigateToInvoices: () => setState(() => _selectedTab = 1),
        onNavigateToEstimates: () => setState(() => _selectedTab = 2),
        onNavigateToExpenses: () => setState(() => _selectedTab = 4),
      ),
      const SalesTab(initialSubTab: 0), // Invoices
      const SalesTab(initialSubTab: 1), // Estimates / Quotes
      const ClientsTab(),
      const ExpensesTab(),
      const ItemsCatalogTab(),
      const DirectorySettingsTab(),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;

        if (isWide) {
          // Desktop / Split Window view with vertical NavigationRail (7 items)
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _selectedTab,
                  onDestinationSelected: (index) => setState(() => _selectedTab = index),
                  labelType: NavigationRailLabelType.all,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Column(
                      children: [
                        CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          child: Text(
                            profile.businessName.isNotEmpty ? profile.businessName[0].toUpperCase() : 'B',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onPrimaryContainer),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          profile.businessName.isNotEmpty ? profile.businessName : 'Freelance',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
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
                      label: Text('Invoices'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.request_quote_outlined),
                      selectedIcon: Icon(Icons.request_quote),
                      label: Text('Quotes'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.people_alt_outlined),
                      selectedIcon: Icon(Icons.people_alt),
                      label: Text('Clients'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.account_balance_wallet_outlined),
                      selectedIcon: Icon(Icons.account_balance_wallet),
                      label: Text('Expenses'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.inventory_2_outlined),
                      selectedIcon: Icon(Icons.inventory_2),
                      label: Text('Catalog'),
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
                          tooltip: 'Business Profile & Branding Settings',
                          icon: const Icon(Icons.business_outlined),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => const BusinessProfileDialog(),
                            );
                          },
                        ),
                        PopupMenuButton<Color>(
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
                        ),
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
                      child: tabs[_selectedTab],
                    ),
                  ),
                ),
              ],
            ),
          );
        } else {
          // Mobile / Half-screen compact view with BottomNavigationBar + More menu
          return Scaffold(
            appBar: AppBar(
              title: const SizedBox.shrink(),
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
                IconButton(
                  tooltip: _getThemeModeTooltip(themeMode),
                  icon: Icon(_getThemeModeIcon(themeMode)),
                  onPressed: () => ref.read(themeModeProvider.notifier).cycleThemeMode(),
                ),
              ],
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: tabs[_selectedTab],
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _selectedTab > 3 ? 3 : _selectedTab,
              onDestinationSelected: (index) {
                if (index == 0) setState(() => _selectedTab = 0);
                else if (index == 1) setState(() => _selectedTab = 1);
                else if (index == 2) setState(() => _selectedTab = 4);
                else if (index == 3) _showMobileMoreMenu(context);
              },
              destinations: const [
                NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
                NavigationDestination(icon: Icon(Icons.work_outline), label: 'Sales'),
                NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), label: 'Expenses'),
                NavigationDestination(icon: Icon(Icons.menu), label: 'More'),
              ],
            ),
          );
        }
      },
    );
  }

  void _showMobileMoreMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.people_alt_outlined),
              title: const Text('Clients Directory'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _selectedTab = 3);
              },
            ),
            ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: const Text('Expenses Hub'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _selectedTab = 4);
              },
            ),
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: const Text('Items Catalog'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _selectedTab = 5);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings & Backup'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _selectedTab = 6);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _getColorName(Color color) {
    if (color == const Color(0xFF4F46E5)) return 'Indigo';
    if (color == const Color(0xFF059669)) return 'Emerald';
    if (color == const Color(0xFF2563EB)) return 'Royal Blue';
    if (color == const Color(0xFFE11D48)) return 'Rose';
    if (color == const Color(0xFFD97706)) return 'Amber';
    if (color == const Color(0xFF475569)) return 'Slate';
    return 'Custom';
  }
}
