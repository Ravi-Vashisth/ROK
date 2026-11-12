import React, { useState, useEffect } from 'react';
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
import { SettingsTab } from './components/settings/SettingsTab';
import { BusinessProfileDialog } from './components/business_profile/BusinessProfileDialog';
import { RecordPaymentModal } from './components/payments/RecordPaymentModal';

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

export interface StoredItem {
  id: string;
  title: string;
  defaultPriceCents?: number;
  default_price_cents?: number;
  sacHsn?: string;
  sac_hsn?: string;
  description?: string;
}

export const App: React.FC = () => {
  // Theme state
  const [isDarkMode, setIsDarkMode] = useState<boolean>(false);
  const [accentColor, setAccentColor] = useState<string>('indigo');

  // Active Primary Tab: 0 = Dashboard, 1 = Sales & Clients, 2 = Expenses, 3 = Settings
  const [activeTab, setActiveTab] = useState<number>(0);
  const [salesSubTab, setSalesSubTab] = useState<number>(0); // 0=Invoices, 1=Quotes, 2=Clients

  // Settings subtab state
  const [settingsSubTab, setSettingsSubTab] = useState<number>(0);

  const [editorMode, setEditorMode] = useState<'none' | 'invoice' | 'estimate'>('none');
  const [editingDraftData, setEditingDraftData] = useState<any>(null);

  // Modals
  const [isProfileModalOpen, setIsProfileModalOpen] = useState<boolean>(false);
  const [isCsvModalOpen, setIsCsvModalOpen] = useState<boolean>(false);
  const [paymentModalInvoice, setPaymentModalInvoice] = useState<InvoiceRecord | null>(null);

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
  useEffect(() => {
    if (isDarkMode) {
      document.documentElement.classList.add('dark');
    } else {
      document.documentElement.classList.remove('dark');
    }
  }, [isDarkMode]);

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
    setEditingDraftData(null);
    setActiveTab(1);
    setSalesSubTab(0);
    setEditorMode('invoice');
  };

  const handleCreateQuote = () => {
    setEditingDraftData(null);
    setActiveTab(1);
    setSalesSubTab(1);
    setEditorMode('estimate');
  };

  const handleEditInvoiceDraft = (inv: InvoiceRecord) => {
    setEditingDraftData(inv);
    setActiveTab(1);
    setSalesSubTab(0);
    setEditorMode('invoice');
  };

  const handleEditEstimateDraft = (est: StoredEstimateRecord) => {
    setEditingDraftData(est);
    setActiveTab(1);
    setSalesSubTab(1);
    setEditorMode('estimate');
  };

  const handleSaveDocFromEditor = (docData: any) => {
    if (editorMode === 'invoice') {
      if (docData.existingId) {
        setInvoices((prev) =>
          prev.map((i) => {
            if (i.id !== docData.existingId) return i;
            let invNum = i.invoice_number;
            if (!docData.isDraft && invNum.startsWith('DRAFT-')) {
              const count = prev.filter((x) => !x.invoice_number.startsWith('DRAFT-')).length + 1;
              invNum = `INV-${count.toString().padStart(4, '0')}`;
            }
            return {
              ...i,
              client_id: docData.clientId,
              client_name: docData.clientName,
              invoice_number: invNum,
              subtotal_cents: docData.subtotalCents,
              tax_cents: docData.taxCents,
              total_cents: docData.totalCents,
              status: docData.isDraft ? 'DRAFT' : 'PENDING',
              computed_status: docData.isDraft ? 'DRAFT' : 'PENDING',
              issue_date: docData.issueDate,
              due_date: calculateDueDate(docData.issueDate, docData.paymentTerms),
              payment_terms: docData.paymentTerms,
              balance_due_cents: Math.max(0, docData.totalCents - (i.paid_cents || 0)),
            };
          })
        );
      } else {
        const invNumber = docData.isDraft
          ? `DRAFT-${Math.random().toString(36).substring(2, 8).toUpperCase()}`
          : `INV-${(invoices.filter((x) => !x.invoice_number.startsWith('DRAFT-')).length + 1).toString().padStart(4, '0')}`;
        const newInv: InvoiceRecord = {
          id: `inv-${Date.now()}`,
          client_id: docData.clientId,
          client_name: docData.clientName,
          invoice_number: invNumber,
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
      }
    } else {
      if (docData.existingId) {
        setEstimates((prev) =>
          prev.map((e) => {
            if (e.id !== docData.existingId) return e;
            let estNum = e.estimate_number;
            if (!docData.isDraft && estNum.startsWith('DRAFT-')) {
              const count = prev.filter((x) => !x.estimate_number.startsWith('DRAFT-')).length + 1;
              estNum = `EST-${count.toString().padStart(4, '0')}`;
            }
            return {
              ...e,
              client_id: docData.clientId,
              client_name: docData.clientName,
              estimate_number: estNum,
              subtotal_cents: docData.subtotalCents,
              tax_cents: docData.taxCents,
              total_cents: docData.totalCents,
              status: docData.isDraft ? 'DRAFT' : 'PENDING',
              issue_date: docData.issueDate,
              expiry_date: calculateDueDate(docData.issueDate, 'Net 30 Days'),
            };
          })
        );
      } else {
        const estNumber = docData.isDraft
          ? `DRAFT-${Math.random().toString(36).substring(2, 8).toUpperCase()}`
          : `EST-${(estimates.filter((x) => !x.estimate_number.startsWith('DRAFT-')).length + 1).toString().padStart(4, '0')}`;
        const newEst: StoredEstimateRecord = {
          id: `est-${Date.now()}`,
          client_id: docData.clientId,
          client_name: docData.clientName,
          estimate_number: estNumber,
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
    }
    setEditingDraftData(null);
    setEditorMode('none');
  };

  const handleRecordPayment = (inv: InvoiceRecord) => {
    setPaymentModalInvoice(inv);
  };

  const handlePaymentSubmit = (paymentData: any) => {
    setInvoices((prev) =>
      prev.map((i) => {
        if (i.id !== paymentData.invoiceId) return i;
        const currentPaid = i.paid_cents || 0;
        const newPaid = currentPaid + paymentData.totalCreditCents;
        const newBalance = Math.max(0, i.total_cents - newPaid);
        const newStatus = newBalance === 0 ? 'PAID' : 'PARTIALLY_PAID';
        return {
          ...i,
          paid_cents: newPaid,
          balance_due_cents: newBalance,
          status: newStatus,
          computed_status: newStatus,
        };
      })
    );
  };

  const handleDeleteInvoice = (inv: InvoiceRecord) => {
    if (confirm(`Are you sure you want to delete invoice ${inv.invoice_number}?`)) {
      setInvoices((prev) => prev.filter((i) => i.id !== inv.id));
    }
  };

  const handleFinalizeInvoice = (inv: InvoiceRecord) => {
    setInvoices((prev) =>
      prev.map((i) => {
        if (i.id !== inv.id) return i;
        let num = i.invoice_number;
        if (num.startsWith('DRAFT-')) {
          const count = prev.filter((x) => !x.invoice_number.startsWith('DRAFT-')).length + 1;
          num = `INV-${count.toString().padStart(4, '0')}`;
        }
        return { ...i, invoice_number: num, status: 'PENDING', computed_status: 'PENDING' };
      })
    );
  };

  const handleFinalizeEstimate = (est: StoredEstimateRecord) => {
    setEstimates((prev) =>
      prev.map((e) => {
        if (e.id !== est.id) return e;
        let num = e.estimate_number;
        if (num.startsWith('DRAFT-')) {
          const count = prev.filter((x) => !x.estimate_number.startsWith('DRAFT-')).length + 1;
          num = `EST-${count.toString().padStart(4, '0')}`;
        }
        return { ...e, estimate_number: num, status: 'PENDING' };
      })
    );
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

  const handleUpdateClient = (id: string, updatedData: any) => {
    setClients((prev) =>
      prev.map((c) =>
        c.id === id
          ? {
              ...c,
              name: updatedData.name,
              email: updatedData.email || '',
              phone: updatedData.phone || '',
              address: updatedData.address || '',
              tax_id: updatedData.taxId || '',
            }
          : c
      )
    );
  };

  const handleDeleteClient = (client: Client) => {
    const hasInvoices = invoices.some((i) => i.client_id === client.id);
    if (hasInvoices) {
      alert(`Cannot delete client "${client.name}" because active invoices exist for this client. Foreign key integrity prevents deleting clients with financial records.`);
      return;
    }
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
      description: iData.description || '',
    };
    setSavedItems((prev) => [...prev, newI]);
  };

  const handleUpdateItem = (id: string, updatedData: any) => {
    setSavedItems((prev) =>
      prev.map((item) =>
        item.id === id
          ? {
              ...item,
              title: updatedData.title,
              defaultPriceCents: updatedData.default_price_cents,
              default_price_cents: updatedData.default_price_cents,
              sacHsn: updatedData.sac_hsn,
              sac_hsn: updatedData.sac_hsn,
              description: updatedData.description,
            }
          : item
      )
    );
  };

  const handleDeleteItem = (item: any) => {
    if (confirm(`Delete preset service "${item.title}"?`)) {
      setSavedItems((prev) => prev.filter((i) => i.id !== item.id));
    }
  };

  const handleExportDatabase = () => {
    const backupData = {
      clients,
      invoices,
      estimates,
      expenses,
      savedItems,
      businessProfile,
      version: 1,
      exported_at: new Date().toISOString(),
    };
    const jsonString = JSON.stringify(backupData, null, 2);
    const blob = new Blob([jsonString], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const dateStr = new Date().toISOString().split('T')[0];
    const a = document.createElement('a');
    a.href = url;
    a.download = `freelance_ledger_backup_${dateStr}.json`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
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
      {/* 1. MASTER SIDEBAR NAVIGATION (4 First-Class Desktop Tabs) */}
      <aside className={`hidden md:flex flex-col w-[220px] border-r select-none sticky top-0 h-screen shrink-0 ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}>
        <div className={`p-5 border-b flex flex-col items-center text-center gap-2 ${isDarkMode ? 'border-slate-800' : 'border-slate-100'}`}>
          <div className={`w-12 h-12 rounded-full text-white flex items-center justify-center font-bold text-lg shadow-xs shrink-0 ${accentColors[accentColor]?.bg || 'bg-indigo-600'}`}>
            {businessProfile.business_name ? businessProfile.business_name[0].toUpperCase() : 'F'}
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
            { id: 1, label: 'Sales & Clients', icon: ReceiptText },
            { id: 2, label: 'Expenses', icon: Wallet },
            { id: 3, label: 'Settings', icon: Settings },
          ].map((item) => {
            const Icon = item.icon;
            const isActive = activeTab === item.id && editorMode === 'none';
            return (
              <button
                key={item.id}
                onClick={() => {
                  setEditorMode('none');
                  setActiveTab(item.id);
                  if (item.id === 3) setSettingsSubTab(0);
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
          {/* Top Utility Bar */}
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
              initialData={editingDraftData}
              isDarkMode={isDarkMode}
              businessProfile={businessProfile}
              clients={clients}
              savedItems={savedItems}
              currencySymbol={sym}
              formatMoney={formatMoney}
              parsePriceToCents={parsePriceToCents}
              onSave={handleSaveDocFromEditor}
              onCancel={() => {
                setEditingDraftData(null);
                setEditorMode('none');
              }}
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
              clients={clients}
              isDarkMode={isDarkMode}
              formatMoney={formatMoney}
              initialSubTab={salesSubTab}
              onCreateInvoice={handleCreateInvoice}
              onCreateQuote={handleCreateQuote}
              onRecordPayment={handleRecordPayment}
              onDeleteInvoice={handleDeleteInvoice}
              onConvertEstimate={handleConvertEstimate}
              onDeleteEstimate={handleDeleteEstimate}
              onEditInvoiceDraft={handleEditInvoiceDraft}
              onEditEstimateDraft={handleEditEstimateDraft}
              onFinalizeInvoice={handleFinalizeInvoice}
              onFinalizeEstimate={handleFinalizeEstimate}
              onAddClient={handleAddClient}
              onUpdateClient={handleUpdateClient}
              onDeleteClient={handleDeleteClient}
            />
          ) : activeTab === 2 ? (
            <ExpensesTab
              expenses={expenses}
              isDarkMode={isDarkMode}
              formatMoney={formatMoney}
              onAddExpense={handleAddExpense}
              onDeleteExpense={handleDeleteExpense}
            />
          ) : (
            <SettingsTab
              isDarkMode={isDarkMode}
              businessProfile={businessProfile}
              savedItems={savedItems}
              currencySymbol={sym}
              formatMoney={formatMoney}
              parsePriceToCents={parsePriceToCents}
              initialSubTab={settingsSubTab}
              onSaveProfile={(profData) => setBusinessProfile(profData)}
              onAddItem={handleAddItem}
              onUpdateItem={handleUpdateItem}
              onDeleteItem={handleDeleteItem}
              onExportDatabase={handleExportDatabase}
              onRestoreDatabase={handleRestoreDatabase}
            />
          )}
        </main>
      </div>

      {/* Mobile Bottom Navigation Bar (STRICTLY 4 DESTINATIONS) */}
      <div className={`md:hidden fixed bottom-0 left-0 right-0 border-t flex items-center justify-around py-2 px-4 z-40 ${isDarkMode ? 'bg-[#0F172A] border-slate-800 text-slate-400' : 'bg-white border-slate-200 text-slate-600'}`}>
        {[
          { id: 0, label: 'Dashboard', icon: LayoutDashboard },
          { id: 1, label: 'Sales & Clients', icon: ReceiptText },
          { id: 2, label: 'Expenses', icon: Wallet },
          { id: 3, label: 'Settings', icon: Settings },
        ].map((item) => {
          const Icon = item.icon;
          const isActive = activeTab === item.id && editorMode === 'none';
          return (
            <button
              key={item.id}
              onClick={() => {
                setEditorMode('none');
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
              <button onClick={() => setIsCsvModalOpen(false)} className="cursor-pointer text-slate-400 hover:text-slate-600"><X className="w-4 h-4" /></button>
            </div>
            <p className="text-xs text-slate-500">Download formatted accounting CSV spreadsheet files compliant with Excel, QuickBooks, and tax software.</p>
            <div className="space-y-3">
              {/* Invoices CSV (Finalized only) */}
              <button
                onClick={() => {
                  const finalizedInvoices = invoices.filter((i) => {
                    const s = (i.computed_status || i.status || '').toUpperCase();
                    return s !== 'DRAFT';
                  });
                  const lines = ['Invoice Number,Issue Date,Due Date,Currency Code,Client Name,Client Tax ID,Subtotal,Tax,Total,Amount Paid,Balance Due,Status'];
                  finalizedInvoices.forEach((i) => {
                    const status = (i.computed_status || i.status || '').toUpperCase();
                    const isVoid = status === 'VOID';
                    const paid = (i.paid_cents || 0) / 100;
                    const total = (i.total_cents || 0) / 100;
                    const due = isVoid ? 0 : Math.max(0, total - paid);
                    const client = clients.find((c) => c.id === i.client_id);
                    const taxId = client?.tax_id || '';
                    const isoCode = businessProfile.currency_code || 'USD';
                    lines.push(
                      `"${i.invoice_number}","${i.issue_date}","${i.due_date}","${isoCode}","${(i.client_name || '').replace(/"/g, '""')}","${taxId}",${((i.subtotal_cents || 0) / 100).toFixed(2)},${((i.tax_cents || 0) / 100).toFixed(2)},${total.toFixed(2)},${paid.toFixed(2)},${due.toFixed(2)},"${isVoid ? 'VOID' : status}"`
                    );
                  });
                  const blob = new Blob(['\uFEFF' + lines.join('\n')], { type: 'text/csv;charset=utf-8;' });
                  const url = URL.createObjectURL(blob);
                  const a = document.createElement('a');
                  a.href = url;
                  a.download = 'invoices_export.csv';
                  a.click();
                  URL.revokeObjectURL(url);
                  setIsCsvModalOpen(false);
                }}
                className="w-full p-3 bg-indigo-50 hover:bg-indigo-100 text-indigo-700 font-bold text-xs rounded-xl flex items-center justify-between transition cursor-pointer"
              >
                <div className="text-left">
                  <div>Invoices CSV ({invoices.filter((i) => (i.computed_status || i.status || '').toUpperCase() !== 'DRAFT').length})</div>
                  <div className="text-[10px] opacity-75 font-normal">Finalized invoices only • headers on row 1 (invoices_export.csv)</div>
                </div>
                <FileSpreadsheet className="w-4 h-4 shrink-0" />
              </button>

              {/* Expenses CSV */}
              <button
                onClick={() => {
                  const lines = ['Expense ID,Date,Category,Vendor,Currency Code,Amount,Tax,Total,Notes'];
                  const isoCode = businessProfile.currency_code || 'USD';
                  expenses.forEach((e) => {
                    lines.push(
                      `"${e.id}","${e.expense_date}","${e.category}","${(e.vendor || '').replace(/"/g, '""')}","${isoCode}",${((e.amount_cents || 0) / 100).toFixed(2)},${((e.tax_cents || 0) / 100).toFixed(2)},${((e.total_cents || 0) / 100).toFixed(2)},""`
                    );
                  });
                  const blob = new Blob(['\uFEFF' + lines.join('\n')], { type: 'text/csv;charset=utf-8;' });
                  const url = URL.createObjectURL(blob);
                  const a = document.createElement('a');
                  a.href = url;
                  a.download = 'expenses_export.csv';
                  a.click();
                  URL.revokeObjectURL(url);
                  setIsCsvModalOpen(false);
                }}
                className="w-full p-3 bg-amber-50 hover:bg-amber-100 text-amber-700 font-bold text-xs rounded-xl flex items-center justify-between transition cursor-pointer"
              >
                <div className="text-left">
                  <div>Expenses CSV ({expenses.length})</div>
                  <div className="text-[10px] opacity-75 font-normal">All operating expenses • headers on row 1 (expenses_export.csv)</div>
                </div>
                <FileSpreadsheet className="w-4 h-4 shrink-0" />
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Rich Payment Modal */}
      {paymentModalInvoice && (
        <RecordPaymentModal
          invoice={paymentModalInvoice}
          isOpen={!!paymentModalInvoice}
          isDarkMode={isDarkMode}
          currencySymbol={sym}
          formatMoney={formatMoney}
          parsePriceToCents={parsePriceToCents}
          onClose={() => setPaymentModalInvoice(null)}
          onSubmit={handlePaymentSubmit}
        />
      )}
    </div>
  );
};

export default App;
