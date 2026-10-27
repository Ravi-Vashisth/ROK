import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/csv_export_service.dart';
import '../../business_profile/presentation/business_profile_dialog.dart';
import '../../business_profile/providers/business_profile_provider.dart';
import '../../clients/providers/clients_provider.dart';
import '../../estimates/presentation/estimate_inputs_card.dart';
import '../../estimates/presentation/offline_estimates_list.dart';
import '../../estimates/providers/estimates_provider.dart';
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
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _taxIdController = TextEditingController();

  String? _selectedClientId;
  int _selectedTab = 0; // 0 = Invoices, 1 = Estimates / Quotes

  @override
  void dispose() {
    _newClientController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _taxIdController.dispose();
    super.dispose();
  }

  void _handleAddClient() {
    final name = _newClientController.text.trim();
    if (name.isEmpty) return;

    ref.read(clientsProvider.notifier).addClient(
          name: name,
          email: _emailController.text,
          phone: _phoneController.text,
          address: _addressController.text,
          taxId: _taxIdController.text,
        );

    _newClientController.clear();
    _emailController.clear();
    _phoneController.clear();
    _addressController.clear();
    _taxIdController.clear();

    final clients = ref.read(clientsProvider);
    final found = clients.where((c) => c.name == name);
    if (found.isNotEmpty) {
      setState(() {
        _selectedClientId = found.first.id;
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Client "$name" saved locally to SQLite.')),
    );
  }

  void _handleSaveInvoice({
    required List<DraftItem> items,
    required int taxPercentage,
    required String paymentTerms,
    required String issueDate,
    required String dueDate,
  }) {
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
          paymentTerms: paymentTerms,
          issueDate: issueDate,
          dueDate: dueDate,
        );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Invoice saved locally ($paymentTerms, Due: $dueDate)!')),
    );
  }

  void _handleSaveEstimate({
    required List<DraftItem> items,
    required int taxPercentage,
    required String issueDate,
    required String expiryDate,
  }) {
    if (_selectedClientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or add a client first.')),
      );
      return;
    }

    ref.read(estimatesProvider.notifier).saveEstimate(
          clientId: _selectedClientId!,
          items: items,
          taxPercentage: taxPercentage,
          issueDate: issueDate,
          expiryDate: expiryDate,
        );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Estimate saved locally (Expires: $expiryDate)!')),
    );
  }

  void _handleExportCsv() {
    final invoices = ref.read(invoicesProvider);
    final clients = ref.read(clientsProvider);
    final profile = ref.read(businessProfileProvider);

    final csvString = CsvExportService.generateInvoicesCsv(
      invoices: invoices,
      clients: clients,
      currencySymbol: profile.currencySymbol,
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.table_chart_outlined, color: Colors.indigo),
              SizedBox(width: 10),
              Text('Accountant CSV Export', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 550,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Standard CSV containing all invoice numbers, client tax IDs, subtotals, tax, totals, amount paid, balance due, and payment status.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 200,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.slate.shade900,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      csvString,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.emeraldAccent),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy to Clipboard'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: csvString));
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invoices CSV copied to clipboard!')),
                );
              },
            ),
          ],
        );
      },
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
    final nextInvoiceNumber = ref.watch(invoicesProvider.notifier).getNextInvoiceNumber();
    final nextEstimateNumber = ref.watch(estimatesProvider.notifier).getNextEstimateNumber();
    final themeMode = ref.watch(themeModeProvider);
    final currentAccent = ref.watch(accentColorProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Local Billing & Quotes System'),
        elevation: 0,
        actions: [
          // Export Accountant CSV Button
          IconButton(
            tooltip: 'Export Accountant CSV',
            icon: const Icon(Icons.file_download_outlined),
            onPressed: _handleExportCsv,
          ),

          // Business Profile & Payment Details Settings Dialog
          IconButton(
            tooltip: 'Business Profile & Currency Settings',
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
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _getColorName(color),
                        style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
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

          // Theme Mode Toggle
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
            // Client Selection / Entry Card (Shared across Invoices and Estimates)
            ClientSelectionCard(
              newClientController: _newClientController,
              emailController: _emailController,
              phoneController: _phoneController,
              addressController: _addressController,
              taxIdController: _taxIdController,
              selectedClientId: _selectedClientId,
              onClientSelected: (val) => setState(() => _selectedClientId = val),
              onAddClient: _handleAddClient,
            ),
            const SizedBox(height: 20),

            // Navigation Segment Bar: Invoices vs Estimates / Quotes
            SegmentedButton<int>(
              segments: const [
                ButtonSegment<int>(
                  value: 0,
                  label: Text('Invoices'),
                  icon: Icon(Icons.receipt_outlined),
                ),
                ButtonSegment<int>(
                  value: 1,
                  label: Text('Estimates / Quotes'),
                  icon: Icon(Icons.request_quote_outlined),
                ),
              ],
              selected: {_selectedTab},
              onSelectionChanged: (newSelection) {
                setState(() => _selectedTab = newSelection.first);
              },
            ),
            const SizedBox(height: 20),

            if (_selectedTab == 0) ...[
              InvoiceInputsCard(
                nextInvoiceNumber: nextInvoiceNumber,
                onSaveInvoice: _handleSaveInvoice,
              ),
              const SizedBox(height: 24),
              const OfflineInvoicesList(),
            ] else ...[
              EstimateInputsCard(
                nextEstimateNumber: nextEstimateNumber,
                onSaveEstimate: _handleSaveEstimate,
              ),
              const SizedBox(height: 24),
              const OfflineEstimatesList(),
            ],
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
