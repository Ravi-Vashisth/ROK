import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../clients/providers/clients_provider.dart';
import '../../estimates/presentation/estimate_inputs_card.dart';
import '../../estimates/presentation/offline_estimates_list.dart';
import '../../estimates/providers/estimates_provider.dart';
import '../../invoices/providers/invoices_provider.dart';
import 'widgets/client_selection_card.dart';
import 'widgets/invoice_inputs_card.dart';
import 'widgets/offline_invoices_list.dart';

class SalesTab extends ConsumerStatefulWidget {
  const SalesTab({super.key});

  @override
  ConsumerState<SalesTab> createState() => _SalesTabState();
}

class _SalesTabState extends ConsumerState<SalesTab> {
  int _subTab = 0; // 0 = Invoices, 1 = Estimates

  final _newClientController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _taxIdController = TextEditingController();

  String? _selectedClientId;

  @override
  void dispose() {
    _newClientController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _taxIdController.dispose();
    super.dispose();
  }

  void _handleAddClient() {
    final name = _newClientController.text.trim();
    if (name.isEmpty) return;

    ref.read(clientsProvider.notifier).addClient(
          name: name,
          email: _emailController.text,
          phone: _phoneController.text,
          address: _addressController.text,
          taxId: _taxIdController.text,
        );

    _newClientController.clear();
    _emailController.clear();
    _phoneController.clear();
    _addressController.clear();
    _taxIdController.clear();

    final clients = ref.read(clientsProvider);
    final found = clients.where((c) => c.name == name);
    if (found.isNotEmpty) {
      setState(() {
        _selectedClientId = found.first.id;
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Client "$name" saved locally to SQLite.')),
    );
  }

  void _handleSaveInvoice({
    required List<DraftItem> items,
    required int taxPercentage,
    required String paymentTerms,
    required String issueDate,
    required String dueDate,
    required String terms,
    required String notes,
    required String discountType,
    required int discountValue,
  }) {
    if (_selectedClientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or add a client first.')),
      );
      return;
    }

    ref.read(invoicesProvider.notifier).saveInvoice(
          clientId: _selectedClientId!,
          items: items,
          taxPercentage: taxPercentage,
          paymentTerms: paymentTerms,
          issueDate: issueDate,
          dueDate: dueDate,
          terms: terms,
          notes: notes,
          discountType: discountType,
          discountValue: discountValue,
        );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Invoice saved locally ($paymentTerms, Due: $dueDate)!')),
    );
  }

  void _handleSaveEstimate({
    required List<DraftItem> items,
    required int taxPercentage,
    required String issueDate,
    required String expiryDate,
    required String terms,
    required String notes,
    required String discountType,
    required int discountValue,
  }) {
    if (_selectedClientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or add a client first.')),
      );
      return;
    }

    ref.read(estimatesProvider.notifier).saveEstimate(
          clientId: _selectedClientId!,
          items: items,
          taxPercentage: taxPercentage,
          issueDate: issueDate,
          expiryDate: expiryDate,
          terms: terms,
          notes: notes,
          discountType: discountType,
          discountValue: discountValue,
        );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Estimate saved locally (Expires: $expiryDate)!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nextInvoiceNumber = ref.watch(invoicesProvider.notifier).getNextInvoiceNumber();
    final nextEstimateNumber = ref.watch(estimatesProvider.notifier).getNextEstimateNumber();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Sales & Proposals Hub',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            ToggleButtons(
              isSelected: [_subTab == 0, _subTab == 1],
              onPressed: (index) {
                setState(() => _subTab = index);
              },
              borderRadius: BorderRadius.circular(8),
              constraints: const BoxConstraints(minHeight: 36, minWidth: 100),
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Icon(Icons.receipt_outlined, size: 16),
                      SizedBox(width: 6),
                      Text('Invoices', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Icon(Icons.request_quote_outlined, size: 16),
                      SizedBox(width: 6),
                      Text('Estimates', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),
        ClientSelectionCard(
          newClientController: _newClientController,
          emailController: _emailController,
          phoneController: _phoneController,
          addressController: _addressController,
          taxIdController: _taxIdController,
          selectedClientId: _selectedClientId,
          onClientSelected: (val) => setState(() => _selectedClientId = val),
          onAddClient: _handleAddClient,
        ),
        const SizedBox(height: 24),
        if (_subTab == 0) ...[
          InvoiceInputsCard(
            nextInvoiceNumber: nextInvoiceNumber,
            onSaveInvoice: _handleSaveInvoice,
          ),
          const SizedBox(height: 24),
          const OfflineInvoicesList(),
        ] else ...[
          EstimateInputsCard(
            nextEstimateNumber: nextEstimateNumber,
            onSaveEstimate: _handleSaveEstimate,
          ),
          const SizedBox(height: 24),
          const OfflineEstimatesList(),
        ],
      ],
    );
  }
}
