import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:billing_app/core/utils/money_utils.dart';
import 'package:billing_app/core/utils/telephony_utils.dart';
import 'package:billing_app/features/business_profile/providers/business_profile_provider.dart';
import 'package:billing_app/features/invoices/providers/invoices_provider.dart';
import 'package:billing_app/features/clients/models/client.dart';
import 'package:billing_app/features/clients/providers/clients_provider.dart';
import 'package:billing_app/features/clients/presentation/client_statement_dialog.dart';

class ClientsTab extends ConsumerStatefulWidget {
  const ClientsTab({super.key});

  @override
  ConsumerState<ClientsTab> createState() => _ClientsTabState();
}

class _ClientsTabState extends ConsumerState<ClientsTab> {
  String? _selectedClientId;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _launchClientIntent({
    required Uri? uri,
    required String actionLabel,
    required String fallbackCopyValue,
  }) async {
    if (uri == null) return;
    final messenger = ScaffoldMessenger.of(context);
    bool launched = false;
    try {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      launched = false;
    }
    if (!mounted) return;
    if (!launched && fallbackCopyValue.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: fallbackCopyValue));
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('No $actionLabel app available. Copied "$fallbackCopyValue" to clipboard.'),
        ),
      );
    }
  }

  void _showAddClientDialog() {
    showDialog(
      context: context,
      builder: (_) => const _ClientFormDialog(),
    );
  }

  void _showEditClientDialog(Client client) {
    showDialog(
      context: context,
      builder: (_) => _ClientFormDialog(initialClient: client),
    );
  }

  void _handleDeleteClient(Client client) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Client'),
        content: Text('Are you sure you want to delete client "${client.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              final deleted = ref.read(clientsProvider.notifier).deleteClient(client.id);
              if (!deleted) {
                showDialog(
                  context: context,
                  builder: (warnCtx) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    title: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.amber),
                        SizedBox(width: 8),
                        Expanded(child: Text('Cannot Delete Client')),
                      ],
                    ),
                    content: Text(
                      'Cannot delete "${client.name}" because existing invoices are attached to this client. Please void or settle all invoices first.',
                    ),
                    actions: [
                      FilledButton(onPressed: () => Navigator.pop(warnCtx), child: const Text('OK')),
                    ],
                  ),
                );
              } else {
                setState(() => _selectedClientId = null);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Client "${client.name}" deleted.')),
                );
              }
            },
            child: const Text('Delete Client'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clients = ref.watch(clientsProvider);
    final constraints = MediaQuery.of(context).size;
    final isWide = constraints.width >= 900;

    final filteredClients = clients.where((c) {
      if (_searchController.text.isEmpty) return true;
      final q = _searchController.text.toLowerCase();
      return c.name.toLowerCase().contains(q) || c.email.toLowerCase().contains(q);
    }).toList();

    if (_selectedClientId == null && clients.isNotEmpty) {
      _selectedClientId = clients.first.id;
    }

    if (!isWide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildClientListHeader(),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Search clients...',
              prefixIcon: Icon(Icons.search, size: 18),
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          _buildClientListView(filteredClients, (id) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: const Text('Client Dossier')),
                  body: SafeArea(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: _buildDetailPane(id),
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildClientListHeader(),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'Search clients...',
                          prefixIcon: Icon(Icons.search, size: 18),
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 10),
                      _buildClientListView(filteredClients, (id) => setState(() => _selectedClientId = id)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 7,
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: _buildDetailPane(_selectedClientId),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildClientListHeader() {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Client CRM & Statements',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Text(
              'Directory of accounts, billing history, and statements of account',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        FilledButton.icon(
          icon: const Icon(Icons.add, size: 16),
          label: const Text('+ Add Client'),
          onPressed: _showAddClientDialog,
        ),
      ],
    );
  }

  Widget _buildClientListView(List<Client> clients, Function(String) onSelect) {
    if (clients.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24.0),
        child: Center(child: Text('No clients found.', style: TextStyle(color: Colors.grey))),
      );
    }

    final invoices = ref.watch(invoicesProvider);
    final profile = ref.watch(businessProfileProvider);

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: clients.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final c = clients[i];
        final isSelected = _selectedClientId == c.id;
        final clientInvoices = invoices.where((inv) => inv.clientId == c.id && !inv.isVoid && !inv.isDraft);
        final rollup = computeClientRollup(
          clientInvoices.map((inv) => CurrencyLedgerEntry(
                currencyCode: inv.currencyCode,
                currencySymbol: inv.currencySymbol,
                currencyDecimals: inv.currencyDecimals,
                totalUnits: inv.totalCents,
                paidUnits: inv.paidCents,
                balanceDueUnits: inv.balanceDueCents,
              )),
          defaultCode: profile.currencyCode,
          defaultSymbol: profile.currencySymbol,
          defaultDecimals: profile.currencyDecimals,
        );
        final hasDue = rollup.hasOutstandingBalance;

        return ListTile(
          selected: isSelected,
          selectedTileColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          subtitle: Text(c.email.isNotEmpty ? c.email : (c.phone.isNotEmpty ? c.phone : 'No contact info'), style: const TextStyle(fontSize: 11)),
          trailing: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 132),
            child: Text(
              hasDue ? '${rollup.formattedOutstandingBalance} Due' : '✓ Settled',
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: hasDue ? Colors.amber.shade900 : Colors.green.shade700,
              ),
            ),
          ),
          onTap: () => onSelect(c.id),
        );
      },
    );
  }

  Widget _buildDetailPane(String? id) {
    if (id == null) {
      return const Center(child: Text('Select a client to view their account dossier.'));
    }

    final clients = ref.watch(clientsProvider);
    final client = clients.firstWhere(
      (c) => c.id == id,
      orElse: () => Client(id: '', name: 'Client Not Found', createdAt: ''),
    );

    if (client.id.isEmpty) {
      return const Center(child: Text('Client not found.'));
    }

    final allClientInvoices = ref.watch(invoicesProvider).where((i) => i.clientId == client.id).toList();
    final activeInvoices = allClientInvoices.where((i) => !i.isVoid && !i.isDraft).toList();
    final profile = ref.watch(businessProfileProvider);

    final rollup = computeClientRollup(
      activeInvoices.map((inv) => CurrencyLedgerEntry(
            currencyCode: inv.currencyCode,
            currencySymbol: inv.currencySymbol,
            currencyDecimals: inv.currencyDecimals,
            totalUnits: inv.totalCents,
            paidUnits: inv.paidCents,
            balanceDueUnits: inv.balanceDueCents,
          )),
      defaultCode: profile.currencyCode,
      defaultSymbol: profile.currencySymbol,
      defaultDecimals: profile.currencyDecimals,
    );
    final hasDue = rollup.hasOutstandingBalance;

    String formatInvMoney(int units, String code, String symbol, int decimals) {
      final resolved = resolveEffectiveCurrency(
        recordCode: code,
        recordSymbol: symbol,
        recordDecimals: code.trim().isNotEmpty ? decimals : null,
        defaultCode: profile.currencyCode,
        defaultSymbol: profile.currencySymbol,
        defaultDecimals: profile.currencyDecimals,
      );
      return formatMoney(units, symbol: resolved.symbol, decimals: resolved.decimals);
    }

    final metricCards = [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Lifetime Billed', style: TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                rollup.formattedTotalBilled,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFeatures: [FontFeature.tabularFigures()]),
              ),
            ),
          ],
        ),
      ),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.shade50.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Total Collected', style: TextStyle(fontSize: 11, color: Colors.green)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                rollup.formattedTotalPaid,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFeatures: const [FontFeature.tabularFigures()], color: Colors.green.shade800),
              ),
            ),
          ],
        ),
      ),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: hasDue ? Colors.amber.shade50.withValues(alpha: 0.4) : Colors.green.shade50.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: hasDue ? Colors.amber.shade300 : Colors.green.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Outstanding Balance', style: TextStyle(fontSize: 11, color: hasDue ? Colors.amber.shade900 : Colors.green)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                rollup.formattedOutstandingBalance,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: hasDue ? Colors.amber.shade900 : Colors.green.shade800,
                ),
              ),
            ),
          ],
        ),
      ),
    ];

    final isCompactScreen = MediaQuery.sizeOf(context).width < 600;
    final tabViewHeight = (MediaQuery.sizeOf(context).height * 0.48).clamp(320.0, 480.0);

    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Client Header
          LayoutBuilder(
            builder: (context, constraints) {
              final infoCol = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(client.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    '${client.email.isNotEmpty ? client.email : "No Email"} • ${client.phone.isNotEmpty ? client.phone : "No Phone"} • Tax ID: ${client.taxId.isNotEmpty ? client.taxId : "None"}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  if (client.address.isNotEmpty)
                    Text(client.address, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              );
              final actionsRow = Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.edit_outlined, size: 14),
                    label: const Text('Edit Client', style: TextStyle(fontSize: 12)),
                    onPressed: () => _showEditClientDialog(client),
                  ),
                  IconButton(
                    tooltip: 'Delete Client',
                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                    onPressed: () => _handleDeleteClient(client),
                  ),
                ],
              );
              if (constraints.maxWidth < 520) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    infoCol,
                    const SizedBox(height: 10),
                    actionsRow,
                  ],
                );
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: infoCol),
                  const SizedBox(width: 12),
                  actionsRow,
                ],
              );
            },
          ),
          if (client.phone.trim().isNotEmpty || client.email.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (buildTelUri(client.phone) != null)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.call_outlined, size: 14),
                    label: const Text('Call', style: TextStyle(fontSize: 12)),
                    onPressed: () => _launchClientIntent(
                      uri: buildTelUri(client.phone),
                      actionLabel: 'phone dialer',
                      fallbackCopyValue: normalizePhoneForUri(client.phone),
                    ),
                  ),
                if (buildSmsUri(
                      phone: client.phone,
                      isIos: Theme.of(context).platform == TargetPlatform.iOS,
                    ) !=
                    null)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.sms_outlined, size: 14),
                    label: const Text('SMS', style: TextStyle(fontSize: 12)),
                    onPressed: () => _launchClientIntent(
                      uri: buildSmsUri(
                        phone: client.phone,
                        isIos: Theme.of(context).platform == TargetPlatform.iOS,
                      ),
                      actionLabel: 'SMS',
                      fallbackCopyValue: normalizePhoneForUri(client.phone),
                    ),
                  ),
                if (client.email.trim().isNotEmpty)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.email_outlined, size: 14),
                    label: const Text('Email', style: TextStyle(fontSize: 12)),
                    onPressed: () => _launchClientIntent(
                      uri: buildMailtoUri(
                        email: client.email,
                        subject: 'Regarding your account with us',
                        body: 'Hi ${client.name},\n\n',
                      ),
                      actionLabel: 'email',
                      fallbackCopyValue: client.email.trim(),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),

          // 3 Financial Metric Cards
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 560) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    metricCards[0],
                    const SizedBox(height: 10),
                    metricCards[1],
                    const SizedBox(height: 10),
                    metricCards[2],
                  ],
                );
              }
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: metricCards[0]),
                    const SizedBox(width: 10),
                    Expanded(child: metricCards[1]),
                    const SizedBox(width: 10),
                    Expanded(child: metricCards[2]),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Sub-tabs: Invoices, Statements, Notes
          TabBar(
            isScrollable: isCompactScreen,
            tabAlignment: isCompactScreen ? TabAlignment.start : TabAlignment.fill,
            tabs: const [
              Tab(text: 'Invoices & Billing'),
              Tab(text: 'Statement of Account'),
              Tab(text: 'Internal Notes'),
            ],
          ),
          const SizedBox(height: 12),

          SizedBox(
            height: tabViewHeight,
            child: TabBarView(
              children: [
                // Invoices List (Finalized/Issued Invoices only - No Drafts)
                (() {
                  final nonDraftInvoices = allClientInvoices.where((i) => !i.isDraft).toList();
                  if (nonDraftInvoices.isEmpty) {
                    return const Center(child: Text('No finalized invoices issued to this client yet.', style: TextStyle(color: Colors.grey)));
                  }
                  return ListView.separated(
                    itemCount: nonDraftInvoices.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final inv = nonDraftInvoices[i];
                      final isVoid = inv.isVoid;
                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isVoid
                                ? Colors.grey.shade100
                                : (inv.isFullyPaid ? Colors.green.shade50 : Colors.amber.shade50),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isVoid
                                  ? Colors.grey.shade400
                                  : (inv.isFullyPaid ? Colors.green.shade300 : Colors.amber.shade300),
                            ),
                          ),
                          child: Text(
                            isVoid ? 'VOID' : inv.invoiceNumber,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isVoid
                                  ? Colors.grey.shade800
                                  : (inv.isFullyPaid ? Colors.green.shade800 : Colors.amber.shade900),
                            ),
                          ),
                        ),
                        title: Text(
                          isVoid ? '${inv.invoiceNumber} (VOID)' : inv.issueDate,
                          style: TextStyle(
                            fontSize: 12,
                            decoration: isVoid ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        subtitle: Text('Terms: ${inv.paymentTerms} • Due: ${inv.dueDate}', style: const TextStyle(fontSize: 11)),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              formatInvMoney(
                                inv.totalCents,
                                inv.currencyCode,
                                inv.currencySymbol,
                                inv.currencyDecimals,
                              ),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFeatures: [FontFeature.tabularFigures()]),
                            ),
                            Text(
                              isVoid
                                  ? 'Voided'
                                  : (inv.balanceDueCents > 0
                                      ? 'Bal: ${formatInvMoney(inv.balanceDueCents, inv.currencyCode, inv.currencySymbol, inv.currencyDecimals)}'
                                      : '✓ Paid'),
                              style: TextStyle(
                                fontSize: 11,
                                fontFeatures: const [FontFeature.tabularFigures()],
                                color: isVoid
                                    ? Colors.grey.shade600
                                    : (inv.balanceDueCents > 0 ? Colors.red.shade700 : Colors.green.shade700),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                })(),

                // Statement of Account View (Excludes Drafts and Voided)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          const Text('Itemized Account Ledger', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          FilledButton.tonalIcon(
                            icon: const Icon(Icons.picture_as_pdf, size: 15),
                            label: const Text('Download Statement PDF', style: TextStyle(fontSize: 12)),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (_) => ClientStatementDialog(client: client),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: activeInvoices.isEmpty
                          ? const Center(child: Text('No active transactions to show.', style: TextStyle(color: Colors.grey)))
                          : ListView.separated(
                              itemCount: activeInvoices.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, i) {
                                final inv = activeInvoices[i];
                                return ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.receipt_long, size: 18),
                                  title: Text('Invoice ${inv.invoiceNumber}'),
                                  subtitle: Text(inv.issueDate),
                                  trailing: Text(
                                    formatInvMoney(
                                      inv.totalCents,
                                      inv.currencyCode,
                                      inv.currencySymbol,
                                      inv.currencyDecimals,
                                    ),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontFeatures: [FontFeature.tabularFigures()]),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),

                // Client Notes
                SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Client Account Terms & Internal Notes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 8),
                      Text(
                        'Client ID: ${client.id}\nCreated: ${client.createdAt}\nAddress: ${client.address.isNotEmpty ? client.address : "Not provided"}\nTax ID: ${client.taxId.isNotEmpty ? client.taxId : "Not provided"}',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.6,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClientFormDialog extends ConsumerStatefulWidget {
  final Client? initialClient;

  const _ClientFormDialog({this.initialClient});

  @override
  ConsumerState<_ClientFormDialog> createState() => _ClientFormDialogState();
}

class _ClientFormDialogState extends ConsumerState<_ClientFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _taxIdController;

  @override
  void initState() {
    super.initState();
    final c = widget.initialClient;
    _nameController = TextEditingController(text: c?.name ?? '');
    _emailController = TextEditingController(text: c?.email ?? '');
    _phoneController = TextEditingController(text: c?.phone ?? '');
    _addressController = TextEditingController(text: c?.address ?? '');
    _taxIdController = TextEditingController(text: c?.taxId ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _taxIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initialClient != null;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(isEdit ? 'Edit Client Details' : 'Add New Client'),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 440,
          maxHeight: MediaQuery.sizeOf(context).height * 0.78,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: isEdit ? 'Client Name *' : 'Client / Company Name *',
                  ),
                  validator: (val) =>
                      val == null || val.trim().isEmpty ? 'Please enter a name' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Billing Email'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone Number'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Billing Address'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _taxIdController,
                  decoration: const InputDecoration(labelText: 'GSTIN / Tax ID'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            final notifier = ref.read(clientsProvider.notifier);
            if (isEdit) {
              notifier.updateClient(
                id: widget.initialClient!.id,
                name: _nameController.text.trim(),
                email: _emailController.text.trim(),
                phone: _phoneController.text.trim(),
                address: _addressController.text.trim(),
                taxId: _taxIdController.text.trim(),
              );
            } else {
              notifier.addClient(
                name: _nameController.text.trim(),
                email: _emailController.text.trim(),
                phone: _phoneController.text.trim(),
                address: _addressController.text.trim(),
                taxId: _taxIdController.text.trim(),
              );
            }
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(isEdit ? 'Client details updated!' : 'Client added successfully!'),
              ),
            );
          },
          child: Text(isEdit ? 'Save Changes' : 'Save Client'),
        ),
      ],
    );
  }
}

