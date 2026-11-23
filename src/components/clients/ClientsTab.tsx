import React, { useState, useMemo, useEffect } from 'react';
import {
  Users,
  Plus,
  Trash2,
  Mail,
  Phone,
  MapPin,
  Hash,
  ArrowLeft,
  Search,
  Edit2,
  MessageSquare,
  Printer,
} from 'lucide-react';
import {
  buildMailtoUrl,
  buildSmsUrl,
  buildTelUrl,
  computeClientRollup,
  formatMoney as formatMoneyUnits,
  getCurrencyDecimals,
  isAppleDevice,
  normalizePhoneForUri,
  resolveEffectiveCurrency,
} from '../../billingRules';

interface ClientsTabProps {
  clients: any[];
  invoices?: any[];
  isDarkMode: boolean;
  currencyCode?: string;
  currencySymbol?: string;
  currencyDecimals?: number;
  formatMoney?: (cents: number) => string;
  onBack: () => void;
  onAddClient: (clientData: any) => void;
  onUpdateClient?: (id: string, clientData: any) => void;
  onDeleteClient: (client: any) => void;
  onPrintStatement?: (client: any) => void;
  onNotify?: (msg: string) => void;
}

export const ClientsTab: React.FC<ClientsTabProps> = ({
  clients,
  invoices = [],
  isDarkMode,
  currencyCode = 'USD',
  currencySymbol = '$',
  currencyDecimals,
  formatMoney: _formatMoney,
  onBack,
  onAddClient,
  onUpdateClient,
  onDeleteClient,
  onPrintStatement,
  onNotify,
}) => {
  const resolvedDefaultDecimals =
    currencyDecimals ?? getCurrencyDecimals(currencyCode || currencySymbol);

  const [selectedClientId, setSelectedClientId] = useState<string>(clients[0]?.id || '');
  const [searchQuery, setSearchQuery] = useState<string>('');
  const [activeDossierSubTab, setActiveDossierSubTab] = useState<'invoices' | 'statement' | 'notes'>('invoices');
  const LEDGER_THRESHOLD = 60;
  const LEDGER_PAGE_SIZE = 50;
  const [visibleCount, setVisibleCount] = useState<number>(LEDGER_PAGE_SIZE);

  useEffect(() => {
    setVisibleCount(LEDGER_PAGE_SIZE);
  }, [searchQuery]);

  // Add / Edit Modal state
  const [isAddModalOpen, setIsAddModalOpen] = useState(false);
  const [editingClient, setEditingClient] = useState<any | null>(null);

  const [formName, setFormName] = useState('');
  const [formEmail, setFormEmail] = useState('');
  const [formPhone, setFormPhone] = useState('');
  const [formAddress, setFormAddress] = useState('');
  const [formTaxId, setFormTaxId] = useState('');

  useEffect(() => {
    if (!isAddModalOpen) return;
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        setIsAddModalOpen(false);
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [isAddModalOpen]);

  const copyBackupContact = async (value: string, label: string) => {
    if (!value) return;
    try {
      await navigator.clipboard.writeText(value);
      onNotify?.(`Opening ${label} — "${value}" copied to clipboard as backup.`);
    } catch (_) {
      // Clipboard API may be restricted in headless contexts
    }
  };

  const filteredClients = useMemo(() => {
    if (!searchQuery.trim()) return clients;
    const q = searchQuery.toLowerCase().trim();
    return clients.filter(
      (c) =>
        c.name.toLowerCase().includes(q) ||
        (c.email && c.email.toLowerCase().includes(q)) ||
        (c.tax_id && c.tax_id.toLowerCase().includes(q))
    );
  }, [clients, searchQuery]);

  const shouldPaginateClients = filteredClients.length > LEDGER_THRESHOLD;
  const displayedClients = shouldPaginateClients
    ? filteredClients.slice(0, visibleCount)
    : filteredClients;
  const remainingClients = filteredClients.length - displayedClients.length;

  // Ensure valid selection
  const selectedClient = clients.find((c) => c.id === selectedClientId) || clients[0] || null;

  const resolveDocCurrency = (doc: any) => {
    const recCode = doc?.currency_code ?? doc?.currencyCode ?? '';
    const recSym = doc?.currency_symbol ?? doc?.currencySymbol ?? '';
    const recDec = doc?.currency_decimals ?? doc?.currencyDecimals;
    return resolveEffectiveCurrency({
      recordCode: recCode,
      recordSymbol: recSym,
      recordDecimals: String(recCode).trim() ? recDec : undefined,
      defaultCode: currencyCode,
      defaultSymbol: currencySymbol,
      defaultDecimals: resolvedDefaultDecimals,
    });
  };

  // Single Source of Truth calculation for any client, grouped strictly by currencyCode
  const getClientFinancials = (clientId: string) => {
    const clientInvoices = invoices.filter((inv) => inv.client_id === clientId);
    const activeInvoices = clientInvoices.filter((inv) => {
      const s = (inv.computed_status || inv.status || '').toUpperCase();
      return s !== 'VOID' && s !== 'DRAFT';
    });

    const rollup = computeClientRollup(activeInvoices, {
      code: currencyCode,
      symbol: currencySymbol,
      decimals: resolvedDefaultDecimals,
    });

    return {
      allInvoices: clientInvoices,
      activeInvoices,
      rollup,
    };
  };

  const selectedFinancials = selectedClient ? getClientFinancials(selectedClient.id) : null;

  const handleOpenAddModal = () => {
    setFormName('');
    setFormEmail('');
    setFormPhone('');
    setFormAddress('');
    setFormTaxId('');
    setEditingClient(null);
    setIsAddModalOpen(true);
  };

  const handleOpenEditModal = (client: any) => {
    setFormName(client.name || '');
    setFormEmail(client.email || '');
    setFormPhone(client.phone || '');
    setFormAddress(client.address || '');
    setFormTaxId(client.tax_id || '');
    setEditingClient(client);
    setIsAddModalOpen(true);
  };

  const handleSaveModal = (e: React.FormEvent) => {
    e.preventDefault();
    if (!formName.trim()) return;

    if (editingClient && onUpdateClient) {
      onUpdateClient(editingClient.id, {
        name: formName.trim(),
        email: formEmail.trim(),
        phone: formPhone.trim(),
        address: formAddress.trim(),
        taxId: formTaxId.trim(),
      });
    } else {
      onAddClient({
        name: formName.trim(),
        email: formEmail.trim(),
        phone: formPhone.trim(),
        address: formAddress.trim(),
        taxId: formTaxId.trim(),
      });
    }
    setIsAddModalOpen(false);
  };

  // Build Statement rows for selected client with isolated per-currency running balances
  const statementRows = useMemo(() => {
    if (!selectedFinancials) return [];
    const rows: Array<{
      date: string;
      reference: string;
      description: string;
      currencySymbol: string;
      currencyDecimals: number;
      debitCents: number;
      creditCents: number;
      runningBalanceCents: number;
    }> = [];

    const runningByCurrency: Record<string, number> = {};
    const sorted = [...selectedFinancials.activeInvoices].sort((a, b) =>
      (a.issue_date || '').localeCompare(b.issue_date || '')
    );

    sorted.forEach((inv) => {
      const cur = resolveDocCurrency(inv);
      const totalUnits = inv.total_cents || 0;
      const afterInvoice = (runningByCurrency[cur.code] || 0) + totalUnits;
      runningByCurrency[cur.code] = afterInvoice;

      rows.push({
        date: inv.issue_date,
        reference: inv.invoice_number,
        description: `Invoice Issued (${inv.payment_terms || 'Net 30'})`,
        currencySymbol: cur.symbol,
        currencyDecimals: cur.decimals,
        debitCents: totalUnits,
        creditCents: 0,
        runningBalanceCents: afterInvoice,
      });

      const paidUnits = inv.paid_cents || 0;
      if (paidUnits > 0) {
        const afterPayment = afterInvoice - paidUnits;
        runningByCurrency[cur.code] = afterPayment;
        rows.push({
          date: inv.issue_date,
          reference: `PAY-${inv.invoice_number}`,
          description: 'Payment Received',
          currencySymbol: cur.symbol,
          currencyDecimals: cur.decimals,
          debitCents: 0,
          creditCents: paidUnits,
          runningBalanceCents: afterPayment,
        });
      }
    });

    return rows;
  }, [selectedFinancials, currencyCode, currencySymbol, resolvedDefaultDecimals]);

  return (
    <div className="space-y-4">
      {/* Top Header */}
      <div className={`p-4 rounded-xl border flex flex-wrap items-center justify-between gap-4 ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}>
        <div className="flex items-center gap-3">
          <button
            onClick={onBack}
            className="flex items-center gap-1.5 text-xs font-bold text-slate-500 hover:text-slate-800 dark:hover:text-slate-200 cursor-pointer"
          >
            <ArrowLeft className="w-4 h-4" />
            <span>Back</span>
          </button>
          <div>
            <h3 className="font-bold text-sm">Client CRM & Statements</h3>
            <p className="text-[11px] text-slate-400">Directory of accounts, billing history, and statements of account</p>
          </div>
        </div>
        <button
          onClick={handleOpenAddModal}
          className="px-3.5 py-1.5 accent-btn font-bold text-xs rounded-xl flex items-center gap-1.5 cursor-pointer transition shadow-xs"
        >
          <Plus className="w-4 h-4" />
          <span>+ Add Client</span>
        </button>
      </div>

      {/* Master-Detail Grid: Left 30% / Right 70% */}
      <div className="grid grid-cols-1 min-[900px]:grid-cols-12 gap-6">
        {/* Left Client List Card (3.5 cols) */}
        <div className={`min-[900px]:col-span-4 rounded-xl border p-4 space-y-3 ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}>
          <div className="relative">
            <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder="Search clients..."
              className={`w-full pl-9 pr-3 py-2 rounded-xl text-xs border ${isDarkMode ? 'bg-slate-900 border-slate-800 text-slate-100' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
            />
          </div>

          <div className="divide-y divide-slate-100 dark:divide-slate-800 max-h-[580px] overflow-y-auto">
            {filteredClients.length === 0 ? (
              <div className="py-8 text-center text-xs text-slate-400">No clients found.</div>
            ) : (
              <>
                {displayedClients.map((c) => {
                  const fin = getClientFinancials(c.id);
                  const isSelected = selectedClient?.id === c.id;
                  const hasBalance = fin.rollup.hasOutstandingBalance;

                  return (
                    <button
                      key={c.id}
                      onClick={() => setSelectedClientId(c.id)}
                      className={`w-full text-left p-3 rounded-xl transition cursor-pointer flex items-center justify-between gap-2 ${
                        isSelected
                          ? 'accent-soft-card border'
                          : isDarkMode
                          ? 'hover:bg-slate-800/50 text-slate-200'
                          : 'hover:bg-slate-50 text-slate-800'
                      }`}
                    >
                      <div className="min-w-0 pr-2">
                        <div className="font-bold text-xs truncate">{c.name}</div>
                        <div className="text-[11px] text-slate-400 truncate">
                          {c.email || c.phone || 'No contact info'}
                        </div>
                      </div>
                      <div className="text-right shrink-0 max-w-[48%]">
                        <span
                          className={`font-mono tabular-nums font-bold text-xs break-words ${
                            hasBalance
                              ? 'text-amber-600 dark:text-amber-400'
                              : 'text-emerald-600 dark:text-emerald-400'
                          }`}
                        >
                          {hasBalance ? `${fin.rollup.formattedOutstandingBalance} Due` : '✓ Settled'}
                        </span>
                      </div>
                    </button>
                  );
                })}
                {shouldPaginateClients && remainingClients > 0 && (
                  <div className="pt-3 pb-1 text-center">
                    <button
                      type="button"
                      onClick={() => setVisibleCount((prev) => prev + LEDGER_PAGE_SIZE)}
                      className={`w-full px-3 py-2 rounded-xl border font-bold text-xs transition cursor-pointer ${
                        isDarkMode
                          ? 'border-slate-700 hover:bg-slate-800 text-slate-200'
                          : 'border-slate-200 hover:bg-slate-50 text-slate-700'
                      }`}
                    >
                      Show {Math.min(LEDGER_PAGE_SIZE, remainingClients)} more ({displayedClients.length} of {filteredClients.length})
                    </button>
                  </div>
                )}
              </>
            )}
          </div>
        </div>

        {/* Right Detail Dossier Card (70% - 8 cols) */}
        <div className={`min-[900px]:col-span-8 rounded-xl border p-6 space-y-6 ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}>
          {!selectedClient ? (
            <div className="py-20 text-center text-xs text-slate-400">
              Select a client to view their account dossier.
            </div>
          ) : (
            <>
              {/* Dossier Header */}
              <div className="flex flex-wrap items-start justify-between gap-4 border-b pb-4 dark:border-slate-800">
                <div className="space-y-1">
                  <h2 className="text-lg font-bold">{selectedClient.name}</h2>
                  <div className="flex flex-wrap items-center gap-3 text-xs text-slate-500">
                    {selectedClient.email && (
                      <span className="flex items-center gap-1">
                        <Mail className="w-3.5 h-3.5" />
                        {selectedClient.email}
                      </span>
                    )}
                    {selectedClient.phone && (
                      <span className="flex items-center gap-1">
                        <Phone className="w-3.5 h-3.5" />
                        {selectedClient.phone}
                      </span>
                    )}
                    {selectedClient.tax_id && (
                      <span className="flex items-center gap-1">
                        <Hash className="w-3.5 h-3.5" />
                        Tax ID: {selectedClient.tax_id}
                      </span>
                    )}
                  </div>
                  {selectedClient.address && (
                    <p className="text-xs text-slate-400 flex items-center gap-1">
                      <MapPin className="w-3.5 h-3.5 shrink-0" />
                      {selectedClient.address}
                    </p>
                  )}
                </div>

                <div className="flex flex-wrap items-center gap-2">
                  {(() => {
                    const isApple = isAppleDevice();
                    const normalizedPhone = normalizePhoneForUri(selectedClient.phone || '');
                    const cleanEmail = (selectedClient.email || '').trim();
                    const telUrl = selectedClient.phone ? buildTelUrl(selectedClient.phone) : null;
                    const smsUrl = selectedClient.phone
                      ? buildSmsUrl(selectedClient.phone, `Hi ${selectedClient.name}, `, isApple)
                      : null;
                    const mailUrl = cleanEmail
                      ? buildMailtoUrl(
                          cleanEmail,
                          'Regarding your account with us',
                          `Hi ${selectedClient.name},\n\n`
                        )
                      : null;
                    return (
                      <>
                        {telUrl && (
                          <a
                            href={telUrl}
                            onClick={() => copyBackupContact(normalizedPhone, 'phone dialer')}
                            className="px-2.5 py-1.5 border border-slate-300 dark:border-slate-700 hover:bg-slate-100 dark:hover:bg-slate-800 text-xs font-bold rounded-xl flex items-center gap-1 transition"
                            title={`Call ${selectedClient.phone}`}
                          >
                            <Phone className="w-3.5 h-3.5 text-emerald-600" />
                            <span>Call</span>
                          </a>
                        )}
                        {smsUrl && (
                          <a
                            href={smsUrl}
                            onClick={() => copyBackupContact(normalizedPhone, 'SMS')}
                            className="px-2.5 py-1.5 border border-slate-300 dark:border-slate-700 hover:bg-slate-100 dark:hover:bg-slate-800 text-xs font-bold rounded-xl flex items-center gap-1 transition"
                            title={`SMS ${selectedClient.phone}`}
                          >
                            <MessageSquare className="w-3.5 h-3.5 accent-text" />
                            <span>SMS</span>
                          </a>
                        )}
                        {mailUrl && (
                          <a
                            href={mailUrl}
                            onClick={() => copyBackupContact(cleanEmail, 'email')}
                            className="px-2.5 py-1.5 border border-slate-300 dark:border-slate-700 hover:bg-slate-100 dark:hover:bg-slate-800 text-xs font-bold rounded-xl flex items-center gap-1 transition"
                            title={`Email ${selectedClient.email}`}
                          >
                            <Mail className="w-3.5 h-3.5 text-sky-600" />
                            <span>Email</span>
                          </a>
                        )}
                      </>
                    );
                  })()}
                  {onPrintStatement && (
                    <button
                      onClick={() => onPrintStatement(selectedClient)}
                      className="px-3 py-1.5 border accent-soft-btn text-xs font-bold rounded-xl flex items-center gap-1.5 transition cursor-pointer"
                      title="Print / Save Client Statement PDF"
                    >
                      <Printer className="w-3.5 h-3.5" />
                      <span>Statement</span>
                    </button>
                  )}
                  <button
                    onClick={() => handleOpenEditModal(selectedClient)}
                    className="px-3 py-1.5 border border-slate-300 dark:border-slate-700 hover:bg-slate-100 dark:hover:bg-slate-800 text-xs font-bold rounded-xl flex items-center gap-1.5 transition cursor-pointer"
                  >
                    <Edit2 className="w-3.5 h-3.5" />
                    <span>Edit Client</span>
                  </button>
                  <button
                    onClick={() => onDeleteClient(selectedClient)}
                    className="p-1.5 rounded-xl bg-rose-50 hover:bg-rose-100 text-rose-700 dark:bg-rose-950 dark:text-rose-300 transition cursor-pointer"
                    title="Delete Client"
                  >
                    <Trash2 className="w-3.5 h-3.5" />
                  </button>
                </div>
              </div>

              {/* KPI Stat Cards (Per-currency grouped single source of truth) */}
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                <div className={`p-4 rounded-xl border ${isDarkMode ? 'bg-slate-900/60 border-slate-800' : 'bg-slate-50 border-slate-200'}`}>
                  <div className="text-[11px] font-bold text-slate-400 uppercase tracking-wider">Lifetime Billed</div>
                  <div className="text-lg font-mono tabular-nums font-bold mt-1 break-words">
                    {selectedFinancials?.rollup.formattedTotalBilled || formatMoneyUnits(0, currencySymbol, resolvedDefaultDecimals)}
                  </div>
                  <div className="text-[10px] text-slate-400 mt-0.5">
                    {selectedFinancials?.activeInvoices.length || 0} active invoices
                  </div>
                </div>

                <div className={`p-4 rounded-xl border ${isDarkMode ? 'bg-emerald-950/20 border-emerald-900/40' : 'bg-emerald-50 border-emerald-200'}`}>
                  <div className="text-[11px] font-bold text-emerald-700 dark:text-emerald-400 uppercase tracking-wider">Total Collected</div>
                  <div className="text-lg font-mono tabular-nums font-bold text-emerald-700 dark:text-emerald-400 mt-1 break-words">
                    {selectedFinancials?.rollup.formattedTotalPaid || formatMoneyUnits(0, currencySymbol, resolvedDefaultDecimals)}
                  </div>
                  <div className="text-[10px] text-emerald-600/80 dark:text-emerald-400/80 mt-0.5">Cleared payments</div>
                </div>

                <div className={`p-4 rounded-xl border ${isDarkMode ? 'bg-amber-950/20 border-amber-900/40' : 'bg-amber-50 border-amber-200'}`}>
                  <div className="text-[11px] font-bold text-amber-700 dark:text-amber-400 uppercase tracking-wider">Outstanding Balance</div>
                  <div className="text-lg font-mono tabular-nums font-bold text-amber-700 dark:text-amber-400 mt-1 break-words">
                    {selectedFinancials?.rollup.formattedOutstandingBalance || formatMoneyUnits(0, currencySymbol, resolvedDefaultDecimals)}
                  </div>
                  <div className="text-[10px] text-amber-600/80 dark:text-amber-400/80 mt-0.5">
                    {!selectedFinancials?.rollup.hasOutstandingBalance ? '✓ Account fully settled' : 'Unpaid balance due'}
                  </div>
                </div>
              </div>

              {/* Subtabs Bar */}
              <div className="border-b border-slate-200 dark:border-slate-800 flex gap-4 text-xs font-bold overflow-x-auto">
                <button
                  onClick={() => setActiveDossierSubTab('invoices')}
                  className={`pb-2 border-b-2 cursor-pointer transition whitespace-nowrap shrink-0 ${
                    activeDossierSubTab === 'invoices'
                      ? 'accent-border-tab-active'
                      : 'border-transparent text-slate-400 hover:text-slate-600'
                  }`}
                >
                  Invoices ({selectedFinancials?.allInvoices.filter((i) => String(i.computed_status || i.status || '').toUpperCase() !== 'DRAFT').length || 0})
                </button>
                <button
                  onClick={() => setActiveDossierSubTab('statement')}
                  className={`pb-2 border-b-2 cursor-pointer transition whitespace-nowrap shrink-0 ${
                    activeDossierSubTab === 'statement'
                      ? 'accent-border-tab-active'
                      : 'border-transparent text-slate-400 hover:text-slate-600'
                  }`}
                >
                  Statement of Account
                </button>
                <button
                  onClick={() => setActiveDossierSubTab('notes')}
                  className={`pb-2 border-b-2 cursor-pointer transition whitespace-nowrap shrink-0 ${
                    activeDossierSubTab === 'notes'
                      ? 'accent-border-tab-active'
                      : 'border-transparent text-slate-400 hover:text-slate-600'
                  }`}
                >
                  Notes & Details
                </button>
              </div>

              {/* Subtab Content */}
              {activeDossierSubTab === 'invoices' && (
                <div className={`rounded-xl border overflow-hidden ${isDarkMode ? 'border-slate-800' : 'border-slate-200'}`}>
                  <div className="overflow-x-auto">
                    <table className="w-full text-left text-xs">
                      <thead className={`border-b font-bold ${isDarkMode ? 'bg-slate-900 border-slate-800 text-slate-400' : 'bg-slate-50 border-slate-200 text-slate-600'}`}>
                        <tr>
                          <th className="p-3 whitespace-nowrap">Invoice #</th>
                          <th className="p-3 whitespace-nowrap">Issue Date</th>
                          <th className="p-3 text-right whitespace-nowrap">Total</th>
                          <th className="p-3 text-right whitespace-nowrap">Balance Due</th>
                          <th className="p-3 text-center whitespace-nowrap">Status</th>
                        </tr>
                      </thead>
                      <tbody className="divide-y divide-slate-100 dark:divide-slate-800">
                        {selectedFinancials?.allInvoices
                          .filter((inv) => String(inv.computed_status || inv.status || '').toUpperCase() !== 'DRAFT')
                          .map((inv) => {
                            const status = (inv.computed_status || inv.status || '').toUpperCase();
                            const isVoid = status === 'VOID';
                            const isPaid = status === 'PAID';
                            const cur = resolveDocCurrency(inv);

                            return (
                              <tr key={inv.id} className={isVoid ? 'opacity-50' : ''}>
                                <td className="p-3 font-mono font-bold accent-text whitespace-nowrap">{inv.invoice_number}</td>
                                <td className="p-3 text-slate-500 whitespace-nowrap">{inv.issue_date}</td>
                                <td className="p-3 text-right font-mono tabular-nums font-bold whitespace-nowrap">
                                  {formatMoneyUnits(inv.total_cents || 0, cur.symbol, cur.decimals)}
                                </td>
                                <td className={`p-3 text-right font-mono tabular-nums font-bold whitespace-nowrap ${isVoid ? 'text-slate-400 line-through' : isPaid ? 'text-emerald-600' : 'text-amber-600'}`}>
                                  {isVoid
                                    ? formatMoneyUnits(0, cur.symbol, cur.decimals)
                                    : formatMoneyUnits(inv.balance_due_cents ?? inv.total_cents ?? 0, cur.symbol, cur.decimals)}
                                </td>
                                <td className="p-3 text-center whitespace-nowrap">
                                  <span
                                    className={`inline-block px-2 py-0.5 rounded text-[10px] font-bold uppercase ${
                                      isVoid
                                        ? 'bg-slate-200 text-slate-700 dark:bg-slate-800 dark:text-slate-400'
                                        : isPaid
                                        ? 'bg-emerald-100 text-emerald-800 dark:bg-emerald-950 dark:text-emerald-300'
                                        : 'accent-badge border'
                                    }`}
                                  >
                                    {isVoid ? 'VOID' : status}
                                  </span>
                                </td>
                              </tr>
                            );
                          })}
                        {(!selectedFinancials || selectedFinancials.allInvoices.filter((i) => String(i.computed_status || i.status || '').toUpperCase() !== 'DRAFT').length === 0) && (
                          <tr>
                            <td colSpan={5} className="p-6 text-center text-slate-400">
                              No finalized invoices recorded for this client.
                            </td>
                          </tr>
                        )}
                      </tbody>
                    </table>
                  </div>
                </div>
              )}

              {activeDossierSubTab === 'statement' && (
                <div className="space-y-3">
                  {onPrintStatement && (
                    <div className="flex justify-end">
                      <button
                        onClick={() => onPrintStatement(selectedClient)}
                        className="px-3 py-1.5 accent-soft-btn border text-xs font-bold rounded-xl flex items-center gap-1.5 transition cursor-pointer"
                      >
                        <Printer className="w-3.5 h-3.5" />
                        <span>Print Statement / Save PDF</span>
                      </button>
                    </div>
                  )}
                  <div className={`rounded-xl border overflow-hidden ${isDarkMode ? 'border-slate-800' : 'border-slate-200'}`}>
                    <div className="overflow-x-auto">
                      <table className="w-full text-left text-xs">
                        <thead className={`border-b font-bold ${isDarkMode ? 'bg-slate-900 border-slate-800 text-slate-400' : 'bg-slate-50 border-slate-200 text-slate-600'}`}>
                          <tr>
                            <th className="p-3 whitespace-nowrap">Date</th>
                            <th className="p-3 whitespace-nowrap">Reference</th>
                            <th className="p-3">Description</th>
                            <th className="p-3 text-right whitespace-nowrap">Debit (Invoiced)</th>
                            <th className="p-3 text-right whitespace-nowrap">Credit (Paid)</th>
                            <th className="p-3 text-right whitespace-nowrap">Running Balance</th>
                          </tr>
                        </thead>
                        <tbody className="divide-y divide-slate-100 dark:divide-slate-800">
                          {statementRows.length === 0 ? (
                            <tr>
                              <td colSpan={6} className="p-6 text-center text-slate-400">
                                No financial ledger transactions recorded.
                              </td>
                            </tr>
                          ) : (
                            statementRows.map((row, idx) => (
                              <tr key={idx}>
                                <td className="p-3 text-slate-500 whitespace-nowrap">{row.date}</td>
                                <td className="p-3 font-mono font-bold accent-text whitespace-nowrap">{row.reference}</td>
                                <td className="p-3 text-slate-600 dark:text-slate-300">{row.description}</td>
                                <td className="p-3 text-right font-mono tabular-nums font-bold whitespace-nowrap">
                                  {row.debitCents > 0 ? formatMoneyUnits(row.debitCents, row.currencySymbol, row.currencyDecimals) : '—'}
                                </td>
                                <td className="p-3 text-right font-mono tabular-nums font-bold text-emerald-600 whitespace-nowrap">
                                  {row.creditCents > 0 ? formatMoneyUnits(row.creditCents, row.currencySymbol, row.currencyDecimals) : '—'}
                                </td>
                                <td className="p-3 text-right font-mono tabular-nums font-bold text-amber-600 whitespace-nowrap">
                                  {formatMoneyUnits(row.runningBalanceCents, row.currencySymbol, row.currencyDecimals)}
                                </td>
                              </tr>
                            ))
                          )}
                        </tbody>
                      </table>
                    </div>
                  </div>
                </div>
              )}

              {activeDossierSubTab === 'notes' && (
                <div className={`p-4 rounded-xl border space-y-3 text-xs ${isDarkMode ? 'bg-slate-900/40 border-slate-800' : 'bg-slate-50 border-slate-200'}`}>
                  <div>
                    <span className="font-bold text-slate-400 block mb-1">Billing Contact Information:</span>
                    <p className="text-slate-700 dark:text-slate-300">{selectedClient.name}</p>
                    <p className="text-slate-500">{selectedClient.email || 'No email specified'}</p>
                    <p className="text-slate-500">{selectedClient.phone || 'No phone specified'}</p>
                  </div>
                  <div>
                    <span className="font-bold text-slate-400 block mb-1">Billing Address:</span>
                    <p className="text-slate-700 dark:text-slate-300">{selectedClient.address || 'No billing address provided'}</p>
                  </div>
                  <div>
                    <span className="font-bold text-slate-400 block mb-1">Statutory Tax Registration:</span>
                    <p className="font-mono text-slate-700 dark:text-slate-300">{selectedClient.tax_id || 'Not registered / Unspecified'}</p>
                  </div>
                </div>
              )}
            </>
          )}
        </div>
      </div>

      {/* Add / Edit Client Modal */}
      {isAddModalOpen && (
        <div
          className="fixed inset-0 bg-black/50 backdrop-blur-xs flex items-center justify-center p-4 z-50"
          onClick={(e) => {
            if (e.target === e.currentTarget) {
              setIsAddModalOpen(false);
            }
          }}
        >
          <div
            role="dialog"
            aria-modal="true"
            className={`w-full max-w-md max-h-[90vh] overflow-y-auto rounded-xl border p-6 space-y-4 ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}
          >
            <h3 className="font-bold text-sm">
              {editingClient ? 'Edit Client Details' : 'Add New Client'}
            </h3>
            <form onSubmit={handleSaveModal} className="space-y-3 text-xs">
              <div>
                <label className="block font-bold text-slate-500 mb-1">Client / Company Name *</label>
                <input
                  type="text"
                  value={formName}
                  onChange={(e) => setFormName(e.target.value)}
                  placeholder="e.g. Acme Corp"
                  className={`w-full p-2.5 rounded-xl border ${isDarkMode ? 'bg-slate-900 border-slate-800 text-slate-100' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
                  required
                />
              </div>
              <div>
                <label className="block font-bold text-slate-500 mb-1">Billing Email</label>
                <input
                  type="email"
                  value={formEmail}
                  onChange={(e) => setFormEmail(e.target.value)}
                  placeholder="billing@client.com"
                  className={`w-full p-2.5 rounded-xl border ${isDarkMode ? 'bg-slate-900 border-slate-800 text-slate-100' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
                />
              </div>
              <div>
                <label className="block font-bold text-slate-500 mb-1">Phone Number</label>
                <input
                  type="text"
                  value={formPhone}
                  onChange={(e) => setFormPhone(e.target.value)}
                  placeholder="+1 (555) 012-3456"
                  className={`w-full p-2.5 rounded-xl border ${isDarkMode ? 'bg-slate-900 border-slate-800 text-slate-100' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
                />
              </div>
              <div>
                <label className="block font-bold text-slate-500 mb-1">GSTIN / Tax ID / VAT</label>
                <input
                  type="text"
                  value={formTaxId}
                  onChange={(e) => setFormTaxId(e.target.value)}
                  placeholder="e.g. US-9876543"
                  className={`w-full p-2.5 rounded-xl border ${isDarkMode ? 'bg-slate-900 border-slate-800 text-slate-100' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
                />
              </div>
              <div>
                <label className="block font-bold text-slate-500 mb-1">Billing Address</label>
                <textarea
                  value={formAddress}
                  onChange={(e) => setFormAddress(e.target.value)}
                  rows={2}
                  placeholder="Suite 200, 456 Enterprise Blvd"
                  className={`w-full p-2.5 rounded-xl border ${isDarkMode ? 'bg-slate-900 border-slate-800 text-slate-100' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
                />
              </div>
              <div className="flex items-center justify-end gap-2 pt-2">
                <button
                  type="button"
                  onClick={() => setIsAddModalOpen(false)}
                  className="px-3 py-1.5 border rounded-xl text-xs font-bold cursor-pointer"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-4 py-1.5 accent-btn rounded-xl text-xs font-bold cursor-pointer"
                >
                  {editingClient ? 'Save Changes' : 'Save Client'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};

export default ClientsTab;
