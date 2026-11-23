import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:billing_app/core/database/database_provider.dart';
import 'package:billing_app/core/theme/app_theme.dart';
import 'package:billing_app/core/theme/theme_provider.dart';
import 'package:billing_app/core/utils/backup_service.dart';
import 'package:billing_app/core/utils/export_file_helper.dart';
import 'package:billing_app/core/utils/file_validation_utils.dart';
import 'package:billing_app/core/utils/tax_compliance_utils.dart';
import 'package:billing_app/features/business_profile/presentation/business_profile_dialog.dart';
import 'package:billing_app/features/business_profile/providers/business_profile_provider.dart';
import 'package:billing_app/features/clients/providers/clients_provider.dart';
import 'package:billing_app/features/estimates/providers/estimates_provider.dart';
import 'package:billing_app/features/expenses/providers/expenses_provider.dart';
import 'package:billing_app/features/invoices/providers/invoices_provider.dart';
import 'package:billing_app/features/items/presentation/items_catalog_tab.dart';
import 'package:billing_app/features/items/providers/saved_items_provider.dart';

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
    final isWide = MediaQuery.sizeOf(context).width >= 900;
    final pagePadding = isWide ? 24.0 : 16.0;

    final settingsHeader = SizedBox(
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
    );

    if (_subTab == 1) {
      return ItemsCatalogTab(
        leadingSlivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(pagePadding, pagePadding, pagePadding, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  settingsHeader,
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          settingsHeader,
          const SizedBox(height: 20),
          if (_subTab == 0) ...[
            _BusinessProfileSettingsCard(),
          ] else if (_subTab == 2) ...[
            _PaymentBankingSettingsCard(),
          ] else ...[
            _BackupRecoveryCard(),
          ],
        ],
      ),
    );
  }
}

class _PaymentBankingSettingsCard extends ConsumerStatefulWidget {
  @override
  ConsumerState<_PaymentBankingSettingsCard> createState() => _PaymentBankingSettingsCardState();
}

class _PaymentBankingSettingsCardState extends ConsumerState<_PaymentBankingSettingsCard> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _paymentDetailsController;
  late final TextEditingController _paymentQrController;
  late final TextEditingController _defaultTermsController;
  late final TextEditingController _defaultNotesController;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(businessProfileProvider);
    _paymentDetailsController = TextEditingController(
      text: profile.paymentDetails.replaceAll(r'\n', '\n'),
    );
    _paymentQrController = TextEditingController(text: profile.paymentQrPayload);
    _defaultTermsController = TextEditingController(text: profile.defaultTerms);
    _defaultNotesController = TextEditingController(text: profile.defaultNotes);
  }

  @override
  void dispose() {
    _paymentDetailsController.dispose();
    _paymentQrController.dispose();
    _defaultTermsController.dispose();
    _defaultNotesController.dispose();
    super.dispose();
  }

  void _savePaymentSettings() {
    if (!_formKey.currentState!.validate()) return;
    final profile = ref.read(businessProfileProvider);
    ref.read(businessProfileProvider.notifier).updateProfile(
          businessName: profile.businessName,
          email: profile.email,
          phone: profile.phone,
          address: profile.address,
          taxId: profile.taxId,
          paymentDetails: _paymentDetailsController.text.trim(),
          currencySymbol: profile.currencySymbol,
          currencyCode: profile.currencyCode,
          currencyDecimals: profile.currencyDecimals,
          defaultTerms: _defaultTermsController.text.trim(),
          defaultNotes: _defaultNotesController.text.trim(),
          logoBase64: profile.logoBase64,
          signatureBase64: profile.signatureBase64,
          signatureLabel: profile.signatureLabel,
          defaultTaxMode: profile.defaultTaxMode,
          defaultPstRatePercentage: profile.defaultPstRatePercentage,
          invoicePrefix: profile.invoicePrefix,
          estimatePrefix: profile.estimatePrefix,
          nextInvoiceNumber: profile.nextInvoiceNumber,
          paymentQrPayload: _paymentQrController.text.trim(),
        );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Payment instructions and QR payload saved!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(businessProfileProvider, (prev, next) {
      if (prev?.paymentDetails != next.paymentDetails) {
        _paymentDetailsController.text = next.paymentDetails.replaceAll(r'\n', '\n');
      }
      if (prev?.paymentQrPayload != next.paymentQrPayload) {
        _paymentQrController.text = next.paymentQrPayload;
      }
      if (prev?.defaultTerms != next.defaultTerms) {
        _defaultTermsController.text = next.defaultTerms;
      }
      if (prev?.defaultNotes != next.defaultNotes) {
        _defaultNotesController.text = next.defaultNotes;
      }
    });

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final secondaryTextColor = Theme.of(context).textTheme.bodySmall?.color ?? Theme.of(context).colorScheme.onSurfaceVariant;
                  final titleRow = Row(
                    children: [
                      Icon(Icons.account_balance, color: Theme.of(context).colorScheme.primary, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Payment Methods & Remittance Instructions',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Configure bank wire transfer accounts, UPI VPA, and online payment QR links.',
                              style: TextStyle(fontSize: 13, color: secondaryTextColor),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                  final editBtn = OutlinedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => const BusinessProfileDialog(),
                      );
                    },
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Full Profile Dialog'),
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
              TextFormField(
                controller: _paymentDetailsController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Bank Account & Wire Transfer Instructions',
                  hintText: 'Bank: Chase\nAccount: 12345678\nRouting / SWIFT: CHASUS33\nUPI: business@upi',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _paymentQrController,
                decoration: const InputDecoration(
                  labelText: 'Payment QR Payload (UPI VPA or Payment URL)',
                  hintText: 'e.g. billing@okaxis or https://pay.studio.com/checkout',
                  helperText: 'Dynamically encodes invoice number & balance due into A4 PDF Scan-to-Pay QR.',
                  prefixIcon: Icon(Icons.qr_code_2, size: 20),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _defaultTermsController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Default Invoice Terms & Legal Notice',
                  hintText: 'Payment due within agreed terms. Thank you for your business!',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _defaultNotesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Default Invoice Notes / Warranty',
                  hintText: 'All work includes 30 days post-delivery support.',
                ),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _savePaymentSettings,
                  icon: const Icon(Icons.save_outlined, size: 16),
                  label: const Text('Save Payment & QR Settings'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackupRecoveryCard extends ConsumerStatefulWidget {
  @override
  ConsumerState<_BackupRecoveryCard> createState() => _BackupRecoveryCardState();
}

class _BackupRecoveryCardState extends ConsumerState<_BackupRecoveryCard> {
  bool _isProcessingBackup = false;
  String _processingLabel = '';

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dangerTone = AppSemanticColors.resolve(theme.brightness, SemanticStatus.danger);
    final secondaryTextColor = theme.textTheme.bodySmall?.color ?? colorScheme.onSurfaceVariant;

    Future<void> handleExport() async {
      if (_isProcessingBackup) return;
      final messenger = ScaffoldMessenger.of(context);
      setState(() {
        _isProcessingBackup = true;
        _processingLabel = 'Preparing JSON backup...';
      });
      try {
        final bytes = await BackupService.exportDatabaseToJsonBytesAsync(db);
        if (!mounted) return;
        final now = DateTime.now();
        final dateStr =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        final res = await ExportFileHelper.saveExportFileWithDetails(
          bytes: bytes,
          filename: 'freelance_ledger_backup_$dateStr.json',
          extension: 'json',
          dialogTitle: 'Save Database Backup JSON',
        );
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              res == null
                  ? 'Backup export cancelled.'
                  : (res.usedFallbackDirectory
                      ? 'OS file picker unavailable — backup saved to app exports folder: ${res.path}'
                      : 'Database backup saved: ${res.path}'),
            ),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(content: Text('Error exporting database: $e')),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isProcessingBackup = false;
            _processingLabel = '';
          });
        }
      }
    }

    Future<void> handlePickAndRestore() async {
      if (_isProcessingBackup) return;
      final messenger = ScaffoldMessenger.of(context);
      setState(() {
        _isProcessingBackup = true;
        _processingLabel = 'Reading & validating backup...';
      });
      try {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['json'],
          withData: false,
        );
        if (result == null || result.files.isEmpty) return;

        final picked = result.files.single;
        if (picked.size > maxBackupSizeBytes) {
          throw const FormatException('Backup file exceeds maximum supported size (50 MB).');
        }

        List<int>? bytes;
        if (picked.path != null) {
          final file = File(picked.path!);
          final fileLength = await file.length();
          if (fileLength > maxBackupSizeBytes) {
            throw const FormatException('Backup file exceeds maximum supported size (50 MB).');
          }
          bytes = await file.readAsBytes();
        } else {
          bytes = picked.bytes;
        }
        if (!context.mounted) return;
        if (bytes == null || bytes.isEmpty) {
          throw const FormatException('Could not read the selected backup file.');
        }
        if (bytes.length > maxBackupSizeBytes) {
          throw const FormatException('Backup file exceeds maximum supported size (50 MB).');
        }

        final decoded = await BackupService.decodeAndValidateBackupBytesAsync(bytes);

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
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.error,
                  foregroundColor: colorScheme.onError,
                ),
                onPressed: () => Navigator.of(dialogCtx).pop(true),
                child: const Text('Restore & Overwrite'),
              ),
            ],
          ),
        );

        if (confirmed != true) return;
        if (mounted) {
          setState(() {
            _processingLabel = 'Importing backup into local database...';
          });
        }

        BackupService.importDatabaseFromJson(db, decoded);

        ref.invalidate(clientsProvider);
        ref.invalidate(invoicesProvider);
        ref.invalidate(estimatesProvider);
        ref.invalidate(expensesProvider);
        ref.invalidate(savedItemsProvider);
        ref.invalidate(businessProfileProvider);
        ref.invalidate(themeModeProvider);
        ref.invalidate(accentColorProvider);

        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(content: Text('Database successfully restored from backup!')),
        );
      } catch (e) {
        if (!mounted) return;
        final msg = e is FormatException ? e.message : 'Error restoring backup: $e';
        messenger.showSnackBar(
          SnackBar(
            content: Text(msg, style: TextStyle(color: dangerTone.text)),
            backgroundColor: dangerTone.background,
          ),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isProcessingBackup = false;
            _processingLabel = '';
          });
        }
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Disaster Recovery & Data Management',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Export or restore your complete ledger database instantly.',
                        style: TextStyle(fontSize: 13, color: secondaryTextColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_isProcessingBackup) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
              if (_processingLabel.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  _processingLabel,
                  style: TextStyle(fontSize: 12, color: secondaryTextColor),
                ),
              ],
            ],
            const Divider(height: 32),
            const Text(
              'Export Backup',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              'Generates a complete JSON snapshot of all your clients, invoices, estimates, expenses, payments, and business settings.',
              style: TextStyle(fontSize: 12, color: secondaryTextColor),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _isProcessingBackup ? null : handleExport,
              icon: _isProcessingBackup
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_outlined, size: 16),
              label: const Text('Export Database File (JSON Backup)'),
            ),
            const SizedBox(height: 24),
            const Text(
              'Restore Backup',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              'Restore your database from an exported JSON backup. Warning: This overwrites all current local records.',
              style: TextStyle(fontSize: 12, color: secondaryTextColor),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: colorScheme.error),
              onPressed: _isProcessingBackup ? null : handlePickAndRestore,
              icon: const Icon(Icons.upload_outlined, size: 16),
              label: const Text('Select JSON Backup File to Restore'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BusinessProfileSettingsCard extends ConsumerStatefulWidget {
  @override
  ConsumerState<_BusinessProfileSettingsCard> createState() => _BusinessProfileSettingsCardState();
}

class _BusinessProfileSettingsCardState extends ConsumerState<_BusinessProfileSettingsCard> {
  final _numberingFormKey = GlobalKey<FormState>();
  late final TextEditingController _invoicePrefixController;
  late final TextEditingController _estimatePrefixController;
  late final TextEditingController _nextInvoiceNumberController;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(businessProfileProvider);
    _invoicePrefixController = TextEditingController(
      text: profile.invoicePrefix.trim().isNotEmpty ? profile.invoicePrefix : 'INV-',
    );
    _estimatePrefixController = TextEditingController(
      text: profile.estimatePrefix.trim().isNotEmpty ? profile.estimatePrefix : 'EST-',
    );
    _nextInvoiceNumberController = TextEditingController(
      text: (profile.nextInvoiceNumber < 1 ? 1 : profile.nextInvoiceNumber).toString(),
    );
  }

  @override
  void dispose() {
    _invoicePrefixController.dispose();
    _estimatePrefixController.dispose();
    _nextInvoiceNumberController.dispose();
    super.dispose();
  }

  void _saveNumbering() {
    if (!_numberingFormKey.currentState!.validate()) return;
    final profile = ref.read(businessProfileProvider);
    final nextNum = int.tryParse(_nextInvoiceNumberController.text.trim()) ?? 1;
    ref.read(businessProfileProvider.notifier).updateProfile(
          businessName: profile.businessName,
          email: profile.email,
          phone: profile.phone,
          address: profile.address,
          taxId: profile.taxId,
          paymentDetails: profile.paymentDetails,
          currencySymbol: profile.currencySymbol,
          currencyCode: profile.currencyCode,
          currencyDecimals: profile.currencyDecimals,
          defaultTerms: profile.defaultTerms,
          defaultNotes: profile.defaultNotes,
          logoBase64: profile.logoBase64,
          signatureBase64: profile.signatureBase64,
          signatureLabel: profile.signatureLabel,
          defaultTaxMode: profile.defaultTaxMode,
          defaultPstRatePercentage: profile.defaultPstRatePercentage,
          invoicePrefix: _invoicePrefixController.text.trim(),
          estimatePrefix: _estimatePrefixController.text.trim(),
          nextInvoiceNumber: nextNum < 1 ? 1 : nextNum,
          paymentQrPayload: profile.paymentQrPayload,
        );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Document prefixes and numbering sequence saved!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(businessProfileProvider);
    final theme = Theme.of(context);
    final infoTone = AppSemanticColors.resolve(theme.brightness, SemanticStatus.info);
    final secondaryTextColor = theme.textTheme.bodySmall?.color ?? theme.colorScheme.onSurfaceVariant;
    ref.listen(businessProfileProvider, (prev, next) {
      if (prev?.invoicePrefix != next.invoicePrefix) {
        _invoicePrefixController.text =
            next.invoicePrefix.trim().isNotEmpty ? next.invoicePrefix : 'INV-';
      }
      if (prev?.estimatePrefix != next.estimatePrefix) {
        _estimatePrefixController.text =
            next.estimatePrefix.trim().isNotEmpty ? next.estimatePrefix : 'EST-';
      }
      if (prev?.nextInvoiceNumber != next.nextInvoiceNumber) {
        _nextInvoiceNumberController.text =
            (next.nextInvoiceNumber < 1 ? 1 : next.nextInvoiceNumber).toString();
      }
    });

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
                            style: TextStyle(fontSize: 13, color: secondaryTextColor),
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
            _infoRow(
              context,
              'Payment QR Payload',
              profile.paymentQrPayload.isNotEmpty ? profile.paymentQrPayload : 'Not configured',
            ),
            const Divider(height: 32),
            const Text('Document Numbering & Prefixes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            Form(
              key: _numberingFormKey,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final invPrefixField = TextFormField(
                    controller: _invoicePrefixController,
                    decoration: const InputDecoration(
                      labelText: 'Invoice Prefix *',
                      hintText: 'INV-',
                    ),
                    validator: (val) => val == null || val.trim().isEmpty
                        ? 'Please enter an invoice prefix'
                        : null,
                  );
                  final estPrefixField = TextFormField(
                    controller: _estimatePrefixController,
                    decoration: const InputDecoration(
                      labelText: 'Quote Prefix *',
                      hintText: 'EST-',
                    ),
                    validator: (val) => val == null || val.trim().isEmpty
                        ? 'Please enter a quote prefix'
                        : null,
                  );
                  final nextNumField = TextFormField(
                    controller: _nextInvoiceNumberController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
                    decoration: const InputDecoration(
                      labelText: 'Next Invoice # *',
                      hintText: '1',
                    ),
                    validator: (val) {
                      final parsed = int.tryParse(val?.trim() ?? '');
                      if (parsed == null || parsed < 1) {
                        return 'Must be an integer >= 1';
                      }
                      return null;
                    },
                  );
                  final saveBtn = FilledButton.tonalIcon(
                    onPressed: _saveNumbering,
                    icon: const Icon(Icons.save_outlined, size: 16),
                    label: const Text('Save Numbering'),
                  );

                  if (constraints.maxWidth < 560) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        invPrefixField,
                        const SizedBox(height: 12),
                        estPrefixField,
                        const SizedBox(height: 12),
                        nextNumField,
                        const SizedBox(height: 12),
                        Align(alignment: Alignment.centerRight, child: saveBtn),
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          Expanded(child: invPrefixField),
                          const SizedBox(width: 12),
                          Expanded(child: estPrefixField),
                          const SizedBox(width: 12),
                          Expanded(child: nextNumField),
                        ],
                      ),
                      const SizedBox(height: 12),
                      saveBtn,
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: infoTone.icon),
                  const SizedBox(width: 10),
                  const Expanded(
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
    final secondaryTextColor = Theme.of(context).textTheme.bodySmall?.color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 460) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12, color: secondaryTextColor)),
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
                child: Text(label, style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: secondaryTextColor)),
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
