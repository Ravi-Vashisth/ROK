import React, { useState, useMemo } from 'react';
import {
  ArrowLeft,
  Save,
  Check,
  Trash2,
  UserPlus,
  Search,
  Calendar,
  Clock,
  Bookmark,
  ShoppingCart,
  Gavel,
  FileText,
  CheckCircle2,
  AlertCircle,
  ShieldCheck,
} from 'lucide-react';
import {
  TAX_MODE_LABELS,
  TaxMode,
  calculateDiscountCents,
  calculateDueDate,
  calculateTaxCents,
  computeRegionalTaxCents,
  formatDecimalUnits,
  formatMoney as formatMoneyUnits,
  getCurrencyDecimals,
  getRegionalTaxIdLabel,
  isZeroRatedTaxMode,
  normalizeTaxMode,
  parsePriceToUnits,
  resolveRegionalTaxBreakdown,
} from '../../billingRules';

const CURRENCY_SYMBOLS: Record<string, string> = {
  USD: '$',
  INR: '₹',
  EUR: '€',
  GBP: '£',
  JPY: '¥',
  KRW: '₩',
  CAD: 'C$',
  AUD: 'A$',
  AED: 'AED',
  SAR: 'SAR',
};

const TAX_SLAB_OPTIONS = [0, 5, 10, 12, 15, 18, 20];

interface InvoiceEditorScreenProps {
  isQuote: boolean;
  initialData?: any;
  nextDocNumber?: string;
  isDarkMode: boolean;
  businessProfile: any;
  clients: any[];
  savedItems: any[];
  currencySymbol: string;
  formatMoney: (cents: number) => string;
  parsePriceToCents: (val: string) => number;
  onSave: (docData: any) => void;
  onCancel: () => void;
  onAddClientModal?: (cData: any) => void;
  onNotify?: (message: string, isError?: boolean) => void;
}

export const InvoiceEditorScreen: React.FC<InvoiceEditorScreenProps> = ({
  isQuote,
  initialData,
  nextDocNumber,
  isDarkMode,
  businessProfile,
  clients,
  savedItems,
  currencySymbol,
  formatMoney,
  onSave,
  onCancel,
  onAddClientModal,
  onNotify,
}) => {
  const [selectedClientId, setSelectedClientId] = useState<string>(
    initialData?.client_id || clients[0]?.id || ''
  );
  const [clientSearch, setClientSearch] = useState<string>('');
  const [isClientDropdownOpen, setIsClientDropdownOpen] = useState<boolean>(false);

  const [issueDate, setIssueDate] = useState<string>(
    initialData?.issue_date || new Date().toISOString().split('T')[0]
  );
  const [paymentTerms, setPaymentTerms] = useState<string>(
    initialData?.payment_terms || (isQuote ? 'Net 30 Days' : 'Due on Receipt')
  );
  const [paymentTermsChanged, setPaymentTermsChanged] = useState<boolean>(false);
  const [poNumber, setPoNumber] = useState<string>(initialData?.po_number || '');
  const [overrideCurrencyCode, setOverrideCurrencyCode] = useState<string>(
    initialData?.currency_code || businessProfile.currency_code || 'USD'
  );
  const activeCurrencyDecimals = useMemo(() => {
    if (
      initialData?.currency_code === overrideCurrencyCode &&
      typeof initialData?.currency_decimals === 'number'
    ) {
      return initialData.currency_decimals;
    }
    return getCurrencyDecimals(overrideCurrencyCode);
  }, [initialData, overrideCurrencyCode]);

  const activeCurrencySymbol = useMemo(() => {
    if (
      initialData?.currency_code === overrideCurrencyCode &&
      initialData?.currency_symbol
    ) {
      return initialData.currency_symbol;
    }
    return CURRENCY_SYMBOLS[overrideCurrencyCode] || businessProfile.currency_symbol || currencySymbol || '$';
  }, [initialData, overrideCurrencyCode, businessProfile.currency_symbol, currencySymbol]);

  const formatDocMoney = (units: number) =>
    formatMoneyUnits(units, activeCurrencySymbol, activeCurrencyDecimals);

  const [terms, setTerms] = useState<string>(
    initialData?.terms || businessProfile.default_terms || 'Payment due within agreed terms. Thank you for your business!'
  );
  const [notes, setNotes] = useState<string>(
    initialData?.notes || businessProfile.default_notes || 'All work includes post-delivery support.'
  );

  const [discountType, setDiscountType] = useState<'none' | 'percent' | 'flat'>(
    initialData?.discount_type || 'none'
  );
  const [discountValue, setDiscountValue] = useState<string>(() => {
    if (initialData?.discount_type === 'flat') {
      const dec =
        initialData?.currency_decimals ??
        getCurrencyDecimals(initialData?.currency_code || businessProfile.currency_code || 'USD');
      return formatDecimalUnits(Number(initialData?.discount_value) || 0, dec);
    }
    return initialData?.discount_value?.toString() || '0';
  });

  const [taxMode, setTaxMode] = useState<TaxMode>(
    normalizeTaxMode(initialData?.tax_mode ?? businessProfile.default_tax_mode)
  );
  const [pstRatePercentage, setPstRatePercentage] = useState<string>(
    String(
      initialData?.pst_rate_percentage ??
        businessProfile.default_pst_rate_percentage ??
        7
    )
  );
  const [taxExemptionId, setTaxExemptionId] = useState<string>(
    initialData?.tax_exemption_id || ''
  );
  const [validationError, setValidationError] = useState<string>('');

  // Quick line item inputs matching Flutter InvoiceInputsCard
  const [itemDesc, setItemDesc] = useState<string>('');
  const [itemSacHsn, setItemSacHsn] = useState<string>('');
  const [itemPrice, setItemPrice] = useState<string>('');
  const [itemQty, setItemQty] = useState<string>('1');
  const [itemTaxSlab, setItemTaxSlab] = useState<number>(10);

  // Add Client Modal State
  const [isAddClientOpen, setIsAddClientOpen] = useState<boolean>(false);
  const [newClientName, setNewClientName] = useState<string>('');
  const [newClientEmail, setNewClientEmail] = useState<string>('');
  const [newClientPhone, setNewClientPhone] = useState<string>('');
  const [newClientTaxId, setNewClientTaxId] = useState<string>('');
  const [newClientAddress, setNewClientAddress] = useState<string>('');

  const [items, setItems] = useState<any[]>(
    initialData?.items?.length
      ? initialData.items
      : [{ id: '1', description: 'Full Stack Web Development', sacHsn: '998314', quantity: 1, unitPriceCents: 150000, taxSlab: 10 }]
  );

  const selectedClient = clients.find((c) => c.id === selectedClientId);

  const computedDueDate = useMemo(() => {
    if (
      isQuote &&
      initialData?.expiry_date &&
      !paymentTermsChanged &&
      issueDate === initialData?.issue_date
    ) {
      return initialData.expiry_date;
    }
    return calculateDueDate(issueDate, paymentTerms);
  }, [isQuote, initialData, paymentTermsChanged, issueDate, paymentTerms]);

  const activeItems = useMemo(() => {
    return items.filter((it) => !(it.description.trim() === '' && it.unitPriceCents === 0));
  }, [items]);

  const subtotalCents = activeItems.reduce((sum, item) => sum + item.quantity * item.unitPriceCents, 0);

  const effectiveDiscountValue = useMemo(() => {
    if (discountType === 'none') return 0;
    if (discountType === 'percent') {
      return Math.min(100, Math.max(0, Math.round(parseFloat(discountValue) || 0)));
    }
    return parsePriceToUnits(discountValue, activeCurrencyDecimals);
  }, [discountType, discountValue, activeCurrencyDecimals]);

  const discountCents = useMemo(() => {
    return calculateDiscountCents(subtotalCents, discountType, effectiveDiscountValue);
  }, [subtotalCents, discountType, effectiveDiscountValue]);

  const netSubtotalCents = Math.max(0, subtotalCents - discountCents);

  const parsedPstRate = useMemo(() => {
    return Math.min(100, Math.max(0, Math.round(Number(pstRatePercentage) || 0)));
  }, [pstRatePercentage]);

  const itemsTaxSumCents = useMemo(() => {
    if (subtotalCents <= 0) return 0;
    return activeItems.reduce((sum, item) => {
      const lineTotal = item.quantity * item.unitPriceCents;
      const lineShare = Math.floor((lineTotal * netSubtotalCents + Math.floor(subtotalCents / 2)) / subtotalCents);
      return sum + calculateTaxCents(lineShare, item.taxSlab ?? 10);
    }, 0);
  }, [activeItems, subtotalCents, netSubtotalCents]);

  const taxCents = useMemo(() => {
    return computeRegionalTaxCents({
      netSubtotalCents,
      taxMode,
      taxPercentage: activeItems[0]?.taxSlab ?? 10,
      pstRatePercentage: taxMode === 'ca_dual' ? parsedPstRate : 0,
      itemsTaxSumCents,
    });
  }, [netSubtotalCents, taxMode, activeItems, parsedPstRate, itemsTaxSumCents]);

  const totalCents = netSubtotalCents + taxCents;

  const taxBreakdown = useMemo(() => {
    return resolveRegionalTaxBreakdown({
      taxMode,
      netSubtotalCents,
      taxCents,
      pstRatePercentage: taxMode === 'ca_dual' ? parsedPstRate : 0,
      taxExemptionId,
      businessTaxId: businessProfile.tax_id,
      clientTaxId: selectedClient?.tax_id,
      fallbackAutoDetect: true,
      clientAddress: selectedClient?.address,
      notes,
      terms,
    });
  }, [
    taxMode,
    netSubtotalCents,
    taxCents,
    parsedPstRate,
    taxExemptionId,
    businessProfile.tax_id,
    selectedClient?.tax_id,
    selectedClient?.address,
    notes,
    terms,
  ]);

  const isZeroRated = isZeroRatedTaxMode(taxMode);

  const reportValidationError = (msg: string) => {
    setValidationError(msg);
    onNotify?.(msg, true);
  };

  const handleAddQuickItem = () => {
    if (!itemDesc.trim()) {
      reportValidationError('Please enter an item description.');
      return;
    }
    const cents = parsePriceToUnits(itemPrice, activeCurrencyDecimals);
    if (cents <= 0) {
      reportValidationError('Please enter a valid positive unit price.');
      return;
    }
    setValidationError('');
    const q = Math.max(1, parseInt(itemQty, 10) || 1);
    const newItem = {
      id: Date.now().toString(),
      description: itemDesc.trim(),
      sacHsn: itemSacHsn.trim(),
      quantity: q,
      unitPriceCents: cents,
      taxSlab: isZeroRated ? 0 : itemTaxSlab,
    };
    setItems((prev) => {
      if (prev.length === 1 && (!prev[0].description?.trim() || prev[0].description === '—') && prev[0].unitPriceCents === 0) {
        return [newItem];
      }
      return [...prev, newItem];
    });
    setItemDesc('');
    setItemSacHsn('');
    setItemPrice('');
    setItemQty('1');
  };

  const handleUpdateItemTaxSlab = (id: string, slab: number) => {
    setItems((prev) =>
      prev.map((it) => (it.id === id ? { ...it, taxSlab: slab } : it))
    );
  };

  const handleRemoveItem = (id: string) => {
    if (items.length <= 1) return;
    setItems((prev) => prev.filter((i) => i.id !== id));
  };

  const handleSelectPresetItem = (itemId: string) => {
    const preset = savedItems.find((it) => it.id === itemId);
    if (!preset) return;
    setValidationError('');
    const newItem = {
      id: Date.now().toString(),
      description: preset.title,
      sacHsn: preset.sacHsn || '',
      quantity: 1,
      unitPriceCents: preset.defaultPriceCents || 0,
      taxSlab: isZeroRated ? 0 : (preset.taxSlab ?? 10),
    };
    setItems((prev) => {
      if (prev.length === 1 && (!prev[0].description?.trim() || prev[0].description === '—') && prev[0].unitPriceCents === 0) {
        return [newItem];
      }
      return [...prev, newItem];
    });
  };

  const handleSaveNewClientModal = () => {
    if (!newClientName.trim()) {
      reportValidationError('Client name is required.');
      return;
    }
    setValidationError('');
    if (onAddClientModal) {
      onAddClientModal({
        name: newClientName.trim(),
        email: newClientEmail.trim(),
        phone: newClientPhone.trim(),
        taxId: newClientTaxId.trim(),
        address: newClientAddress.trim(),
      });
    }
    setNewClientName('');
    setNewClientEmail('');
    setNewClientPhone('');
    setNewClientTaxId('');
    setNewClientAddress('');
    setIsAddClientOpen(false);
  };

  const handleSaveDoc = (isDraft: boolean) => {
    if (!selectedClientId) {
      reportValidationError('Please select a client first.');
      return;
    }
    const validItems = items.filter((i) => i.description.trim().length > 0);
    if (validItems.length === 0) {
      reportValidationError('Please add at least one line item with a description.');
      return;
    }
    setValidationError('');

    onSave({
      existingId: initialData?.id,
      clientId: selectedClientId,
      clientName: selectedClient?.name || 'Client',
      issueDate,
      paymentTerms,
      expiryDate: computedDueDate,
      poNumber,
      currencyCode: overrideCurrencyCode,
      currencySymbol: activeCurrencySymbol,
      currencyDecimals: activeCurrencyDecimals,
      taxMode,
      pstRatePercentage: taxMode === 'ca_dual' ? parsedPstRate : 0,
      taxExemptionId: taxExemptionId.trim(),
      terms,
      notes,
      discountType,
      discountValue: effectiveDiscountValue,
      discountCents,
      subtotalCents,
      taxCents,
      totalCents,
      isDraft,
      items: validItems,
    });
  };

  const filteredClients = useMemo(() => {
    if (!clientSearch.trim()) return clients;
    const q = clientSearch.toLowerCase();
    return clients.filter((c) => c.name.toLowerCase().includes(q) || (c.email && c.email.toLowerCase().includes(q)) || (c.tax_id && c.tax_id.toLowerCase().includes(q)));
  }, [clients, clientSearch]);

  return (
    <div className="space-y-4">
      {/* Top Action Bar */}
      <div className={`p-4 rounded-xl border flex flex-wrap items-center justify-between gap-4 ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}>
        <button
          onClick={onCancel}
          className="flex items-center gap-2 text-xs font-bold text-slate-500 hover:text-slate-800 dark:hover:text-slate-200 cursor-pointer"
        >
          <ArrowLeft className="w-4 h-4" />
          <span>Cancel / Back</span>
        </button>

        <h3 className="font-bold text-sm">
          {isQuote ? 'Two-Column Live Quote Editor' : 'Two-Column Live Invoice Editor'}
        </h3>

        <div className="flex items-center gap-2">
          <button
            onClick={() => handleSaveDoc(true)}
            className="px-3 py-1.5 border border-slate-300 dark:border-slate-700 hover:bg-slate-50 dark:hover:bg-slate-800 text-xs font-bold rounded-xl flex items-center gap-1.5 cursor-pointer transition"
          >
            <Save className="w-3.5 h-3.5" />
            <span>Save as Draft</span>
          </button>
          <button
            onClick={() => handleSaveDoc(false)}
            className="px-4 py-1.5 bg-indigo-600 hover:bg-indigo-700 text-white text-xs font-bold rounded-xl flex items-center gap-1.5 cursor-pointer transition shadow-sm"
          >
            <Check className="w-3.5 h-3.5" />
            <span>{isQuote ? 'Save & Issue Quote' : 'Save & Issue Invoice'}</span>
          </button>
        </div>
      </div>

      {validationError && (
        <div className="p-3 rounded-xl border border-rose-300 dark:border-rose-800 bg-rose-50 dark:bg-rose-950/60 text-rose-700 dark:text-rose-300 text-xs font-semibold flex items-center gap-2">
          <AlertCircle className="w-4 h-4 shrink-0" />
          <span className="flex-1">{validationError}</span>
        </div>
      )}

      {/* Two-Column Split View */}
      <div className="grid grid-cols-1 min-[900px]:grid-cols-2 gap-6">
        {/* Editor Column */}
        <div className="space-y-4">
          {/* Section 1 Card: Client Selection */}
          <div className={`p-5 rounded-xl border space-y-3 ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}>
            <div className="flex flex-wrap items-center justify-between gap-2">
              <h4 className="font-bold text-xs uppercase tracking-wider text-slate-400">1. Client Selection & Billing Details</h4>
              <button
                onClick={() => setIsAddClientOpen(true)}
                className="text-xs font-bold text-indigo-600 dark:text-indigo-400 hover:underline flex items-center gap-1 cursor-pointer"
              >
                <UserPlus className="w-3.5 h-3.5" />
                <span>+ Add New Client</span>
              </button>
            </div>

            {/* Client Search Autocomplete */}
            <div className="relative">
              <div className="relative">
                <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
                <input
                  type="text"
                  value={clientSearch || (selectedClient ? selectedClient.name : '')}
                  onChange={(e) => {
                    setClientSearch(e.target.value);
                    setIsClientDropdownOpen(true);
                  }}
                  onFocus={() => setIsClientDropdownOpen(true)}
                  placeholder="Search Client by Name, Email or Tax ID..."
                  className={`w-full pl-9 pr-3 py-2.5 rounded-xl text-xs border focus:outline-none focus:ring-2 focus:ring-indigo-500 ${isDarkMode ? 'bg-slate-900 border-slate-800 text-slate-100' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
                />
              </div>

              {isClientDropdownOpen && (
                <div className={`absolute left-0 right-0 mt-1 max-h-52 overflow-y-auto rounded-xl border shadow-xl z-50 divide-y ${isDarkMode ? 'bg-[#0F172A] border-slate-800 divide-slate-800' : 'bg-white border-slate-200 divide-slate-100'}`}>
                  {filteredClients.map((c) => (
                    <button
                      key={c.id}
                      onClick={() => {
                        setSelectedClientId(c.id);
                        setClientSearch(c.name);
                        setIsClientDropdownOpen(false);
                      }}
                      className="w-full text-left p-2.5 hover:bg-slate-50 dark:hover:bg-slate-800 text-xs transition cursor-pointer"
                    >
                      <div className="font-bold">{c.name}</div>
                      <div className="text-[11px] text-slate-400">{c.email || 'No email'} {c.tax_id ? `• Tax ID: ${c.tax_id}` : ''}</div>
                    </button>
                  ))}
                  {clientSearch.trim() && (
                    <button
                      onClick={() => {
                        setNewClientName(clientSearch);
                        setIsClientDropdownOpen(false);
                        setIsAddClientOpen(true);
                      }}
                      className="w-full text-left p-2.5 hover:bg-indigo-50 dark:hover:bg-indigo-950 text-xs text-indigo-600 font-bold transition cursor-pointer flex items-center gap-1.5"
                    >
                      <UserPlus className="w-3.5 h-3.5" />
                      <span>+ Add new client "{clientSearch}"</span>
                    </button>
                  )}
                </div>
              )}
            </div>

            {/* Selected Client Card */}
            {selectedClient && (
              <div className={`p-3 rounded-xl border flex items-center gap-2.5 text-xs ${isDarkMode ? 'bg-indigo-950/40 border-indigo-900/60 text-indigo-200' : 'bg-indigo-50/70 border-indigo-200 text-indigo-900'}`}>
                <CheckCircle2 className="w-4 h-4 text-indigo-600 shrink-0" />
                <div className="min-w-0">
                  <div className="font-bold">{selectedClient.name}</div>
                  <div className="text-[11px] opacity-80">{selectedClient.email} {selectedClient.tax_id ? `• Tax ID: ${selectedClient.tax_id}` : ''} {selectedClient.address ? `• ${selectedClient.address}` : ''}</div>
                </div>
              </div>
            )}
          </div>

          {/* Section 2 Card: Line Items & Payment Terms */}
          <div className={`p-5 rounded-xl border space-y-4 ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}>
            <div className="flex flex-wrap items-center justify-between gap-2">
              <h4 className="font-bold text-xs uppercase tracking-wider text-slate-400">2. Invoice Line Items & Payment Terms</h4>
              <span className="font-mono text-xs font-bold text-indigo-600">
                {initialData?.invoice_number || initialData?.estimate_number
                  ? `Editing: ${initialData.invoice_number || initialData.estimate_number}`
                  : `Next: ${nextDocNumber || (isQuote ? 'EST-0001' : 'INV-0001')}`}
              </span>
            </div>

            {/* Date & Terms Row */}
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
              <div>
                <label className="block text-[11px] font-bold text-slate-500 mb-1 flex items-center gap-1">
                  <Calendar className="w-3.5 h-3.5" />
                  <span>Issue Date</span>
                </label>
                <input
                  type="date"
                  value={issueDate}
                  onChange={(e) => setIssueDate(e.target.value)}
                  className={`w-full p-2.5 rounded-xl text-xs border focus:outline-none ${isDarkMode ? 'bg-slate-900 border-slate-800 text-slate-100' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
                />
              </div>

              <div>
                <label className="block text-[11px] font-bold text-slate-500 mb-1 flex items-center gap-1">
                  <Clock className="w-3.5 h-3.5" />
                  <span>{isQuote ? 'Validity Period' : 'Payment Terms'}</span>
                </label>
                <select
                  value={paymentTerms}
                  onChange={(e) => {
                    setPaymentTerms(e.target.value);
                    setPaymentTermsChanged(true);
                  }}
                  className={`w-full p-2.5 rounded-xl text-xs border focus:outline-none ${isDarkMode ? 'bg-slate-900 border-slate-800 text-slate-100' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
                >
                  <option value="Due on Receipt">Due on Receipt</option>
                  <option value="Net 15 Days">Net 15 Days</option>
                  <option value="Net 30 Days">Net 30 Days</option>
                  <option value="Net 60 Days">Net 60 Days</option>
                </select>
              </div>

              <div className={`p-2.5 rounded-xl border flex items-center gap-2 ${isDarkMode ? 'bg-slate-900 border-slate-800' : 'bg-slate-50 border-slate-200'}`}>
                <Clock className="w-4 h-4 text-indigo-600 shrink-0" />
                <div className="min-w-0">
                  <div className="text-[10px] font-bold text-slate-400">{isQuote ? 'Expiry Date:' : 'Computed Due Date:'}</div>
                  <div className="font-mono font-bold text-xs text-indigo-600">{computedDueDate}</div>
                </div>
              </div>
            </div>

            {/* PO Number & Currency Override Row */}
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div>
                <label className="block text-[11px] font-bold text-slate-500 mb-1">PO / Client Reference # (Optional)</label>
                <input
                  type="text"
                  value={poNumber}
                  onChange={(e) => setPoNumber(e.target.value)}
                  placeholder="e.g. PO-2026-9874"
                  className={`w-full p-2.5 rounded-xl text-xs border focus:outline-none ${isDarkMode ? 'bg-slate-900 border-slate-800 text-slate-100' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
                />
              </div>
              <div>
                <label className="block text-[11px] font-bold text-slate-500 mb-1">Currency Override</label>
                <select
                  value={overrideCurrencyCode}
                  onChange={(e) => setOverrideCurrencyCode(e.target.value)}
                  className={`w-full p-2.5 rounded-xl text-xs border focus:outline-none ${isDarkMode ? 'bg-slate-900 border-slate-800 text-slate-100' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
                >
                  <option value="USD">USD ($)</option>
                  <option value="INR">INR (₹)</option>
                  <option value="EUR">EUR (€)</option>
                  <option value="GBP">GBP (£)</option>
                  <option value="JPY">JPY (¥)</option>
                  <option value="KRW">KRW (₩)</option>
                  <option value="CAD">CAD (C$)</option>
                  <option value="AUD">AUD (A$)</option>
                  <option value="AED">AED (UAE)</option>
                  <option value="SAR">SAR (KSA)</option>
                </select>
              </div>
            </div>

            {/* Regional Tax Compliance Row */}
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div className={taxMode === 'ca_dual' || taxMode === 'us_exempt' ? '' : 'sm:col-span-2'}>
                <label className="block text-[11px] font-bold text-slate-500 mb-1 flex items-center gap-1">
                  <ShieldCheck className="w-3.5 h-3.5 text-indigo-500" />
                  <span>Regional Tax Compliance Mode</span>
                </label>
                <select
                  value={taxMode}
                  onChange={(e) => setTaxMode(normalizeTaxMode(e.target.value))}
                  className={`w-full p-2.5 rounded-xl text-xs border focus:outline-none ${isDarkMode ? 'bg-slate-900 border-slate-800 text-slate-100' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
                >
                  {(Object.keys(TAX_MODE_LABELS) as TaxMode[]).map((mode) => (
                    <option key={mode} value={mode}>
                      {TAX_MODE_LABELS[mode]}
                    </option>
                  ))}
                </select>
              </div>

              {taxMode === 'ca_dual' && (
                <div>
                  <label className="block text-[11px] font-bold text-slate-500 mb-1">Canada PST Rate %</label>
                  <input
                    type="number"
                    min={0}
                    max={100}
                    value={pstRatePercentage}
                    onChange={(e) => setPstRatePercentage(e.target.value)}
                    className={`w-full p-2.5 rounded-xl text-xs border font-mono tabular-nums focus:outline-none ${isDarkMode ? 'bg-slate-900 border-slate-800 text-slate-100' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
                  />
                </div>
              )}

              {taxMode === 'us_exempt' && (
                <div>
                  <label className="block text-[11px] font-bold text-slate-500 mb-1">Client Exemption Certificate ID</label>
                  <input
                    type="text"
                    value={taxExemptionId}
                    onChange={(e) => setTaxExemptionId(e.target.value)}
                    placeholder="e.g. EX-998812-TX"
                    className={`w-full p-2.5 rounded-xl text-xs border focus:outline-none ${isDarkMode ? 'bg-slate-900 border-slate-800 text-slate-100' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
                  />
                </div>
              )}
            </div>

            {isZeroRated && (
              <div className="p-2.5 rounded-xl border border-amber-200 dark:border-amber-800 bg-amber-50 dark:bg-amber-950/40 text-amber-800 dark:text-amber-300 text-[11px] font-semibold">
                {TAX_MODE_LABELS[taxMode]} assesses 0% statutory tax and appends the legal declaration to your preview & PDF.
              </div>
            )}

            {/* Saved Service Library Quick Fill */}
            {savedItems.length > 0 && (
              <div className={`p-3 rounded-xl border flex flex-col sm:flex-row items-stretch sm:items-center gap-2 ${isDarkMode ? 'bg-slate-900/60 border-slate-800' : 'bg-blue-50/50 border-blue-200'}`}>
                <div className="flex items-center gap-2 shrink-0">
                  <Bookmark className="w-4 h-4 text-blue-600 shrink-0" />
                  <span className="text-xs font-bold">Saved Service Library:</span>
                </div>
                <select
                  onChange={(e) => {
                    if (e.target.value) handleSelectPresetItem(e.target.value);
                    e.target.value = '';
                  }}
                  className={`w-full p-1.5 rounded-lg text-xs border focus:outline-none ${isDarkMode ? 'bg-slate-900 border-slate-800 text-slate-200' : 'bg-white border-slate-200 text-slate-800'}`}
                >
                  <option value="">Select a preset service to 1-click auto-fill...</option>
                  {savedItems.map((item) => (
                    <option key={item.id} value={item.id}>
                      {item.title} ({formatMoney(item.defaultPriceCents || 0)})
                    </option>
                  ))}
                </select>
              </div>
            )}

            {/* Item Input Form Row */}
            <div className="grid grid-cols-1 sm:grid-cols-12 gap-2 items-end">
              <div className="sm:col-span-4">
                <label className="block text-[10px] font-bold text-slate-400 mb-0.5">Item Description</label>
                <input
                  type="text"
                  value={itemDesc}
                  onChange={(e) => setItemDesc(e.target.value)}
                  placeholder="e.g. Website Consulting"
                  className={`w-full p-2 rounded-lg text-xs border ${isDarkMode ? 'bg-slate-900 border-slate-800 text-slate-100' : 'bg-white border-slate-200 text-slate-900'}`}
                />
              </div>
              <div className="sm:col-span-2">
                <label className="block text-[10px] font-bold text-slate-400 mb-0.5">SAC / HSN</label>
                <input
                  type="text"
                  value={itemSacHsn}
                  onChange={(e) => setItemSacHsn(e.target.value)}
                  placeholder="998311"
                  className={`w-full p-2 rounded-lg text-xs border ${isDarkMode ? 'bg-slate-900 border-slate-800 text-slate-100' : 'bg-white border-slate-200 text-slate-900'}`}
                />
              </div>
              <div className="sm:col-span-2">
                <label className="block text-[10px] font-bold text-slate-400 mb-0.5">Price ({activeCurrencySymbol})</label>
                <input
                  type="text"
                  value={itemPrice}
                  onChange={(e) => setItemPrice(e.target.value)}
                  placeholder={activeCurrencyDecimals === 0 ? '2500' : '25.00'}
                  className={`w-full p-2 rounded-lg text-xs border ${isDarkMode ? 'bg-slate-900 border-slate-800 text-slate-100' : 'bg-white border-slate-200 text-slate-900'}`}
                />
              </div>
              <div className="sm:col-span-1">
                <label className="block text-[10px] font-bold text-slate-400 mb-0.5">Qty</label>
                <input
                  type="number"
                  min="1"
                  value={itemQty}
                  onChange={(e) => setItemQty(e.target.value)}
                  className={`w-full p-2 rounded-lg text-xs border ${isDarkMode ? 'bg-slate-900 border-slate-800 text-slate-100' : 'bg-white border-slate-200 text-slate-900'}`}
                />
              </div>
              <div className="sm:col-span-1">
                <label className="block text-[10px] font-bold text-slate-400 mb-0.5">Tax</label>
                <select
                  value={isZeroRated ? 0 : itemTaxSlab}
                  disabled={isZeroRated}
                  onChange={(e) => setItemTaxSlab(Number(e.target.value))}
                  className={`w-full p-2 rounded-lg text-xs border ${isDarkMode ? 'bg-slate-900 border-slate-800 text-slate-100' : 'bg-white border-slate-200 text-slate-900'} disabled:opacity-50`}
                >
                  {TAX_SLAB_OPTIONS.map((rate) => (
                    <option key={rate} value={rate}>
                      {rate}%
                    </option>
                  ))}
                </select>
              </div>
              <div className="sm:col-span-2">
                <button
                  onClick={handleAddQuickItem}
                  className="w-full py-2 bg-indigo-600 hover:bg-indigo-700 text-white font-bold text-xs rounded-lg flex items-center justify-center gap-1.5 transition cursor-pointer"
                >
                  <ShoppingCart className="w-3.5 h-3.5" />
                  <span>Add</span>
                </button>
              </div>
            </div>

            {/* Line Items Table */}
            {items.length === 0 ? (
              <div className={`p-8 rounded-xl border text-center text-xs text-slate-400 ${isDarkMode ? 'bg-slate-900/30 border-slate-800' : 'bg-slate-50 border-slate-200'}`}>
                No items in this invoice yet. Enter item details above and click "Add".
              </div>
            ) : (
              <div className={`rounded-xl border overflow-hidden ${isDarkMode ? 'border-slate-800' : 'border-slate-200'}`}>
                <div className="overflow-x-auto">
                  <table className="w-full text-left text-xs">
                    <thead className={`border-b ${isDarkMode ? 'bg-slate-900 border-slate-800 text-slate-400' : 'bg-slate-100 border-slate-200 text-slate-600'} font-bold`}>
                      <tr>
                        <th className="p-2.5">Description</th>
                        <th className="p-2.5 whitespace-nowrap">SAC / HSN</th>
                        <th className="p-2.5 text-center whitespace-nowrap">Qty</th>
                        <th className="p-2.5 text-right whitespace-nowrap">Unit Price</th>
                        <th className="p-2.5 text-center whitespace-nowrap">Tax %</th>
                        <th className="p-2.5 text-right whitespace-nowrap">Total</th>
                        <th className="p-2.5 text-center whitespace-nowrap">Action</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-slate-100 dark:divide-slate-800">
                      {items.map((it) => (
                        <tr key={it.id}>
                          <td className="p-2.5 font-medium">{it.description || '—'}</td>
                          <td className="p-2.5 text-slate-400 whitespace-nowrap">{it.sacHsn || '-'}</td>
                          <td className="p-2.5 text-center tabular-nums">{it.quantity}</td>
                          <td className="p-2.5 text-right font-mono tabular-nums whitespace-nowrap">{formatDocMoney(it.unitPriceCents)}</td>
                          <td className="p-2.5 text-center">
                            <select
                              value={isZeroRated ? 0 : (it.taxSlab ?? 10)}
                              disabled={isZeroRated}
                              onChange={(e) => handleUpdateItemTaxSlab(it.id, Number(e.target.value))}
                              className={`p-1 rounded-lg text-[11px] border ${isDarkMode ? 'bg-slate-900 border-slate-800 text-slate-200' : 'bg-white border-slate-200 text-slate-800'} disabled:opacity-50`}
                            >
                              {TAX_SLAB_OPTIONS.map((rate) => (
                                <option key={rate} value={rate}>
                                  {rate}%
                                </option>
                              ))}
                            </select>
                          </td>
                          <td className="p-2.5 text-right font-mono tabular-nums font-bold whitespace-nowrap">{formatDocMoney(it.quantity * it.unitPriceCents)}</td>
                          <td className="p-2.5 text-center">
                            <button onClick={() => handleRemoveItem(it.id)} className="text-rose-500 hover:text-rose-700 cursor-pointer">
                              <Trash2 className="w-3.5 h-3.5" />
                            </button>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>
            )}

            {/* Terms & Notes */}
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div>
                <label className="block text-[11px] font-bold text-slate-500 mb-1 flex items-center gap-1">
                  <Gavel className="w-3.5 h-3.5" />
                  <span>Invoice Payment Terms / Legal Notice</span>
                </label>
                <textarea
                  value={terms}
                  onChange={(e) => setTerms(e.target.value)}
                  rows={2}
                  className={`w-full p-2.5 rounded-xl text-xs border focus:outline-none ${isDarkMode ? 'bg-slate-900 border-slate-800 text-slate-100' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
                />
              </div>

              <div>
                <label className="block text-[11px] font-bold text-slate-500 mb-1 flex items-center gap-1">
                  <FileText className="w-3.5 h-3.5" />
                  <span>Invoice Notes / Warranty</span>
                </label>
                <textarea
                  value={notes}
                  onChange={(e) => setNotes(e.target.value)}
                  rows={2}
                  className={`w-full p-2.5 rounded-xl text-xs border focus:outline-none ${isDarkMode ? 'bg-slate-900 border-slate-800 text-slate-100' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
                />
              </div>
            </div>

            {/* Discount & Financial Totals */}
            <div className="flex flex-wrap items-center justify-between gap-4 pt-2 border-t dark:border-slate-800">
              <div className="flex items-center gap-3">
                <select
                  value={discountType}
                  onChange={(e) => setDiscountType(e.target.value as any)}
                  className={`p-2 rounded-xl text-xs border focus:outline-none ${isDarkMode ? 'bg-slate-900 border-slate-800 text-slate-100' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
                >
                  <option value="none">No Discount</option>
                  <option value="percent">% Percentage</option>
                  <option value="flat">Flat Amount</option>
                </select>
                {discountType !== 'none' && (
                  <input
                    type="text"
                    value={discountValue}
                    onChange={(e) => setDiscountValue(e.target.value)}
                    placeholder="Value"
                    className={`w-24 p-2 rounded-xl text-xs border focus:outline-none ${isDarkMode ? 'bg-slate-900 border-slate-800 text-slate-100' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
                  />
                )}
              </div>

              <div className="flex flex-wrap items-center gap-4 text-xs font-mono tabular-nums">
                <div>Subtotal: <span className="font-bold">{formatDocMoney(subtotalCents)}</span></div>
                {discountCents > 0 && <div className="text-amber-600">Disc: <span className="font-bold">-{formatDocMoney(discountCents)}</span></div>}
                {taxBreakdown.lines.map((line) => (
                  <div key={line.label}>
                    {line.label}: <span className="font-bold">{formatDocMoney(line.cents)}</span>
                  </div>
                ))}
                <div className="text-sm font-bold text-indigo-600">Total: {formatDocMoney(totalCents)}</div>
              </div>
            </div>
          </div>
        </div>

        {/* Live A4 Preview Canvas Column */}
        <div className="p-4 sm:p-6 bg-slate-100 dark:bg-slate-900 rounded-xl border border-slate-200 dark:border-slate-800 flex justify-center items-start overflow-y-auto">
          <div className="w-full max-w-[580px] bg-white text-slate-900 p-5 sm:p-8 rounded-xl shadow-lg border border-slate-200 space-y-6 text-xs font-sans">
            {/* Header */}
            <div className="flex flex-wrap items-start justify-between gap-3 border-b pb-4">
              <div className="min-w-0">
                <h2 className="text-lg font-bold break-words">{businessProfile.business_name || 'My Freelance Studio'}</h2>
                <p className="text-slate-500 text-[11px]">{businessProfile.email}</p>
                <p className="text-slate-500 text-[11px]">{businessProfile.phone}</p>
                {businessProfile.tax_id && (
                  <p className="text-slate-500 text-[11px]">
                    {getRegionalTaxIdLabel(taxBreakdown.effectiveMode, false)}: {businessProfile.tax_id}
                  </p>
                )}
              </div>
              <div className="px-3 py-1 rounded-md bg-indigo-50 text-indigo-900 font-bold uppercase text-xs shrink-0">
                {isQuote ? 'ESTIMATE / QUOTE' : 'TAX INVOICE'}
              </div>
            </div>

            {/* Bill To & Meta */}
            <div className="flex flex-wrap items-start justify-between gap-4">
              <div className="min-w-0">
                <span className="text-[10px] font-bold text-slate-400 uppercase">BILL TO:</span>
                <p className="font-bold text-sm text-slate-800 break-words">{selectedClient?.name || 'Select Client'}</p>
                <p className="text-slate-500 break-all">{selectedClient?.email}</p>
                {selectedClient?.tax_id && (
                  <p className="text-slate-500">
                    {getRegionalTaxIdLabel(taxBreakdown.effectiveMode, true)}: {selectedClient.tax_id}
                  </p>
                )}
              </div>
              <div className="text-left sm:text-right text-slate-600 tabular-nums">
                <p>Date: <span className="font-mono font-bold">{issueDate}</span></p>
                <p>Terms: <span className="font-bold">{paymentTerms}</span></p>
                {poNumber && <p>PO #: <span className="font-mono font-bold">{poNumber}</span></p>}
              </div>
            </div>

            {/* Table */}
            <div className="overflow-x-auto">
              <table className="w-full text-left text-xs border-collapse">
                <thead>
                  <tr className="border-b-2 border-slate-900 font-bold">
                    <th className="py-2 pr-2">Item</th>
                    <th className="py-2 px-2 text-center whitespace-nowrap">Qty</th>
                    <th className="py-2 px-2 text-right whitespace-nowrap">Rate</th>
                    <th className="py-2 pl-2 text-right whitespace-nowrap">Amount</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {activeItems.length === 0 ? (
                    <tr>
                      <td colSpan={4} className="py-3 text-center text-slate-400 italic">No line items added yet</td>
                    </tr>
                  ) : (
                    activeItems.map((item) => (
                      <tr key={item.id}>
                        <td className="py-2 pr-2 font-medium">{item.description || '—'}</td>
                        <td className="py-2 px-2 text-center tabular-nums">{item.quantity}</td>
                        <td className="py-2 px-2 text-right font-mono tabular-nums whitespace-nowrap">{formatDocMoney(item.unitPriceCents)}</td>
                        <td className="py-2 pl-2 text-right font-mono tabular-nums font-bold whitespace-nowrap">{formatDocMoney(item.quantity * item.unitPriceCents)}</td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>

            {/* Totals */}
            <div className="flex justify-end pt-2 border-t">
              <div className="w-full sm:w-56 space-y-1.5 text-right font-mono tabular-nums">
                <div className="flex justify-between text-slate-600">
                  <span>Subtotal:</span>
                  <span>{formatDocMoney(subtotalCents)}</span>
                </div>
                {discountCents > 0 && (
                  <div className="flex justify-between text-amber-600 font-bold">
                    <span>Discount:</span>
                    <span>-{formatDocMoney(discountCents)}</span>
                  </div>
                )}
                {taxBreakdown.lines.map((line) => (
                  <div key={line.label} className="flex justify-between text-slate-600">
                    <span className="font-sans text-left">{line.label}:</span>
                    <span>{formatDocMoney(line.cents)}</span>
                  </div>
                ))}
                <div className="flex justify-between text-sm font-bold border-t pt-1.5 text-slate-900">
                  <span>Total:</span>
                  <span className="text-indigo-600">{formatDocMoney(totalCents)}</span>
                </div>
              </div>
            </div>

            {/* Statutory Regional Compliance Banner */}
            {(taxBreakdown.noticeTitle || taxBreakdown.noticeText) && (
              <div className="p-3 rounded-lg border border-amber-300 bg-amber-50 text-amber-900 text-[10px] space-y-0.5">
                {taxBreakdown.noticeTitle && (
                  <p className="font-bold uppercase tracking-wider">{taxBreakdown.noticeTitle}</p>
                )}
                {taxBreakdown.noticeText && <p className="leading-relaxed">{taxBreakdown.noticeText}</p>}
              </div>
            )}

            {/* Instructions / Acceptance Block */}
            {isQuote ? (
              <div className="space-y-4 pt-2">
                <div className="p-3 bg-slate-50 rounded-lg border border-slate-200 text-[11px] text-slate-600">
                  <span className="font-bold text-slate-700">Proposal Validity: </span>
                  This estimate is valid until <span className="font-bold font-mono tabular-nums">{computedDueDate}</span>.
                </div>
                <div className="pt-6 border-t border-slate-200 flex flex-wrap justify-between items-end gap-4 text-[11px] text-slate-500">
                  <div>
                    <div className="w-44 border-b border-slate-400 mb-1"></div>
                    <p className="font-bold text-slate-700">Client Acceptance Signature</p>
                    <p className="text-[10px]">Date: ________________________</p>
                  </div>
                  {businessProfile.signature_base64 && (
                    <div className="text-right">
                      <img src={businessProfile.signature_base64} alt="Signature" className="h-10 ml-auto object-contain" />
                      <p className="font-bold text-slate-700 mt-1">Authorized Signatory</p>
                    </div>
                  )}
                </div>
              </div>
            ) : (
              businessProfile.payment_details && (
                <div className="p-3 bg-slate-50 rounded-lg border border-slate-200 text-[11px]">
                  <p className="font-bold text-slate-700">Payment Instructions:</p>
                  <p className="text-slate-600 whitespace-pre-line mt-0.5">{businessProfile.payment_details}</p>
                </div>
              )
            )}
          </div>
        </div>
      </div>

      {/* Add Client Modal */}
      {isAddClientOpen && (
        <div className="fixed inset-0 bg-black/50 backdrop-blur-xs flex items-center justify-center p-4 z-50">
          <div className={`w-full max-w-md max-h-[90vh] overflow-y-auto rounded-xl border p-6 space-y-4 ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}>
            <h3 className="font-bold text-sm">Add New Client</h3>
            <div className="space-y-3 text-xs">
              <div>
                <label className="block font-bold text-slate-500 mb-1">Client Name *</label>
                <input
                  type="text"
                  value={newClientName}
                  onChange={(e) => setNewClientName(e.target.value)}
                  placeholder="e.g. Acme Corp"
                  className={`w-full p-2.5 rounded-xl border ${isDarkMode ? 'bg-slate-900 border-slate-800 text-slate-100' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
                />
              </div>
              <div>
                <label className="block font-bold text-slate-500 mb-1">Email</label>
                <input
                  type="email"
                  value={newClientEmail}
                  onChange={(e) => setNewClientEmail(e.target.value)}
                  placeholder="billing@client.com"
                  className={`w-full p-2.5 rounded-xl border ${isDarkMode ? 'bg-slate-900 border-slate-800 text-slate-100' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
                />
              </div>
              <div>
                <label className="block font-bold text-slate-500 mb-1">Phone</label>
                <input
                  type="text"
                  value={newClientPhone}
                  onChange={(e) => setNewClientPhone(e.target.value)}
                  placeholder="+1 (555) 012-3456"
                  className={`w-full p-2.5 rounded-xl border ${isDarkMode ? 'bg-slate-900 border-slate-800 text-slate-100' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
                />
              </div>
              <div>
                <label className="block font-bold text-slate-500 mb-1">Tax ID / GSTIN / VAT</label>
                <input
                  type="text"
                  value={newClientTaxId}
                  onChange={(e) => setNewClientTaxId(e.target.value)}
                  placeholder="e.g. US-9876543"
                  className={`w-full p-2.5 rounded-xl border ${isDarkMode ? 'bg-slate-900 border-slate-800 text-slate-100' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
                />
              </div>
              <div>
                <label className="block font-bold text-slate-500 mb-1">Billing Address</label>
                <textarea
                  value={newClientAddress}
                  onChange={(e) => setNewClientAddress(e.target.value)}
                  rows={2}
                  placeholder="Suite 200, 456 Enterprise Blvd, Austin, TX"
                  className={`w-full p-2.5 rounded-xl border ${isDarkMode ? 'bg-slate-900 border-slate-800 text-slate-100' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
                />
              </div>
            </div>
            <div className="flex items-center justify-end gap-2">
              <button
                onClick={() => setIsAddClientOpen(false)}
                className="px-3 py-1.5 border rounded-xl text-xs font-bold cursor-pointer"
              >
                Cancel
              </button>
              <button
                onClick={handleSaveNewClientModal}
                className="px-4 py-1.5 bg-indigo-600 text-white rounded-xl text-xs font-bold cursor-pointer"
              >
                Save Client
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default InvoiceEditorScreen;
