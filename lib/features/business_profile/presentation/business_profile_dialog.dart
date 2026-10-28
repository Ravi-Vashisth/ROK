import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/business_profile_provider.dart';

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
  late final TextEditingController _logoBase64Controller;
  late final TextEditingController _signatureBase64Controller;
  late final TextEditingController _signatureLabelController;
  late String _selectedCurrencySymbol;

  static const List<String> _currencyPresets = ['\$', '€', '£', '₹', 'C\$', 'A\$', '¥'];

  @override
  void initState() {
    super.initState();
    final profile = ref.read(businessProfileProvider);
    _businessNameController = TextEditingController(text: profile.businessName);
    _emailController = TextEditingController(text: profile.email);
    _phoneController = TextEditingController(text: profile.phone);
    _addressController = TextEditingController(text: profile.address);
    _taxIdController = TextEditingController(text: profile.taxId);
    _paymentDetailsController = TextEditingController(text: profile.paymentDetails);
    _defaultTermsController = TextEditingController(text: profile.defaultTerms);
    _defaultNotesController = TextEditingController(text: profile.defaultNotes);
    _logoBase64Controller = TextEditingController(text: profile.logoBase64);
    _signatureBase64Controller = TextEditingController(text: profile.signatureBase64);
    _signatureLabelController = TextEditingController(
      text: profile.signatureLabel.isNotEmpty ? profile.signatureLabel : 'Authorized Signatory',
    );
    _selectedCurrencySymbol = _currencyPresets.contains(profile.currencySymbol)
        ? profile.currencySymbol
        : '\$';
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
    _logoBase64Controller.dispose();
    _signatureBase64Controller.dispose();
    _signatureLabelController.dispose();
    super.dispose();
  }

  void _handleSave() {
    if (!_formKey.currentState!.validate()) return;

    ref.read(businessProfileProvider.notifier).updateProfile(
          businessName: _businessNameController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          address: _addressController.text.trim(),
          taxId: _taxIdController.text.trim(),
          paymentDetails: _paymentDetailsController.text.trim(),
          currencySymbol: _selectedCurrencySymbol,
          defaultTerms: _defaultTermsController.text.trim(),
          defaultNotes: _defaultNotesController.text.trim(),
          logoBase64: _logoBase64Controller.text.trim(),
          signatureBase64: _signatureBase64Controller.text.trim(),
          signatureLabel: _signatureLabelController.text.trim(),
        );

    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Business profile, logo, signature & defaults saved to local SQLite.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
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
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'These branding settings appear on your printed A4 PDF invoices and proposals.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
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
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: _selectedCurrencySymbol,
                        decoration: const InputDecoration(
                          labelText: 'Currency Symbol',
                          prefixIcon: Icon(Icons.attach_money, size: 20),
                        ),
                        items: _currencyPresets.map((sym) {
                          return DropdownMenuItem(
                            value: sym,
                            child: Text(sym, style: const TextStyle(fontWeight: FontWeight.bold)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedCurrencySymbol = val);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Billing Email',
                          hintText: 'billing@studio.com',
                          prefixIcon: Icon(Icons.email_outlined, size: 20),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Phone',
                          hintText: '+1 555-0199',
                          prefixIcon: Icon(Icons.phone_outlined, size: 20),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                  ],
                ),
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
                  decoration: const InputDecoration(
                    labelText: 'Tax ID / VAT / GSTIN / EIN',
                    hintText: 'e.g. US-EIN-123456789 or GSTIN29ABCDE1234F1Z5',
                    prefixIcon: Icon(Icons.badge_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Branding: Company Logo & Digital Signature',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _logoBase64Controller,
                  decoration: const InputDecoration(
                    labelText: 'Company Logo (Image URL or Base64 String)',
                    hintText: 'Paste image URL or base64 data URI...',
                    prefixIcon: Icon(Icons.image_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _signatureBase64Controller,
                        decoration: const InputDecoration(
                          labelText: 'Digital Signature (Typed Name or Image Base64)',
                          hintText: 'e.g. Jane Doe, CEO',
                          prefixIcon: Icon(Icons.draw_outlined, size: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _signatureLabelController,
                        decoration: const InputDecoration(
                          labelText: 'Signature Label',
                          hintText: 'Authorized Signatory',
                          prefixIcon: Icon(Icons.label_outlined, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Payment Instructions & Remittance Details',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _paymentDetailsController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText:
                        'Bank: ACME Bank\nAccount: 123456789\nRouting / IFSC / SWIFT: ACM00123\nPayPal / UPI: pay@studio.com',
                    alignLabelWithHint: true,
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
                  decoration: const InputDecoration(
                    labelText: 'Default Payment Terms / Legal Notice',
                    hintText: 'Payment due within agreed terms. Thank you for your business!',
                    prefixIcon: Icon(Icons.gavel_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _defaultNotesController,
                  decoration: const InputDecoration(
                    labelText: 'Default Invoice Notes / Warranty',
                    hintText: 'e.g. All work includes 30 days post-delivery support.',
                    prefixIcon: Icon(Icons.notes_outlined, size: 20),
                  ),
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
        FilledButton.icon(
          onPressed: _handleSave,
          icon: const Icon(Icons.save_outlined, size: 18),
          label: const Text('Save Profile & Branding'),
        ),
      ],
    );
  }
}
