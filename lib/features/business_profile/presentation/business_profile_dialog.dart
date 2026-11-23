import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:billing_app/core/theme/app_theme.dart';
import 'package:billing_app/core/utils/file_validation_utils.dart';
import 'package:billing_app/core/utils/tax_compliance_utils.dart';
import 'package:billing_app/features/business_profile/providers/business_profile_provider.dart';

class BusinessProfileDialog extends ConsumerStatefulWidget {
  const BusinessProfileDialog({super.key});

  @override
  ConsumerState<BusinessProfileDialog> createState() => _BusinessProfileDialogState();
}

class _BusinessProfileDialogState extends ConsumerState<BusinessProfileDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _businessNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _taxIdController;
  late final TextEditingController _paymentDetailsController;
  late final TextEditingController _defaultTermsController;
  late final TextEditingController _defaultNotesController;
  late final TextEditingController _signatureLabelController;
  late final TextEditingController _defaultPstController;
  late final TextEditingController _invoicePrefixController;
  late final TextEditingController _estimatePrefixController;
  late final TextEditingController _nextInvoiceNumberController;
  late final TextEditingController _paymentQrPayloadController;
  late String _selectedCurrencySymbol;
  late String _selectedCurrencyCode;
  late int _selectedCurrencyDecimals;
  late String _selectedTaxMode;

  String _logoBase64 = '';
  String _signatureBase64 = '';

  static const List<Map<String, dynamic>> _currencyPresets = [
    {'code': 'USD', 'symbol': '\$', 'decimals': 2, 'label': 'USD (\$) - US Dollar'},
    {'code': 'INR', 'symbol': '₹', 'decimals': 2, 'label': 'INR (₹) - Indian Rupee'},
    {'code': 'EUR', 'symbol': '€', 'decimals': 2, 'label': 'EUR (€) - Euro'},
    {'code': 'GBP', 'symbol': '£', 'decimals': 2, 'label': 'GBP (£) - British Pound'},
    {'code': 'CAD', 'symbol': 'C\$', 'decimals': 2, 'label': 'CAD (C\$) - Canadian Dollar'},
    {'code': 'AUD', 'symbol': 'A\$', 'decimals': 2, 'label': 'AUD (A\$) - Australian Dollar'},
    {'code': 'AED', 'symbol': 'AED', 'decimals': 2, 'label': 'AED - UAE Dirham'},
    {'code': 'SAR', 'symbol': 'SAR', 'decimals': 2, 'label': 'SAR - Saudi Riyal'},
    {'code': 'KWD', 'symbol': 'KWD', 'decimals': 3, 'label': 'KWD (3 dec) - Kuwaiti Dinar'},
    {'code': 'BHD', 'symbol': 'BHD', 'decimals': 3, 'label': 'BHD (3 dec) - Bahraini Dinar'},
    {'code': 'OMR', 'symbol': 'OMR', 'decimals': 3, 'label': 'OMR (3 dec) - Omani Rial'},
    {'code': 'JOD', 'symbol': 'JOD', 'decimals': 3, 'label': 'JOD (3 dec) - Jordanian Dinar'},
    {'code': 'TND', 'symbol': 'TND', 'decimals': 3, 'label': 'TND (3 dec) - Tunisian Dinar'},
    {'code': 'JPY', 'symbol': '¥', 'decimals': 0, 'label': 'JPY (¥) - Japanese Yen'},
    {'code': 'KRW', 'symbol': '₩', 'decimals': 0, 'label': 'KRW (₩) - S. Korean Won'},
    {'code': 'VND', 'symbol': '₫', 'decimals': 0, 'label': 'VND (₫) - Vietnamese Dong'},
  ];

  @override
  void initState() {
    super.initState();
    final profile = ref.read(businessProfileProvider);
    _businessNameController = TextEditingController(text: profile.businessName);
    _emailController = TextEditingController(text: profile.email);
    _phoneController = TextEditingController(text: profile.phone);
    _addressController = TextEditingController(text: profile.address);
    _taxIdController = TextEditingController(text: profile.taxId);
    _paymentDetailsController = TextEditingController(
      text: profile.paymentDetails.replaceAll(r'\n', '\n'),
    );
    _defaultTermsController = TextEditingController(text: profile.defaultTerms);
    _defaultNotesController = TextEditingController(text: profile.defaultNotes);
    _signatureLabelController = TextEditingController(
      text: profile.signatureLabel.isNotEmpty ? profile.signatureLabel : 'Authorized Signatory',
    );
    _defaultPstController = TextEditingController(
      text: profile.defaultPstRatePercentage.toString(),
    );
    _invoicePrefixController = TextEditingController(
      text: profile.invoicePrefix.trim().isNotEmpty ? profile.invoicePrefix : 'INV-',
    );
    _estimatePrefixController = TextEditingController(
      text: profile.estimatePrefix.trim().isNotEmpty ? profile.estimatePrefix : 'EST-',
    );
    _nextInvoiceNumberController = TextEditingController(
      text: (profile.nextInvoiceNumber < 1 ? 1 : profile.nextInvoiceNumber).toString(),
    );
    _paymentQrPayloadController = TextEditingController(text: profile.paymentQrPayload);
    _logoBase64 = profile.logoBase64;
    _signatureBase64 = profile.signatureBase64;
    _selectedCurrencySymbol = profile.currencySymbol;
    _selectedCurrencyCode = profile.currencyCode;
    _selectedCurrencyDecimals = profile.currencyDecimals;
    _selectedTaxMode = normalizeTaxMode(profile.defaultTaxMode);
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _taxIdController.dispose();
    _paymentDetailsController.dispose();
    _defaultTermsController.dispose();
    _defaultNotesController.dispose();
    _signatureLabelController.dispose();
    _defaultPstController.dispose();
    _invoicePrefixController.dispose();
    _estimatePrefixController.dispose();
    _nextInvoiceNumberController.dispose();
    _paymentQrPayloadController.dispose();
    super.dispose();
  }

  Future<String?> _pickValidatedImageDataUri() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
      withData: false,
    );
    if (result == null || result.files.isEmpty) return null;

    final picked = result.files.single;
    const maxMb = maxAttachmentSizeBytes ~/ (1024 * 1024);
    if (picked.size > maxAttachmentSizeBytes) {
      if (!mounted) return null;
      final dangerTone = AppSemanticColors.resolve(Theme.of(context).brightness, SemanticStatus.danger);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('File exceeds maximum allowed size of $maxMb MB.', style: TextStyle(color: dangerTone.text)),
          backgroundColor: dangerTone.background,
        ),
      );
      return null;
    }

    List<int>? bytes;
    if (picked.path != null) {
      final file = File(picked.path!);
      final fileLength = await file.length();
      if (fileLength > maxAttachmentSizeBytes) {
        if (!mounted) return null;
        final dangerTone = AppSemanticColors.resolve(Theme.of(context).brightness, SemanticStatus.danger);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File exceeds maximum allowed size of $maxMb MB.', style: TextStyle(color: dangerTone.text)),
            backgroundColor: dangerTone.background,
          ),
        );
        return null;
      }
      bytes = await file.readAsBytes();
    } else {
      bytes = picked.bytes;
    }
    if (!mounted) return null;

    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read the selected image file.')),
      );
      return null;
    }

    final validation = validateUploadedFileBytes(
      bytes: bytes,
      filename: picked.name,
      allowPdf: false,
    );
    if (!validation.isValid || validation.mimeType == null) {
      final dangerTone = AppSemanticColors.resolve(Theme.of(context).brightness, SemanticStatus.danger);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validation.errorMessage ?? 'Invalid image file selected.', style: TextStyle(color: dangerTone.text)),
          backgroundColor: dangerTone.background,
        ),
      );
      return null;
    }

    return 'data:${validation.mimeType};base64,${base64Encode(bytes)}';
  }

  Future<void> _pickLogoFile() async {
    try {
      final dataUri = await _pickValidatedImageDataUri();
      if (!mounted || dataUri == null) return;
      setState(() {
        _logoBase64 = dataUri;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File selection note: $e')),
        );
      }
    }
  }

  Future<void> _pickSignatureFile() async {
    try {
      final dataUri = await _pickValidatedImageDataUri();
      if (!mounted || dataUri == null) return;
      setState(() {
        _signatureBase64 = dataUri;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File selection note: $e')),
        );
      }
    }
  }

  void _handleSave() {
    if (!_formKey.currentState!.validate()) return;

    final defaultPst = (int.tryParse(_defaultPstController.text.trim()) ?? 0).clamp(0, 100);
    final nextInvNum = int.tryParse(_nextInvoiceNumberController.text.trim()) ?? 1;
    ref.read(businessProfileProvider.notifier).updateProfile(
          businessName: _businessNameController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          address: _addressController.text.trim(),
          taxId: _taxIdController.text.trim(),
          paymentDetails: _paymentDetailsController.text.trim(),
          currencySymbol: _selectedCurrencySymbol,
          currencyCode: _selectedCurrencyCode,
          currencyDecimals: _selectedCurrencyDecimals,
          defaultTerms: _defaultTermsController.text.trim(),
          defaultNotes: _defaultNotesController.text.trim(),
          logoBase64: _logoBase64.trim(),
          signatureBase64: _signatureBase64.trim(),
          signatureLabel: _signatureLabelController.text.trim(),
          defaultTaxMode: _selectedTaxMode,
          defaultPstRatePercentage: defaultPst,
          invoicePrefix: _invoicePrefixController.text.trim(),
          estimatePrefix: _estimatePrefixController.text.trim(),
          nextInvoiceNumber: nextInvNum < 1 ? 1 : nextInvNum,
          paymentQrPayload: _paymentQrPayloadController.text.trim(),
        );

    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Business profile, currency settings & defaults saved to local SQLite.'),
      ),
    );
  }

  Widget _buildImagePreview(String base64Str, VoidCallback onRemove, String label) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final successTone = AppSemanticColors.resolve(theme.brightness, SemanticStatus.success);
    final secondaryTextColor = theme.textTheme.bodySmall?.color ?? colorScheme.onSurfaceVariant;

    if (base64Str.isEmpty) {
      return Container(
        height: 60,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor, style: BorderStyle.solid),
        ),
        child: Center(
          child: Text('No $label selected yet', style: TextStyle(fontSize: 12, color: secondaryTextColor)),
        ),
      );
    }

    try {
      final pureBase64 = base64Str.contains(',') ? base64Str.split(',').last : base64Str;
      final bytes = base64Decode(pureBase64);
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Image.memory(bytes, height: 40, fit: BoxFit.contain),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$label uploaded',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: colorScheme.onSurface),
              ),
            ),
            TextButton.icon(
              onPressed: onRemove,
              icon: Icon(Icons.close, size: 16, color: colorScheme.error),
              label: Text('Remove', style: TextStyle(color: colorScheme.error, fontSize: 12)),
            ),
          ],
        ),
      );
    } catch (_) {
      return Row(
        children: [
          Icon(Icons.check_circle, color: successTone.icon, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text('$label configured', style: const TextStyle(fontSize: 12))),
          TextButton(onPressed: onRemove, child: Text('Remove', style: TextStyle(color: colorScheme.error))),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    return AlertDialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: screenSize.width < 600 ? 12 : 24,
        vertical: 24,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Row(
        children: [
          Icon(Icons.business_outlined),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Business Profile & Branding Settings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 580,
          maxHeight: screenSize.height * 0.85,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 460;

                final businessNameField = TextFormField(
                  controller: _businessNameController,
                  decoration: const InputDecoration(
                    labelText: 'Business / Studio Name *',
                    hintText: 'e.g. My Freelance Studio',
                    prefixIcon: Icon(Icons.storefront_outlined, size: 20),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your business or freelancer name';
                    }
                    return null;
                  },
                );

                final currencyDropdown = DropdownButtonFormField<String>(
                  value: _selectedCurrencyCode,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Currency Preset',
                    prefixIcon: Icon(Icons.attach_money, size: 20),
                  ),
                  items: _currencyPresets.map((item) {
                    return DropdownMenuItem<String>(
                      value: item['code'] as String,
                      child: Text(
                        item['label'] as String,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      final preset = _currencyPresets.firstWhere(
                        (element) => element['code'] == val,
                        orElse: () => _currencyPresets.first,
                      );
                      setState(() {
                        _selectedCurrencyCode = preset['code'] as String;
                        _selectedCurrencySymbol = preset['symbol'] as String;
                        _selectedCurrencyDecimals = preset['decimals'] as int;
                      });
                    }
                  },
                );

                final emailField = TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Billing Email',
                    hintText: 'billing@studio.com',
                    prefixIcon: Icon(Icons.email_outlined, size: 20),
                  ),
                  keyboardType: TextInputType.emailAddress,
                );

                final phoneField = TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                    hintText: '+1 555-0199',
                    prefixIcon: Icon(Icons.phone_outlined, size: 20),
                  ),
                  keyboardType: TextInputType.phone,
                );

                final logoBtn = FilledButton.tonalIcon(
                  onPressed: _pickLogoFile,
                  icon: const Icon(Icons.file_upload_outlined, size: 16),
                  label: const Text('Select Logo File'),
                );
                final logoPreview = _buildImagePreview(_logoBase64, () => setState(() => _logoBase64 = ''), 'Logo');

                final sigBtn = FilledButton.tonalIcon(
                  onPressed: _pickSignatureFile,
                  icon: const Icon(Icons.draw_outlined, size: 16),
                  label: const Text('Select Signature'),
                );
                final sigPreview = _buildImagePreview(_signatureBase64, () => setState(() => _signatureBase64 = ''), 'Signature');

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'These branding settings appear on your printed A4 PDF invoices and proposals.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodySmall?.color ?? Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (isCompact) ...[
                      businessNameField,
                      const SizedBox(height: 12),
                      currencyDropdown,
                      const SizedBox(height: 12),
                      emailField,
                      const SizedBox(height: 12),
                      phoneField,
                    ] else ...[
                      Row(
                        children: [
                          Expanded(flex: 3, child: businessNameField),
                          const SizedBox(width: 12),
                          Expanded(flex: 3, child: currencyDropdown),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: emailField),
                          const SizedBox(width: 12),
                          Expanded(child: phoneField),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(
                        labelText: 'Business Address',
                        hintText: '100 Tech Plaza, Suite 400, San Francisco, CA',
                        prefixIcon: Icon(Icons.location_on_outlined, size: 20),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _taxIdController,
                      decoration: InputDecoration(
                        labelText: '${getRegionalTaxIdLabel(_selectedTaxMode)} / Registration #',
                        hintText: 'e.g. US-EIN-123456789 or GSTIN29ABCDE1234F1Z5',
                        prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedTaxMode,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Default Regional Tax Compliance Mode',
                        prefixIcon: Icon(Icons.public_outlined, size: 20),
                      ),
                      items: TaxMode.all.map((mode) {
                        return DropdownMenuItem<String>(
                          value: mode,
                          child: Text(
                            taxModeLabels[mode] ?? mode,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedTaxMode = val);
                      },
                    ),
                    if (_selectedTaxMode == TaxMode.caDual) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _defaultPstController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Default Canada PST Rate (%)',
                          hintText: '7',
                          prefixIcon: Icon(Icons.percent, size: 20),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    const Text(
                      'Document Numbering & Prefixes',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    (() {
                      final invPrefixField = TextFormField(
                        controller: _invoicePrefixController,
                        decoration: const InputDecoration(
                          labelText: 'Invoice Prefix *',
                          hintText: 'INV-',
                          prefixIcon: Icon(Icons.tag, size: 18),
                        ),
                        validator: (val) =>
                            val == null || val.trim().isEmpty ? 'Enter prefix' : null,
                      );
                      final estPrefixField = TextFormField(
                        controller: _estimatePrefixController,
                        decoration: const InputDecoration(
                          labelText: 'Quote Prefix *',
                          hintText: 'EST-',
                          prefixIcon: Icon(Icons.tag, size: 18),
                        ),
                        validator: (val) =>
                            val == null || val.trim().isEmpty ? 'Enter prefix' : null,
                      );
                      final nextNumField = TextFormField(
                        controller: _nextInvoiceNumberController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
                        decoration: const InputDecoration(
                          labelText: 'Next Invoice # *',
                          hintText: '1',
                          prefixIcon: Icon(Icons.pin_outlined, size: 18),
                        ),
                        validator: (val) {
                          final parsed = int.tryParse(val?.trim() ?? '');
                          if (parsed == null || parsed < 1) {
                            return 'Min 1';
                          }
                          return null;
                        },
                      );
                      if (isCompact) {
                        return Column(
                          children: [
                            invPrefixField,
                            const SizedBox(height: 10),
                            estPrefixField,
                            const SizedBox(height: 10),
                            nextNumField,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: invPrefixField),
                          const SizedBox(width: 10),
                          Expanded(child: estPrefixField),
                          const SizedBox(width: 10),
                          Expanded(child: nextNumField),
                        ],
                      );
                    })(),
                    const SizedBox(height: 18),
                    const Text(
                      'Branding: Company Logo & Digital Signature',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (isCompact) ...[
                      logoBtn,
                      const SizedBox(height: 8),
                      logoPreview,
                    ] else
                      Row(
                        children: [
                          logoBtn,
                          const SizedBox(width: 12),
                          Expanded(child: logoPreview),
                        ],
                      ),
                    const SizedBox(height: 12),
                    if (isCompact) ...[
                      sigBtn,
                      const SizedBox(height: 8),
                      sigPreview,
                    ] else
                      Row(
                        children: [
                          sigBtn,
                          const SizedBox(width: 12),
                          Expanded(child: sigPreview),
                        ],
                      ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _signatureLabelController,
                      decoration: const InputDecoration(
                        labelText: 'Signature Label',
                        hintText: 'Authorized Signatory',
                        prefixIcon: Icon(Icons.label_outlined, size: 20),
                      ),
                    ),
                const SizedBox(height: 18),
                const Text(
                  'Payment Instructions & Remittance Details',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _paymentDetailsController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText:
                        'Bank: ACME Bank\nAccount: 123456789\nRouting / IFSC / SWIFT: ACM00123\nPayPal / UPI: pay@studio.com',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _paymentQrPayloadController,
                  decoration: const InputDecoration(
                    labelText: 'Payment QR Payload (UPI VPA or Payment URL)',
                    hintText: 'e.g. billing@okaxis or https://pay.studio.com/checkout',
                    helperText: 'Generates a dynamic Scan-to-Pay QR code with balance due on PDFs.',
                    prefixIcon: Icon(Icons.qr_code_2, size: 20),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Global Default Terms & Notes',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _defaultTermsController,
                  minLines: 2,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  decoration: const InputDecoration(
                    labelText: 'Default Payment Terms / Legal Notice',
                    hintText: 'Payment due within agreed terms. Thank you for your business!',
                    prefixIcon: Icon(Icons.gavel_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 10),
                  TextFormField(
                    controller: _defaultNotesController,
                    minLines: 2,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    decoration: const InputDecoration(
                      labelText: 'Default Invoice Notes / Warranty',
                      hintText: 'e.g. All work includes 30 days post-delivery support.',
                      prefixIcon: Icon(Icons.notes_outlined, size: 20),
                    ),
                  ),
                ],
              );
              },
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _handleSave,
          icon: const Icon(Icons.save_outlined, size: 18),
          label: const Text('Save Profile & Branding'),
        ),
      ],
    );
  }
}
