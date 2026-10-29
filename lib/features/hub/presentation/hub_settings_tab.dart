import 'package:flutter/material.dart';
import '../../clients/presentation/clients_tab.dart';
import '../../items/presentation/items_catalog_tab.dart';
import '../../settings/presentation/directory_settings_tab.dart';

class HubSettingsTab extends StatefulWidget {
  const HubSettingsTab({super.key});

  @override
  State<HubSettingsTab> createState() => _HubSettingsTabState();
}

class _HubSettingsTabState extends State<HubSettingsTab> {
  int _subTab = 0; // 0=Clients, 1=Catalog, 2=Settings

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Hub & Settings',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Clients')),
                ButtonSegment(value: 1, label: Text('Catalog')),
                ButtonSegment(value: 2, label: Text('Settings')),
              ],
              selected: {_subTab},
              onSelectionChanged: (newSelection) {
                setState(() => _subTab = newSelection.first);
              },
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (_subTab == 0)
          const ClientsTab()
        else if (_subTab == 1)
          const ItemsCatalogTab()
        else
          const DirectorySettingsTab(),
      ],
    );
  }
}
