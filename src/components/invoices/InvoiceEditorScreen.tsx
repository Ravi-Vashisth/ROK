import React, { useState, useMemo } from 'react';
import { ArrowLeft, Save, Check, Plus, Trash2, Zap, UserPlus, Search, Calendar, Clock, Bookmark, ShoppingCart, Gavel, FileText, CheckCircle2 } from 'lucide-react';
import { calculateDueDate } from '../../billingRules';

interface InvoiceEditorScreenProps {
  isQuote: boolean;
  initialData?: any;
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
}

export const InvoiceEditorScreen: React.FC<InvoiceEditorScreenProps> = ({
  isQuote,
  initialData,
  isDarkMode,
  businessProfile,
  clients,
  savedItems,
  currencySymbol,
  formatMoney,
  parsePriceToCents,
  onSave,
  onCancel,
  onAddClientModal,
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
    initialData?.payment_terms || 'Due on Receipt'
  );
  const [poNumber, setPoNumber] = useState<string>(initialData?.po_number || '');
  const [overrideCurrencyCode, setOverrideCurrencyCode] = useState<string>(
    initialData?.currency_code || businessProfile.currency_code || 'USD'
  );
  const [terms, setTerms] = useState<string>(
    initialData?.terms || businessProfile.default_terms || 'Payment due within agreed terms. Thank you for your business!'
  );
  const [notes, setNotes] = useState<string>(
    initialData?.notes || businessProfile.default_notes || 'All work includes post-delivery support.'
  );

  const [discountType, setDiscountType] = useState<'none' | 'percent' | 'flat'>(
    initialData?.discount_type || 'none'
  );
  const [discountValue, setDiscountValue] = useState<string>(
    initialData?.discount_value?.toString() || '0'
  );
  const [saveAsPreset, setSaveAsPreset] = useState<boolean>(false);

  // Quick line item inputs matching Flutter InvoiceInputsCard
  const [itemDesc, setItemDesc] = useState<string>('');
  const [itemSacHsn, setItemSacHsn] = useState<string>('');
  const [itemPrice, setItemPrice] = useState<string>('');
  const [itemQty, setItemQty] = useState<string>('1');

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
    return calculateDueDate(issueDate, paymentTerms);
  }, [issueDate, paymentTerms]);

  const activeItems = useMemo(() => {
    return items.filter((it) => !(it.description.trim() === '' && it.unitPriceCents === 0));
  }, [items]);

  const subtotalCents = activeItems.reduce((sum, item) => sum + item.quantity * item.unitPriceCents, 0);

  const discountCents = useMemo(() => {
    if (discountType === 'none') return 0;
    if (discountType === 'percent') {
      const pct = parseFloat(discountValue) || 0;
      return Math.round((subtotalCents * pct) / 100);
    }
    return parsePriceToCents(discountValue);
  }, [discountType, discountValue, subtotalCents, parsePriceToCents]);

  const taxCents = useMemo(() => {
    const subAfterDisc = Math.max(0, subtotalCents - discountCents);
    return activeItems.reduce((sum, item) => {
      if (subtotalCents <= 0) return sum;
      const lineTotal = item.quantity * item.unitPriceCents;
      const lineNet = Math.floor((lineTotal * subAfterDisc) / subtotalCents);
      return sum + Math.floor((lineNet * (item.taxSlab ?? 10)) / 100);
    }, 0);
  }, [activeItems, subtotalCents, discountCents]);

  const totalCents = Math.max(0, subtotalCents - discountCents) + taxCents;

  const handleAddQuickItem = () => {
    if (!itemDesc.trim()) {
      alert('Please enter an item description.');
      return;
    }
    const cents = parsePriceToCents(itemPrice);
    if (cents <= 0) {
      alert('Please enter a valid unit price.');
      return;
    }
    const q = parseInt(itemQty) || 1;
    const newItem = {
      id: Date.now().toString(),
      description: itemDesc.trim(),
      sacHsn: itemSacHsn.trim(),
      quantity: q,
      unitPriceCents: cents,
      taxSlab: 10,
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

  const handleRemoveItem = (id: string) => {
    if (items.length <= 1) return;
    setItems((prev) => prev.filter((i) => i.id !== id));
  };

  const handleSelectPresetItem = (itemId: string) => {
    const preset = savedItems.find((it) => it.id === itemId);
    if (!preset) return;
    const newItem = {
      id: Date.now().toString(),
      description: preset.title,
      sacHsn: preset.sacHsn || '',
      quantity: 1,
      unitPriceCents: preset.defaultPriceCents || 0,
      taxSlab: preset.taxSlab ?? 10,
    };
    setItems((prev) => {
      if (prev.length === 1 && (!prev[0].description?.trim() || prev[0].description === '—') && prev[0].unitPriceCents === 0) {
        return [newItem];
      }
      return [...prev, newItem];
    });
  };

  const handleSaveNewClientModal = () => {
    if (!newClientName.trim()) return;
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
      alert('Please select a client first.');
      return;
    }
    const validItems = items.filter((i) => i.description.trim().length > 0);
    if (validItems.length === 0) {
      alert('Please add at least one line item with a description.');
      return;
    }

    onSave({
      existingId: initialData?.id,
      clientId: selectedClientId,
      clientName: selectedClient?.name || 'Client',
      issueDate,
      paymentTerms,
      poNumber,
      currencyCode: overrideCurrencyCode,
      currencySymbol,
      terms,
      notes,
      discountType,
      discountValue,
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

      {/* Two-Column Split View */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Editor Column */}
        <div className="space-y-4">
          {/* Section 1 Card: Client Selection */}
          <div className={`p-5 rounded-xl border space-y-3 ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}>
            <div className="flex items-center justify-between">
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
            <div className="flex items-center justify-between">
              <h4 className="font-bold text-xs uppercase tracking-wider text-slate-400">2. Invoice Line Items & Payment Terms</h4>
              <span className="font-mono text-xs font-bold text-indigo-600">Next: INV-0006</span>
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
                  <span>Payment Terms</span>
                </label>
                <select
                  value={paymentTerms}
                  onChange={(e) => setPaymentTerms(e.target.value)}
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
                  <div className="text-[10px] font-bold text-slate-400">Computed Due Date:</div>
                  <div className="font-mono font-bold text-xs text-indigo-600">{computedDueDate}</div>
                </div>
              </div>
            </div>

            {/* Saved Service Library Quick Fill */}
            {savedItems.length > 0 && (
              <div className={`p-3 rounded-xl border flex items-center gap-2 ${isDarkMode ? 'bg-slate-900/60 border-slate-800' : 'bg-blue-50/50 border-blue-200'}`}>
                <Bookmark className="w-4 h-4 text-blue-600 shrink-0" />
                <span className="text-xs font-bold shrink-0">Saved Service Library:</span>
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
              <div className="sm:col-span-5">
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
                <label className="block text-[10px] font-bold text-slate-400 mb-0.5">Price ({currencySymbol})</label>
                <input
                  type="text"
                  value={itemPrice}
                  onChange={(e) => setItemPrice(e.target.value)}
                  placeholder="25.00"
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
              <div className="sm:col-span-2">
                <button
                  onClick={handleAddQuickItem}
                  className="w-full py-2 bg-indigo-600 hover:bg-indigo-700 text-white font-bold text-xs rounded-lg flex items-center justify-center gap-1.5 transition cursor-pointer"
                >
                  <ShoppingCart className="w-3.5 h-3.5" />
                  <span>Add Item</span>
                </button>
              </div>
            </div>

            {/* Line Items Table */}
            {items.length === 0 ? (
              <div className={`p-8 rounded-xl border text-center text-xs text-slate-400 ${isDarkMode ? 'bg-slate-900/30 border-slate-800' : 'bg-slate-50 border-slate-200'}`}>
                No items in this invoice yet. Enter item details above and click "Add Item".
              </div>
            ) : (
              <div className={`rounded-xl border overflow-hidden ${isDarkMode ? 'border-slate-800' : 'border-slate-200'}`}>
                <table className="w-full text-left text-xs">
                  <thead className={`border-b ${isDarkMode ? 'bg-slate-900 border-slate-800 text-slate-400' : 'bg-slate-100 border-slate-200 text-slate-600'} font-bold`}>
                    <tr>
                      <th className="p-2.5">Description</th>
                      <th className="p-2.5">SAC / HSN</th>
                      <th className="p-2.5 text-center">Qty</th>
                      <th className="p-2.5 text-right">Unit Price</th>
                      <th className="p-2.5 text-right">Total</th>
                      <th className="p-2.5 text-center">Action</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100 dark:divide-slate-800">
                    {items.map((it) => (
                      <tr key={it.id}>
                        <td className="p-2.5 font-medium">{it.description || '—'}</td>
                        <td className="p-2.5 text-slate-400">{it.sacHsn || '-'}</td>
                        <td className="p-2.5 text-center">{it.quantity}</td>
                        <td className="p-2.5 text-right font-mono">{formatMoney(it.unitPriceCents)}</td>
                        <td className="p-2.5 text-right font-mono font-bold">{formatMoney(it.quantity * it.unitPriceCents)}</td>
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

              <div className="flex items-center gap-4 text-xs font-mono">
                <div>Subtotal: <span className="font-bold">{formatMoney(subtotalCents)}</span></div>
                {discountCents > 0 && <div className="text-amber-600">Disc: <span className="font-bold">-{formatMoney(discountCents)}</span></div>}
                <div>Tax: <span className="font-bold">{formatMoney(taxCents)}</span></div>
                <div className="text-sm font-bold text-indigo-600">Total: {formatMoney(totalCents)}</div>
              </div>
            </div>
          </div>
        </div>

        {/* Live A4 Preview Canvas Column */}
        <div className="p-6 bg-slate-100 dark:bg-slate-900 rounded-xl border border-slate-200 dark:border-slate-800 flex justify-center items-start overflow-y-auto">
          <div className="w-full max-w-[580px] bg-white text-slate-900 p-8 rounded-xl shadow-lg border border-slate-200 space-y-6 text-xs font-sans">
            {/* Header */}
            <div className="flex items-start justify-between border-b pb-4">
              <div>
                <h2 className="text-lg font-bold">{businessProfile.business_name || 'My Freelance Studio'}</h2>
                <p className="text-slate-500 text-[11px]">{businessProfile.email}</p>
                <p className="text-slate-500 text-[11px]">{businessProfile.phone}</p>
                {businessProfile.tax_id && <p className="text-slate-500 text-[11px]">Tax ID: {businessProfile.tax_id}</p>}
              </div>
              <div className="px-3 py-1 rounded-md bg-indigo-50 text-indigo-900 font-bold uppercase text-xs">
                {isQuote ? 'ESTIMATE / QUOTE' : 'TAX INVOICE'}
              </div>
            </div>

            {/* Bill To & Meta */}
            <div className="flex items-start justify-between">
              <div>
                <span className="text-[10px] font-bold text-slate-400 uppercase">BILL TO:</span>
                <p className="font-bold text-sm text-slate-800">{selectedClient?.name || 'Select Client'}</p>
                <p className="text-slate-500">{selectedClient?.email}</p>
                {selectedClient?.tax_id && <p className="text-slate-500">Tax ID: {selectedClient.tax_id}</p>}
              </div>
              <div className="text-right text-slate-600">
                <p>Date: <span className="font-mono font-bold">{issueDate}</span></p>
                <p>Terms: <span className="font-bold">{paymentTerms}</span></p>
                {poNumber && <p>PO #: <span className="font-mono font-bold">{poNumber}</span></p>}
              </div>
            </div>

            {/* Table */}
            <table className="w-full text-left text-xs border-collapse">
              <thead>
                <tr className="border-b-2 border-slate-900 font-bold">
                  <th className="py-2">Item</th>
                  <th className="py-2 text-center">Qty</th>
                  <th className="py-2 text-right">Rate</th>
                  <th className="py-2 text-right">Amount</th>
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
                      <td className="py-2 font-medium">{item.description || '—'}</td>
                      <td className="py-2 text-center">{item.quantity}</td>
                      <td className="py-2 text-right font-mono">{formatMoney(item.unitPriceCents)}</td>
                      <td className="py-2 text-right font-mono font-bold">{formatMoney(item.quantity * item.unitPriceCents)}</td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>

            {/* Totals */}
            <div className="flex justify-end pt-2 border-t">
              <div className="w-48 space-y-1.5 text-right font-mono">
                <div className="flex justify-between text-slate-600">
                  <span>Subtotal:</span>
                  <span>{formatMoney(subtotalCents)}</span>
                </div>
                {discountCents > 0 && (
                  <div className="flex justify-between text-amber-600 font-bold">
                    <span>Discount:</span>
                    <span>-{formatMoney(discountCents)}</span>
                  </div>
                )}
                <div className="flex justify-between text-slate-600">
                  <span>Tax:</span>
                  <span>{formatMoney(taxCents)}</span>
                </div>
                <div className="flex justify-between text-sm font-bold border-t pt-1.5 text-slate-900">
                  <span>Total:</span>
                  <span className="text-indigo-600">{formatMoney(totalCents)}</span>
                </div>
              </div>
            </div>

            {/* Instructions / Acceptance Block */}
            {isQuote ? (
              <div className="space-y-4 pt-2">
                <div className="p-3 bg-slate-50 rounded-lg border border-slate-200 text-[11px] text-slate-600">
                  <span className="font-bold text-slate-700">Proposal Validity: </span>
                  This estimate is valid until <span className="font-bold font-mono">{computedDueDate}</span>.
                </div>
                <div className="pt-6 border-t border-slate-200 flex justify-between items-end text-[11px] text-slate-500">
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
          <div className={`w-full max-w-md rounded-xl border p-6 space-y-4 ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}>
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
