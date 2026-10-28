import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../clients/presentation/clients_tab.dart';
import '../../items/presentation/items_catalog_tab.dart';
import '../../business_profile/presentation/business_profile_dialog.dart';
import '../../business_profile/providers/business_profile_provider.dart';

class DirectorySettingsTab extends ConsumerStatefulWidget {
  const DirectorySettingsTab({super.key});

  @override
  ConsumerState<DirectorySettingsTab> createState() => _DirectorySettingsTabState();
}

class _DirectorySettingsTabState extends ConsumerState<DirectorySettingsTab> {
  int _subTab = 0; // 0 = Clients, 1 = Items Catalog, 2 = Business & Branding Settings

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Directory & Business Settings',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ToggleButtons(
                isSelected: [_subTab == 0, _subTab == 1, _subTab == 2],
                onPressed: (index) {
                  setState(() => _subTab = index);
                },
                borderRadius: BorderRadius.circular(8),
                constraints: const BoxConstraints(minHeight: 36, minWidth: 90),
                children: const [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        Icon(Icons.people_outline, size: 16),
                        SizedBox(width: 4),
                        Text('Clients', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 16),
                        SizedBox(width: 4),
                        Text('Catalog', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        Icon(Icons.business_outlined, size: 16),
                        SizedBox(width: 4),
                        Text('Branding & Prefs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
        ] else ...[
          _BusinessProfileSettingsCard(),
        ],
      ],
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
