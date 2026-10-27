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
        );

    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Business profile & currency settings saved to local SQLite.'),
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
              'Business Profile & Currency Settings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'These details appear on your printed A4 PDF invoices and payment instructions.',
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
          label: const Text('Save Profile'),
        ),
      ],
    );
  }
}
