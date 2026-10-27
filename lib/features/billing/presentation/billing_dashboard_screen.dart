import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../business_profile/presentation/business_profile_dialog.dart';
import '../../clients/providers/clients_provider.dart';
import '../../invoices/providers/invoices_provider.dart';
import 'widgets/client_selection_card.dart';
import 'widgets/invoice_inputs_card.dart';
import 'widgets/offline_invoices_list.dart';

class BillingDashboardScreen extends ConsumerStatefulWidget {
  const BillingDashboardScreen({super.key});

  @override
  ConsumerState<BillingDashboardScreen> createState() => _BillingDashboardScreenState();
}

class _BillingDashboardScreenState extends ConsumerState<BillingDashboardScreen> {
  final _newClientController = TextEditingController();
  String? _selectedClientId;

  @override
  void dispose() {
    _newClientController.dispose();
    super.dispose();
  }

  void _handleAddClient() {
    final name = _newClientController.text.trim();
    if (name.isEmpty) return;

    ref.read(clientsProvider.notifier).addClient(name);
    _newClientController.clear();

    final clients = ref.read(clientsProvider);
    final found = clients.where((c) => c.name == name);
    if (found.isNotEmpty) {
      setState(() {
        _selectedClientId = found.first.id;
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Client "$name" added locally to SQLite.')),
    );
  }

  void _handleSaveInvoice(List<DraftItem> items, int taxPercentage) {
    if (_selectedClientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or add a client first.')),
      );
      return;
    }

    ref.read(invoicesProvider.notifier).saveInvoice(
          clientId: _selectedClientId!,
          items: items,
          taxPercentage: taxPercentage,
        );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Invoice saved locally with ${items.length} line item(s)!')),
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
        return 'Theme: System Auto (click to switch to Light)';
      case ThemeMode.light:
        return 'Theme: Light Mode (click to switch to Dark)';
      case ThemeMode.dark:
        return 'Theme: Dark Mode (click to switch to System)';
    }
  }

  @override
  Widget build(BuildContext context) {
    final nextInvoiceNumber = ref.watch(invoicesProvider.notifier).getNextInvoiceNumber();
    final themeMode = ref.watch(themeModeProvider);
    final currentAccent = ref.watch(accentColorProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Local Billing (Offline Desktop Skeleton)'),
        elevation: 0,
        actions: [
          // Business Profile & Payment Details Settings Dialog
          IconButton(
            tooltip: 'Business Profile & Payment Details',
            icon: const Icon(Icons.business_outlined),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const BusinessProfileDialog(),
              );
            },
          ),

          // Accent Color Palette Picker
          PopupMenuButton<Color>(
            tooltip: 'Accent Color',
            icon: Icon(Icons.palette_outlined, color: currentAccent),
            onSelected: (color) {
              ref.read(accentColorProvider.notifier).setAccentColor(color);
            },
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
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _getColorName(color),
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
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

          // Theme Mode Toggle (System -> Light -> Dark)
          IconButton(
            tooltip: _getThemeModeTooltip(themeMode),
            icon: Icon(_getThemeModeIcon(themeMode)),
            onPressed: () {
              ref.read(themeModeProvider.notifier).cycleThemeMode();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClientSelectionCard(
              newClientController: _newClientController,
              selectedClientId: _selectedClientId,
              onClientSelected: (val) => setState(() => _selectedClientId = val),
              onAddClient: _handleAddClient,
            ),
            const SizedBox(height: 20),
            InvoiceInputsCard(
              nextInvoiceNumber: nextInvoiceNumber,
              onSaveInvoice: _handleSaveInvoice,
            ),
            const SizedBox(height: 24),
            const OfflineInvoicesList(),
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
