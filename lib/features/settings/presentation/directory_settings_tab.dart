import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/utils/backup_service.dart';
import '../../business_profile/presentation/business_profile_dialog.dart';
import '../../business_profile/providers/business_profile_provider.dart';
import '../../clients/presentation/clients_tab.dart';
import '../../estimates/providers/estimates_provider.dart';
import '../../expenses/providers/expenses_provider.dart';
import '../../invoices/providers/invoices_provider.dart';
import '../../items/presentation/items_catalog_tab.dart';

class DirectorySettingsTab extends ConsumerStatefulWidget {
  const DirectorySettingsTab({super.key});

  @override
  ConsumerState<DirectorySettingsTab> createState() => _DirectorySettingsTabState();
}

class _DirectorySettingsTabState extends ConsumerState<DirectorySettingsTab> {
  int _subTab = 0; // 0 = Clients, 1 = Items Catalog, 2 = Branding & Prefs, 3 = Backup & Recovery

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Directory, Settings & Backup',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ToggleButtons(
                isSelected: [_subTab == 0, _subTab == 1, _subTab == 2, _subTab == 3],
                onPressed: (index) {
                  setState(() => _subTab = index);
                },
                borderRadius: BorderRadius.circular(8),
                constraints: const BoxConstraints(minHeight: 36, minWidth: 80),
                children: const [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        Icon(Icons.people_outline, size: 16),
                        SizedBox(width: 4),
                        Text('Clients', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 16),
                        SizedBox(width: 4),
                        Text('Catalog', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        Icon(Icons.business_outlined, size: 16),
                        SizedBox(width: 4),
                        Text('Branding', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        Icon(Icons.settings_backup_restore, size: 16),
                        SizedBox(width: 4),
                        Text('Backup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (_subTab == 0) ...[
          const ClientsTab(),
        ] else if (_subTab == 1) ...[
          const ItemsCatalogTab(),
        ] else if (_subTab == 2) ...[
          _BusinessProfileSettingsCard(),
        ] else ...[
          _BackupRecoveryCard(),
        ],
      ],
    );
  }
}

class _BackupRecoveryCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final importController = TextEditingController();

    void handleExport() {
      try {
        final jsonStr = BackupService.exportToJsonString(db);
        Clipboard.setData(ClipboardData(text: jsonStr));
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Database Backup Exported'),
            content: SizedBox(
              width: 500,
              height: 300,
              child: Column(
                children: [
                  const Text('Your complete SQLite database has been exported to JSON and copied to your clipboard! You can paste it into a file to store safely.'),
                  const SizedBox(height: 12),
                  Expanded(
                    child: TextField(
                      controller: TextEditingController(text: jsonStr),
                      maxLines: null,
                      readOnly: true,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting database: $e')),
        );
      }
    }

    void handleImportModal() {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Restore Database from JSON'),
          content: SizedBox(
            width: 500,
            height: 300,
            child: Column(
              children: [
                const Text('Paste your previously exported database JSON payload below to restore all records atomically.'),
                const SizedBox(height: 12),
                Expanded(
                  child: TextField(
                    controller: importController,
                    maxLines: null,
                    decoration: const InputDecoration(
                      hintText: 'Paste backup JSON here...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                try {
                  BackupService.importFromJsonString(db, importController.text.trim());
                  ref.invalidate(invoicesProvider);
                  ref.invalidate(estimatesProvider);
                  ref.invalidate(expensesProvider);
                  ref.invalidate(businessProfileProvider);

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Database successfully restored from backup!')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error restoring backup: $e')),
                  );
                }
              },
              child: const Text('Restore & Overwrite'),
            ),
          ],
        ),
      );
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
                        'Disaster Recovery & SQLite Backup',
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
              label: const Text('Export JSON Backup (Copy to Clipboard)'),
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
              onPressed: handleImportModal,
              icon: const Icon(Icons.upload_outlined, size: 16),
              label: const Text('Restore Database from JSON'),
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
            Row(
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
                FilledButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => const BusinessProfileDialog(),
                    );
                  },
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit Profile & Branding'),
                ),
              ],
            ),
            const Divider(height: 32),
            const Text('Configured Business Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            _infoRow(context, 'Currency Symbol', profile.currencySymbol),
            _infoRow(context, 'Phone', profile.phone.isNotEmpty ? profile.phone : 'Not specified'),
            _infoRow(context, 'Address', profile.address.isNotEmpty ? profile.address : 'Not specified'),
            _infoRow(context, 'Tax ID / EIN / VAT', profile.taxId.isNotEmpty ? profile.taxId : 'Not specified'),
            _infoRow(context, 'Default Payment Terms', profile.defaultTerms),
            _infoRow(context, 'Company Logo / QR Payload', profile.logoBase64.isNotEmpty ? 'Configured' : 'Not configured'),
            _infoRow(context, 'Digital Signature', profile.signatureBase64.isNotEmpty ? '${profile.signatureLabel} (${profile.signatureBase64})' : 'Not configured'),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 200,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.grey)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
