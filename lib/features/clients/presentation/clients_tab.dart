import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:billing_app/core/theme/app_theme.dart';
import 'package:billing_app/core/utils/money_utils.dart';
import 'package:billing_app/core/utils/telephony_utils.dart';
import 'package:billing_app/features/business_profile/models/business_profile.dart';
import 'package:billing_app/features/business_profile/providers/business_profile_provider.dart';
import 'package:billing_app/features/invoices/models/invoice_record.dart';
import 'package:billing_app/features/invoices/providers/invoices_provider.dart';
import 'package:billing_app/features/clients/models/client.dart';
import 'package:billing_app/features/clients/providers/clients_provider.dart';
import 'package:billing_app/features/clients/presentation/client_statement_dialog.dart';

class ClientsTab extends ConsumerStatefulWidget {
  final List<Widget> leadingSlivers;
  const ClientsTab({super.key, this.leadingSlivers = const []});

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
    Uri? fallbackUri,
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
    if (!launched && fallbackUri != null) {
      try {
        launched = await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
      } catch (_) {
        launched = false;
      }
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
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              final deleted = ref.read(clientsProvider.notifier).deleteClient(client.id);
              if (!deleted) {
                showDialog(
                  context: context,
                  builder: (warnCtx) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    title: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: AppSemanticColors.resolve(Theme.of(warnCtx).brightness, SemanticStatus.warning).icon,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(child: Text('Cannot Delete Client')),
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
    final invoices = ref.watch(invoicesProvider);
    final profile = ref.watch(businessProfileProvider);
    final constraints = MediaQuery.of(context).size;
    final isWide = constraints.width >= 900;

    final invoicesByClient = <String, List<InvoiceRecord>>{};
    for (final inv in invoices) {
      if (!inv.isVoid && !inv.isDraft) {
        (invoicesByClient[inv.clientId] ??= []).add(inv);
      }
    }

    final filteredClients = clients.where((c) {
      if (_searchController.text.isEmpty) return true;
      final q = _searchController.text.toLowerCase();
      return c.name.toLowerCase().contains(q) || c.email.toLowerCase().contains(q);
    }).toList();

    if (_selectedClientId == null && clients.isNotEmpty) {
      _selectedClientId = clients.first.id;
    }

    final pagePadding = isWide ? 24.0 : 16.0;

    if (!isWide) {
      return CustomScrollView(
        slivers: [
          ...widget.leadingSlivers,
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: pagePadding),
            sliver: SliverToBoxAdapter(
              child: Column(
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
                ],
              ),
            ),
          ),
          if (filteredClients.isEmpty)
            SliverPadding(
              padding: EdgeInsets.fromLTRB(pagePadding, 0, pagePadding, pagePadding),
              sliver: SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: Text(
                      'No clients found.',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(pagePadding, 0, pagePadding, pagePadding),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final client = filteredClients[index];
                    final isLast = index == filteredClients.length - 1;
                    return Card(
                      elevation: 0,
                      margin: EdgeInsets.only(bottom: isLast ? 0 : 8),
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: Theme.of(context).dividerColor),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _buildClientListTile(
                        client,
                        invoicesByClient[client.id] ?? const [],
                        profile,
                        (id) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => Scaffold(
                                appBar: AppBar(title: const Text('Client Dossier')),
                                body: SafeArea(
                                  child: _ClientDossierView(
                                    clientId: id,
                                    pagePadding: 16,
                                    onEditClient: _showEditClientDialog,
                                    onDeleteClient: _handleDeleteClient,
                                    onLaunchIntent: _launchClientIntent,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                  childCount: filteredClients.length,
                ),
              ),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildClientListHeader(),
        const SizedBox(height: 16),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                        Expanded(
                          child: _buildClientListView(
                            filteredClients,
                            invoicesByClient,
                            profile,
                            (id) => setState(() => _selectedClientId = id),
                          ),
                        ),
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
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _ClientDossierView(
                      clientId: _selectedClientId,
                      pagePadding: 20,
                      onEditClient: _showEditClientDialog,
                      onDeleteClient: _handleDeleteClient,
                      onLaunchIntent: _launchClientIntent,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildClientListHeader() {
    final theme = Theme.of(context);
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
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              'Directory of accounts, billing history, and statements of account',
              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
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

  Widget _buildClientListTile(
    Client c,
    List<InvoiceRecord> clientInvoices,
    BusinessProfile profile,
    Function(String) onSelect,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final brightness = theme.brightness;
    final warningTone = AppSemanticColors.resolve(brightness, SemanticStatus.warning);
    final successTone = AppSemanticColors.resolve(brightness, SemanticStatus.success);

    final isSelected = _selectedClientId == c.id;
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

    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final secondaryTextColor = theme.textTheme.bodySmall?.color ?? colorScheme.onSurfaceVariant;
    final contactLabel = c.email.isNotEmpty ? c.email : (c.phone.isNotEmpty ? c.phone : 'No contact info');
    final dueLabel = hasDue ? '${rollup.formattedOutstandingBalance} Due' : '✓ Settled';
    final dueStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.bold,
      fontFeatures: const [FontFeature.tabularFigures()],
      color: hasDue ? warningTone.text : successTone.text,
    );

    return LayoutBuilder(
      builder: (context, rowConstraints) {
        final stackBalanceBelow = rowConstraints.maxWidth < 360 || textScale > 1.3;
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onSelect(c.id),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? colorScheme.primaryContainer.withValues(alpha: 0.35) : null,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: stackBalanceBelow ? CrossAxisAlignment.start : CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(contactLabel, style: TextStyle(fontSize: 11, color: secondaryTextColor)),
                      if (stackBalanceBelow) ...[
                        const SizedBox(height: 4),
                        Text(dueLabel, style: dueStyle),
                      ],
                    ],
                  ),
                ),
                if (!stackBalanceBelow) ...[
                  const SizedBox(width: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 132),
                    child: Text(
                      dueLabel,
                      textAlign: TextAlign.right,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: dueStyle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildClientListView(
    List<Client> clients,
    Map<String, List<InvoiceRecord>> invoicesByClient,
    BusinessProfile profile,
    Function(String) onSelect,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    if (clients.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(child: Text('No clients found.', style: TextStyle(color: colorScheme.onSurfaceVariant))),
      );
    }

    return ListView.separated(
      itemCount: clients.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final client = clients[i];
        return _buildClientListTile(
          client,
          invoicesByClient[client.id] ?? const [],
          profile,
          onSelect,
        );
      },
    );
  }

}

class _ClientDossierView extends ConsumerStatefulWidget {
  final String? clientId;
  final double pagePadding;
  final void Function(Client client) onEditClient;
  final void Function(Client client) onDeleteClient;
  final Future<void> Function({
    required Uri? uri,
    Uri? fallbackUri,
    required String actionLabel,
    required String fallbackCopyValue,
  }) onLaunchIntent;

  const _ClientDossierView({
    required this.clientId,
    required this.pagePadding,
    required this.onEditClient,
    required this.onDeleteClient,
    required this.onLaunchIntent,
  });

  @override
  ConsumerState<_ClientDossierView> createState() => _ClientDossierViewState();
}

class _ClientDossierViewState extends ConsumerState<_ClientDossierView> {
  int _activeSubTab = 0;

  @override
  void didUpdateWidget(covariant _ClientDossierView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clientId != widget.clientId) {
      _activeSubTab = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.clientId;
    if (id == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Select a client to view their account dossier.'),
        ),
      );
    }

    final clients = ref.watch(clientsProvider);
    final client = clients.firstWhere(
      (c) => c.id == id,
      orElse: () => const Client(id: '', name: 'Client Not Found', createdAt: ''),
    );

    if (client.id.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Client not found.'),
        ),
      );
    }

    final allClientInvoices = ref.watch(invoicesProvider).where((i) => i.clientId == client.id).toList();
    final nonDraftInvoices = allClientInvoices.where((i) => !i.isDraft).toList();
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

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final brightness = theme.brightness;
    final successTone = AppSemanticColors.resolve(brightness, SemanticStatus.success);
    final warningTone = AppSemanticColors.resolve(brightness, SemanticStatus.warning);
    final dangerTone = AppSemanticColors.resolve(brightness, SemanticStatus.danger);
    final neutralTone = AppSemanticColors.resolve(brightness, SemanticStatus.neutral);
    final secondaryTextColor = theme.textTheme.bodySmall?.color ?? colorScheme.onSurfaceVariant;
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final pad = widget.pagePadding;

    final metricCards = [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Lifetime Billed', style: TextStyle(fontSize: 11, color: secondaryTextColor)),
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
          color: successTone.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: successTone.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total Collected', style: TextStyle(fontSize: 11, color: successTone.text)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                rollup.formattedTotalPaid,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFeatures: const [FontFeature.tabularFigures()], color: successTone.text),
              ),
            ),
          ],
        ),
      ),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: hasDue ? warningTone.background : successTone.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: hasDue ? warningTone.border : successTone.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Outstanding Balance', style: TextStyle(fontSize: 11, color: hasDue ? warningTone.text : successTone.text)),
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
                  color: hasDue ? warningTone.text : successTone.text,
                ),
              ),
            ),
          ],
        ),
      ),
    ];

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(pad, pad, pad, 12),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Client Header
                LayoutBuilder(
                  builder: (context, constraints) {
                    final infoCol = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(client.name, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                          '${client.email.isNotEmpty ? client.email : "No Email"} • ${client.phone.isNotEmpty ? client.phone : "No Phone"} • Tax ID: ${client.taxId.isNotEmpty ? client.taxId : "None"}',
                          style: TextStyle(fontSize: 12, color: secondaryTextColor),
                        ),
                        if (client.address.isNotEmpty)
                          Text(client.address, style: TextStyle(fontSize: 11, color: secondaryTextColor)),
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
                          onPressed: () => widget.onEditClient(client),
                        ),
                        IconButton(
                          tooltip: 'Delete Client',
                          icon: Icon(Icons.delete_outline, size: 18, color: colorScheme.error),
                          onPressed: () => widget.onDeleteClient(client),
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
                          onPressed: () => widget.onLaunchIntent(
                            uri: buildTelUri(client.phone),
                            actionLabel: 'phone dialer',
                            fallbackCopyValue: normalizePhoneForUri(client.phone),
                          ),
                        ),
                      if (buildSmsUri(
                            phone: client.phone,
                            isIos: theme.platform == TargetPlatform.iOS ||
                                theme.platform == TargetPlatform.macOS,
                          ) !=
                          null)
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.sms_outlined, size: 14),
                          label: const Text('SMS', style: TextStyle(fontSize: 12)),
                          onPressed: () => widget.onLaunchIntent(
                            uri: buildSmsUri(
                              phone: client.phone,
                              isIos: theme.platform == TargetPlatform.iOS ||
                                  theme.platform == TargetPlatform.macOS,
                            ),
                            fallbackUri: buildSmsFallbackUri(phone: client.phone),
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
                          onPressed: () => widget.onLaunchIntent(
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

                // Sub-tabs: Invoices & Billing, Statement of Account, Internal Notes
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ToggleButtons(
                    isSelected: [_activeSubTab == 0, _activeSubTab == 1, _activeSubTab == 2],
                    onPressed: (idx) => setState(() => _activeSubTab = idx),
                    borderRadius: BorderRadius.circular(12),
                    constraints: const BoxConstraints(minHeight: 38, minWidth: 112),
                    children: const [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('Invoices & Billing', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('Statement of Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('Internal Notes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        if (_activeSubTab == 0) ...[
          if (nonDraftInvoices.isEmpty)
            SliverPadding(
              padding: EdgeInsets.fromLTRB(pad, 12, pad, pad),
              sliver: SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No finalized invoices issued to this client yet.',
                      style: TextStyle(color: secondaryTextColor),
                    ),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(pad, 0, pad, pad),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final inv = nonDraftInvoices[i];
                    final isVoid = inv.isVoid;
                    final isLast = i == nonDraftInvoices.length - 1;
                    final badgeTone = isVoid
                        ? neutralTone
                        : (inv.isFullyPaid ? successTone : warningTone);
                    final badge = Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeTone.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: badgeTone.border),
                      ),
                      child: Text(
                        isVoid ? 'VOID' : inv.invoiceNumber,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: badgeTone.text,
                        ),
                      ),
                    );
                    final titleInfo = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isVoid ? '${inv.invoiceNumber} (VOID)' : inv.issueDate,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            decoration: isVoid ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Terms: ${inv.paymentTerms} • Due: ${inv.dueDate}',
                          style: TextStyle(fontSize: 11, color: secondaryTextColor),
                        ),
                      ],
                    );

                    return Column(
                      children: [
                        LayoutBuilder(
                          builder: (context, rowConstraints) {
                            final stackAmounts = rowConstraints.maxWidth < 420 || textScale > 1.3;
                            final amountCol = Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: stackAmounts ? CrossAxisAlignment.start : CrossAxisAlignment.end,
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
                                        ? secondaryTextColor
                                        : (inv.balanceDueCents > 0 ? dangerTone.text : successTone.text),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            );
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: stackAmounts
                                  ? Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 6,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          children: [badge, titleInfo],
                                        ),
                                        const SizedBox(height: 6),
                                        amountCol,
                                      ],
                                    )
                                  : Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        badge,
                                        const SizedBox(width: 12),
                                        Expanded(child: titleInfo),
                                        const SizedBox(width: 12),
                                        amountCol,
                                      ],
                                    ),
                            );
                          },
                        ),
                        if (!isLast) const Divider(height: 1),
                      ],
                    );
                  },
                  childCount: nonDraftInvoices.length,
                ),
              ),
            ),
        ] else if (_activeSubTab == 1) ...[
          SliverPadding(
            padding: EdgeInsets.fromLTRB(pad, 0, pad, 12),
            sliver: SliverToBoxAdapter(
              child: SizedBox(
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
            ),
          ),
          if (activeInvoices.isEmpty)
            SliverPadding(
              padding: EdgeInsets.fromLTRB(pad, 12, pad, pad),
              sliver: SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('No active transactions to show.', style: TextStyle(color: secondaryTextColor)),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(pad, 0, pad, pad),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final inv = activeInvoices[i];
                    final isLast = i == activeInvoices.length - 1;
                    final formattedTotal = formatInvMoney(
                      inv.totalCents,
                      inv.currencyCode,
                      inv.currencySymbol,
                      inv.currencyDecimals,
                    );
                    return Column(
                      children: [
                        LayoutBuilder(
                          builder: (context, rowConstraints) {
                            final stackAmount = rowConstraints.maxWidth < 360 || textScale > 1.3;
                            final totalWidget = Text(
                              formattedTotal,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontFeatures: [FontFeature.tabularFigures()]),
                            );
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                crossAxisAlignment: stackAmount ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                                children: [
                                  const Icon(Icons.receipt_long, size: 18),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Invoice ${inv.invoiceNumber}', style: const TextStyle(fontWeight: FontWeight.w600)),
                                        Text(inv.issueDate, style: TextStyle(fontSize: 12, color: secondaryTextColor)),
                                        if (stackAmount) ...[
                                          const SizedBox(height: 4),
                                          totalWidget,
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (!stackAmount) ...[
                                    const SizedBox(width: 12),
                                    totalWidget,
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                        if (!isLast) const Divider(height: 1),
                      ],
                    );
                  },
                  childCount: activeInvoices.length,
                ),
              ),
            ),
        ] else ...[
          SliverPadding(
            padding: EdgeInsets.fromLTRB(pad, 4, pad, pad),
            sliver: SliverToBoxAdapter(
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
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
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

