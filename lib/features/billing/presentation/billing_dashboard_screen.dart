import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money_utils.dart';
import '../../clients/providers/clients_provider.dart';
import '../../invoices/providers/invoices_provider.dart';
import 'widgets/client_selection_card.dart';
import 'widgets/invoice_inputs_card.dart';
import 'widgets/offline_invoices_list.dart';

class BillingDashboardScreen extends ConsumerStatefulWidget {
  const BillingDashboardScreen({super.key});

  @override
  ConsumerState<BillingDashboardScreen> createState() => _BillingDashboardScreenState();
}

class _BillingDashboardScreenState extends ConsumerState<BillingDashboardScreen> {
  final _newClientController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _taxPercentageController = TextEditingController(text: '10');

  String? _selectedClientId;

  @override
  void dispose() {
    _newClientController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _taxPercentageController.dispose();
    super.dispose();
  }

  void _handleAddClient() {
    final name = _newClientController.text.trim();
    if (name.isEmpty) return;

    ref.read(clientsProvider.notifier).addClient(name);
    _newClientController.clear();

    final clients = ref.read(clientsProvider);
    final found = clients.where((c) => c.name == name);
    if (found.isNotEmpty) {
      setState(() {
        _selectedClientId = found.first.id;
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Client "$name" added locally to SQLite.')),
    );
  }

  void _handleSaveInvoice() {
    if (_selectedClientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or add a client first.')),
      );
      return;
    }

    final priceCents = parsePriceToCents(_priceController.text);
    if (priceCents <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid price.')),
      );
      return;
    }

    final quantity = int.tryParse(_quantityController.text.trim()) ?? 1;
    if (quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quantity must be at least 1.')),
      );
      return;
    }

    final taxPercentage = int.tryParse(_taxPercentageController.text.trim()) ?? 0;
    final subtotalCents = priceCents * quantity;
    final taxCents = calculateTaxCents(subtotalCents, taxPercentage);
    final totalCents = subtotalCents + taxCents;

    ref.read(invoicesProvider.notifier).saveInvoice(
          clientId: _selectedClientId!,
          subtotalCents: subtotalCents,
          taxCents: taxCents,
          totalCents: totalCents,
        );

    _descriptionController.clear();
    _priceController.clear();
    _quantityController.text = '1';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Invoice saved locally! Total: ${formatCents(totalCents)}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nextInvoiceNumber = ref.watch(invoicesProvider.notifier).getNextInvoiceNumber();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Local Billing (Offline Desktop Skeleton)'),
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClientSelectionCard(
              newClientController: _newClientController,
              selectedClientId: _selectedClientId,
              onClientSelected: (val) => setState(() => _selectedClientId = val),
              onAddClient: _handleAddClient,
            ),
            const SizedBox(height: 20),
            InvoiceInputsCard(
              descriptionController: _descriptionController,
              priceController: _priceController,
              quantityController: _quantityController,
              taxPercentageController: _taxPercentageController,
              onSaveInvoice: _handleSaveInvoice,
              onValuesChanged: () => setState(() {}),
              nextInvoiceNumber: nextInvoiceNumber,
            ),
            const SizedBox(height: 24),
            const OfflineInvoicesList(),
          ],
        ),
      ),
    );
  }
}
