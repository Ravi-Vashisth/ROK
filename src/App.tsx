import React, { useState, useEffect, useMemo } from 'react';
import {
  LayoutDashboard,
  ReceiptText,
  Wallet,
  Settings,
  Sun,
  Moon,
  Download,
  X,
  FileSpreadsheet,
} from 'lucide-react';
import {
  parsePriceToCents,
  calculateDueDate,
} from './billingRules';

import { DashboardTab } from './components/dashboard/DashboardTab';
import { SalesTab } from './components/billing/SalesTab';
import { InvoiceEditorScreen } from './components/invoices/InvoiceEditorScreen';
import { ExpensesTab } from './components/expenses/ExpensesTab';
import { HubSettingsTab } from './components/hub/HubSettingsTab';
import { ClientsTab } from './components/clients/ClientsTab';
import { ItemsCatalogTab } from './components/items/ItemsCatalogTab';
import { BusinessProfileDialog } from './components/business_profile/BusinessProfileDialog';

export interface Client {
  id: string;
  name: string;
  email: string;
  phone: string;
  address: string;
  tax_id: string;
  created_at: string;
}

export interface InvoiceRecord {
  id: string;
  client_id: string;
  client_name: string;
  invoice_number: string;
  subtotal_cents: number;
  tax_cents: number;
  total_cents: number;
  status: string;
  issue_date: string;
  due_date: string;
  payment_terms: string;
  paid_cents?: number;
  balance_due_cents?: number;
  computed_status?: string;
  created_at: string;
}

export interface StoredEstimateRecord {
  id: string;
  client_id: string;
  client_name: string;
  estimate_number: string;
  subtotal_cents: number;
  tax_cents: number;
  total_cents: number;
  status: string;
  issue_date: string;
  expiry_date: string;
  created_at: string;
}

export interface ExpenseRecord {
  id: string;
  vendor: string;
  category: string;
  amount_cents: number;
  tax_cents: number;
  total_cents: number;
  expense_date: string;
  created_at: string;
}

export const App: React.FC = () => {
  // Theme state
  const [isDarkMode, setIsDarkMode] = useState<boolean>(false);
  const [accentColor, setAccentColor] = useState<string>('indigo');

  // Active Tab: 0 = Dashboard, 1 = Sales, 2 = Expenses, 3 = Hub
  const [activeTab, setActiveTab] = useState<number>(0);

  // Sub-screens under Hub / Sales
  const [hubSubScreen, setHubSubScreen] = useState<'main' | 'clients' | 'items'>('main');
  const [editorMode, setEditorMode] = useState<'none' | 'invoice' | 'estimate'>('none');

  // Modals
  const [isProfileModalOpen, setIsProfileModalOpen] = useState<boolean>(false);
  const [isCsvModalOpen, setIsCsvModalOpen] = useState<boolean>(false);

  // Persistent State
  const [clients, setClients] = useState<Client[]>(() => {
    const saved = localStorage.getItem('freelance_clients');
    return saved ? JSON.parse(saved) : [
      { id: 'c1', name: 'Acme Technologies', email: 'billing@acme.com', phone: '+1 555-0192', address: '100 Tech Blvd, CA', tax_id: 'US-9876543', created_at: new Date().toISOString() },
      { id: 'c2', name: 'Global Logistics', email: 'accounts@global.com', phone: '+1 555-0381', address: '450 Shipping Way, NY', tax_id: 'US-1234567', created_at: new Date().toISOString() },
    ];
  });

  const [invoices, setInvoices] = useState<InvoiceRecord[]>(() => {
    const saved = localStorage.getItem('freelance_invoices');
    return saved ? JSON.parse(saved) : [
      { id: 'inv-1', client_id: 'c1', client_name: 'Acme Technologies', invoice_number: 'INV-0001', subtotal_cents: 150000, tax_cents: 15000, total_cents: 165000, paid_cents: 165000, balance_due_cents: 0, status: 'PAID', computed_status: 'PAID', issue_date: '2026-10-01', due_date: '2026-10-15', payment_terms: 'Net 15 Days', created_at: new Date().toISOString() },
      { id: 'inv-2', client_id: 'c2', client_name: 'Global Logistics', invoice_number: 'INV-0002', subtotal_cents: 240000, tax_cents: 24000, total_cents: 264000, paid_cents: 100000, balance_due_cents: 164000, status: 'PARTIALLY_PAID', computed_status: 'PARTIALLY_PAID', issue_date: '2026-10-10', due_date: '2026-10-25', payment_terms: 'Net 15 Days', created_at: new Date().toISOString() },
    ];
  });

  const [estimates, setEstimates] = useState<StoredEstimateRecord[]>(() => {
    const saved = localStorage.getItem('freelance_estimates');
    return saved ? JSON.parse(saved) : [
      { id: 'est-1', client_id: 'c1', client_name: 'Acme Technologies', estimate_number: 'EST-0001', subtotal_cents: 300000, tax_cents: 30000, total_cents: 330000, status: 'PENDING', issue_date: '2026-10-20', expiry_date: '2026-11-20', created_at: new Date().toISOString() },
    ];
  });

  const [expenses, setExpenses] = useState<ExpenseRecord[]>(() => {
    const saved = localStorage.getItem('freelance_expenses');
    return saved ? JSON.parse(saved) : [
      { id: 'exp-1', vendor: 'Amazon Web Services', category: 'Software & SaaS', amount_cents: 12000, tax_cents: 1200, total_cents: 13200, expense_date: '2026-10-05', created_at: new Date().toISOString() },
      { id: 'exp-2', vendor: 'Apple Store', category: 'Hardware', amount_cents: 199900, tax_cents: 19990, total_cents: 219890, expense_date: '2026-10-12', created_at: new Date().toISOString() },
    ];
  });

  const [savedItems, setSavedItems] = useState<any[]>(() => {
    const saved = localStorage.getItem('freelance_saved_items');
    return saved ? JSON.parse(saved) : [
      { id: 'si-1', title: 'Full Stack Web Development (Hourly)', defaultPriceCents: 8500, sacHsn: '998314' },
      { id: 'si-2', title: 'UI/UX Mobile Design Package', defaultPriceCents: 150000, sacHsn: '998313' },
    ];
  });

  const [businessProfile, setBusinessProfile] = useState<any>(() => {
    const saved = localStorage.getItem('freelance_business_profile');
    return saved ? JSON.parse(saved) : {
      business_name: 'My Freelance Studio',
      email: 'billing@studio.com',
      phone: '+1 (555) 019-2834',
      address: '100 Tech Plaza, Suite 400, San Francisco, CA 94107',
      tax_id: 'US-EIN-987654321',
      currency_code: 'USD',
      currency_symbol: '$',
      payment_details: 'Bank: Silicon Valley Bank\nAccount: 987654321098\nRouting / SWIFT: SVB12345',
      default_terms: 'Payment due within agreed terms. Thank you for your business!',
      default_notes: 'All work includes 30 days post-delivery support.',
    };
  });

  // LocalStorage Sync Effects
  useEffect(() => { localStorage.setItem('freelance_clients', JSON.stringify(clients)); }, [clients]);
  useEffect(() => { localStorage.setItem('freelance_invoices', JSON.stringify(invoices)); }, [invoices]);
  useEffect(() => { localStorage.setItem('freelance_estimates', JSON.stringify(estimates)); }, [estimates]);
  useEffect(() => { localStorage.setItem('freelance_expenses', JSON.stringify(expenses)); }, [expenses]);
  useEffect(() => { localStorage.setItem('freelance_saved_items', JSON.stringify(savedItems)); }, [savedItems]);
  useEffect(() => { localStorage.setItem('freelance_business_profile', JSON.stringify(businessProfile)); }, [businessProfile]);

  const sym = businessProfile.currency_symbol || '$';

  const formatMoney = (cents: number) => {
    const val = cents / 100;
    return `${sym}${val.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
  };

  // State Handlers
  const handleCreateInvoice = () => {
    setActiveTab(1);
    setEditorMode('invoice');
  };

  const handleCreateQuote = () => {
    setActiveTab(1);
    setEditorMode('estimate');
  };

  const handleSaveDocFromEditor = (docData: any) => {
    if (editorMode === 'invoice') {
      const newInv: InvoiceRecord = {
        id: `inv-${Date.now()}`,
        client_id: docData.clientId,
        client_name: docData.clientName,
        invoice_number: `INV-${(invoices.length + 1).toString().padStart(4, '0')}`,
        subtotal_cents: docData.subtotalCents,
        tax_cents: docData.taxCents,
        total_cents: docData.totalCents,
        status: docData.isDraft ? 'DRAFT' : 'PENDING',
        computed_status: docData.isDraft ? 'DRAFT' : 'PENDING',
        issue_date: docData.issueDate,
        due_date: calculateDueDate(docData.issueDate, docData.paymentTerms),
        payment_terms: docData.paymentTerms,
        paid_cents: 0,
        balance_due_cents: docData.totalCents,
        created_at: new Date().toISOString(),
      };
      setInvoices((prev) => [newInv, ...prev]);
    } else {
      const newEst: StoredEstimateRecord = {
        id: `est-${Date.now()}`,
        client_id: docData.clientId,
        client_name: docData.clientName,
        estimate_number: `EST-${(estimates.length + 1).toString().padStart(4, '0')}`,
        subtotal_cents: docData.subtotalCents,
        tax_cents: docData.taxCents,
        total_cents: docData.totalCents,
        status: docData.isDraft ? 'DRAFT' : 'PENDING',
        issue_date: docData.issueDate,
        expiry_date: calculateDueDate(docData.issueDate, 'Net 30 Days'),
        created_at: new Date().toISOString(),
      };
      setEstimates((prev) => [newEst, ...prev]);
    }
    setEditorMode('none');
  };

  const handleRecordPayment = (inv: InvoiceRecord) => {
    const amountStr = prompt(`Record payment for invoice ${inv.invoice_number} (Balance Due: ${formatMoney(inv.balance_due_cents ?? inv.total_cents)}):`, ((inv.balance_due_cents ?? inv.total_cents) / 100).toFixed(2));
    if (!amountStr) return;
    const paidCents = parsePriceToCents(amountStr);
    if (paidCents <= 0) return;

    setInvoices((prev) =>
      prev.map((i) => {
        if (i.id !== inv.id) return i;
        const currentPaid = i.paid_cents || 0;
        const newPaid = currentPaid + paidCents;
        const newBalance = Math.max(0, i.total_cents - newPaid);
        const newStatus = newBalance === 0 ? 'PAID' : 'PARTIALLY_PAID';
        return { ...i, paid_cents: newPaid, balance_due_cents: newBalance, status: newStatus, computed_status: newStatus };
      })
    );
  };

  const handleDeleteInvoice = (inv: InvoiceRecord) => {
    if (confirm(`Are you sure you want to delete invoice ${inv.invoice_number}?`)) {
      setInvoices((prev) => prev.filter((i) => i.id !== inv.id));
    }
  };

  const handleConvertEstimate = (est: StoredEstimateRecord) => {
    const newInv: InvoiceRecord = {
      id: `inv-${Date.now()}`,
      client_id: est.client_id,
      client_name: est.client_name,
      invoice_number: `INV-C-${est.estimate_number}`,
      subtotal_cents: est.subtotal_cents,
      tax_cents: est.tax_cents,
      total_cents: est.total_cents,
      status: 'PENDING',
      computed_status: 'PENDING',
      issue_date: new Date().toISOString().split('T')[0],
      due_date: calculateDueDate(new Date().toISOString().split('T')[0], 'Net 15 Days'),
      payment_terms: 'Net 15 Days',
      paid_cents: 0,
      balance_due_cents: est.total_cents,
      created_at: new Date().toISOString(),
    };
    setInvoices((prev) => [newInv, ...prev]);
    setEstimates((prev) => prev.map((e) => (e.id === est.id ? { ...e, status: 'CONVERTED' } : e)));
    alert(`Converted quote ${est.estimate_number} into live invoice ${newInv.invoice_number}!`);
  };

  const handleDeleteEstimate = (est: StoredEstimateRecord) => {
    if (confirm(`Are you sure you want to delete quote ${est.estimate_number}?`)) {
      setEstimates((prev) => prev.filter((e) => e.id !== est.id));
    }
  };

  const handleAddExpense = () => {
    const vendor = prompt('Vendor Name (e.g. Google Cloud, Apple):');
    if (!vendor) return;
    const cat = prompt('Category (Software & SaaS, Hardware, Office Supplies, Travel):', 'Software & SaaS');
    const amtStr = prompt('Amount:', '50.00');
    if (!amtStr) return;
    const amtCents = parsePriceToCents(amtStr);
    const newExp: ExpenseRecord = {
      id: `exp-${Date.now()}`,
      vendor: vendor.trim(),
      category: cat || 'General',
      amount_cents: amtCents,
      tax_cents: Math.round(amtCents * 0.1),
      total_cents: Math.round(amtCents * 1.1),
      expense_date: new Date().toISOString().split('T')[0],
      created_at: new Date().toISOString(),
    };
    setExpenses((prev) => [newExp, ...prev]);
  };

  const handleDeleteExpense = (exp: ExpenseRecord) => {
    if (confirm(`Delete expense record from ${exp.vendor}?`)) {
      setExpenses((prev) => prev.filter((e) => e.id !== exp.id));
    }
  };

  const handleAddClient = (cData: any) => {
    const newC: Client = {
      id: `c-${Date.now()}`,
      name: cData.name,
      email: cData.email || '',
      phone: cData.phone || '',
      address: cData.address || '',
      tax_id: cData.taxId || '',
      created_at: new Date().toISOString(),
    };
    setClients((prev) => [...prev, newC]);
  };

  const handleDeleteClient = (client: Client) => {
    if (confirm(`Delete client "${client.name}"?`)) {
      setClients((prev) => prev.filter((c) => c.id !== client.id));
    }
  };

  const handleAddItem = (iData: any) => {
    const newI = {
      id: `si-${Date.now()}`,
      title: iData.title,
      defaultPriceCents: iData.default_price_cents,
      sacHsn: iData.sac_hsn || '',
    };
    setSavedItems((prev) => [...prev, newI]);
  };

  const handleDeleteItem = (item: any) => {
    if (confirm(`Delete preset service "${item.title}"?`)) {
      setSavedItems((prev) => prev.filter((i) => i.id !== item.id));
    }
  };

  const handleRestoreDatabase = (file: File) => {
    const reader = new FileReader();
    reader.onload = (e) => {
      try {
        const data = JSON.parse(e.target?.result as string);
        if (data.clients) setClients(data.clients);
        if (data.invoices) setInvoices(data.invoices);
        if (data.estimates) setEstimates(data.estimates);
        if (data.expenses) setExpenses(data.expenses);
        if (data.businessProfile) setBusinessProfile(data.businessProfile);
        alert('Database restored successfully from backup JSON!');
      } catch (err) {
        alert('Invalid database backup file.');
      }
    };
    reader.readAsText(file);
  };

  // Color palette options matching Flutter AppPalette presetAccents
  const accentColors: Record<string, { name: string; hex: string; bg: string; text: string }> = {
    indigo: { name: 'Indigo', hex: '#4F46E5', bg: 'bg-indigo-600', text: 'text-indigo-600' },
    emerald: { name: 'Emerald', hex: '#10B981', bg: 'bg-emerald-600', text: 'text-emerald-600' },
    royalBlue: { name: 'Royal Blue', hex: '#2563EB', bg: 'bg-blue-600', text: 'text-blue-600' },
    roseRed: { name: 'Rose Red', hex: '#F43F5E', bg: 'bg-rose-600', text: 'text-rose-600' },
    amberGold: { name: 'Amber Gold', hex: '#F59E0B', bg: 'bg-amber-600', text: 'text-amber-600' },
    slateSteel: { name: 'Slate Steel', hex: '#64748B', bg: 'bg-slate-600', text: 'text-slate-600' },
  };

  const [isPaletteOpen, setIsPaletteOpen] = useState<boolean>(false);

  return (
    <div className={`min-h-screen font-sans flex antialiased ${isDarkMode ? 'bg-[#0B0F19] text-slate-100' : 'bg-slate-50 text-slate-900'}`}>
      {/* 1. MASTER SIDEBAR NAVIGATION (NavigationRail parity) */}
      <aside className={`hidden md:flex flex-col w-[220px] border-r select-none sticky top-0 h-screen shrink-0 ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}>
        <div className={`p-5 border-b flex flex-col items-center text-center gap-2 ${isDarkMode ? 'border-slate-800' : 'border-slate-100'}`}>
          <div className={`w-12 h-12 rounded-full text-white flex items-center justify-center font-bold text-lg shadow-sm shrink-0 ${accentColors[accentColor]?.bg || 'bg-indigo-600'}`}>
            {businessProfile.business_name ? businessProfile.business_name[0].toUpperCase() : 'B'}
          </div>
          <div className="min-w-0 w-full px-1">
            <h1 className={`font-bold text-xs whitespace-normal break-words leading-tight ${isDarkMode ? 'text-white' : 'text-slate-900'}`}>
              {businessProfile.business_name || 'Freelance'}
            </h1>
          </div>
        </div>

        <nav className="flex-1 p-3 space-y-1.5 overflow-y-auto">
          {[
            { id: 0, label: 'Dashboard', icon: LayoutDashboard },
            { id: 1, label: 'Sales', icon: ReceiptText },
            { id: 2, label: 'Expenses', icon: Wallet },
            { id: 3, label: 'Hub', icon: Settings },
          ].map((item) => {
            const Icon = item.icon;
            const isActive = activeTab === item.id && editorMode === 'none';
            return (
              <button
                key={item.id}
                onClick={() => {
                  setEditorMode('none');
                  setHubSubScreen('main');
                  setActiveTab(item.id);
                }}
                className={`w-full flex items-center gap-3 px-3.5 py-2.5 rounded-xl text-xs font-bold transition cursor-pointer ${
                  isActive
                    ? isDarkMode ? 'bg-indigo-950/60 text-indigo-300 border border-indigo-800/40' : 'bg-indigo-50 text-indigo-700 shadow-xs'
                    : isDarkMode ? 'text-slate-400 hover:bg-slate-800/60 hover:text-white' : 'text-slate-600 hover:bg-slate-100/80 hover:text-slate-900'
                }`}
              >
                <Icon className={`w-4 h-4 ${isActive ? 'text-indigo-600' : 'text-slate-400'}`} />
                <span>{item.label}</span>
              </button>
            );
          })}
        </nav>
      </aside>

      {/* 2. MAIN VIEWPORT */}
      <div className="flex-1 flex flex-col min-w-0 pb-16 md:pb-0">
        <main className="flex-1 p-6 overflow-y-auto max-w-7xl mx-auto w-full space-y-6">
          {/* Top Utility Bar - 1:1 Flutter AppBar parity */}
          <div className="flex flex-wrap items-center justify-end gap-2 mb-2">
            <button
              onClick={() => setIsCsvModalOpen(true)}
              className="px-3 py-2 bg-indigo-50 hover:bg-indigo-100 dark:bg-indigo-950/50 dark:hover:bg-indigo-900/60 text-indigo-700 dark:text-indigo-300 border border-indigo-200 dark:border-indigo-800 text-xs font-bold rounded-xl flex items-center gap-1.5 cursor-pointer transition shadow-xs"
              title="Export Accountant CSV"
            >
              <Download className="w-3.5 h-3.5" />
              <span>Export Accountant CSV</span>
            </button>

            <button
              onClick={() => setIsProfileModalOpen(true)}
              className={`p-2 rounded-xl border transition cursor-pointer ${isDarkMode ? 'bg-[#0F172A] border-slate-800 text-slate-300 hover:bg-slate-800' : 'bg-white border-slate-200 text-slate-600 hover:bg-slate-50'}`}
              title="Business Profile & Branding Settings"
            >
              <Settings className="w-4 h-4" />
            </button>

            {/* Accent Color Palette Selector */}
            <div className="relative">
              <button
                onClick={() => setIsPaletteOpen((p) => !p)}
                className={`p-2 rounded-xl border transition cursor-pointer flex items-center justify-center ${isDarkMode ? 'bg-[#0F172A] border-slate-800 hover:bg-slate-800' : 'bg-white border-slate-200 hover:bg-slate-50'}`}
                title="Accent Color"
              >
                <span className={`w-4 h-4 rounded-full ${accentColors[accentColor]?.bg || 'bg-indigo-600'}`}></span>
              </button>

              {isPaletteOpen && (
                <div className={`absolute right-0 mt-2 w-44 rounded-xl border shadow-xl p-2 z-50 space-y-1 ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}>
                  <div className="text-[10px] font-bold uppercase tracking-wider text-slate-400 px-2 py-1">Accent Theme</div>
                  {Object.entries(accentColors).map(([key, info]) => (
                    <button
                      key={key}
                      onClick={() => {
                        setAccentColor(key);
                        setIsPaletteOpen(false);
                      }}
                      className={`w-full flex items-center gap-2.5 px-2.5 py-1.5 rounded-lg text-xs font-semibold cursor-pointer transition ${accentColor === key ? 'bg-slate-100 dark:bg-slate-800' : 'hover:bg-slate-50 dark:hover:bg-slate-800/50'}`}
                    >
                      <span className={`w-3.5 h-3.5 rounded-full ${info.bg}`}></span>
                      <span className="flex-1 text-left">{info.name}</span>
                      {accentColor === key && <span className="text-xs font-bold text-indigo-600">✓</span>}
                    </button>
                  ))}
                </div>
              )}
            </div>

            <button
              onClick={() => setIsDarkMode((prev) => !prev)}
              className={`p-2 rounded-xl border transition cursor-pointer ${isDarkMode ? 'bg-[#0F172A] border-slate-800 text-amber-400 hover:bg-slate-800' : 'bg-white border-slate-200 text-slate-600 hover:bg-slate-50'}`}
              title={isDarkMode ? 'Theme: Dark Mode' : 'Theme: Light Mode'}
            >
              {isDarkMode ? <Sun className="w-4 h-4" /> : <Moon className="w-4 h-4" />}
            </button>
          </div>

          {/* COMPONENT ROUTER */}
          {editorMode !== 'none' ? (
            <InvoiceEditorScreen
              isQuote={editorMode === 'estimate'}
              isDarkMode={isDarkMode}
              businessProfile={businessProfile}
              clients={clients}
              savedItems={savedItems}
              currencySymbol={sym}
              formatMoney={formatMoney}
              parsePriceToCents={parsePriceToCents}
              onSave={handleSaveDocFromEditor}
              onCancel={() => setEditorMode('none')}
              onAddClientModal={(cData) => handleAddClient(cData)}
            />
          ) : activeTab === 0 ? (
            <DashboardTab
              invoices={invoices}
              expenses={expenses}
              clients={clients}
              isDarkMode={isDarkMode}
              currencySymbol={sym}
              formatMoney={formatMoney}
              onNavigateToSales={() => setActiveTab(1)}
              onNavigateToExpenses={() => setActiveTab(2)}
              onCreateInvoice={handleCreateInvoice}
            />
          ) : activeTab === 1 ? (
            <SalesTab
              invoices={invoices}
              estimates={estimates}
              isDarkMode={isDarkMode}
              formatMoney={formatMoney}
              onCreateInvoice={handleCreateInvoice}
              onCreateQuote={handleCreateQuote}
              onRecordPayment={handleRecordPayment}
              onDeleteInvoice={handleDeleteInvoice}
              onConvertEstimate={handleConvertEstimate}
              onDeleteEstimate={handleDeleteEstimate}
            />
          ) : activeTab === 2 ? (
            <ExpensesTab
              expenses={expenses}
              isDarkMode={isDarkMode}
              formatMoney={formatMoney}
              onAddExpense={handleAddExpense}
              onDeleteExpense={handleDeleteExpense}
            />
          ) : activeTab === 3 && hubSubScreen === 'clients' ? (
            <ClientsTab
              clients={clients}
              isDarkMode={isDarkMode}
              onBack={() => setHubSubScreen('main')}
              onAddClient={handleAddClient}
              onDeleteClient={handleDeleteClient}
            />
          ) : activeTab === 3 && hubSubScreen === 'items' ? (
            <ItemsCatalogTab
              savedItems={savedItems}
              isDarkMode={isDarkMode}
              currencySymbol={sym}
              formatMoney={formatMoney}
              parsePriceToCents={parsePriceToCents}
              onBack={() => setHubSubScreen('main')}
              onAddItem={handleAddItem}
              onDeleteItem={handleDeleteItem}
            />
          ) : (
            <HubSettingsTab
              isDarkMode={isDarkMode}
              onOpenClients={() => setHubSubScreen('clients')}
              onOpenItems={() => setHubSubScreen('items')}
              onOpenProfile={() => setIsProfileModalOpen(true)}
              onOpenCsvModal={() => setIsCsvModalOpen(true)}
              onRestoreDatabase={handleRestoreDatabase}
            />
          )}
        </main>
      </div>

      {/* Mobile Bottom Navigation Bar (4 destinations) */}
      <div className={`md:hidden fixed bottom-0 left-0 right-0 border-t flex items-center justify-around py-2 px-4 z-40 ${isDarkMode ? 'bg-[#0F172A] border-slate-800 text-slate-400' : 'bg-white border-slate-200 text-slate-600'}`}>
        {[
          { id: 0, label: 'Dashboard', icon: LayoutDashboard },
          { id: 1, label: 'Sales', icon: ReceiptText },
          { id: 2, label: 'Expenses', icon: Wallet },
          { id: 3, label: 'Hub', icon: Settings },
        ].map((item) => {
          const Icon = item.icon;
          const isActive = activeTab === item.id && editorMode === 'none';
          return (
            <button
              key={item.id}
              onClick={() => {
                setEditorMode('none');
                setHubSubScreen('main');
                setActiveTab(item.id);
              }}
              className={`flex flex-col items-center gap-1 text-[10px] font-bold cursor-pointer ${isActive ? 'text-indigo-600' : ''}`}
            >
              <Icon className="w-5 h-5" />
              <span>{item.label}</span>
            </button>
          );
        })}
      </div>

      {/* Modals */}
      {isProfileModalOpen && (
        <BusinessProfileDialog
          businessProfile={businessProfile}
          isDarkMode={isDarkMode}
          onClose={() => setIsProfileModalOpen(false)}
          onSaveProfile={(profData) => setBusinessProfile(profData)}
        />
      )}

      {isCsvModalOpen && (
        <div className="fixed inset-0 bg-black/50 backdrop-blur-xs flex items-center justify-center p-4 z-50">
          <div className={`w-full max-w-md rounded-xl border p-6 space-y-4 ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}>
            <div className="flex items-center justify-between">
              <h3 className="font-bold text-sm">Export Financial CSV Data</h3>
              <button onClick={() => setIsCsvModalOpen(false)}><X className="w-4 h-4" /></button>
            </div>
            <p className="text-xs text-slate-500">Download formatted accounting CSV spreadsheet files.</p>
            <div className="space-y-2">
              <button
                onClick={() => {
                  const lines = ['Invoice Number,Issue Date,Due Date,Client Name,Total,Status'];
                  invoices.forEach((i) => lines.push(`${i.invoice_number},${i.issue_date},${i.due_date},"${i.client_name}",${(i.total_cents / 100).toFixed(2)},${i.computed_status || i.status}`));
                  const blob = new Blob([lines.join('\n')], { type: 'text/csv' });
                  const url = URL.createObjectURL(blob);
                  const a = document.createElement('a'); a.href = url; a.download = 'invoices.csv'; a.click();
                  setIsCsvModalOpen(false);
                }}
                className="w-full p-3 bg-indigo-50 hover:bg-indigo-100 text-indigo-700 font-bold text-xs rounded-xl flex items-center justify-between transition"
              >
                <span>Export Invoices CSV ({invoices.length})</span>
                <FileSpreadsheet className="w-4 h-4" />
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default App;
