import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/utils/backup_service.dart';
import '../../../core/utils/export_file_helper.dart';
import '../../../core/utils/tax_compliance_utils.dart';
import '../../business_profile/presentation/business_profile_dialog.dart';
import '../../business_profile/providers/business_profile_provider.dart';
import '../../clients/providers/clients_provider.dart';
import '../../estimates/providers/estimates_provider.dart';
import '../../expenses/providers/expenses_provider.dart';
import '../../invoices/providers/invoices_provider.dart';
import '../../items/presentation/items_catalog_tab.dart';
import '../../items/providers/saved_items_provider.dart';

class DirectorySettingsTab extends ConsumerStatefulWidget {
  final int initialSubTab;
  const DirectorySettingsTab({super.key, this.initialSubTab = 0});

  @override
  ConsumerState<DirectorySettingsTab> createState() => _DirectorySettingsTabState();
}

class _DirectorySettingsTabState extends ConsumerState<DirectorySettingsTab> {
  late int _subTab;

  @override
  void initState() {
    super.initState();
    _subTab = widget.initialSubTab;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              Text(
                'Application Settings & System Preferences',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ToggleButtons(
                  isSelected: [_subTab == 0, _subTab == 1, _subTab == 2, _subTab == 3],
                  onPressed: (index) {
                    setState(() => _subTab = index);
                  },
                  borderRadius: BorderRadius.circular(12),
                  constraints: const BoxConstraints(minHeight: 38, minWidth: 100),
                  children: const [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        children: [
                          Icon(Icons.business_outlined, size: 16),
                          SizedBox(width: 6),
                          Text('Profile & Branding', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 16),
                          SizedBox(width: 6),
                          Text('Catalog & Services', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        children: [
                          Icon(Icons.account_balance_outlined, size: 16),
                          SizedBox(width: 6),
                          Text('Payment & Banking', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        children: [
                          Icon(Icons.settings_backup_restore, size: 16),
                          SizedBox(width: 6),
                          Text('Data Backup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (_subTab == 0) ...[
          _BusinessProfileSettingsCard(),
        ] else if (_subTab == 1) ...[
          const ItemsCatalogTab(),
        ] else if (_subTab == 2) ...[
          _PaymentBankingSettingsCard(),
        ] else ...[
          _BackupRecoveryCard(),
        ],
      ],
    );
  }
}

class _PaymentBankingSettingsCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(businessProfileProvider);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final titleRow = Row(
                  children: [
                    Icon(Icons.account_balance, color: Theme.of(context).colorScheme.primary, size: 28),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Payment Methods & Remittance Instructions',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Configure bank wire transfer accounts, UPI VPA, and online payment links.',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
                final editBtn = FilledButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => const BusinessProfileDialog(),
                    );
                  },
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit Payment Instructions'),
                );
                if (constraints.maxWidth < 560) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleRow,
                      const SizedBox(height: 12),
                      editBtn,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: titleRow),
                    const SizedBox(width: 12),
                    editBtn,
                  ],
                );
              },
            ),
            const Divider(height: 32),
            const Text('Bank Account & Wire Transfer Instructions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Text(
                profile.paymentDetails.isNotEmpty ? profile.paymentDetails : 'No remittance details specified.',
                style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Default Invoice Terms & Legal Notice', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Text(
                profile.defaultTerms.isNotEmpty ? profile.defaultTerms : 'Payment due within agreed terms. Thank you for your business!',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackupRecoveryCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);

    void handleExport() async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        final jsonStr = BackupService.exportToJsonString(db);
        final bytes = utf8.encode(jsonStr);
        final now = DateTime.now();
        final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        final savedPath = await ExportFileHelper.saveExportFile(
          bytes: bytes,
          filename: 'freelance_ledger_backup_$dateStr.json',
          extension: 'json',
          dialogTitle: 'Save Database Backup JSON',
        );
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              savedPath != null
                  ? 'Database backup saved: $savedPath'
                  : 'Backup export cancelled.',
            ),
          ),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Error exporting database: $e')),
        );
      }
    }

    Future<void> handlePickAndRestore() async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['json'],
          withData: true,
        );
        if (result == null || result.files.isEmpty) return;

        final picked = result.files.single;
        final bytes = picked.bytes ??
            (picked.path != null ? await File(picked.path!).readAsBytes() : null);
        if (bytes == null) {
          throw const FormatException('Could not read the selected backup file.');
        }

        final jsonStr = utf8.decode(bytes);
        final decoded = jsonDecode(jsonStr);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('Invalid backup file: Root payload must be a JSON object.');
        }
        BackupService.validateBackupMap(decoded);

        if (!context.mounted) return;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            title: const Text('Confirm Database Restore'),
            content: Text(
              'Restore ledger from "${picked.name}"?\n\nWarning: This atomically replaces all current clients, invoices, quotes, expenses, catalog items, payments, and business settings.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.of(dialogCtx).pop(true),
                child: const Text('Restore & Overwrite'),
              ),
            ],
          ),
        );

        if (confirmed != true) return;

        BackupService.importDatabaseFromJson(db, decoded);

        ref.invalidate(clientsProvider);
        ref.invalidate(invoicesProvider);
        ref.invalidate(estimatesProvider);
        ref.invalidate(expensesProvider);
        ref.invalidate(savedItemsProvider);
        ref.invalidate(businessProfileProvider);

        messenger.showSnackBar(
          const SnackBar(content: Text('Database successfully restored from backup!')),
        );
      } catch (e) {
        final msg = e is FormatException ? e.message : 'Error restoring backup: $e';
        messenger.showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.security, color: Theme.of(context).colorScheme.primary, size: 28),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Disaster Recovery & Data Management',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Export or restore your complete ledger database instantly.',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            const Text(
              'Export Backup',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 6),
            const Text(
              'Generates a complete JSON snapshot of all your clients, invoices, estimates, expenses, payments, and business settings.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: handleExport,
              icon: const Icon(Icons.download_outlined, size: 16),
              label: const Text('Export Database File (JSON Backup)'),
            ),
            const SizedBox(height: 24),
            const Text(
              'Restore Backup',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 6),
            const Text(
              'Restore your database from an exported JSON backup. Warning: This overwrites all current local records.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              onPressed: handlePickAndRestore,
              icon: const Icon(Icons.upload_outlined, size: 16),
              label: const Text('Select JSON Backup File to Restore'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BusinessProfileSettingsCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(businessProfileProvider);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final titleRow = Row(
                  children: [
                    Icon(Icons.storefront, color: Theme.of(context).colorScheme.primary, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.businessName,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            profile.email.isNotEmpty ? profile.email : 'No email configured',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
                final editBtn = FilledButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => const BusinessProfileDialog(),
                    );
                  },
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit Profile & Branding'),
                );
                if (constraints.maxWidth < 560) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleRow,
                      const SizedBox(height: 12),
                      editBtn,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: titleRow),
                    const SizedBox(width: 12),
                    editBtn,
                  ],
                );
              },
            ),
            const Divider(height: 32),
            const Text('Configured Business Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            _infoRow(context, 'Currency Symbol', profile.currencySymbol),
            _infoRow(context, 'Phone', profile.phone.isNotEmpty ? profile.phone : 'Not specified'),
            _infoRow(context, 'Address', profile.address.isNotEmpty ? profile.address : 'Not specified'),
            _infoRow(context, getRegionalTaxIdLabel(profile.defaultTaxMode), profile.taxId.isNotEmpty ? profile.taxId : 'Not specified'),
            _infoRow(
              context,
              'Tax Compliance Mode',
              profile.defaultTaxMode == TaxMode.caDual && profile.defaultPstRatePercentage > 0
                  ? '${taxModeLabels[normalizeTaxMode(profile.defaultTaxMode)]} (Default PST: ${profile.defaultPstRatePercentage}%)'
                  : (taxModeLabels[normalizeTaxMode(profile.defaultTaxMode)] ?? 'Standard Tax'),
            ),
            _infoRow(context, 'Company Logo', profile.logoBase64.isNotEmpty ? '✔ Configured' : 'Not configured'),
            _infoRow(context, 'Digital Signature', profile.signatureBase64.isNotEmpty ? '✔ Digital Signature Configured' : 'Not configured'),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: Colors.blue),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'All changes to business profile, logo, QR payment payload, and tax settings instantly apply to newly generated PDF invoices and quotes.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 460) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 180,
                child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.grey)),
              ),
              Expanded(
                child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ],
          );
        },
      ),
    );
  }
}
