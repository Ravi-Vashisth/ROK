import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:billing_app/core/utils/money_utils.dart';
import 'package:billing_app/core/utils/tax_compliance_utils.dart';
import 'package:billing_app/features/billing/presentation/widgets/client_autocomplete_picker.dart';
import 'package:billing_app/features/business_profile/models/business_profile.dart';
import 'package:billing_app/features/business_profile/providers/business_profile_provider.dart';
import 'package:billing_app/features/clients/models/client.dart';
import 'package:billing_app/features/clients/providers/clients_provider.dart';
import 'package:billing_app/features/estimates/models/estimate_record.dart';
import 'package:billing_app/features/invoices/models/invoice_record.dart';
import 'package:billing_app/features/estimates/providers/estimates_provider.dart';
import 'package:billing_app/features/invoices/providers/invoices_provider.dart';
import 'package:billing_app/features/items/providers/saved_items_provider.dart';

class LineItemEntry {
  String description;
  String sacHsn;
  int quantity;
  int unitPriceCents;
  int taxSlab;

  LineItemEntry({
    required this.description,
    this.sacHsn = '',
    this.quantity = 1,
    this.unitPriceCents = 0,
    this.taxSlab = 10,
  });

  int get totalCents => quantity * unitPriceCents;
}

class InvoiceEditorScreen extends ConsumerStatefulWidget {
  final bool isQuote;
  final InvoiceRecord? existingInvoice;
  final EstimateRecord? existingEstimate;

  const InvoiceEditorScreen({
    super.key,
    this.isQuote = false,
    this.existingInvoice,
    this.existingEstimate,
  });

  @override
  ConsumerState<InvoiceEditorScreen> createState() => _InvoiceEditorScreenState();
}

class _InvoiceEditorScreenState extends ConsumerState<InvoiceEditorScreen> {
  String? _selectedClientId;
  int _mobileTabIndex = 0; // 0 = Editor, 1 = Preview

  late TextEditingController _issueDateController;
  late TextEditingController _termsController;
  late TextEditingController _notesController;
  late TextEditingController _poNumberController;
  String? _overrideCurrencyCode;
  String? _overrideCurrencySymbol;
  int? _overrideCurrencyDecimals;
  String _paymentTerms = 'Due on Receipt';
  String _discountType = 'none'; // 'none', 'percent', 'flat'
  late TextEditingController _discountController;
  late String _taxMode;
  late TextEditingController _pstRateController;
  late TextEditingController _exemptionIdController;
  String? _initialQuoteExpiryDate;
  bool _paymentTermsChanged = false;

  List<LineItemEntry> _items = [];

  @override
  void initState() {
    super.initState();
    final profile = ref.read(businessProfileProvider);

    if (widget.existingInvoice != null) {
      final inv = widget.existingInvoice!;
      _selectedClientId = inv.clientId;
      _issueDateController = TextEditingController(text: inv.issueDate);
      _paymentTerms = inv.paymentTerms;
      _poNumberController = TextEditingController(text: inv.poNumber);
      _overrideCurrencyCode = inv.currencyCode.isNotEmpty ? inv.currencyCode : profile.currencyCode;
      _overrideCurrencySymbol = inv.currencySymbol.isNotEmpty ? inv.currencySymbol : profile.currencySymbol;
      _overrideCurrencyDecimals = inv.currencyCode.isNotEmpty ? inv.currencyDecimals : profile.currencyDecimals;
      _termsController = TextEditingController(text: inv.terms);
      _notesController = TextEditingController(text: inv.notes);
      _discountType = inv.discountType;
      _discountController = TextEditingController(
        text: inv.discountType == 'flat'
            ? formatDecimalUnits(inv.discountValue, _overrideCurrencyDecimals ?? profile.currencyDecimals)
            : inv.discountValue.toString(),
      );
      _taxMode = normalizeTaxMode(inv.taxMode);
      _pstRateController = TextEditingController(text: inv.pstRatePercentage.toString());
      _exemptionIdController = TextEditingController(text: inv.taxExemptionId);

      final dbItems = ref.read(invoicesProvider.notifier).getInvoiceItems(inv.id);
      if (dbItems.isNotEmpty) {
        _items = dbItems
            .map((it) => LineItemEntry(
                  description: it.description,
                  sacHsn: it.sacHsn,
                  quantity: it.quantity,
                  unitPriceCents: it.unitPriceCents,
                  taxSlab: it.taxRatePercentage,
                ))
            .toList();
      } else {
        _items = [
          LineItemEntry(description: '', sacHsn: '', quantity: 1, unitPriceCents: 0, taxSlab: 10)
        ];
      }
    } else if (widget.existingEstimate != null) {
      final est = widget.existingEstimate!;
      _selectedClientId = est.clientId;
      _issueDateController = TextEditingController(text: est.issueDate);
      _initialQuoteExpiryDate = est.expiryDate;
      _paymentTerms = 'Net 30 Days';
      _poNumberController = TextEditingController(text: est.poNumber);
      _overrideCurrencyCode = est.currencyCode.isNotEmpty ? est.currencyCode : profile.currencyCode;
      _overrideCurrencySymbol = est.currencySymbol.isNotEmpty ? est.currencySymbol : profile.currencySymbol;
      _overrideCurrencyDecimals = est.currencyCode.isNotEmpty ? est.currencyDecimals : profile.currencyDecimals;
      _termsController = TextEditingController(text: est.terms);
      _notesController = TextEditingController(text: est.notes);
      _discountType = est.discountType;
      _discountController = TextEditingController(
        text: est.discountType == 'flat'
            ? formatDecimalUnits(est.discountValue, _overrideCurrencyDecimals ?? profile.currencyDecimals)
            : est.discountValue.toString(),
      );
      _taxMode = normalizeTaxMode(est.taxMode);
      _pstRateController = TextEditingController(text: est.pstRatePercentage.toString());
      _exemptionIdController = TextEditingController(text: est.taxExemptionId);

      final dbItems = ref.read(estimatesProvider.notifier).getEstimateItems(est.id);
      if (dbItems.isNotEmpty) {
        _items = dbItems
            .map((it) => LineItemEntry(
                  description: it.description,
                  sacHsn: it.sacHsn,
                  quantity: it.quantity,
                  unitPriceCents: it.unitPriceCents,
                  taxSlab: it.taxRatePercentage,
                ))
            .toList();
      } else {
        _items = [
          LineItemEntry(description: '', sacHsn: '', quantity: 1, unitPriceCents: 0, taxSlab: 10)
        ];
      }
    } else {
      final now = DateTime.now();
      _issueDateController = TextEditingController(
        text: '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
      );
      if (widget.isQuote) {
        _paymentTerms = 'Net 30 Days';
      }
      _poNumberController = TextEditingController();
      _overrideCurrencyCode = profile.currencyCode;
      _overrideCurrencySymbol = profile.currencySymbol;
      _overrideCurrencyDecimals = profile.currencyDecimals;
      _termsController = TextEditingController(text: profile.defaultTerms);
      _notesController = TextEditingController(text: profile.defaultNotes);
      _discountController = TextEditingController(text: '0');
      _taxMode = normalizeTaxMode(profile.defaultTaxMode);
      _pstRateController = TextEditingController(text: profile.defaultPstRatePercentage.toString());
      _exemptionIdController = TextEditingController();
      _items = [
        LineItemEntry(description: '', sacHsn: '', quantity: 1, unitPriceCents: 0, taxSlab: 10)
      ];
    }
  }

  @override
  void dispose() {
    _issueDateController.dispose();
    _poNumberController.dispose();
    _termsController.dispose();
    _notesController.dispose();
    _discountController.dispose();
    _pstRateController.dispose();
    _exemptionIdController.dispose();
    super.dispose();
  }

  void _addItem() {
    setState(() {
      _items.add(LineItemEntry(
        description: '',
        sacHsn: '',
        quantity: 1,
        unitPriceCents: 0,
        taxSlab: 10,
      ));
    });
  }

  void _removeItem(int index) {
    if (_items.length <= 1) return;
    setState(() => _items.removeAt(index));
  }

  List<LineItemEntry> get _validItems => _items
      .where((i) => !(i.description.trim().isEmpty && i.unitPriceCents == 0))
      .toList();

  int get _activeDecimals {
    final code = _overrideCurrencyCode ?? ref.read(businessProfileProvider).currencyCode;
    return _overrideCurrencyDecimals ?? getCurrencyDecimals(code);
  }

  int get _subtotalCents => _validItems.fold(0, (sum, i) => sum + i.totalCents);

  int _effectiveDiscountValue(int decimals) {
    if (_discountType == 'none') return 0;
    if (_discountType == 'percent') {
      return (double.tryParse(_discountController.text.trim()) ?? 0).round().clamp(0, 100);
    }
    return parsePriceToUnits(_discountController.text.trim(), decimals);
  }

  int get _discountCents => calculateDiscountCents(
        _subtotalCents,
        _discountType,
        _effectiveDiscountValue(_activeDecimals),
      );

  int get _pstRatePct => (int.tryParse(_pstRateController.text.trim()) ?? 0).clamp(0, 100);

  int get _netSubtotalCents => (_subtotalCents - _discountCents).clamp(0, _subtotalCents);

  int get _taxCents {
    final subAfterDisc = _netSubtotalCents;
    final itemsTaxSum = _validItems.fold(0, (sum, i) {
      if (_subtotalCents <= 0) return sum;
      final lineShare = (i.totalCents * subAfterDisc + (_subtotalCents ~/ 2)) ~/ _subtotalCents;
      return sum + calculateTaxCents(lineShare, i.taxSlab);
    });
    final primaryTaxPct = _validItems.isNotEmpty ? _validItems.first.taxSlab : 0;
    return computeRegionalTaxCents(
      netSubtotalCents: subAfterDisc,
      taxMode: _taxMode,
      taxPercentage: primaryTaxPct,
      pstRatePercentage: _pstRatePct,
      itemsTaxSumCents: itemsTaxSum,
    );
  }

  int get _totalCents => _netSubtotalCents + _taxCents;

  String _calculateDueDate(String issueDateStr, String terms) {
    final issue = parseLocalCalendarDate(issueDateStr);
    if (issue == null) return issueDateStr;
    int addDays = 0;
    if (terms.contains('15')) addDays = 15;
    if (terms.contains('30')) addDays = 30;
    if (terms.contains('60')) addDays = 60;
    final due = DateTime(issue.year, issue.month, issue.day + addDays);
    return '${due.year}-${due.month.toString().padLeft(2, '0')}-${due.day.toString().padLeft(2, '0')}';
  }

  String? get _issueDateError {
    final text = _issueDateController.text.trim();
    if (text.isEmpty) return 'Required (YYYY-MM-DD)';
    if (!isValidIsoCalendarDate(text)) return 'Use valid YYYY-MM-DD';
    return null;
  }

  Future<void> _pickIssueDate() async {
    final firstDate = DateTime(2000);
    final lastDate = DateTime(2100, 12, 31);
    final rawInitial =
        parseLocalCalendarDate(_issueDateController.text.trim()) ?? DateTime.now();
    final initialDate = rawInitial.isBefore(firstDate)
        ? firstDate
        : (rawInitial.isAfter(lastDate) ? lastDate : rawInitial);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked != null && mounted) {
      setState(() {
        _issueDateController.text =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  void _handleSave({bool isDraft = false}) {
    if (_selectedClientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a client first.')),
      );
      return;
    }

    final issueDate = _issueDateController.text.trim();
    if (!isValidIsoCalendarDate(issueDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid Issue Date in YYYY-MM-DD format.'),
        ),
      );
      return;
    }

    if (_items.isEmpty || _items.every((it) => it.description.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one line item with a description.')),
      );
      return;
    }

    final profile = ref.read(businessProfileProvider);
    final curCode = _overrideCurrencyCode ?? profile.currencyCode;
    final curSym = _overrideCurrencySymbol ?? profile.currencySymbol;
    final curDec = _overrideCurrencyDecimals ?? getCurrencyDecimals(curCode);

    final discVal = _effectiveDiscountValue(curDec);
    final resolvedDiscount = calculateDiscountCents(_subtotalCents, _discountType, discVal);
    final subAfterDisc = (_subtotalCents - resolvedDiscount).clamp(0, _subtotalCents);

    final zeroRated = isZeroRatedTaxMode(_taxMode);
    final draftItems = _items
        .where((i) => i.description.trim().isNotEmpty)
        .map((i) {
          final lineTotal = i.totalCents;
          final lineNet = _subtotalCents > 0
              ? (lineTotal * subAfterDisc + (_subtotalCents ~/ 2)) ~/ _subtotalCents
              : lineTotal;
          final itemTaxCents = zeroRated ? 0 : calculateTaxCents(lineNet, i.taxSlab);
          return DraftItem(
            description: i.description.trim(),
            sacHsn: i.sacHsn.trim(),
            quantity: i.quantity,
            unitPriceCents: i.unitPriceCents,
            taxRatePercentage: zeroRated ? 0 : i.taxSlab,
            taxCents: itemTaxCents,
            totalCents: i.totalCents,
          );
        })
        .toList();

    final dueDate = _calculateDueDate(issueDate, _paymentTerms);
    final effectiveQuoteExpiry = (widget.existingEstimate != null &&
            !_paymentTermsChanged &&
            issueDate == widget.existingEstimate!.issueDate &&
            (_initialQuoteExpiryDate?.isNotEmpty ?? false))
        ? _initialQuoteExpiryDate!
        : dueDate;

    final avgTaxPct = zeroRated ? 0 : (_items.isNotEmpty ? _items.first.taxSlab : 10);
    final docStatus = isDraft ? 'DRAFT' : 'PENDING';
    final pstPct = _taxMode == TaxMode.caDual ? _pstRatePct : 0;
    final exemptionId = _taxMode == TaxMode.usExempt ? _exemptionIdController.text.trim() : '';

    if (widget.isQuote) {
      ref.read(estimatesProvider.notifier).saveEstimate(
            existingEstimateId: widget.existingEstimate?.id,
            clientId: _selectedClientId!,
            items: draftItems,
            taxPercentage: avgTaxPct,
            issueDate: issueDate,
            expiryDate: effectiveQuoteExpiry,
            terms: _termsController.text.trim(),
            notes: _notesController.text.trim(),
            discountType: _discountType,
            discountValue: discVal,
            poNumber: _poNumberController.text.trim(),
            currencyCode: curCode,
            currencySymbol: curSym,
            currencyDecimals: curDec,
            taxMode: _taxMode,
            pstRatePercentage: pstPct,
            taxExemptionId: exemptionId,
            status: docStatus,
          );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isDraft ? 'Quote saved as Draft!' : 'Quote saved and issued successfully!')),
      );
    } else {
      ref.read(invoicesProvider.notifier).saveInvoice(
            existingInvoiceId: widget.existingInvoice?.id,
            clientId: _selectedClientId!,
            items: draftItems,
            taxPercentage: avgTaxPct,
            paymentTerms: _paymentTerms,
            issueDate: issueDate,
            dueDate: dueDate,
            terms: _termsController.text.trim(),
            notes: _notesController.text.trim(),
            discountType: _discountType,
            discountValue: discVal,
            poNumber: _poNumberController.text.trim(),
            currencyCode: curCode,
            currencySymbol: curSym,
            currencyDecimals: curDec,
            taxMode: _taxMode,
            pstRatePercentage: pstPct,
            taxExemptionId: exemptionId,
            status: docStatus,
          );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isDraft ? 'Invoice saved as Draft!' : 'Invoice saved and issued successfully!')),
      );
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final constraints = MediaQuery.sizeOf(context);
    final isWide = constraints.width >= 900;
    final profile = ref.watch(businessProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isQuote ? 'Two-Column Live Quote Editor' : 'Two-Column Live Invoice Editor',
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: isWide
            ? [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel / Back'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.drafts_outlined, size: 16),
                  label: const Text('Save as Draft'),
                  onPressed: () => _handleSave(isDraft: true),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  icon: const Icon(Icons.check, size: 16),
                  label: Text(widget.isQuote ? 'Save & Issue Quote' : 'Save & Issue Invoice'),
                  onPressed: () => _handleSave(isDraft: false),
                ),
                const SizedBox(width: 16),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.drafts_outlined),
                  tooltip: 'Save as Draft',
                  onPressed: () => _handleSave(isDraft: true),
                ),
                IconButton(
                  icon: const Icon(Icons.check),
                  tooltip: 'Save & Issue',
                  onPressed: () => _handleSave(isDraft: false),
                ),
              ],
      ),
      body: isWide ? _buildSplitView(profile) : _buildMobileView(profile),
    );
  }

  Widget _buildSplitView(BusinessProfile profile) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 1,
          child: _buildEditor(profile),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          flex: 1,
          child: _buildPreview(profile),
        ),
      ],
    );
  }

  Widget _buildMobileView(BusinessProfile profile) {
    return SafeArea(
      top: false,
      child: Column(
        children: [
          Expanded(
            child: _mobileTabIndex == 0 ? _buildEditor(profile) : _buildPreview(profile),
          ),
          NavigationBar(
            selectedIndex: _mobileTabIndex,
            onDestinationSelected: (i) => setState(() => _mobileTabIndex = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.edit_note), label: 'Editor'),
              NavigationDestination(icon: Icon(Icons.preview_outlined), label: 'Live A4 Preview'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditor(BusinessProfile profile) {
    final catalog = ref.watch(savedItemsProvider);
    final curCode = _overrideCurrencyCode ?? profile.currencyCode;
    final curSym = _overrideCurrencySymbol ?? profile.currencySymbol;
    final curDec = _overrideCurrencyDecimals ?? getCurrencyDecimals(curCode);
    String formatCurrency(int units) => formatMoney(units, symbol: curSym, decimals: curDec);

    final isCompactEditor = MediaQuery.sizeOf(context).width < 520;
    final issueDateField = TextField(
      controller: _issueDateController,
      keyboardType: TextInputType.datetime,
      decoration: InputDecoration(
        labelText: 'Issue Date (YYYY-MM-DD)',
        hintText: 'YYYY-MM-DD',
        errorText: _issueDateError,
        border: const OutlineInputBorder(),
        isDense: true,
        suffixIcon: IconButton(
          icon: const Icon(Icons.calendar_today, size: 18),
          tooltip: 'Pick Issue Date',
          onPressed: _pickIssueDate,
        ),
      ),
      onChanged: (_) => setState(() {}),
    );
    final termsDropdown = DropdownButtonFormField<String>(
      value: _paymentTerms,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: widget.isQuote ? 'Validity Period' : 'Payment Terms',
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      items: const [
        DropdownMenuItem(value: 'Due on Receipt', child: Text('Due on Receipt')),
        DropdownMenuItem(value: 'Net 15 Days', child: Text('Net 15 Days')),
        DropdownMenuItem(value: 'Net 30 Days', child: Text('Net 30 Days')),
        DropdownMenuItem(value: 'Net 60 Days', child: Text('Net 60 Days')),
      ],
      onChanged: (val) {
        if (val != null) {
          setState(() {
            _paymentTerms = val;
            _paymentTermsChanged = true;
          });
        }
      },
    );
    final poField = TextField(
      controller: _poNumberController,
      decoration: const InputDecoration(
        labelText: 'PO / Client Reference # (Optional)',
        hintText: 'e.g. PO-2026-9874',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: (_) => setState(() {}),
    );
    final currencyOverrideDropdown = DropdownButtonFormField<String>(
      value: _overrideCurrencyCode ?? profile.currencyCode,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Currency Override',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: const [
        DropdownMenuItem(value: 'USD', child: Text('USD (\$)')),
        DropdownMenuItem(value: 'INR', child: Text('INR (₹)')),
        DropdownMenuItem(value: 'EUR', child: Text('EUR (€)')),
        DropdownMenuItem(value: 'GBP', child: Text('GBP (£)')),
        DropdownMenuItem(value: 'JPY', child: Text('JPY (¥)')),
        DropdownMenuItem(value: 'KRW', child: Text('KRW (₩)')),
        DropdownMenuItem(value: 'CAD', child: Text('CAD (C\$)')),
        DropdownMenuItem(value: 'AUD', child: Text('AUD (A\$)')),
        DropdownMenuItem(value: 'AED', child: Text('AED (UAE)')),
        DropdownMenuItem(value: 'SAR', child: Text('SAR (KSA)')),
        DropdownMenuItem(value: 'KWD', child: Text('KWD (Kuwait - 3 dec)')),
        DropdownMenuItem(value: 'BHD', child: Text('BHD (Bahrain - 3 dec)')),
        DropdownMenuItem(value: 'OMR', child: Text('OMR (Oman - 3 dec)')),
        DropdownMenuItem(value: 'JOD', child: Text('JOD (Jordan - 3 dec)')),
        DropdownMenuItem(value: 'TND', child: Text('TND (Tunisia - 3 dec)')),
      ],
      onChanged: (code) {
        if (code == null) return;
        setState(() {
          _overrideCurrencyCode = code;
          _overrideCurrencyDecimals = getCurrencyDecimals(code);
          if (code == 'INR') { _overrideCurrencySymbol = '₹'; }
          else if (code == 'EUR') { _overrideCurrencySymbol = '€'; }
          else if (code == 'GBP') { _overrideCurrencySymbol = '£'; }
          else if (code == 'JPY') { _overrideCurrencySymbol = '¥'; }
          else if (code == 'KRW') { _overrideCurrencySymbol = '₩'; }
          else if (code == 'CAD') { _overrideCurrencySymbol = 'C\$'; }
          else if (code == 'AUD') { _overrideCurrencySymbol = 'A\$'; }
          else if (code == 'AED' || code == 'SAR' || code == 'KWD' || code == 'BHD' || code == 'OMR' || code == 'JOD' || code == 'TND') {
            _overrideCurrencySymbol = code;
          }
          else { _overrideCurrencySymbol = '\$'; }
        });
      },
    );

    final taxModeDropdown = DropdownButtonFormField<String>(
      value: _taxMode,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Regional Tax Compliance Mode',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: TaxMode.all.map((mode) {
        return DropdownMenuItem<String>(
          value: mode,
          child: Text(
            taxModeLabels[mode] ?? mode,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
        );
      }).toList(),
      onChanged: (val) {
        if (val != null) setState(() => _taxMode = val);
      },
    );

    return SingleChildScrollView(
      padding: EdgeInsets.all(isCompactEditor ? 14 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Client Autocomplete Picker
          Text(
            'Client & Billing Particulars',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          ClientAutocompletePicker(
            selectedClientId: _selectedClientId,
            onClientSelected: (id) => setState(() => _selectedClientId = id),
          ),
          const SizedBox(height: 16),

          // Date & Terms
          if (isCompactEditor) ...[
            issueDateField,
            const SizedBox(height: 12),
            termsDropdown,
            const SizedBox(height: 12),
            poField,
            const SizedBox(height: 12),
            currencyOverrideDropdown,
          ] else ...[
            Row(
              children: [
                Expanded(child: issueDateField),
                const SizedBox(width: 12),
                Expanded(child: termsDropdown),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(flex: 3, child: poField),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: currencyOverrideDropdown),
              ],
            ),
          ],
          const SizedBox(height: 14),
          taxModeDropdown,
          if (_taxMode == TaxMode.caDual) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _pstRateController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Canada PST Rate (%)',
                hintText: '7',
                border: OutlineInputBorder(),
                isDense: true,
                suffixText: '%',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
          if (_taxMode == TaxMode.usExempt) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _exemptionIdController,
              decoration: const InputDecoration(
                labelText: 'Client Tax Exemption Certificate ID (Optional)',
                hintText: 'e.g. EX-99412-CA',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
          if (isZeroRatedTaxMode(_taxMode)) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.indigo.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.indigo.withValues(alpha: 0.3)),
              ),
              child: const Text(
                'Zero-rated statutory mode active: Total tax is automatically locked to 0 and compliance notice is embedded on the document.',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
              ),
            ),
          ],
          const SizedBox(height: 20),

          // Catalog Quick Insert Dropdown
          if (catalog.isNotEmpty) ...[
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.flash_on, size: 16, color: Colors.amber),
                    SizedBox(width: 6),
                    Text('Quick-Insert from Catalog:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
                DropdownButton<String>(
                  hint: const Text('Select preset item...', style: TextStyle(fontSize: 12)),
                  underline: const SizedBox(),
                  items: catalog.map((item) {
                    return DropdownMenuItem(
                      value: item.id,
                      child: Text('${item.title} (${formatCurrency(item.defaultPriceCents)})', style: const TextStyle(fontSize: 12)),
                    );
                  }).toList(),
                  onChanged: (itemId) {
                    if (itemId == null) return;
                    final item = catalog.firstWhere((it) => it.id == itemId);
                    setState(() {
                      final newEntry = LineItemEntry(
                        description: item.title,
                        sacHsn: item.sacHsn,
                        quantity: 1,
                        unitPriceCents: item.defaultPriceCents,
                        taxSlab: 10,
                      );
                      if (_items.length == 1 &&
                          _items.first.description.trim().isEmpty &&
                          _items.first.unitPriceCents == 0) {
                        _items[0] = newEntry;
                      } else {
                        _items.add(newEntry);
                      }
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // Line Items Table
          Text(
            'Line Items',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          ..._items.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            final qtyField = TextFormField(
              initialValue: item.quantity.toString(),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Qty',
                isDense: true,
              ),
              onChanged: (v) => setState(() => item.quantity = int.tryParse(v) ?? 1),
            );
            final priceField = TextFormField(
              key: ValueKey('price_${idx}_$curDec'),
              initialValue: formatDecimalUnits(item.unitPriceCents, curDec),
              keyboardType: curDec == 0
                  ? TextInputType.number
                  : const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Price ($curSym)',
                isDense: true,
              ),
              onChanged: (v) => setState(
                () => item.unitPriceCents = parsePriceToUnits(v, curDec),
              ),
            );
            final slabOptions = <int>{0, 5, 10, 12, 15, 18, 20, item.taxSlab}.toList()..sort();
            final taxSlabField = DropdownButtonFormField<int>(
              value: item.taxSlab,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: _taxMode == TaxMode.caDual ? 'GST Slab' : 'Tax Slab',
                isDense: true,
              ),
              items: slabOptions
                  .map((s) => DropdownMenuItem(value: s, child: Text('$s%')))
                  .toList(),
              onChanged: isZeroRatedTaxMode(_taxMode)
                  ? null
                  : (v) {
                      if (v != null) setState(() => item.taxSlab = v);
                    },
            );
            final totalText = Text(
              formatCurrency(item.totalCents),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            );

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            initialValue: item.description,
                            decoration: const InputDecoration(
                              labelText: 'Description *',
                              isDense: true,
                            ),
                            onChanged: (v) => setState(() => item.description = v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            initialValue: item.sacHsn,
                            decoration: const InputDecoration(
                              labelText: 'SAC/HSN',
                              isDense: true,
                            ),
                            onChanged: (v) => setState(() => item.sacHsn = v),
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                          onPressed: () => _removeItem(idx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (isCompactEditor) ...[
                      Row(
                        children: [
                          Expanded(flex: 2, child: qtyField),
                          const SizedBox(width: 8),
                          Expanded(flex: 3, child: priceField),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: taxSlabField),
                          const SizedBox(width: 12),
                          totalText,
                        ],
                      ),
                    ] else
                      Row(
                        children: [
                          Expanded(child: qtyField),
                          const SizedBox(width: 8),
                          Expanded(child: priceField),
                          const SizedBox(width: 8),
                          Expanded(child: taxSlabField),
                          const SizedBox(width: 12),
                          totalText,
                        ],
                      ),
                  ],
                ),
              ),
            );
          }),

          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Line Item'),
              onPressed: _addItem,
            ),
          ),
          const SizedBox(height: 16),

          // Discount Selector
          if (isCompactEditor) ...[
            DropdownButtonFormField<String>(
              value: _discountType,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Discount Type', isDense: true),
              items: const [
                DropdownMenuItem(value: 'none', child: Text('None')),
                DropdownMenuItem(value: 'percent', child: Text('Percentage (%)')),
                DropdownMenuItem(value: 'flat', child: Text('Flat Amount')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _discountType = val);
              },
            ),
            if (_discountType != 'none') ...[
              const SizedBox(height: 10),
              TextField(
                controller: _discountController,
                decoration: InputDecoration(
                  labelText: _discountType == 'percent' ? 'Discount %' : 'Discount Amount',
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
          ] else
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _discountType,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Discount Type', isDense: true),
                    items: const [
                      DropdownMenuItem(value: 'none', child: Text('None')),
                      DropdownMenuItem(value: 'percent', child: Text('Percentage (%)')),
                      DropdownMenuItem(value: 'flat', child: Text('Flat Amount')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _discountType = val);
                    },
                  ),
                ),
                if (_discountType != 'none') ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _discountController,
                      decoration: InputDecoration(
                        labelText: _discountType == 'percent' ? 'Discount %' : 'Discount Amount',
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ],
            ),
          const SizedBox(height: 16),

          // Terms & Notes
          TextField(
            controller: _termsController,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Payment Terms / Conditions', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Notes / Remarks', border: OutlineInputBorder()),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(BusinessProfile profile) {
    final clients = ref.watch(clientsProvider);
    final curSym = _overrideCurrencySymbol ?? profile.currencySymbol;
    final curDec = _overrideCurrencyDecimals ?? profile.currencyDecimals;
    String formatCurrency(int cents) => formatMoney(cents, symbol: curSym, decimals: curDec);
    final client = _selectedClientId != null
        ? clients.firstWhere(
            (c) => c.id == _selectedClientId,
            orElse: () => Client(id: '', name: 'Selected Client', createdAt: ''),
          )
        : null;

    final isCompactScreen = MediaQuery.sizeOf(context).width < 600;
    final breakdown = resolveRegionalTaxBreakdown(
      taxMode: _taxMode,
      netSubtotalCents: _netSubtotalCents,
      taxCents: _taxCents,
      pstRatePercentage: _pstRatePct,
      taxExemptionId: _exemptionIdController.text,
      businessTaxId: profile.taxId,
      clientTaxId: client?.taxId ?? '',
      fallbackAutoDetect: true,
      clientAddress: client?.address ?? '',
      notes: _notesController.text,
      terms: _termsController.text,
    );
    final supplierTaxLabel = getRegionalTaxIdLabel(breakdown.effectiveMode);
    final clientTaxLabel = getRegionalTaxIdLabel(breakdown.effectiveMode, isClient: true);

    return Container(
      color: Colors.grey.shade100,
      padding: EdgeInsets.all(isCompactScreen ? 12 : 24),
      child: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(isCompactScreen ? 18 : 32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.start,
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.businessName.isNotEmpty ? profile.businessName : 'My Freelance Studio',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          if (profile.email.isNotEmpty) Text(profile.email, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          if (profile.phone.isNotEmpty) Text(profile.phone, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          if (profile.taxId.isNotEmpty) Text('$supplierTaxLabel: ${profile.taxId}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: widget.isQuote ? Colors.amber.shade50 : Colors.indigo.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          widget.isQuote ? 'ESTIMATE / QUOTE' : 'TAX INVOICE',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: widget.isQuote ? Colors.amber.shade900 : Colors.indigo.shade900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 28),

                  // Bill To & Meta
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.start,
                    spacing: 16,
                    runSpacing: 10,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('BILL TO:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                          Text(client?.name ?? 'Select a Client', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
                          if (client != null && client.email.isNotEmpty) Text(client.email, style: const TextStyle(fontSize: 11, color: Colors.black87)),
                          if (client != null && client.taxId.isNotEmpty) Text('$clientTaxLabel: ${client.taxId}', style: const TextStyle(fontSize: 11, color: Colors.black87)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Date: ${_issueDateController.text}', style: const TextStyle(fontSize: 11, color: Colors.black87)),
                          Text('Terms: $_paymentTerms', style: const TextStyle(fontSize: 11, color: Colors.black87)),
                          if (_poNumberController.text.trim().isNotEmpty)
                            Text('PO #: ${_poNumberController.text.trim()}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (breakdown.noticeText.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: breakdown.isZeroRated ? Colors.indigo.shade50 : Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: breakdown.isZeroRated ? Colors.indigo.shade300 : Colors.amber.shade300,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (breakdown.noticeTitle.isNotEmpty)
                            Text(
                              breakdown.noticeTitle,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: breakdown.isZeroRated ? Colors.indigo.shade900 : Colors.amber.shade900,
                              ),
                            ),
                          Text(
                            breakdown.noticeText,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Items Table
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: constraints.maxWidth,
                            maxWidth: math.max(constraints.maxWidth, 420),
                          ),
                          child: Table(
                            columnWidths: const {
                              0: FlexColumnWidth(4),
                              1: FlexColumnWidth(1),
                              2: FlexColumnWidth(2),
                              3: FlexColumnWidth(2),
                            },
                            children: [
                              const TableRow(
                                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black26))),
                                children: [
                                  Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Item', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87))),
                                  Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Qty', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87))),
                                  Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Rate', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87))),
                                  Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('Amount', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87))),
                                ],
                              ),
                              ..._items.map((i) => TableRow(
                                    children: [
                                      Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(i.description.isNotEmpty ? i.description : '—', style: const TextStyle(fontSize: 11, color: Colors.black87))),
                                      Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text('${i.quantity}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Colors.black87, fontFeatures: [FontFeature.tabularFigures()]))),
                                      Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(formatCurrency(i.unitPriceCents), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, color: Colors.black87, fontFeatures: [FontFeature.tabularFigures()]))),
                                      Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(formatCurrency(i.totalCents), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87, fontFeatures: [FontFeature.tabularFigures()]))),
                                    ],
                                  )),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  const Divider(),

                  // Totals
                  Align(
                    alignment: Alignment.centerRight,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 240),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Subtotal:', style: TextStyle(fontSize: 11, color: Colors.black87)),
                              Text(formatCurrency(_subtotalCents), style: const TextStyle(fontSize: 11, color: Colors.black87, fontFeatures: [FontFeature.tabularFigures()])),
                            ],
                          ),
                          if (_discountCents > 0) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Discount:', style: TextStyle(fontSize: 11, color: Colors.orange)),
                                Text('-${formatCurrency(_discountCents)}', style: const TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold, fontFeatures: [FontFeature.tabularFigures()])),
                              ],
                            ),
                          ],
                          ...breakdown.lines.map((line) => Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('${line.label}:', style: const TextStyle(fontSize: 11, color: Colors.black87)),
                                    Text(formatCurrency(line.cents), style: const TextStyle(fontSize: 11, color: Colors.black87, fontFeatures: [FontFeature.tabularFigures()])),
                                  ],
                                ),
                              )),
                          const Divider(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
                              Text(formatCurrency(_totalCents), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFeatures: const [FontFeature.tabularFigures()], color: Theme.of(context).colorScheme.primary)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (profile.paymentDetails.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Payment Instructions:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87)),
                          const SizedBox(height: 2),
                          Text(profile.paymentDetails, style: const TextStyle(fontSize: 10, color: Colors.black87)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
