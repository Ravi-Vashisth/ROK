import 'package:flutter/material.dart';

class MoreTab extends StatelessWidget {
  final VoidCallback onNavigateToClients;
  final VoidCallback onNavigateToCatalog;
  final VoidCallback onNavigateToReports;
  final VoidCallback onNavigateToSettings;
  final VoidCallback onNavigateToBackup;

  const MoreTab({
    super.key,
    required this.onNavigateToClients,
    required this.onNavigateToCatalog,
    required this.onNavigateToReports,
    required this.onNavigateToSettings,
    required this.onNavigateToBackup,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        ListTile(
          leading: const CircleAvatar(
            backgroundColor: Color(0xFFEEF2FF),
            child: Icon(Icons.people_alt_outlined, color: Colors.indigo, size: 20),
          ),
          title: const Text('Clients & Account Dossiers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          subtitle: const Text('CRM directory, contact records, and statements of account', style: TextStyle(fontSize: 11)),
          trailing: const Icon(Icons.chevron_right, size: 18),
          onTap: onNavigateToClients,
        ),
        const Divider(),
        ListTile(
          leading: const CircleAvatar(
            backgroundColor: Color(0xFFEFF6FF),
            child: Icon(Icons.inventory_2_outlined, color: Colors.blue, size: 20),
          ),
          title: const Text('Items & Services Catalog', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          subtitle: const Text('Preset rates, SAC/HSN codes, and service packages', style: TextStyle(fontSize: 11)),
          trailing: const Icon(Icons.chevron_right, size: 18),
          onTap: onNavigateToCatalog,
        ),
        const Divider(),
        ListTile(
          leading: const CircleAvatar(
            backgroundColor: Color(0xFFECFDF5),
            child: Icon(Icons.table_chart_outlined, color: Color(0xFF10B981), size: 20),
          ),
          title: const Text('Reports & Export CSV', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          subtitle: const Text('Single-table accountant CSV export for Invoices and Expenses', style: TextStyle(fontSize: 11)),
          trailing: const Icon(Icons.chevron_right, size: 18),
          onTap: onNavigateToReports,
        ),
        const Divider(),
        ListTile(
          leading: const CircleAvatar(
            backgroundColor: Color(0xFFF5F3FF),
            child: Icon(Icons.settings_outlined, color: Colors.purple, size: 20),
          ),
          title: const Text('Business Settings & Branding', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          subtitle: const Text('Legal name, address, tax ID, logo, and digital signature', style: TextStyle(fontSize: 11)),
          trailing: const Icon(Icons.chevron_right, size: 18),
          onTap: onNavigateToSettings,
        ),
        const Divider(),
        ListTile(
          leading: const CircleAvatar(
            backgroundColor: Color(0xFFFEF3C7),
            child: Icon(Icons.security, color: Colors.amber, size: 20),
          ),
          title: const Text('Data Backup & Recovery', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          subtitle: const Text('Export or restore JSON database snapshots', style: TextStyle(fontSize: 11)),
          trailing: const Icon(Icons.chevron_right, size: 18),
          onTap: onNavigateToBackup,
        ),
      ],
    );
  }
}
