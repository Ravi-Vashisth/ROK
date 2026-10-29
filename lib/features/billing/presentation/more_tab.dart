import 'package:flutter/material.dart';

class MoreTab extends StatelessWidget {
  final VoidCallback onNavigateToClients;
  final VoidCallback onNavigateToCatalog;
  final VoidCallback onNavigateToReports;
  final VoidCallback onNavigateToSettings;

  const MoreTab({
    super.key,
    required this.onNavigateToClients,
    required this.onNavigateToCatalog,
    required this.onNavigateToReports,
    required this.onNavigateToSettings,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.people_alt_outlined),
          title: const Text('Clients & Statements'),
          onTap: onNavigateToClients,
        ),
        ListTile(
          leading: const Icon(Icons.inventory_2_outlined),
          title: const Text('Items & Services Catalog'),
          onTap: onNavigateToCatalog,
        ),
        ListTile(
          leading: const Icon(Icons.trending_up_outlined),
          title: const Text('Reports & Export CSV'),
          onTap: onNavigateToReports,
        ),
        ListTile(
          leading: const Icon(Icons.settings_outlined),
          title: const Text('Profile, Branding & Settings'),
          onTap: onNavigateToSettings,
        ),
      ],
    );
  }
}
