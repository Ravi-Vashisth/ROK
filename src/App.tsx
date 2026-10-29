import React, { useState, useEffect, useMemo } from 'react';
import {
  LayoutDashboard,
  ReceiptText,
  Wallet,
  Users,
  Building2,
  FileText,
  CheckCircle,
  CreditCard,
  AlertTriangle,
  FileSpreadsheet,
  Plus,
  Copy,
  Printer,
  Trash2,
  Search,
  Download,
  Settings,
  Package,
  ArrowLeft,
  X,
  FileCheck,
  Paperclip,
} from 'lucide-react';
import { parsePriceToCents, calculateDueDate, isInvoiceOverdue } from './billingRules';

// --- Parity Models & Interfaces ---
export interface Client {
  id: string;
  name: string;
  email: string;
  phone: string;
  address: string;
  tax_id: string;
  created_at: string;
  notes?: string;
}

export interface StoredInvoiceItem {
  id: string;
  invoice_id: string;
  description: string;
  sac_hsn?: string;
  quantity: number;
  unit_price_cents: number;
  total_cents: number;
  tax_slab?: number;
  created_at: string;
}

export interface StoredPayment {
  id: string;
  invoice_id: string;
  amount_cents: number;
  amount_received_cents?: number;
  tds_cents?: number;
  reference_number?: string;
  payment_method: string;
  payment_date: string;
  notes: string;
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
  status: string; // 'PENDING' | 'PARTIALLY_PAID' | 'PAID' | 'OVERDUE' | 'VOID'
  issue_date: string;
  due_date: string;
  payment_terms: string;
  terms?: string;
  notes?: string;
  discount_type?: 'none' | 'percent' | 'flat';
  discount_value?: number;
  discount_cents?: number;
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
  status: string; // 'DRAFT' | 'SENT' | 'CONVERTED' | 'DECLINED'
  issue_date: string;
  expiry_date: string;
  converted_invoice_id?: string;
  terms?: string;
  notes?: string;
  created_at: string;
}

export interface StoredEstimateItem {
  id: string;
  estimate_id: string;
  description: string;
  sac_hsn?: string;
  quantity: number;
  unit_price_cents: number;
  total_cents: number;
  created_at: string;
}

export interface ExpenseRecord {
  id: string;
  category: string;
  vendor: string;
  amount_cents: number;
  tax_cents: number;
  total_cents: number;
  expense_date: string;
  notes: string;
  receipt_base64?: string;
  receipt_name?: string;
  created_at: string;
}

export interface StoredItem {
  id: string;
  title: string;
  sac_hsn?: string;
  default_price_cents: number;
  description: string;
  created_at: string;
}

export interface BusinessProfile {
  business_name: string;
  currency_symbol: string;
  currency_code: string;
  email: string;
  phone: string;
  address: string;
  tax_id: string;
  payment_details: string;
  default_terms: string;
  default_notes: string;
  logo_base64: string;
  signature_base64: string;
  signature_label: string;
  invoice_prefix: string;
  estimate_prefix: string;
  payment_qr_payload?: string;
}

const DEFAULT_PROFILE: BusinessProfile = {
  business_name: 'My Freelance Studio',
  currency_symbol: '₹',
  currency_code: 'INR',
  email: 'billing@studio.com',
  phone: '+1 (555) 019-2834',
  address: '100 Tech Plaza, Suite 400, San Francisco, CA 94107',
  tax_id: 'US-EIN-987654321',
  payment_details: 'Bank: Silicon Valley Bank\nAccount: 987654321098\nRouting / SWIFT: SVB12345\nPayPal / UPI: pay@studio.com',
  default_terms: 'Payment due within agreed terms. Thank you for your business!',
  default_notes: 'All work includes 30 days post-delivery support.',
  logo_base64: '',
  signature_base64: '',
  signature_label: 'Authorized Signatory',
  invoice_prefix: 'INV-',
  estimate_prefix: 'EST-',
  payment_qr_payload: '',
};

export default function App() {
  useEffect(() => {
    document.title = 'Freelance Ledger — Enterprise SaaS';
  }, []);

  // --- LocalStorage Reactive State ---
  const [businessProfile, setBusinessProfile] = useState<BusinessProfile>(() => {
    try {
      const saved = localStorage.getItem('fl_business_profile');
      if (saved) return JSON.parse(saved);
    } catch (_) {}
    return DEFAULT_PROFILE;
  });

  const [clients, setClients] = useState<Client[]>(() => {
    try {
      const saved = localStorage.getItem('fl_clients');
      if (saved) return JSON.parse(saved);
    } catch (_) {}
    return [
      {
        id: 'client-1',
        name: 'ACME GLOBAL',
        email: 'accounts@acme.com',
        phone: '+1 (555) 234-5678',
        address: '500 Corporate Way, New York, NY 10001',
        tax_id: 'US-EIN-123456789',
        created_at: '2026-10-27T10:00:00Z',
        notes: 'Preferred enterprise client with net-30 terms.',
      },
      {
        id: 'client-2',
        name: 'Mohan Enterprises',
        email: 'billing@mohan.io',
        phone: '+91 98765 43210',
        address: '22 Creative Blvd, Bangalore, KA 560001',
        tax_id: 'GSTIN29ABCDE1234F1Z5',
        created_at: '2026-10-27T14:30:00Z',
        notes: 'Agile retainer client.',
      },
    ];
  });

  const [invoices, setInvoices] = useState<InvoiceRecord[]>(() => {
    try {
      const saved = localStorage.getItem('fl_invoices');
      if (saved) return JSON.parse(saved);
    } catch (_) {}
    return [
      {
        id: 'inv-3',
        client_id: 'client-1',
        client_name: 'ACME GLOBAL',
        invoice_number: 'INV-0003',
        subtotal_cents: 20000,
        tax_cents: 2000,
        total_cents: 22000,
        status: 'OVERDUE',
        issue_date: '2026-10-27',
        due_date: '2026-10-27',
        payment_terms: 'Due on Receipt',
        terms: 'Payment due on receipt.',
        notes: 'Urgent delivery items.',
        created_at: '2026-10-27T15:00:00Z',
      },
      {
        id: 'inv-2',
        client_id: 'client-2',
        client_name: 'Mohan Enterprises',
        invoice_number: 'INV-0002',
        subtotal_cents: 250000,
        tax_cents: 25000,
        total_cents: 275000,
        status: 'PENDING',
        issue_date: '2026-10-27',
        due_date: '2026-11-11',
        payment_terms: 'Net 15 Days',
        terms: 'Payment due in 15 days.',
        notes: 'Monthly retainer deliverable.',
        created_at: '2026-10-27T12:00:00Z',
      },
      {
        id: 'inv-1',
        client_id: 'client-1',
        client_name: 'ACME GLOBAL',
        invoice_number: 'INV-0001',
        subtotal_cents: 13516,
        tax_cents: 1352,
        total_cents: 14868,
        status: 'PAID',
        issue_date: '2026-10-27',
        due_date: '2026-10-27',
        payment_terms: 'Due on Receipt',
        terms: 'Settled via wire.',
        notes: 'Consultation kickoff.',
        created_at: '2026-10-27T09:00:00Z',
      },
    ];
  });

  const [invoiceItems, setInvoiceItems] = useState<StoredInvoiceItem[]>(() => {
    try {
      const saved = localStorage.getItem('fl_invoice_items');
      if (saved) return JSON.parse(saved);
    } catch (_) {}
    return [
      { id: 'item-1', invoice_id: 'inv-1', description: 'Initial Architecture Scoping', quantity: 1, unit_price_cents: 13516, total_cents: 13516, created_at: '2026-10-27T09:00:00Z' },
      { id: 'item-2', invoice_id: 'inv-2', description: 'Full-Stack Development Sprint 1', quantity: 1, unit_price_cents: 250000, total_cents: 250000, created_at: '2026-10-27T12:00:00Z' },
      { id: 'item-3', invoice_id: 'inv-3', description: 'Emergency SSL & DNS Migration', quantity: 1, unit_price_cents: 20000, total_cents: 20000, created_at: '2026-10-27T15:00:00Z' },
    ];
  });

  const [payments, setPayments] = useState<StoredPayment[]>(() => {
    try {
      const saved = localStorage.getItem('fl_payments');
      if (saved) return JSON.parse(saved);
    } catch (_) {}
    return [
      {
        id: 'pay-1',
        invoice_id: 'inv-1',
        amount_cents: 14868,
        amount_received_cents: 14868,
        tds_cents: 0,
        reference_number: 'BW-88219',
        payment_method: 'Bank Wire',
        payment_date: '2026-10-27',
        notes: 'Wire Ref #BW-88219',
        created_at: '2026-10-27T10:00:00Z',
      },
    ];
  });

  const [expenses, setExpenses] = useState<ExpenseRecord[]>(() => {
    try {
      const saved = localStorage.getItem('fl_expenses');
      if (saved) return JSON.parse(saved);
    } catch (_) {}
    return [
      { id: 'exp-1', category: 'Software & Tools', vendor: 'GitHub Enterprise', amount_cents: 2100, tax_cents: 210, total_cents: 2310, expense_date: '2026-10-01', notes: 'Monthly subscription' },
    ];
  });

  const [savedItems, setSavedItems] = useState<StoredItem[]>(() => {
    try {
      const saved = localStorage.getItem('fl_saved_items');
      if (saved) return JSON.parse(saved);
    } catch (_) {}
    return [
      { id: 'si-1', title: 'Software Architecture & Development', default_price_cents: 10000, description: 'Senior full-stack engineering rate', created_at: '2026-10-01' },
      { id: 'si-2', title: 'UI/UX Interface Design Mockups', default_price_cents: 8500, description: 'High-fidelity Figma mockups and wireframes', created_at: '2026-10-01' },
      { id: 'si-3', title: 'System Maintenance & Support (Monthly)', default_price_cents: 5000, description: 'Ongoing bug fixes and infrastructure upkeep', created_at: '2026-10-01' },
    ];
  });

  const [estimates, setEstimates] = useState<StoredEstimateRecord[]>(() => {
    try {
      const saved = localStorage.getItem('fl_estimates');
      if (saved) return JSON.parse(saved);
    } catch (_) {}
    return [];
  });

  const [estimateItems, setEstimateItems] = useState<StoredEstimateItem[]>(() => {
    try {
      const saved = localStorage.getItem('fl_estimate_items');
      if (saved) return JSON.parse(saved);
    } catch (_) {}
    return [];
  });

  // Save to localStorage
  useEffect(() => { localStorage.setItem('fl_business_profile', JSON.stringify(businessProfile)); }, [businessProfile]);
  useEffect(() => { localStorage.setItem('fl_clients', JSON.stringify(clients)); }, [clients]);
  useEffect(() => { localStorage.setItem('fl_invoices', JSON.stringify(invoices)); }, [invoices]);
  useEffect(() => { localStorage.setItem('fl_invoice_items', JSON.stringify(invoiceItems)); }, [invoiceItems]);
  useEffect(() => { localStorage.setItem('fl_payments', JSON.stringify(payments)); }, [payments]);
  useEffect(() => { localStorage.setItem('fl_expenses', JSON.stringify(expenses)); }, [expenses]);
  useEffect(() => { localStorage.setItem('fl_saved_items', JSON.stringify(savedItems)); }, [savedItems]);
  useEffect(() => { localStorage.setItem('fl_estimates', JSON.stringify(estimates)); }, [estimates]);
  useEffect(() => { localStorage.setItem('fl_estimate_items', JSON.stringify(estimateItems)); }, [estimateItems]);

  const handleExportInvoicesCsv = () => {
    const lines: string[] = ['\uFEFF'];
    lines.push('Invoice Number,Issue Date,Due Date,Client Name,Total,Status');
    for (const inv of invoices) {
      lines.push([quote(inv.invoice_number), quote(inv.issue_date), quote(inv.due_date), quote(inv.client_name), formatDecimal(inv.total_cents), quote(getComputedInvoiceStatus(inv))].join(','));
    }
    const blob = new Blob([lines.join('\n')], { type: 'text/csv;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'invoices_export.csv';
    a.click();
    URL.revokeObjectURL(url);
    setIsCsvModalOpen(false);
  };

  // --- Master Navigation State ---
  // 0: Dashboard, 1: Invoices, 2: Quotes, 3: Clients, 4: Expenses, 5: Catalog, 6: Settings
  const [activeTab, setActiveTab] = useState(0);

  // --- Feature Overhaul States ---
  // 1. Two-Column Live Invoice & Quote Editor State
  const [editorMode, setEditorMode] = useState<'none' | 'invoice' | 'quote'>('none');
  const [editorClientSearch, setEditorClientSearch] = useState('');
  const [editorClientId, setEditorClientId] = useState<string>('client-1');
  const [editorIssueDate, setEditorIssueDate] = useState(() => new Date().toISOString().split('T')[0]);
  const [editorPaymentTerms, setEditorPaymentTerms] = useState('Due on Receipt');
  const [editorItems, setEditorItems] = useState<{ id: string; description: string; sac_hsn: string; unitPriceCents: number; quantity: number; taxSlab: number; totalCents: number }[]>([
    { id: 'ed-1', description: 'Full-Stack Architecture & Implementation', sac_hsn: '998311', unitPriceCents: 15000, quantity: 1, taxSlab: 10, totalCents: 15000 }
  ]);
  const [editorDiscountType, setEditorDiscountType] = useState<'none' | 'percent' | 'flat'>('none');
  const [editorDiscountValue, setEditorDiscountValue] = useState('0');
  const [editorTerms, setEditorTerms] = useState(businessProfile.default_terms);
  const [editorNotes, setEditorNotes] = useState(businessProfile.default_notes);
  const [mobileEditorTab, setMobileEditorTab] = useState<'form' | 'preview'>('form');

  // 2. Client CRM Dossier State
  const [selectedDossierClientId, setSelectedDossierClientId] = useState<string>('client-1');
  const [clientSearchQuery, setClientSearchQuery] = useState('');
  const [clientDossierSubTab, setClientDossierSubTab] = useState<'invoices' | 'statement' | 'notes'>('invoices');

  // 3. Expense Slide-Over Drawer State
  const [isExpenseDrawerOpen, setIsExpenseDrawerOpen] = useState(false);
  const [expenseVendor, setExpenseVendor] = useState('');
  const [expenseCategory, setExpenseCategory] = useState('Software & Tools');
  const [expenseDate, setExpenseDate] = useState(() => new Date().toISOString().split('T')[0]);
  const [expenseAmount, setExpenseAmount] = useState('');
  const [expenseTax, setExpenseTax] = useState('');
  const [expenseNotes, setExpenseNotes] = useState('');
  const [expenseReceiptName, setExpenseReceiptName] = useState<string | null>(null);

  // Filter & Search state for Invoices / Estimates lists
  const [invoiceSearchQuery, setInvoiceSearchQuery] = useState('');
  const [invoiceStatusFilter, setInvoiceStatusFilter] = useState('ALL');
  const [estimateSearchQuery, setEstimateSearchQuery] = useState('');

  // Modals
  const [isProfileModalOpen, setIsProfileModalOpen] = useState(false);
  const [isCsvModalOpen, setIsCsvModalOpen] = useState(false);
  const [isClientModalOpen, setIsClientModalOpen] = useState(false);
  const [newClientName, setNewClientName] = useState('');
  const [recordPaymentInvoice, setRecordPaymentInvoice] = useState<InvoiceRecord | null>(null);
  const [paymentAmountReceived, setPaymentAmountReceived] = useState('');
  const [paymentTds, setPaymentTds] = useState('');
  const [previewInvoice, setPreviewInvoice] = useState<InvoiceRecord | null>(null);

  // Formatters
  const sym = businessProfile.currency_symbol || '₹';
  const formatMoney = (cents: number) => `${sym}${(cents / 100).toFixed(2)}`;
  const formatDecimal = (cents: number) => (cents / 100).toFixed(2);
  const quote = (text: string) => `"${(text || '').replace(/"/g, '""')}"`;

  // Calculations
  const getInvoicePaidCents = (invoiceId: string) => {
    return payments
      .filter((p) => p.invoice_id === invoiceId)
      .reduce((sum, p) => sum + ((p.amount_received_cents || 0) + (p.tds_cents || 0) || p.amount_cents), 0);
  };

  const getInvoiceBalanceDueCents = (inv: InvoiceRecord) => {
    if (inv.status === 'VOID') return 0;
    const paid = getInvoicePaidCents(inv.id);
    return Math.max(0, inv.total_cents - paid);
  };

  const getComputedInvoiceStatus = (inv: InvoiceRecord): 'PAID' | 'PARTIALLY_PAID' | 'OVERDUE' | 'PENDING' | 'VOID' => {
    if (inv.status === 'VOID') return 'VOID';
    const paid = getInvoicePaidCents(inv.id);
    const balance = inv.total_cents - paid;
    if (balance <= 0) return 'PAID';
    if (paid > 0) return 'PARTIALLY_PAID';
    if (isInvoiceOverdue(inv.status, inv.due_date)) return 'OVERDUE';
    return 'PENDING';
  };

  // Financial Pulse Metrics
  const totalCollectedGrossCents = payments.reduce((sum, p) => sum + ((p.amount_received_cents || 0) + (p.tds_cents || 0) || p.amount_cents), 0);
  const taxCollectedOnPaymentsCents = payments.reduce((sum, p) => {
    const inv = invoices.find(i => i.id === p.invoice_id);
    if (!inv || inv.status === 'VOID' || inv.total_cents <= 0) return sum;
    const credit = (p.amount_received_cents || 0) + (p.tds_cents || 0) || p.amount_cents;
    return sum + Math.round((credit * inv.tax_cents) / inv.total_cents);
  }, 0);

  const totalExpensesGrossCents = expenses.reduce((sum, e) => sum + e.total_cents, 0);
  const totalExpenseTaxCents = expenses.reduce((sum, e) => sum + e.tax_cents, 0);
  const totalExpensesExclTaxCents = Math.max(0, totalExpensesGrossCents - totalExpenseTaxCents);

  const taxLiabilityCents = taxCollectedOnPaymentsCents - totalExpenseTaxCents;
  const netRevenueExclTaxCents = totalCollectedGrossCents - taxCollectedOnPaymentsCents;
  const realNetProfitCents = netRevenueExclTaxCents - totalExpensesExclTaxCents;

  const nextInvoiceNumber = useMemo(() => {
    const prefix = businessProfile.invoice_prefix || 'INV-';
    let maxNum = 0;
    for (const inv of invoices) {
      const match = inv.invoice_number.match(/(\d+)$/);
      if (match) {
        const num = parseInt(match[1], 10);
        if (num > maxNum) maxNum = num;
      }
    }
    return `${prefix}${String(maxNum + 1).padStart(4, '0')}`;
  }, [invoices, businessProfile.invoice_prefix]);

  const nextEstimateNumber = useMemo(() => {
    const prefix = businessProfile.estimate_prefix || 'EST-';
    let maxNum = 0;
    for (const est of estimates) {
      const match = est.estimate_number.match(/(\d+)$/);
      if (match) {
        const num = parseInt(match[1], 10);
        if (num > maxNum) maxNum = num;
      }
    }
    return `${prefix}${String(maxNum + 1).padStart(4, '0')}`;
  }, [estimates, businessProfile.estimate_prefix]);

  // Live Editor Subtotals
  const editorSubtotalCents = editorItems.reduce((sum, i) => sum + (i.unitPriceCents * i.quantity), 0);
  const editorDiscountCents = editorDiscountType === 'percent'
    ? Math.round((editorSubtotalCents * (parseFloat(editorDiscountValue) || 0)) / 100)
    : editorDiscountType === 'flat' ? parsePriceToCents(editorDiscountValue) : 0;
  const editorNetSub = Math.max(0, editorSubtotalCents - editorDiscountCents);
  const editorTaxCents = editorItems.reduce((sum, i) => {
    const lineTotal = i.unitPriceCents * i.quantity;
    const lineNet = editorDiscountCents > 0 ? lineTotal - Math.round((lineTotal * editorDiscountCents) / editorSubtotalCents) : lineTotal;
    return sum + Math.round((lineNet * i.taxSlab) / 100);
  }, 0);
  const editorTotalCents = editorNetSub + editorTaxCents;

  return (
    <div className="min-h-screen bg-slate-50 text-slate-900 font-sans flex antialiased">
      {/* ===================================================================== */}
      {/* 1. MASTER SIDEBAR NAVIGATION HIERARCHY (7 DESTINATIONS) */}
      {/* ===================================================================== */}
      <aside className="hidden md:flex flex-col w-[220px] bg-white border-r border-slate-200 select-none sticky top-0 h-screen">
        <div className="p-5 border-b border-slate-100 flex items-center gap-3">
          <div className="w-9 h-9 rounded-full bg-indigo-100 text-indigo-700 flex items-center justify-center font-bold text-sm shrink-0">
            {businessProfile.business_name ? businessProfile.business_name[0].toUpperCase() : 'M'}
          </div>
          <div className="min-w-0">
            <h1 className="font-bold text-sm text-slate-900 whitespace-normal break-words leading-tight">
              {businessProfile.business_name || 'My Studio'}
            </h1>
            <p className="text-[11px] text-slate-400">Enterprise SaaS</p>
          </div>
        </div>

        <nav className="flex-1 p-3 space-y-1 overflow-y-auto">
          {[
            { id: 0, label: 'Dashboard', icon: LayoutDashboard },
            { id: 1, label: 'Invoices', icon: ReceiptText },
            { id: 2, label: 'Quotes', icon: FileText },
            { id: 3, label: 'Clients', icon: Users },
            { id: 4, label: 'Expenses', icon: Wallet },
            { id: 5, label: 'Catalog', icon: Package },
            { id: 6, label: 'Settings', icon: Settings },
          ].map(item => {
            const Icon = item.icon;
            const isActive = activeTab === item.id && editorMode === 'none';
            return (
              <button
                key={item.id}
                onClick={() => {
                  setEditorMode('none');
                  setActiveTab(item.id);
                }}
                className={`w-full flex items-center gap-3 px-3.5 py-2.5 rounded-xl text-sm font-semibold transition cursor-pointer ${
                  isActive
                    ? 'bg-indigo-50 text-indigo-700 shadow-sm'
                    : 'text-slate-600 hover:bg-slate-50 hover:text-slate-900'
                }`}
              >
                <Icon className={`w-5 h-5 ${isActive ? 'text-indigo-600' : 'text-slate-400'}`} />
                <span>{item.label}</span>
              </button>
            );
          })}
        </nav>
      </aside>

      {/* MAIN VIEWPORT */}
      <div className="flex-1 flex flex-col min-w-0 pb-16 md:pb-0">
        {/* Removed header */}
        <main className="flex-1 p-6 overflow-y-auto max-w-7xl mx-auto w-full space-y-6">
          {/* Global Utility Actions (Theme/Profile/Settings) */}
          <div className="flex justify-end gap-3 mb-6">
            <button className="p-2 text-slate-500 hover:text-slate-900"><Settings /></button>
          </div>
          
          {/* Main Action Bar (for Pages) */}
          {activeTab === 0 && editorMode === 'none' && (
             <div className="flex items-center justify-between">
                <h2 className="font-bold text-lg text-slate-900">Dashboard</h2>
                <div className="flex items-center gap-3">
                  <button onClick={() => { /* ... */ }} className="px-4 py-2 bg-indigo-600 text-white text-xs font-bold rounded-xl">+ Create Invoice</button>
                  <button onClick={() => { /* ... */ }} className="px-3.5 py-2 bg-white text-slate-700 border border-slate-200 text-xs font-bold rounded-xl">+ New Quote</button>
                  <button onClick={() => setIsExpenseDrawerOpen(true)} className="px-3.5 py-2 bg-white text-slate-700 border border-slate-200 text-xs font-bold rounded-xl">+ Log Expense</button>
                </div>
             </div>
          )}

          {/* Payment Reminder Modal */}
          {recordPaymentInvoice && (
            <div className="fixed inset-0 bg-slate-900/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
               <div className="bg-white rounded-2xl p-6 shadow-2xl">
                 <h4 className="font-bold text-base text-slate-900">Send Payment Reminder</h4>
                 <p className="text-xs text-slate-600 mt-2 mb-4">Invoice {recordPaymentInvoice.invoice_number} for {recordPaymentInvoice.client_name}</p>
                 <div className="space-y-3">
                   <button onClick={() => { navigator.clipboard.writeText(`Reminder: Invoice ${recordPaymentInvoice.invoice_number} is overdue.`); alert('Copied!'); }} className="w-full text-left px-4 py-3 bg-slate-100 rounded-xl font-bold text-xs">Copy Reminder Message</button>
                   <a href={`https://wa.me/?text=Reminder: Invoice ${recordPaymentInvoice.invoice_number} is overdue.`} target="_blank" className="block w-full text-left px-4 py-3 bg-slate-100 rounded-xl font-bold text-xs">Send via WhatsApp</a>
                   <a href={`mailto:?subject=Overdue Invoice ${recordPaymentInvoice.invoice_number}&body=Reminder: Invoice ${recordPaymentInvoice.invoice_number} is overdue.`} className="block w-full text-left px-4 py-3 bg-slate-100 rounded-xl font-bold text-xs">Send Email</a>
                   <button onClick={() => setRecordPaymentInvoice(null)} className="w-full py-2 text-xs text-slate-500 font-bold">Cancel</button>
                 </div>
               </div>
            </div>
          )}

          {/* Metrics Bar */}
          {activeTab === 0 && (
             <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
                <div className="p-4 bg-red-50 border border-red-200 rounded-xl">
                  <div className="text-[10px] font-bold text-red-900 uppercase">Unpaid Receivables</div>
                  <div className="text-lg font-bold text-red-900">{formatMoney(invoices.reduce((sum, inv) => inv.status !== 'PAID' && inv.status !== 'VOID' ? sum + getInvoiceBalanceDueCents(inv) : sum, 0))}</div>
                  <div className="text-[10px] font-bold text-red-700">Overdue: {formatMoney(invoices.filter(i => isInvoiceOverdue(i.status, i.due_date) && i.status !== 'PAID' && i.status !== 'VOID').reduce((sum, i) => sum + getInvoiceBalanceDueCents(i), 0))}</div>
                </div>
                <div className="p-4 bg-emerald-50 border border-emerald-200 rounded-xl">
                  <div className="text-[10px] font-bold text-emerald-900 uppercase">Gross Collected</div>
                  <div className="text-lg font-bold text-emerald-900">{formatMoney(totalCollectedGrossCents)}</div>
                </div>
                <div className="p-4 bg-purple-50 border border-purple-200 rounded-xl">
                  <div className="text-[10px] font-bold text-purple-900 uppercase">Tax Liability / GST</div>
                  <div className="text-lg font-bold text-purple-900">{formatMoney(taxLiabilityCents)}</div>
                </div>
                <div className="p-4 bg-blue-50 border border-blue-200 rounded-xl">
                  <div className="text-[10px] font-bold text-blue-900 uppercase">Real Net Profit</div>
                  <div className="text-lg font-bold text-blue-900">{formatMoney(realNetProfitCents)}</div>
                </div>
             </div>
          )}

          {/* Triage Inbox (Update button) */}
          {activeTab === 0 && (
            <div className="bg-amber-50 p-4 rounded-xl border border-amber-200">
              {invoices.filter(i => isInvoiceOverdue(i.status, i.due_date)).map(inv => (
                 <div key={inv.id} className="flex justify-between items-center py-2">
                    <span className="text-xs font-bold text-amber-900">Invoice {inv.invoice_number} is Overdue</span>
                    <button onClick={() => setRecordPaymentInvoice(inv)} className="px-3 py-1 bg-amber-200 text-amber-900 text-[10px] font-bold rounded-lg">Send Reminder</button>
                 </div>
              ))}
            </div>
          )}
            <div className="space-y-4">
              <div className="flex items-center justify-between bg-white p-4 rounded-2xl border border-slate-200 shadow-sm">
                <button
                  onClick={() => setEditorMode('none')}
                  className="flex items-center gap-2 text-xs font-bold text-slate-600 hover:text-slate-900 cursor-pointer"
                >
                  <ArrowLeft className="w-4 h-4" />
                  <span>Back to Hub</span>
                </button>
                <div className="flex md:hidden items-center gap-2">
                  <button
                    onClick={() => setMobileEditorTab('form')}
                    className={`px-3 py-1.5 rounded-lg text-xs font-bold ${mobileEditorTab === 'form' ? 'bg-indigo-600 text-white' : 'bg-slate-100 text-slate-600'}`}
                  >
                    ✏️ Editor
                  </button>
                  <button
                    onClick={() => setMobileEditorTab('preview')}
                    className={`px-3 py-1.5 rounded-lg text-xs font-bold ${mobileEditorTab === 'preview' ? 'bg-indigo-600 text-white' : 'bg-slate-100 text-slate-600'}`}
                  >
                    👁️ Preview
                  </button>
                </div>
                <div className="flex items-center gap-2">
                  <button
                    onClick={() => setEditorMode('none')}
                    className="px-4 py-2 bg-slate-100 hover:bg-slate-200 text-slate-700 text-xs font-bold rounded-xl cursor-pointer"
                  >
                    Cancel
                  </button>
                  <button
                    onClick={() => {
                      const client = clients.find(c => c.id === editorClientId);
                      if (!client) {
                        alert('Please select a client.');
                        return;
                      }
                      if (editorItems.length === 0) {
                        alert('Please add at least one line item.');
                        return;
                      }

                      if (editorMode === 'invoice') {
                        const newInv: InvoiceRecord = {
                          id: `inv-${Date.now()}`,
                          client_id: editorClientId,
                          client_name: client.name,
                          invoice_number: nextInvoiceNumber,
                          subtotal_cents: editorSubtotalCents,
                          tax_cents: editorTaxCents,
                          total_cents: editorTotalCents,
                          status: 'PENDING',
                          issue_date: editorIssueDate,
                          due_date: calculateDueDate(editorIssueDate, editorPaymentTerms),
                          payment_terms: editorPaymentTerms,
                          terms: editorTerms,
                          notes: editorNotes,
                          created_at: new Date().toISOString(),
                        };
                        const newItems = editorItems.map(it => ({
                          id: `ii-${Date.now()}-${Math.random()}`,
                          invoice_id: newInv.id,
                          description: it.description,
                          sac_hsn: it.sac_hsn,
                          quantity: it.quantity,
                          unit_price_cents: it.unitPriceCents,
                          total_cents: it.unitPriceCents * it.quantity,
                          created_at: new Date().toISOString(),
                        }));
                        setInvoices(prev => [newInv, ...prev]);
                        setInvoiceItems(prev => [...prev, ...newItems]);
                        alert(`Invoice ${newInv.invoice_number} saved and issued successfully!`);
                        setActiveTab(1);
                      } else {
                        const newEst: StoredEstimateRecord = {
                          id: `est-${Date.now()}`,
                          client_id: editorClientId,
                          client_name: client.name,
                          estimate_number: nextEstimateNumber,
                          subtotal_cents: editorSubtotalCents,
                          tax_cents: editorTaxCents,
                          total_cents: editorTotalCents,
                          status: 'SENT',
                          issue_date: editorIssueDate,
                          expiry_date: calculateDueDate(editorIssueDate, 'Net 30 Days'),
                          terms: editorTerms,
                          notes: editorNotes,
                          created_at: new Date().toISOString(),
                        };
                        setEstimates(prev => [newEst, ...prev]);
                        alert(`Quote ${newEst.estimate_number} saved successfully!`);
                        setActiveTab(2);
                      }
                      setEditorMode('none');
                    }}
                    className="px-5 py-2 bg-indigo-600 hover:bg-indigo-700 text-white text-xs font-bold rounded-xl shadow-sm cursor-pointer flex items-center gap-1.5"
                  >
                    <FileCheck className="w-4 h-4" />
                    <span>Save & Issue {editorMode === 'invoice' ? 'Invoice' : 'Quote'}</span>
                  </button>
                </div>
              </div>

              {/* Two-Column Split View (Desktop 50/50, Mobile Tabbed) */}
              <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                {/* LEFT COLUMN: Input Controls */}
                <div className={`space-y-6 ${mobileEditorTab === 'preview' ? 'hidden lg:block' : 'block'}`}>
                  <div className="bg-white rounded-2xl border border-slate-200 p-6 shadow-sm space-y-4">
                    <h4 className="font-bold text-sm text-slate-900 uppercase tracking-wider">Client & Billing Details</h4>
                    <div>
                      <label className="block text-xs font-bold text-slate-600 mb-1">Select Client</label>
                      <select
                        value={editorClientId}
                        onChange={(e) => setEditorClientId(e.target.value)}
                        className="w-full px-3 py-2.5 rounded-xl border border-slate-200 text-sm bg-slate-50 font-semibold text-slate-800"
                      >
                        {clients.map(c => (
                          <option key={c.id} value={c.id}>{c.name} ({c.tax_id || 'No Tax ID'})</option>
                        ))}
                      </select>
                    </div>

                    <div className="grid grid-cols-2 gap-3">
                      <div>
                        <label className="block text-xs font-bold text-slate-600 mb-1">Issue Date</label>
                        <input
                          type="date"
                          value={editorIssueDate}
                          onChange={(e) => setEditorIssueDate(e.target.value)}
                          className="w-full px-3 py-2 rounded-xl border border-slate-200 text-xs bg-slate-50"
                        />
                      </div>
                      <div>
                        <label className="block text-xs font-bold text-slate-600 mb-1">Payment Terms</label>
                        <select
                          value={editorPaymentTerms}
                          onChange={(e) => setEditorPaymentTerms(e.target.value)}
                          className="w-full px-3 py-2 rounded-xl border border-slate-200 text-xs bg-slate-50"
                        >
                          <option value="Due on Receipt">Due on Receipt</option>
                          <option value="Net 15 Days">Net 15 Days</option>
                          <option value="Net 30 Days">Net 30 Days</option>
                          <option value="Net 60 Days">Net 60 Days</option>
                        </select>
                      </div>
                    </div>
                  </div>

                  {/* Line Items Table & Catalog Quick-Insert */}
                  <div className="bg-white rounded-2xl border border-slate-200 p-6 shadow-sm space-y-4">
                    <div className="flex items-center justify-between">
                      <h4 className="font-bold text-sm text-slate-900 uppercase tracking-wider">Line Items & Services</h4>
                      <select
                        onChange={(e) => {
                          const item = savedItems.find(si => si.id === e.target.value);
                          if (!item) return;
                          setEditorItems(prev => [
                            ...prev,
                            {
                              id: `ed-${Date.now()}`,
                              description: item.title,
                              sac_hsn: item.sac_hsn || '998311',
                              unitPriceCents: item.default_price_cents,
                              quantity: 1,
                              taxSlab: 10,
                              totalCents: item.default_price_cents,
                            }
                          ]);
                          e.target.value = '';
                        }}
                        defaultValue=""
                        className="px-3 py-1.5 rounded-xl border border-indigo-200 text-xs bg-indigo-50 text-indigo-700 font-bold cursor-pointer"
                      >
                        <option value="" disabled>+ Insert from Catalog...</option>
                        {savedItems.map(si => (
                          <option key={si.id} value={si.id}>{si.title} ({formatMoney(si.default_price_cents)})</option>
                        ))}
                      </select>
                    </div>

                    <div className="space-y-3">
                      {editorItems.map((item, idx) => (
                        <div key={item.id} className="p-3 bg-slate-50 rounded-xl border border-slate-200 space-y-2">
                          <div className="grid grid-cols-1 sm:grid-cols-12 gap-2">
                            <div className="sm:col-span-5">
                              <input
                                type="text"
                                value={item.description}
                                onChange={(e) => {
                                  const val = e.target.value;
                                  setEditorItems(prev => prev.map((it, i) => i === idx ? { ...it, description: val } : it));
                                }}
                                placeholder="Description"
                                className="w-full px-2.5 py-1.5 rounded-lg border border-slate-200 text-xs bg-white"
                              />
                            </div>
                            <div className="sm:col-span-2">
                              <input
                                type="text"
                                value={item.sac_hsn}
                                onChange={(e) => {
                                  const val = e.target.value;
                                  setEditorItems(prev => prev.map((it, i) => i === idx ? { ...it, sac_hsn: val } : it));
                                }}
                                placeholder="SAC/HSN"
                                className="w-full px-2.5 py-1.5 rounded-lg border border-slate-200 text-xs bg-white font-mono"
                              />
                            </div>
                            <div className="sm:col-span-2">
                              <input
                                type="number"
                                value={item.unitPriceCents / 100}
                                onChange={(e) => {
                                  const pCents = parsePriceToCents(e.target.value);
                                  setEditorItems(prev => prev.map((it, i) => i === idx ? { ...it, unitPriceCents: pCents } : it));
                                }}
                                placeholder="Price"
                                className="w-full px-2.5 py-1.5 rounded-lg border border-slate-200 text-xs bg-white"
                              />
                            </div>
                            <div className="sm:col-span-1">
                              <input
                                type="number"
                                value={item.quantity}
                                onChange={(e) => {
                                  const qty = parseInt(e.target.value, 10) || 1;
                                  setEditorItems(prev => prev.map((it, i) => i === idx ? { ...it, quantity: qty } : it));
                                }}
                                placeholder="Qty"
                                className="w-full px-2.5 py-1.5 rounded-lg border border-slate-200 text-xs bg-white text-center"
                              />
                            </div>
                            <div className="sm:col-span-2 flex items-center justify-end gap-2">
                              <select
                                value={item.taxSlab}
                                onChange={(e) => {
                                  const slab = parseInt(e.target.value, 10) || 0;
                                  setEditorItems(prev => prev.map((it, i) => i === idx ? { ...it, taxSlab: slab } : it));
                                }}
                                className="px-1 py-1 rounded border border-slate-200 text-[11px] bg-white"
                              >
                                <option value="0">0%</option>
                                <option value="5">5%</option>
                                <option value="12">12%</option>
                                <option value="18">18%</option>
                              </select>
                              <button
                                onClick={() => setEditorItems(prev => prev.filter((_, i) => i !== idx))}
                                className="text-red-500 hover:text-red-700 cursor-pointer p-1"
                              >
                                <Trash2 className="w-4 h-4" />
                              </button>
                            </div>
                          </div>
                        </div>
                      ))}
                    </div>

                    <button
                      onClick={() => {
                        setEditorItems(prev => [
                          ...prev,
                          { id: `ed-${Date.now()}`, description: 'New Service Item', sac_hsn: '998311', unitPriceCents: 10000, quantity: 1, taxSlab: 10, totalCents: 10000 }
                        ]);
                      }}
                      className="w-full py-2.5 bg-indigo-50 hover:bg-indigo-100 text-indigo-700 text-xs font-bold rounded-xl transition cursor-pointer flex items-center justify-center gap-2"
                    >
                      <Plus className="w-4 h-4" />
                      <span>+ Add Another Line Row (or press Enter)</span>
                    </button>
                  </div>

                  {/* Notes & Terms */}
                  <div className="bg-white rounded-2xl border border-slate-200 p-6 shadow-sm space-y-3">
                    <h4 className="font-bold text-sm text-slate-900 uppercase tracking-wider">Terms & Notes</h4>
                    <textarea
                      value={editorTerms}
                      onChange={(e) => setEditorTerms(e.target.value)}
                      rows={2}
                      className="w-full px-3 py-2 rounded-xl border border-slate-200 text-xs bg-slate-50"
                      placeholder="Payment terms..."
                    />
                    <textarea
                      value={editorNotes}
                      onChange={(e) => setEditorNotes(e.target.value)}
                      rows={2}
                      className="w-full px-3 py-2 rounded-xl border border-slate-200 text-xs bg-slate-50"
                      placeholder="Warranty or notes..."
                    />
                  </div>
                </div>

                {/* RIGHT COLUMN: Live Real-Time A4 Document Preview (WYSIWYG) */}
                <div className={`space-y-4 ${mobileEditorTab === 'form' ? 'hidden lg:block' : 'block'}`}>
                  <div className="bg-white rounded-2xl border border-slate-300 p-8 shadow-xl space-y-6 sticky top-20">
                    <div className="flex items-center justify-between border-b border-slate-200 pb-4">
                      <div>
                        <span className="text-[10px] font-bold text-indigo-600 uppercase tracking-widest">Live WYSIWYG Preview</span>
                        <h3 className="font-bold text-lg text-slate-900">{editorMode === 'invoice' ? 'TAX INVOICE' : 'PROPOSAL / QUOTE'}</h3>
                      </div>
                      <div className="text-right">
                        <span className="font-mono font-bold text-sm text-indigo-600">{editorMode === 'invoice' ? nextInvoiceNumber : nextEstimateNumber}</span>
                        <p className="text-xs text-slate-400 font-mono">Date: {editorIssueDate}</p>
                      </div>
                    </div>

                    <div className="flex justify-between text-xs">
                      <div>
                        <strong className="text-slate-900 text-sm">{businessProfile.business_name}</strong>
                        <p className="text-slate-500 whitespace-pre-line">{businessProfile.address}</p>
                        <p className="text-slate-500">Tax ID: {businessProfile.tax_id}</p>
                      </div>
                      <div className="text-right">
                        <span className="text-slate-400 uppercase tracking-wider text-[10px] block font-bold">Billed To:</span>
                        {(() => {
                          const c = clients.find(cl => cl.id === editorClientId);
                          if (!c) return <span className="text-slate-400">No client selected</span>;
                          return (
                            <div>
                              <strong className="text-slate-900">{c.name}</strong>
                              <p className="text-slate-500">{c.email}</p>
                              <p className="text-slate-500">{c.address}</p>
                              <p className="text-slate-500 font-mono">Tax ID: {c.tax_id || 'N/A'}</p>
                            </div>
                          );
                        })()}
                      </div>
                    </div>

                    {/* Live Line Items Table */}
                    <table className="w-full text-left text-xs border-collapse">
                      <thead>
                        <tr className="border-b border-slate-200 text-slate-600 font-bold">
                          <th className="py-2">Description</th>
                          <th className="py-2">SAC/HSN</th>
                          <th className="py-2 text-center">Qty</th>
                          <th className="py-2 text-right">Unit Price</th>
                          <th className="py-2 text-right">Amount</th>
                        </tr>
                      </thead>
                      <tbody className="divide-y divide-slate-100">
                        {editorItems.map(it => (
                          <tr key={it.id}>
                            <td className="py-2 font-medium text-slate-900">{it.description}</td>
                            <td className="py-2 font-mono text-slate-400">{it.sac_hsn || '-'}</td>
                            <td className="py-2 text-center">{it.quantity}</td>
                            <td className="py-2 text-right">{formatMoney(it.unitPriceCents)}</td>
                            <td className="py-2 text-right font-bold">{formatMoney(it.unitPriceCents * it.quantity)}</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>

                    {/* Totals */}
                    <div className="flex justify-end pt-3 border-t border-slate-200 text-xs">
                      <div className="w-52 space-y-1.5">
                        <div className="flex justify-between"><span>Subtotal:</span><span>{formatMoney(editorSubtotalCents)}</span></div>
                        <div className="flex justify-between"><span>Estimated Tax:</span><span>{formatMoney(editorTaxCents)}</span></div>
                        <div className="flex justify-between font-bold text-sm text-indigo-700 border-t pt-1">
                          <span>Total:</span>
                          <span>{formatMoney(editorTotalCents)}</span>
                        </div>
                      </div>
                    </div>

                    {businessProfile.payment_details && (
                      <div className="p-3 bg-indigo-50 rounded-xl border border-indigo-100 text-[11px] text-slate-700 whitespace-pre-line">
                        <strong>Payment Instructions:</strong>
                        <div>{businessProfile.payment_details}</div>
                      </div>
                    )}
                  </div>
                </div>
              </div>
            </div>
          ) : (
            <>
              {/* ===================================================================== */}
              {/* TAB 0: DASHBOARD */}
              {/* ===================================================================== */}
              {activeTab === 0 && (
                <div className="space-y-6">
                  <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3">
                    <div>
                      <h3 className="text-xl font-bold text-slate-900">Business Pulse & Action Center</h3>
                      <p className="text-xs text-slate-500">Real-time financial telemetry and urgent triage alerts</p>
                    </div>
                    <div className="flex items-center gap-2">
                      <button
                        onClick={() => {
                          setEditorItems([{ id: `ed-${Date.now()}`, description: 'Full-Stack Development', sac_hsn: '998311', unitPriceCents: 15000, quantity: 1, taxSlab: 10, totalCents: 15000 }]);
                          setEditorMode('invoice');
                        }}
                        className="px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white text-xs font-bold rounded-xl shadow-sm transition flex items-center gap-1.5 cursor-pointer"
                      >
                        <Plus className="w-4 h-4" />
                        <span>Create Invoice</span>
                      </button>
                      <button
                        onClick={() => {
                          setEditorItems([{ id: `ed-${Date.now()}`, description: 'UI/UX Proposal', sac_hsn: '998314', unitPriceCents: 8000, quantity: 1, taxSlab: 10, totalCents: 8000 }]);
                          setEditorMode('quote');
                        }}
                        className="px-3.5 py-2 bg-white hover:bg-slate-50 text-slate-700 border border-slate-200 text-xs font-bold rounded-xl shadow-sm transition flex items-center gap-1.5 cursor-pointer"
                      >
                        <FileText className="w-4 h-4 text-indigo-600" />
                        <span>New Quote</span>
                      </button>
                      <button
                        onClick={() => setIsExpenseDrawerOpen(true)}
                        className="px-3.5 py-2 bg-white hover:bg-slate-50 text-slate-700 border border-slate-200 text-xs font-bold rounded-xl shadow-sm transition flex items-center gap-1.5 cursor-pointer"
                      >
                        <Wallet className="w-4 h-4 text-orange-600" />
                        <span>Log Expense</span>
                      </button>
                    </div>
                  </div>

                  {/* Financial Pulse Row */}
                  <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
                    <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-sm space-y-2">
                      <span className="text-xs font-bold text-slate-400 uppercase tracking-wider">Gross Collected</span>
                      <div className="text-2xl font-bold text-slate-900">{formatMoney(totalCollectedGrossCents)}</div>
                      <p className="text-xs text-slate-500">Total cash wire + TDS received</p>
                    </div>
                    <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-sm space-y-2">
                      <span className="text-xs font-bold text-amber-600 uppercase tracking-wider">Tax Liability / GST</span>
                      <div className="text-2xl font-bold text-amber-700">{formatMoney(Math.max(0, taxLiabilityCents))}</div>
                      <p className="text-xs text-slate-500">Owed to tax authorities (Govt Share)</p>
                    </div>
                    <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-sm space-y-2">
                      <span className="text-xs font-bold text-emerald-600 uppercase tracking-wider">Net Revenue (Ex. Tax)</span>
                      <div className="text-2xl font-bold text-emerald-700">{formatMoney(netRevenueExclTaxCents)}</div>
                      <p className="text-xs text-slate-500">Actual earnings excluding tax</p>
                    </div>
                    <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-sm space-y-2">
                      <span className="text-xs font-bold text-indigo-600 uppercase tracking-wider">Real Net Profit</span>
                      <div className="text-2xl font-bold text-indigo-700">{formatMoney(realNetProfitCents)}</div>
                      <p className="text-xs text-slate-500">Net Revenue minus business expenses</p>
                    </div>
                  </div>

                  {/* Action Required Triage Inbox */}
                  <div className="bg-amber-50/60 border border-amber-200 rounded-2xl p-6 shadow-sm space-y-4">
                    <div className="flex items-center gap-2">
                      <AlertTriangle className="w-5 h-5 text-amber-600" />
                      <h4 className="font-bold text-base text-amber-900">Action Required Triage Inbox</h4>
                    </div>
                    {invoices.filter(i => i.status === 'OVERDUE' && getInvoiceBalanceDueCents(i) > 0).length === 0 && estimates.filter(e => e.status !== 'CONVERTED').length === 0 ? (
                      <p className="text-xs text-emerald-700 font-semibold">All client balances are up to date. No urgent action required.</p>
                    ) : (
                      <div className="space-y-3">
                        {invoices.filter(i => i.status === 'OVERDUE' && getInvoiceBalanceDueCents(i) > 0).map(inv => (
                          <div key={inv.id} className="flex items-center justify-between p-3.5 bg-white rounded-xl border border-amber-100 shadow-xs">
                            <div className="flex items-center gap-3">
                              <span className="w-2.5 h-2.5 rounded-full bg-red-500 shrink-0"></span>
                              <div>
                                <span className="font-bold text-sm text-slate-900">{inv.client_name}</span>
                                <p className="text-xs text-slate-500">Invoice {inv.invoice_number} is overdue ({formatMoney(getInvoiceBalanceDueCents(inv))} due)</p>
                              </div>
                            </div>
                            <button
                              onClick={() => setActiveTab(1)}
                              className="px-3 py-1.5 bg-red-50 hover:bg-red-100 text-red-700 text-xs font-bold rounded-lg transition cursor-pointer"
                            >
                              Send Reminder
                            </button>
                          </div>
                        ))}
                      </div>
                    )}
                  </div>
                </div>
              )}

              {/* ===================================================================== */}
              {/* TAB 1: INVOICES HUB (Sales) */}
              {/* ===================================================================== */}
              {activeTab === 1 && (
                <div className="space-y-6">
                  <div className="flex items-center justify-between">
                    <div>
                      <h3 className="text-xl font-bold text-slate-900">Invoices Management Hub</h3>
                      <p className="text-xs text-slate-500">Search, filter, record payments, and issue A4 invoices</p>
                    </div>
                    <button
                      onClick={() => {
                        setEditorItems([{ id: `ed-${Date.now()}`, description: 'Full-Stack Development', sac_hsn: '998311', unitPriceCents: 15000, quantity: 1, taxSlab: 10, totalCents: 15000 }]);
                        setEditorMode('invoice');
                      }}
                      className="px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white text-xs font-bold rounded-xl shadow-sm transition flex items-center gap-1.5 cursor-pointer"
                    >
                      <Plus className="w-4 h-4" />
                      <span>+ Create Invoice</span>
                    </button>
                  </div>

                  <div className="bg-white rounded-2xl border border-slate-200 overflow-hidden shadow-sm">
                    <div className="p-4 border-b border-slate-100 font-bold text-sm text-slate-800">
                      Invoices List ({invoices.length})
                    </div>
                    <div className="overflow-x-auto">
                      <table className="w-full text-left text-xs">
                        <thead className="bg-slate-50 text-slate-700 font-bold border-b border-slate-200">
                          <tr>
                            <th className="p-3">Status</th>
                            <th className="p-3">Invoice #</th>
                            <th className="p-3">Client Name</th>
                            <th className="p-3">Issue Date</th>
                            <th className="p-3 text-right">Total Amount</th>
                            <th className="p-3 text-right">Balance Due</th>
                            <th className="p-3 text-center">Actions</th>
                          </tr>
                        </thead>
                        <tbody className="divide-y divide-slate-100">
                          {invoices.map(inv => {
                            const bal = getInvoiceBalanceDueCents(inv);
                            const status = getComputedInvoiceStatus(inv);
                            return (
                              <tr key={inv.id} className="hover:bg-slate-50">
                                <td className="p-3"><span className="px-2 py-0.5 rounded text-[10px] font-bold bg-indigo-50 text-indigo-700">{status}</span></td>
                                <td className="p-3 font-mono font-bold text-indigo-600">{inv.invoice_number}</td>
                                <td className="p-3 font-bold text-slate-900">{inv.client_name}</td>
                                <td className="p-3 text-slate-500">{inv.issue_date}</td>
                                <td className="p-3 text-right font-bold">{formatMoney(inv.total_cents)}</td>
                                <td className="p-3 text-right font-bold text-indigo-700">{formatMoney(bal)}</td>
                                <td className="p-3 text-center">
                                  <div className="flex items-center justify-center gap-1.5">
                                    <button onClick={() => setPreviewInvoice(inv)} className="p-1.5 bg-indigo-50 text-indigo-700 rounded-lg" title="Print PDF"><Printer className="w-4 h-4" /></button>
                                    {bal > 0 && <button onClick={() => setRecordPaymentInvoice(inv)} className="p-1.5 bg-emerald-50 text-emerald-700 rounded-lg" title="Record Payment"><CreditCard className="w-4 h-4" /></button>}
                                  </div>
                                </td>
                              </tr>
                            );
                          })}
                        </tbody>
                      </table>
                    </div>
                  </div>
                </div>
              )}

              {/* ===================================================================== */}
              {/* TAB 2: QUOTES / ESTIMATES HUB */}
              {/* ===================================================================== */}
              {activeTab === 2 && (
                <div className="space-y-6">
                  <div className="flex items-center justify-between">
                    <div>
                      <h3 className="text-xl font-bold text-slate-900">Quotes & Proposals Hub</h3>
                      <p className="text-xs text-slate-500">Manage client proposals and convert accepted quotes to invoices</p>
                    </div>
                    <button
                      onClick={() => {
                        setEditorItems([{ id: `ed-${Date.now()}`, description: 'UI/UX Proposal', sac_hsn: '998314', unitPriceCents: 8000, quantity: 1, taxSlab: 10, totalCents: 8000 }]);
                        setEditorMode('quote');
                      }}
                      className="px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white text-xs font-bold rounded-xl shadow-sm transition flex items-center gap-1.5 cursor-pointer"
                    >
                      <Plus className="w-4 h-4" />
                      <span>+ New Quote</span>
                    </button>
                  </div>

                  <div className="bg-white rounded-2xl border border-slate-200 overflow-hidden shadow-sm">
                    <div className="p-4 border-b border-slate-100 font-bold text-sm text-slate-800">
                      Quotes List ({estimates.length})
                    </div>
                    {estimates.length === 0 ? (
                      <div className="p-8 text-center text-slate-400 text-sm">No quotes recorded yet.</div>
                    ) : (
                      <table className="w-full text-left text-xs">
                        <thead className="bg-slate-50 text-slate-700 font-bold border-b border-slate-200">
                          <tr>
                            <th className="p-3">Status</th>
                            <th className="p-3">Quote #</th>
                            <th className="p-3">Client</th>
                            <th className="p-3 text-right">Total</th>
                            <th className="p-3 text-center">Action</th>
                          </tr>
                        </thead>
                        <tbody className="divide-y divide-slate-100">
                          {estimates.map(est => (
                            <tr key={est.id}>
                              <td className="p-3"><span className="px-2 py-0.5 rounded text-[10px] font-bold bg-amber-50 text-amber-800">{est.status}</span></td>
                              <td className="p-3 font-mono font-bold">{est.estimate_number}</td>
                              <td className="p-3 font-bold">{est.client_name}</td>
                              <td className="p-3 text-right font-bold">{formatMoney(est.total_cents)}</td>
                              <td className="p-3 text-center">
                                {est.status !== 'CONVERTED' ? (
                                  <button
                                    onClick={() => {
                                      setEstimates(prev => prev.map(e => e.id === est.id ? { ...e, status: 'CONVERTED' } : e));
                                      alert(`Quote ${est.estimate_number} converted to invoice!`);
                                    }}
                                    className="px-3 py-1 bg-emerald-600 text-white font-bold rounded-lg text-xs"
                                  >
                                    Convert to Invoice
                                  </button>
                                ) : <span className="text-xs text-emerald-700 font-bold">✓ Converted</span>}
                              </td>
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    )}
                  </div>
                </div>
              )}

              {/* ===================================================================== */}
              {/* TAB 3: CLIENT CRM DOSSIER (Directory) */}
              {/* ===================================================================== */}
              {activeTab === 3 && (
                <div className="space-y-4">
                  <div className="flex items-center justify-between">
                    <div>
                      <h3 className="text-xl font-bold text-slate-900">Client CRM Dossier</h3>
                      <p className="text-xs text-slate-500">Master-detail enterprise CRM & Account Statements</p>
                    </div>
                    <button
                      onClick={() => setIsClientModalOpen(true)}
                      className="px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white text-xs font-bold rounded-xl shadow-sm transition flex items-center gap-1.5 cursor-pointer"
                    >
                      <Plus className="w-4 h-4" />
                      <span>+ Add Client</span>
                    </button>
                  </div>

                  <div className="grid grid-cols-1 lg:grid-cols-12 gap-6 items-start">
                    {/* LEFT PANE (30%): Searchable Client List */}
                    <div className="lg:col-span-4 bg-white rounded-2xl border border-slate-200 p-4 shadow-sm space-y-3">
                      <div className="relative">
                        <Search className="absolute left-3 top-3 w-4 h-4 text-slate-400" />
                        <input
                          type="text"
                          value={clientSearchQuery}
                          onChange={(e) => setClientSearchQuery(e.target.value)}
                          placeholder="Search clients..."
                          className="w-full pl-9 pr-4 py-2 rounded-xl border border-slate-200 text-xs bg-slate-50"
                        />
                      </div>
                      <div className="space-y-2 max-h-[600px] overflow-y-auto">
                        {clients
                          .filter(c => c.name.toLowerCase().includes(clientSearchQuery.toLowerCase()))
                          .map(c => {
                            const isSelected = selectedDossierClientId === c.id;
                            const clientInvoices = invoices.filter(i => i.client_id === c.id);
                            const clientBalance = clientInvoices.reduce((sum, inv) => sum + getInvoiceBalanceDueCents(inv), 0);

                            return (
                              <button
                                key={c.id}
                                onClick={() => setSelectedDossierClientId(c.id)}
                                className={`w-full text-left p-3.5 rounded-xl border transition cursor-pointer flex items-center justify-between ${
                                  isSelected ? 'bg-indigo-50 border-indigo-300 shadow-sm' : 'bg-slate-50 hover:bg-slate-100 border-slate-200'
                                }`}
                              >
                                <div>
                                  <div className="font-bold text-sm text-slate-900">{c.name}</div>
                                  <p className="text-xs text-slate-500">{c.email || 'No email'}</p>
                                </div>
                                <div className="text-right">
                                  <span className={`inline-block px-2 py-0.5 rounded text-[10px] font-bold ${
                                    clientBalance > 0 ? 'bg-amber-100 text-amber-800' : 'bg-emerald-100 text-emerald-800'
                                  }`}>
                                    {clientBalance > 0 ? `${formatMoney(clientBalance)} Due` : '✓ Settled'}
                                  </span>
                                </div>
                              </button>
                            );
                          })}
                      </div>
                    </div>

                    {/* RIGHT PANE (70%): Detailed Dossier */}
                    <div className="lg:col-span-8 bg-white rounded-2xl border border-slate-200 p-6 shadow-sm space-y-6">
                      {(() => {
                        const client = clients.find(c => c.id === selectedDossierClientId) || clients[0];
                        if (!client) return <div className="p-8 text-center text-slate-400">Select a client to view dossier.</div>;

                        const clientInvoices = invoices.filter(i => i.client_id === client.id);
                        const clientEstimates = estimates.filter(e => e.client_id === client.id);
                        const totalBilled = clientInvoices.reduce((sum, i) => sum + i.total_cents, 0);
                        const totalCollected = clientInvoices.reduce((sum, i) => sum + getInvoicePaidCents(i.id), 0);
                        const outstanding = clientInvoices.reduce((sum, i) => sum + getInvoiceBalanceDueCents(i), 0);

                        return (
                          <div className="space-y-6">
                            <div className="flex items-center justify-between border-b border-slate-100 pb-4">
                              <div>
                                <h3 className="text-xl font-bold text-slate-900">{client.name}</h3>
                                <p className="text-xs text-slate-500">{client.email} • {client.phone} • Tax ID: {client.tax_id || 'N/A'}</p>
                              </div>
                              <button
                                onClick={() => {
                                  const newEmail = prompt('Update Client Email:', client.email);
                                  if (newEmail !== null) {
                                    setClients(prev => prev.map(c => c.id === client.id ? { ...c, email: newEmail.trim() } : c));
                                  }
                                }}
                                className="px-3 py-1.5 border border-slate-200 rounded-xl text-xs font-bold text-slate-700 hover:bg-slate-50 cursor-pointer"
                              >
                                Edit Client
                              </button>
                            </div>

                            {/* Financial Metric Cards */}
                            <div className="grid grid-cols-3 gap-4">
                              <div className="p-4 bg-slate-50 rounded-xl border border-slate-200">
                                <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider">Lifetime Billed</span>
                                <div className="text-lg font-bold text-slate-900">{formatMoney(totalBilled)}</div>
                              </div>
                              <div className="p-4 bg-emerald-50/60 rounded-xl border border-emerald-200">
                                <span className="text-[10px] font-bold text-emerald-600 uppercase tracking-wider">Total Collected</span>
                                <div className="text-lg font-bold text-emerald-700">{formatMoney(totalCollected)}</div>
                              </div>
                              <div className="p-4 bg-indigo-50/60 rounded-xl border border-indigo-200">
                                <span className="text-[10px] font-bold text-indigo-600 uppercase tracking-wider">Outstanding Balance</span>
                                <div className="text-lg font-bold text-indigo-700">{formatMoney(outstanding)}</div>
                              </div>
                            </div>

                            {/* Internal Tabs */}
                            <div className="flex items-center gap-2 border-b border-slate-100 pb-2">
                              <button
                                onClick={() => setClientDossierSubTab('invoices')}
                                className={`px-4 py-2 rounded-xl text-xs font-bold transition cursor-pointer ${
                                  clientDossierSubTab === 'invoices' ? 'bg-indigo-600 text-white' : 'bg-slate-100 text-slate-600 hover:bg-slate-200'
                                }`}
                              >
                                Invoices & Quotes ({clientInvoices.length + clientEstimates.length})
                              </button>
                              <button
                                onClick={() => setClientDossierSubTab('statement')}
                                className={`px-4 py-2 rounded-xl text-xs font-bold transition cursor-pointer ${
                                  clientDossierSubTab === 'statement' ? 'bg-indigo-600 text-white' : 'bg-slate-100 text-slate-600 hover:bg-slate-200'
                                }`}
                              >
                                Statement of Account
                              </button>
                              <button
                                onClick={() => setClientDossierSubTab('notes')}
                                className={`px-4 py-2 rounded-xl text-xs font-bold transition cursor-pointer ${
                                  clientDossierSubTab === 'notes' ? 'bg-indigo-600 text-white' : 'bg-slate-100 text-slate-600 hover:bg-slate-200'
                                }`}
                              >
                                Internal Notes
                              </button>
                            </div>

                            {clientDossierSubTab === 'invoices' && (
                              <div className="space-y-3">
                                {clientInvoices.length === 0 ? (
                                  <p className="text-xs text-slate-400">No invoices issued to this client yet.</p>
                                ) : (
                                  clientInvoices.map(inv => (
                                    <div key={inv.id} className="flex items-center justify-between p-3 bg-slate-50 rounded-xl border border-slate-100 text-xs">
                                      <div>
                                        <span className="font-bold text-indigo-600">{inv.invoice_number}</span>
                                        <p className="text-[11px] text-slate-400">Issued: {inv.issue_date} • Due: {inv.due_date}</p>
                                      </div>
                                      <div className="text-right">
                                        <span className="font-bold text-slate-900">{formatMoney(inv.total_cents)}</span>
                                        <div className="text-[10px] font-bold text-slate-500">{getComputedInvoiceStatus(inv)}</div>
                                      </div>
                                    </div>
                                  ))
                                )}
                              </div>
                            )}

                            {clientDossierSubTab === 'statement' && (
                              <div className="space-y-4">
                                <div className="flex justify-between items-center">
                                  <h5 className="font-bold text-xs text-slate-700 uppercase tracking-wider">Itemized Account Statement</h5>
                                  <button
                                    onClick={() => alert(`Downloading Statement PDF for ${client.name}...`)}
                                    className="px-3 py-1.5 bg-indigo-50 text-indigo-700 font-bold rounded-lg text-xs flex items-center gap-1.5 cursor-pointer"
                                  >
                                    <Download className="w-3.5 h-3.5" />
                                    <span>Download Statement PDF</span>
                                  </button>
                                </div>
                                <div className="border border-slate-200 rounded-xl overflow-hidden">
                                  <table className="w-full text-left text-xs">
                                    <thead className="bg-slate-50 text-slate-600 font-bold border-b border-slate-200">
                                      <tr>
                                        <th className="p-3">Date</th>
                                        <th className="p-3">Reference</th>
                                        <th className="p-3 text-right">Debit (Invoice)</th>
                                        <th className="p-3 text-right">Credit (Payment)</th>
                                      </tr>
                                    </thead>
                                    <tbody className="divide-y divide-slate-100">
                                      {clientInvoices.map(inv => (
                                        <tr key={inv.id}>
                                          <td className="p-3 text-slate-500">{inv.issue_date}</td>
                                          <td className="p-3 font-mono font-bold">{inv.invoice_number}</td>
                                          <td className="p-3 text-right font-bold text-slate-900">{formatMoney(inv.total_cents)}</td>
                                          <td className="p-3 text-right text-slate-400">-</td>
                                        </tr>
                                      ))}
                                      {payments
                                        .filter(p => clientInvoices.some(i => i.id === p.invoice_id))
                                        .map(pay => (
                                          <tr key={pay.id}>
                                            <td className="p-3 text-slate-500">{pay.payment_date}</td>
                                            <td className="p-3 font-mono text-emerald-700">Payment ({pay.payment_method})</td>
                                            <td className="p-3 text-right text-slate-400">-</td>
                                            <td className="p-3 text-right font-bold text-emerald-700">{formatMoney(pay.amount_cents)}</td>
                                          </tr>
                                        ))}
                                    </tbody>
                                  </table>
                                </div>
                              </div>
                            )}

                            {clientDossierSubTab === 'notes' && (
                              <div className="space-y-3">
                                <label className="block text-xs font-bold text-slate-600 uppercase tracking-wider">Internal Client Notes & Management Terms</label>
                                <textarea
                                  value={client.notes || ''}
                                  onChange={(e) => {
                                    const val = e.target.value;
                                    setClients(prev => prev.map(c => c.id === client.id ? { ...c, notes: val } : c));
                                  }}
                                  rows={4}
                                  className="w-full p-3 rounded-xl border border-slate-200 text-xs bg-slate-50"
                                  placeholder="Enter management notes, agreed special discounts..."
                                />
                              </div>
                            )}
                          </div>
                        );
                      })()}
                    </div>
                  </div>
                </div>
              )}

              {/* ===================================================================== */}
              {/* TAB 4: EXPENSES HUB */}
              {/* ===================================================================== */}
              {activeTab === 4 && (
                <div className="space-y-6">
                  <div className="flex items-center justify-between">
                    <div>
                      <h3 className="text-xl font-bold text-slate-900">Expenses & Receipts Hub</h3>
                      <p className="text-xs text-slate-500">Track business expenditures and tax-deductible outlays</p>
                    </div>
                    <button
                      onClick={() => setIsExpenseDrawerOpen(true)}
                      className="px-4 py-2 bg-orange-600 hover:bg-orange-700 text-white text-xs font-bold rounded-xl shadow-sm transition flex items-center gap-1.5 cursor-pointer"
                    >
                      <Plus className="w-4 h-4" />
                      <span>+ Log Expense</span>
                    </button>
                  </div>

                  <div className="bg-white rounded-2xl border border-slate-200 overflow-hidden shadow-sm">
                    <div className="p-4 border-b border-slate-100 font-bold text-sm text-slate-800">
                      Recorded Expenses ({expenses.length})
                    </div>
                    <table className="w-full text-left text-xs">
                      <thead className="bg-slate-50 text-slate-700 font-bold border-b border-slate-200">
                        <tr>
                          <th className="p-3">Vendor</th>
                          <th className="p-3">Category</th>
                          <th className="p-3">Date</th>
                          <th className="p-3">Receipt</th>
                          <th className="p-3 text-right">Total Amount</th>
                        </tr>
                      </thead>
                      <tbody className="divide-y divide-slate-100">
                        {expenses.map(exp => (
                          <tr key={exp.id} className="hover:bg-slate-50">
                            <td className="p-3 font-bold text-slate-900">{exp.vendor}</td>
                            <td className="p-3 text-slate-600">{exp.category}</td>
                            <td className="p-3 text-slate-500">{exp.expense_date}</td>
                            <td className="p-3 text-slate-500">{exp.receipt_name ? '📎 Attached' : 'None'}</td>
                            <td className="p-3 text-right font-bold text-orange-600">{formatMoney(exp.total_cents)}</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                </div>
              )}

              {/* ===================================================================== */}
              {/* TAB 5: CATALOG */}
              {/* ===================================================================== */}
              {activeTab === 5 && (
                <div className="space-y-6">
                  <div className="flex items-center justify-between">
                    <div>
                      <h3 className="text-xl font-bold text-slate-900">Service Catalog & Preset Library</h3>
                      <p className="text-xs text-slate-500">Preset items for 1-click auto-fill in invoice builder</p>
                    </div>
                  </div>
                  <div className="bg-white rounded-2xl border border-slate-200 overflow-hidden shadow-sm">
                    <table className="w-full text-left text-xs">
                      <thead className="bg-slate-50 text-slate-700 font-bold border-b border-slate-200">
                        <tr>
                          <th className="p-3">Service Title</th>
                          <th className="p-3">SAC / HSN</th>
                          <th className="p-3 text-right">Default Price</th>
                        </tr>
                      </thead>
                      <tbody className="divide-y divide-slate-100">
                        {savedItems.map(item => (
                          <tr key={item.id}>
                            <td className="p-3 font-bold">{item.title}</td>
                            <td className="p-3 font-mono">{item.sac_hsn || '-'}</td>
                            <td className="p-3 text-right font-bold text-indigo-700">{formatMoney(item.default_price_cents)}</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                </div>
              )}

              {/* ===================================================================== */}
              {/* TAB 6: SETTINGS */}
              {/* ===================================================================== */}
              {activeTab === 6 && (
                <div className="space-y-6">
                  <h3 className="text-xl font-bold text-slate-900">Settings & Disaster Recovery</h3>
                  <div className="bg-white rounded-2xl border border-slate-200 p-6 shadow-sm space-y-4">
                    <h4 className="font-bold text-base">JSON Database Backup</h4>
                    <button
                      onClick={() => {
                        const backup = { version: 1, tables: { clients, invoices, expenses, estimates } };
                        const blob = new Blob([JSON.stringify(backup, null, 2)], { type: 'application/json' });
                        const url = URL.createObjectURL(blob);
                        const a = document.createElement('a');
                        a.href = url;
                        a.download = 'freelance_ledger_backup.json';
                        a.click();
                        URL.revokeObjectURL(url);
                      }}
                      className="px-4 py-2 bg-indigo-600 text-white text-xs font-bold rounded-xl"
                    >
                      Export JSON Backup
                    </button>
                  </div>
                </div>
              )}
            </>
        </main>
      </div>

      {/* ===================================================================== */}
      {/* 3. EXPENSE LOGGING SLIDE-OVER DRAWER */}
      {/* ===================================================================== */}
      {isExpenseDrawerOpen && (
        <div className="fixed inset-0 bg-slate-900/50 backdrop-blur-sm z-50 flex justify-end">
          <div className="bg-white w-full max-w-md h-full shadow-2xl p-6 flex flex-col justify-between overflow-y-auto animate-in slide-in-from-right duration-200">
            <div className="space-y-6">
              <div className="flex items-center justify-between border-b border-slate-100 pb-4">
                <h4 className="font-bold text-base text-slate-900">Log New Business Expense</h4>
                <button onClick={() => setIsExpenseDrawerOpen(false)} className="text-slate-400 hover:text-slate-600 cursor-pointer">
                  <X className="w-5 h-5" />
                </button>
              </div>

              <div className="space-y-4 text-xs">
                <div>
                  <label className="block font-bold text-slate-600 uppercase tracking-wider mb-1">Vendor Name *</label>
                  <input
                    type="text"
                    value={expenseVendor}
                    onChange={(e) => setExpenseVendor(e.target.value)}
                    placeholder="e.g. AWS Cloud / GitHub"
                    className="w-full px-3 py-2.5 rounded-xl border border-slate-200 bg-slate-50 text-sm"
                  />
                </div>
                <div>
                  <label className="block font-bold text-slate-600 uppercase tracking-wider mb-1">Category</label>
                  <select
                    value={expenseCategory}
                    onChange={(e) => setExpenseCategory(e.target.value)}
                    className="w-full px-3 py-2.5 rounded-xl border border-slate-200 bg-slate-50 text-sm"
                  >
                    <option value="Software & Tools">Software & Tools</option>
                    <option value="Cloud Hosting">Cloud Hosting</option>
                    <option value="Hardware & Equipment">Hardware & Equipment</option>
                    <option value="Professional Services">Professional Services</option>
                    <option value="Travel & Meals">Travel & Meals</option>
                  </select>
                </div>
                <div>
                  <label className="block font-bold text-slate-600 uppercase tracking-wider mb-1">Expense Date</label>
                  <input
                    type="date"
                    value={expenseDate}
                    onChange={(e) => setExpenseDate(e.target.value)}
                    className="w-full px-3 py-2.5 rounded-xl border border-slate-200 bg-slate-50 text-sm"
                  />
                </div>
                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label className="block font-bold text-slate-600 uppercase tracking-wider mb-1">Base Amount ({sym})</label>
                    <input
                      type="number"
                      step="0.01"
                      value={expenseAmount}
                      onChange={(e) => setExpenseAmount(e.target.value)}
                      placeholder="100.00"
                      className="w-full px-3 py-2.5 rounded-xl border border-slate-200 bg-slate-50 text-sm"
                    />
                  </div>
                  <div>
                    <label className="block font-bold text-slate-600 uppercase tracking-wider mb-1">Tax Amount ({sym})</label>
                    <input
                      type="number"
                      step="0.01"
                      value={expenseTax}
                      onChange={(e) => setExpenseTax(e.target.value)}
                      placeholder="10.00"
                      className="w-full px-3 py-2.5 rounded-xl border border-slate-200 bg-slate-50 text-sm"
                    />
                  </div>
                </div>

                {/* Receipt Dropzone */}
                <div>
                  <label className="block font-bold text-slate-600 uppercase tracking-wider mb-1">Receipt Attachment</label>
                  <label className="border-2 border-dashed border-slate-200 rounded-xl p-4 flex flex-col items-center justify-center cursor-pointer hover:bg-slate-50 transition">
                    <Paperclip className="w-5 h-5 text-indigo-600 mb-1" />
                    <span className="font-semibold text-slate-700">{expenseReceiptName || 'Click to attach receipt photo/PDF'}</span>
                    <input
                      type="file"
                      className="hidden"
                      onChange={(e) => {
                        const file = e.target.files?.[0];
                        if (file) setExpenseReceiptName(file.name);
                      }}
                    />
                  </label>
                </div>

                <div>
                  <label className="block font-bold text-slate-600 uppercase tracking-wider mb-1">Notes / Memo</label>
                  <textarea
                    value={expenseNotes}
                    onChange={(e) => setExpenseNotes(e.target.value)}
                    rows={2}
                    className="w-full p-3 rounded-xl border border-slate-200 bg-slate-50 text-xs"
                    placeholder="Optional details..."
                  />
                </div>
              </div>
            </div>

            <div className="flex gap-3 pt-4 border-t border-slate-100">
              <button
                onClick={() => setIsExpenseDrawerOpen(false)}
                className="flex-1 py-2.5 bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold rounded-xl text-xs"
              >
                Cancel
              </button>
              <button
                onClick={() => {
                  if (!expenseVendor.trim()) {
                    alert('Please enter vendor name.');
                    return;
                  }
                  const baseCents = parsePriceToCents(expenseAmount);
                  const taxCents = parsePriceToCents(expenseTax);
                  const total = baseCents + taxCents;
                  if (total <= 0) {
                    alert('Please enter a valid expense amount.');
                    return;
                  }

                  const newExp: ExpenseRecord = {
                    id: `exp-${Date.now()}`,
                    category: expenseCategory,
                    vendor: expenseVendor.trim(),
                    amount_cents: baseCents,
                    tax_cents: taxCents,
                    total_cents: total,
                    expense_date: expenseDate,
                    notes: expenseNotes.trim(),
                    receipt_name: expenseReceiptName || undefined,
                    created_at: new Date().toISOString(),
                  };

                  setExpenses(prev => [newExp, ...prev]);
                  setIsExpenseDrawerOpen(false);
                  setExpenseVendor('');
                  setExpenseAmount('');
                  setExpenseTax('');
                  setExpenseNotes('');
                  setExpenseReceiptName(null);
                  alert('Expense successfully logged and reflected in net profit telemetry!');
                }}
                className="flex-1 py-2.5 bg-orange-600 hover:bg-orange-700 text-white font-bold rounded-xl text-xs shadow-sm"
              >
                Save Expense
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Record Payment Modal */}
      {recordPaymentInvoice && (
        <div className="fixed inset-0 bg-slate-900/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-md w-full p-6 shadow-2xl space-y-4">
            <h4 className="font-bold text-base text-slate-900">Record Payment for {recordPaymentInvoice.invoice_number}</h4>
            <div>
              <label className="block text-xs font-bold text-slate-600 mb-1">Amount Received ({sym})</label>
              <input
                type="number"
                step="0.01"
                value={paymentAmountReceived}
                onChange={(e) => setPaymentAmountReceived(e.target.value)}
                className="w-full px-3 py-2 rounded-xl border border-slate-200 text-sm bg-slate-50"
              />
            </div>
            <div className="flex justify-end gap-3 pt-3 border-t border-slate-100">
              <button onClick={() => setRecordPaymentInvoice(null)} className="px-4 py-2 text-xs font-semibold text-slate-600">Cancel</button>
              <button
                onClick={() => {
                  const amt = parsePriceToCents(paymentAmountReceived);
                  if (amt <= 0) return;
                  const newPay: StoredPayment = {
                    id: `pay-${Date.now()}`,
                    invoice_id: recordPaymentInvoice.id,
                    amount_cents: amt,
                    amount_received_cents: amt,
                    tds_cents: 0,
                    payment_method: 'Bank Wire',
                    payment_date: new Date().toISOString().split('T')[0],
                    notes: 'Recorded via hub',
                    created_at: new Date().toISOString(),
                  };
                  setPayments(prev => [...prev, newPay]);
                  setRecordPaymentInvoice(null);
                  alert('Payment recorded successfully!');
                }}
                className="px-5 py-2 bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-bold rounded-xl"
              >
                Confirm Payment
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Add Client Modal */}
      {isClientModalOpen && (
        <div className="fixed inset-0 bg-slate-900/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-md w-full p-6 shadow-2xl space-y-4">
            <h4 className="font-bold text-base text-slate-900">Add New Client</h4>
            <div>
              <input
                type="text"
                value={newClientName}
                onChange={(e) => setNewClientName(e.target.value)}
                placeholder="Client Name *"
                className="w-full px-3 py-2 rounded-xl border border-slate-200 text-sm bg-slate-50"
              />
            </div>
            <div className="flex justify-end gap-3 pt-3 border-t border-slate-100">
              <button onClick={() => setIsClientModalOpen(false)} className="px-4 py-2 text-xs font-semibold text-slate-600">Cancel</button>
              <button
                onClick={() => {
                  if (!newClientName.trim()) return;
                  const newC: Client = {
                    id: `client-${Date.now()}`,
                    name: newClientName.trim(),
                    email: '',
                    phone: '',
                    address: '',
                    tax_id: '',
                    created_at: new Date().toISOString(),
                  };
                  setClients(prev => [...prev, newC]);
                  setSelectedDossierClientId(newC.id);
                  setIsClientModalOpen(false);
                  setNewClientName('');
                }}
                className="px-5 py-2 bg-indigo-600 hover:bg-indigo-700 text-white text-xs font-bold rounded-xl"
              >
                Save Client
              </button>
            </div>
          </div>
        </div>
      )}

      {/* CSV Export Modal */}
      {isCsvModalOpen && (
        <div className="fixed inset-0 bg-slate-900/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-md w-full p-6 shadow-2xl space-y-4">
            <h4 className="font-bold text-base text-slate-900">Export Accountant CSV</h4>
            <div className="space-y-3">
              <button onClick={handleExportInvoicesCsv} className="w-full py-3 bg-indigo-50 hover:bg-indigo-100 text-indigo-700 text-xs font-bold rounded-xl border border-indigo-200 transition flex items-center justify-center gap-2">
                <FileSpreadsheet className="w-4 h-4 text-indigo-600" />
                <span>Export Invoices CSV</span>
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Invoice PDF Preview Modal */}
      {previewInvoice && (
        <div className="fixed inset-0 bg-slate-900/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-2xl w-full p-6 shadow-2xl space-y-4 max-h-[90vh] overflow-y-auto">
            <div className="flex items-center justify-between border-b border-slate-100 pb-3">
              <h4 className="font-bold text-base text-slate-900">TAX INVOICE — {previewInvoice.invoice_number}</h4>
              <button onClick={() => setPreviewInvoice(null)} className="text-slate-400 hover:text-slate-600">✕</button>
            </div>
            <div className="space-y-4 text-xs">
              <div className="flex justify-between">
                <div>
                  <h5 className="font-bold text-sm text-slate-900">{businessProfile.business_name}</h5>
                  <p className="text-slate-500 whitespace-pre-line">{businessProfile.address}</p>
                </div>
                <div className="text-right">
                  <span className="font-bold text-indigo-600 text-sm">TAX INVOICE</span>
                  <p className="text-slate-500 font-mono">Date: {previewInvoice.issue_date}</p>
                </div>
              </div>
              <div className="flex justify-end pt-3 border-t border-slate-200">
                <div className="w-48 space-y-1 text-right">
                  <div className="flex justify-between"><span>Total:</span><span className="font-bold">{formatMoney(previewInvoice.total_cents)}</span></div>
                </div>
              </div>
            </div>
            <div className="flex justify-end gap-3 pt-3 border-t border-slate-100">
              <button onClick={() => window.print()} className="px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white text-xs font-bold rounded-xl flex items-center gap-1.5 cursor-pointer">
                <Printer className="w-4 h-4" />
                <span>Print Invoice</span>
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
