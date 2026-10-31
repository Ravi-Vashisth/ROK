import React, { useState, useEffect, useMemo } from 'react';
import {
  LayoutDashboard,
  ReceiptText,
  Wallet,
  Users,
  FileText,
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
  Edit,
  Sun,
  Moon,
  Send,
  Ban,
  CheckCircle2,
  Upload,
} from 'lucide-react';
import { parsePriceToCents, parsePriceToUnits, getCurrencyDecimals, calculateDueDate, isInvoiceOverdue } from './billingRules';

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
  currency_decimals?: number;
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
  currency_decimals: 2,
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
      { id: 'exp-1', category: 'Software & Tools', vendor: 'GitHub Enterprise', amount_cents: 2100, tax_cents: 210, total_cents: 2310, expense_date: '2026-10-01', notes: 'Monthly subscription', created_at: '2026-10-01T00:00:00Z' },
    ];
  });

  const [savedItems, setSavedItems] = useState<StoredItem[]>(() => {
    try {
      const saved = localStorage.getItem('fl_saved_items');
      if (saved) return JSON.parse(saved);
    } catch (_) {}
    return [
      { id: 'si-1', title: 'Software Architecture & Development', sac_hsn: '998311', default_price_cents: 10000, description: 'Senior full-stack engineering rate', created_at: '2026-10-01' },
      { id: 'si-2', title: 'UI/UX Interface Design Mockups', sac_hsn: '998314', default_price_cents: 8500, description: 'High-fidelity Figma mockups and wireframes', created_at: '2026-10-01' },
      { id: 'si-3', title: 'System Maintenance & Support (Monthly)', sac_hsn: '998313', default_price_cents: 5000, description: 'Ongoing bug fixes and infrastructure upkeep', created_at: '2026-10-01' },
    ];
  });

  const [estimates, setEstimates] = useState<StoredEstimateRecord[]>(() => {
    try {
      const saved = localStorage.getItem('fl_estimates');
      if (saved) return JSON.parse(saved);
    } catch (_) {}
    return [
      {
        id: 'est-1',
        client_id: 'client-1',
        client_name: 'ACME GLOBAL',
        estimate_number: 'EST-0001',
        subtotal_cents: 18000,
        tax_cents: 1800,
        total_cents: 19800,
        status: 'SENT',
        issue_date: '2026-10-27',
        expiry_date: '2026-11-26',
        terms: 'Quote valid for 30 days.',
        notes: 'Mobile app overhaul phase 2.',
        created_at: '2026-10-27T16:00:00Z',
      }
    ];
  });

  const [estimateItems, setEstimateItems] = useState<StoredEstimateItem[]>(() => {
    try {
      const saved = localStorage.getItem('fl_estimate_items');
      if (saved) return JSON.parse(saved);
    } catch (_) {}
    return [
      { id: 'ei-1', estimate_id: 'est-1', description: 'Phase 2 Architecture', sac_hsn: '998311', quantity: 1, unit_price_cents: 18000, total_cents: 18000, created_at: '2026-10-27T16:00:00Z' }
    ];
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

  // --- Master Navigation State (4 primary tabs) ---
  // 0: Dashboard, 1: Sales, 2: Expenses, 3: Hub & Settings
  const [activeTab, setActiveTab] = useState(0);
  const [salesSubTab, setSalesSubTab] = useState<'invoices' | 'quotes'>('invoices');
  const [hubSubTab, setHubSubTab] = useState<'clients' | 'catalog' | 'settings'>('clients');

  // Theme & Accent Palette
  const [isDarkMode, setIsDarkMode] = useState(false);
  const [accentColor, setAccentColor] = useState<'indigo' | 'emerald' | 'blue' | 'rose' | 'amber' | 'slate'>('indigo');

  // --- Two-Column Live Invoice & Quote Editor State ---
  const [editorMode, setEditorMode] = useState<'none' | 'invoice' | 'quote'>('none');
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

  // --- Client CRM Dossier State ---
  const [selectedDossierClientId, setSelectedDossierClientId] = useState<string>('client-1');
  const [clientSearchQuery, setClientSearchQuery] = useState('');
  const [clientDossierSubTab, setClientDossierSubTab] = useState<'invoices' | 'statement' | 'notes'>('invoices');

  // Client Modals
  const [isAddClientModalOpen, setIsAddClientModalOpen] = useState(false);
  const [editingClient, setEditingClient] = useState<Client | null>(null);
  const [clientFormName, setClientFormName] = useState('');
  const [clientFormEmail, setClientFormEmail] = useState('');
  const [clientFormPhone, setClientFormPhone] = useState('');
  const [clientFormAddress, setClientFormAddress] = useState('');
  const [clientFormTaxId, setClientFormTaxId] = useState('');
  const [statementClient, setStatementClient] = useState<Client | null>(null);

  // Catalog Item Modals
  const [isAddItemModalOpen, setIsAddItemModalOpen] = useState(false);
  const [editingItem, setEditingItem] = useState<StoredItem | null>(null);
  const [itemFormTitle, setItemFormTitle] = useState('');
  const [itemFormSacHsn, setItemFormSacHsn] = useState('');
  const [itemFormPrice, setItemFormPrice] = useState('');
  const [itemFormDesc, setItemFormDesc] = useState('');

  // Expense Drawer State
  const [isExpenseDrawerOpen, setIsExpenseDrawerOpen] = useState(false);
  const [expenseVendor, setExpenseVendor] = useState('');
  const [expenseCategory, setExpenseCategory] = useState('Software & Tools');
  const [expenseDate, setExpenseDate] = useState(() => new Date().toISOString().split('T')[0]);
  const [expenseAmount, setExpenseAmount] = useState('');
  const [expenseTax, setExpenseTax] = useState('');
  const [expenseNotes, setExpenseNotes] = useState('');
  const [expenseReceiptName, setExpenseReceiptName] = useState<string | null>(null);

  // Invoices & Quotes Filter State
  const [invoiceSearchQuery, setInvoiceSearchQuery] = useState('');
  const [invoiceStatusFilter, setInvoiceStatusFilter] = useState('ALL');

  // Utility Modals
  const [isProfileModalOpen, setIsProfileModalOpen] = useState(false);
  const [isCsvModalOpen, setIsCsvModalOpen] = useState(false);

  // Payment Recording Modal
  const [recordPaymentInvoice, setRecordPaymentInvoice] = useState<InvoiceRecord | null>(null);
  const [paymentAmountReceived, setPaymentAmountReceived] = useState('');
  const [paymentTds, setPaymentTds] = useState('0');
  const [paymentMethod, setPaymentMethod] = useState('Bank Wire');
  const [paymentRefNumber, setPaymentRefNumber] = useState('');

  // Payment Reminder Modal
  const [reminderModalInvoice, setReminderModalInvoice] = useState<InvoiceRecord | null>(null);

  // Invoice / Quote PDF Preview Modal
  const [previewInvoice, setPreviewInvoice] = useState<InvoiceRecord | null>(null);

  // Formatters & Currency
  const dec = businessProfile.currency_decimals ?? getCurrencyDecimals(businessProfile.currency_code || businessProfile.currency_symbol || 'USD');
  const sym = businessProfile.currency_symbol || '₹';
  const formatMoney = (units: number) => {
    if (dec === 0) {
      return `${sym}${Math.round(units).toLocaleString('en-US')}`;
    }
    return `${sym}${(units / 100).toFixed(2)}`;
  };
  const formatDecimal = (units: number) => {
    if (dec === 0) return Math.round(units).toString();
    return (units / 100).toFixed(2);
  };
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

  // Financial Telemetry
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

  const editorSubtotalCents = editorItems.reduce((sum, i) => sum + (i.unitPriceCents * i.quantity), 0);
  const rawFlat = parsePriceToCents(editorDiscountValue);
  const editorDiscountCents = editorDiscountType === 'percent'
    ? Math.round((editorSubtotalCents * (parseFloat(editorDiscountValue) || 0)) / 100)
    : editorDiscountType === 'flat' ? Math.min(rawFlat, editorSubtotalCents) : 0;
  const editorNetSub = Math.max(0, editorSubtotalCents - editorDiscountCents);
  const editorTaxCents = editorItems.reduce((sum, i) => {
    const lineTotal = i.unitPriceCents * i.quantity;
    const lineNet = editorDiscountCents > 0 ? lineTotal - Math.round((lineTotal * editorDiscountCents) / (editorSubtotalCents || 1)) : lineTotal;
    return sum + Math.round((Math.max(0, lineNet) * i.taxSlab) / 100);
  }, 0);
  const editorTotalCents = editorNetSub + editorTaxCents;

  // Actions
  const handleDuplicateInvoice = (inv: InvoiceRecord) => {
    const newNum = nextInvoiceNumber;
    const newInv: InvoiceRecord = {
      ...inv,
      id: `inv-${Date.now()}`,
      invoice_number: newNum,
      status: 'PENDING',
      issue_date: new Date().toISOString().split('T')[0],
      due_date: calculateDueDate(new Date().toISOString().split('T')[0], inv.payment_terms),
      created_at: new Date().toISOString(),
    };
    const originalItems = invoiceItems.filter(it => it.invoice_id === inv.id);
    const duplicatedItems = originalItems.map(it => ({
      ...it,
      id: `ii-${Date.now()}-${Math.random()}`,
      invoice_id: newInv.id,
      created_at: new Date().toISOString(),
    }));
    setInvoices(prev => [newInv, ...prev]);
    setInvoiceItems(prev => [...prev, ...duplicatedItems]);
    alert(`Invoice ${inv.invoice_number} duplicated as ${newNum}!`);
  };

  const handleVoidInvoice = (inv: InvoiceRecord) => {
    if (window.confirm(`Are you sure you want to void invoice ${inv.invoice_number}? This action cannot be undone.`)) {
      setInvoices(prev => prev.map(i => i.id === inv.id ? { ...i, status: 'VOID' } : i));
      alert(`Invoice ${inv.invoice_number} marked as VOID.`);
    }
  };

  const handleConvertQuote = (est: StoredEstimateRecord) => {
    const newInvNum = nextInvoiceNumber;
    const estItems = estimateItems.filter(i => i.estimate_id === est.id);
    const newInv: InvoiceRecord = {
      id: `inv-${Date.now()}`,
      client_id: est.client_id,
      client_name: est.client_name,
      invoice_number: newInvNum,
      subtotal_cents: est.subtotal_cents,
      tax_cents: est.tax_cents,
      total_cents: est.total_cents,
      status: 'PENDING',
      issue_date: new Date().toISOString().split('T')[0],
      due_date: calculateDueDate(new Date().toISOString().split('T')[0], 'Net 15 Days'),
      payment_terms: 'Net 15 Days',
      terms: est.terms || '',
      notes: est.notes || '',
      created_at: new Date().toISOString(),
    };
    const newItems: StoredInvoiceItem[] = estItems.map(it => ({
      id: `ii-${Date.now()}-${Math.random()}`,
      invoice_id: newInv.id,
      description: it.description,
      sac_hsn: it.sac_hsn,
      quantity: it.quantity,
      unit_price_cents: it.unit_price_cents,
      total_cents: it.total_cents,
      created_at: new Date().toISOString(),
    }));
    setInvoices(prev => [newInv, ...prev]);
    setInvoiceItems(prev => [...prev, ...newItems]);
    setEstimates(prev => prev.map(e => e.id === est.id ? { ...e, status: 'CONVERTED', converted_invoice_id: newInv.id } : e));
    alert(`Quote ${est.estimate_number} converted into live invoice ${newInvNum}!`);
  };

  const handleDeleteClient = (client: Client) => {
    const hasInvoices = invoices.some(i => i.client_id === client.id);
    if (hasInvoices) {
      alert(`Cannot delete "${client.name}" because existing invoices are attached to this client. Please void or settle their invoices first.`);
      return;
    }
    if (window.confirm(`Are you sure you want to delete client "${client.name}"?`)) {
      setClients(prev => prev.filter(c => c.id !== client.id));
      if (selectedDossierClientId === client.id) {
        const remaining = clients.filter(c => c.id !== client.id);
        setSelectedDossierClientId(remaining[0]?.id || '');
      }
      alert(`Client "${client.name}" deleted.`);
    }
  };

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

  const handleExportExpensesCsv = () => {
    const lines: string[] = ['\uFEFF'];
    lines.push('Vendor,Category,Date,Receipt,Amount,Tax,Total');
    for (const exp of expenses) {
      lines.push([quote(exp.vendor), quote(exp.category), quote(exp.expense_date), quote(exp.receipt_name || 'None'), formatDecimal(exp.amount_cents), formatDecimal(exp.tax_cents), formatDecimal(exp.total_cents)].join(','));
    }
    const blob = new Blob([lines.join('\n')], { type: 'text/csv;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'expenses_export.csv';
    a.click();
    URL.revokeObjectURL(url);
    setIsCsvModalOpen(false);
  };

  const handleRestoreDatabase = (file: File) => {
    const reader = new FileReader();
    reader.onload = (e) => {
      try {
        const data = JSON.parse(e.target?.result as string);
        if (!data || typeof data !== 'object') {
          alert('Invalid backup file: The selected file is not a valid Freelance Ledger database snapshot.');
          return;
        }
        const tbl = data.tables || data;
        const hasProfile = Boolean(tbl.businessProfile || tbl.business_profile);
        const hasClients = Boolean(tbl.clients);
        const hasInvoices = Boolean(tbl.invoices);
        if (!hasProfile && !hasClients && !hasInvoices) {
          alert('Invalid backup file: The selected file is not a valid Freelance Ledger database snapshot.');
          return;
        }

        if (tbl.clients && Array.isArray(tbl.clients)) setClients(tbl.clients);
        if (tbl.invoices && Array.isArray(tbl.invoices)) setInvoices(tbl.invoices);
        if (tbl.invoiceItems && Array.isArray(tbl.invoiceItems)) setInvoiceItems(tbl.invoiceItems);
        else if (tbl.invoice_items && Array.isArray(tbl.invoice_items)) setInvoiceItems(tbl.invoice_items);
        if (tbl.payments && Array.isArray(tbl.payments)) setPayments(tbl.payments);
        if (tbl.expenses && Array.isArray(tbl.expenses)) setExpenses(tbl.expenses);
        if (tbl.estimates && Array.isArray(tbl.estimates)) setEstimates(tbl.estimates);
        if (tbl.savedItems && Array.isArray(tbl.savedItems)) setSavedItems(tbl.savedItems);
        else if (tbl.saved_items && Array.isArray(tbl.saved_items)) setSavedItems(tbl.saved_items);
        
        const prof = tbl.businessProfile || tbl.business_profile;
        if (prof) {
          setBusinessProfile(Array.isArray(prof) ? prof[0] : prof);
        }
        alert('Database successfully restored from JSON backup!');
      } catch (err) {
        alert('Invalid backup file: The selected file is not a valid Freelance Ledger database snapshot.');
      }
    };
    reader.readAsText(file);
  };

  return (
    <div className={`min-h-screen font-sans flex antialiased ${isDarkMode ? 'bg-[#0B0F19] text-slate-100' : 'bg-slate-50 text-slate-900'}`}>
      {/* ===================================================================== */}
      {/* 1. MASTER SIDEBAR NAVIGATION (STRICTLY 4 PRIMARY TABS) */}
      {/* ===================================================================== */}
      <aside className={`hidden md:flex flex-col w-[220px] border-r select-none sticky top-0 h-screen shrink-0 ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}>
        <div className={`p-5 border-b flex items-center gap-3 ${isDarkMode ? 'border-slate-800' : 'border-slate-100'}`}>
          <div className="w-9 h-9 rounded-xl bg-indigo-600 text-white flex items-center justify-center font-bold text-sm shrink-0">
            {businessProfile.business_name ? businessProfile.business_name[0].toUpperCase() : 'M'}
          </div>
          <div className="min-w-0">
            <h1 className={`font-bold text-sm whitespace-normal break-words leading-tight ${isDarkMode ? 'text-white' : 'text-slate-900'}`}>
              {businessProfile.business_name || 'My Studio'}
            </h1>
            <p className="text-[11px] text-slate-400">Enterprise SaaS</p>
          </div>
        </div>

        <nav className="flex-1 p-3 space-y-1 overflow-y-auto">
          {[
            { id: 0, label: 'Dashboard', icon: LayoutDashboard },
            { id: 1, label: 'Sales', icon: ReceiptText },
            { id: 2, label: 'Expenses', icon: Wallet },
            { id: 3, label: 'Hub & Settings', icon: Settings },
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
                    ? isDarkMode ? 'bg-indigo-900/50 text-indigo-300' : 'bg-indigo-50 text-indigo-700 shadow-sm'
                    : isDarkMode ? 'text-slate-400 hover:bg-slate-800 hover:text-white' : 'text-slate-600 hover:bg-slate-50 hover:text-slate-900'
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
        <main className="flex-1 p-6 overflow-y-auto max-w-7xl mx-auto w-full space-y-6">
          {/* Global Utility Top Bar */}
          <div className="flex flex-wrap items-center justify-between gap-3 mb-2">
            <div className={`flex items-center gap-2 text-xs font-semibold px-3 py-1.5 rounded-xl border shadow-xs ${isDarkMode ? 'bg-[#0F172A] border-slate-800 text-slate-300' : 'bg-white border-slate-200 text-slate-600'}`}>
              <span className="w-2 h-2 rounded-full bg-emerald-500"></span>
              <span>Currency: {businessProfile.currency_code} ({sym})</span>
            </div>
            <div className="flex items-center gap-2">
              {/* Accent Color Palette Selector */}
              <div className={`flex items-center gap-1.5 p-1 rounded-xl border ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}>
                {(['indigo', 'emerald', 'blue', 'rose', 'amber', 'slate'] as const).map(color => (
                  <button
                    key={color}
                    onClick={() => setAccentColor(color)}
                    className={`w-4 h-4 rounded-full transition ${accentColor === color ? 'ring-2 ring-offset-1 ring-slate-700 scale-110' : 'opacity-70 hover:opacity-100'} ${
                      color === 'indigo' ? 'bg-[#4F46E5]' :
                      color === 'emerald' ? 'bg-[#10B981]' :
                      color === 'blue' ? 'bg-[#2563EB]' :
                      color === 'rose' ? 'bg-[#F43F5E]' :
                      color === 'amber' ? 'bg-[#F59E0B]' : 'bg-[#475569]'
                    }`}
                    title={`Accent: ${color}`}
                  />
                ))}
              </div>

              {/* Theme Toggle Button */}
              <button
                onClick={() => setIsDarkMode(prev => !prev)}
                className={`p-2 rounded-xl border transition cursor-pointer ${isDarkMode ? 'bg-[#0F172A] border-slate-800 text-amber-400 hover:bg-slate-800' : 'bg-white border-slate-200 text-slate-600 hover:bg-slate-50'}`}
                title={isDarkMode ? 'Switch to Light Mode' : 'Switch to Dark Mode'}
              >
                {isDarkMode ? <Sun className="w-4 h-4" /> : <Moon className="w-4 h-4" />}
              </button>

              {/* CSV Export Button */}
              <button
                onClick={() => setIsCsvModalOpen(true)}
                className="px-3 py-1.5 bg-indigo-50 hover:bg-indigo-100 text-indigo-700 border border-indigo-200 text-xs font-bold rounded-xl flex items-center gap-1.5 cursor-pointer transition"
              >
                <Download className="w-3.5 h-3.5" />
                <span>Export CSV</span>
              </button>

              {/* Settings Gear Button */}
              <button
                onClick={() => setIsProfileModalOpen(true)}
                className={`p-2 rounded-xl border transition cursor-pointer ${isDarkMode ? 'bg-[#0F172A] border-slate-800 text-slate-300 hover:bg-slate-800' : 'bg-white border-slate-200 text-slate-600 hover:bg-slate-50'}`}
                title="Business Settings & Branding"
              >
                <Settings className="w-4 h-4" />
              </button>
            </div>
          </div>

          {/* TWO-COLUMN LIVE INVOICE / QUOTE EDITOR */}
          {editorMode !== 'none' ? (
            <div className="space-y-4">
              <div className={`flex items-center justify-between p-4 rounded-xl border shadow-sm ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}>
                <button
                  onClick={() => setEditorMode('none')}
                  className="flex items-center gap-2 text-xs font-bold text-slate-500 hover:text-slate-800 cursor-pointer"
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
                      if (editorItems.length === 0 || editorItems.every(i => !i.description.trim())) {
                        alert('Please add at least one line item with a description.');
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
                          discount_type: editorDiscountType,
                          discount_value: parseFloat(editorDiscountValue) || 0,
                          discount_cents: editorDiscountCents,
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
                          tax_slab: it.taxSlab,
                          created_at: new Date().toISOString(),
                        }));
                        setInvoices(prev => [newInv, ...prev]);
                        setInvoiceItems(prev => [...prev, ...newItems]);
                        alert(`Invoice ${newInv.invoice_number} saved and issued successfully!`);
                        setActiveTab(1);
                        setSalesSubTab('invoices');
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
                        const newItems: StoredEstimateItem[] = editorItems.map(it => ({
                          id: `ei-${Date.now()}-${Math.random()}`,
                          estimate_id: newEst.id,
                          description: it.description,
                          sac_hsn: it.sac_hsn,
                          quantity: it.quantity,
                          unit_price_cents: it.unitPriceCents,
                          total_cents: it.unitPriceCents * it.quantity,
                          created_at: new Date().toISOString(),
                        }));
                        setEstimates(prev => [newEst, ...prev]);
                        setEstimateItems(prev => [...prev, ...newItems]);
                        alert(`Quote ${newEst.estimate_number} saved successfully!`);
                        setActiveTab(1);
                        setSalesSubTab('quotes');
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

              {/* 50/50 Split View */}
              <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                {/* LEFT PANE: Editor Controls */}
                <div className={`space-y-6 ${mobileEditorTab === 'preview' ? 'hidden lg:block' : 'block'}`}>
                  <div className={`p-6 rounded-xl border shadow-sm space-y-4 ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}>
                    <h4 className="font-bold text-xs uppercase tracking-wider text-slate-500">Client & Terms Particulars</h4>
                    <div>
                      <label className="block text-xs font-bold text-slate-600 mb-1">Select Client</label>
                      <select
                        value={editorClientId}
                        onChange={(e) => setEditorClientId(e.target.value)}
                        className={`w-full px-3 py-2.5 rounded-xl border text-sm font-semibold ${isDarkMode ? 'bg-slate-800 border-slate-700 text-white' : 'bg-slate-50 border-slate-200 text-slate-800'}`}
                      >
                        {clients.map(c => (
                          <option key={c.id} value={c.id}>{c.name} {c.tax_id ? `(${c.tax_id})` : ''}</option>
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
                          className={`w-full px-3 py-2 rounded-xl border text-xs ${isDarkMode ? 'bg-slate-800 border-slate-700 text-white' : 'bg-slate-50 border-slate-200'}`}
                        />
                      </div>
                      <div>
                        <label className="block text-xs font-bold text-slate-600 mb-1">Payment Terms</label>
                        <select
                          value={editorPaymentTerms}
                          onChange={(e) => setEditorPaymentTerms(e.target.value)}
                          className={`w-full px-3 py-2 rounded-xl border text-xs ${isDarkMode ? 'bg-slate-800 border-slate-700 text-white' : 'bg-slate-50 border-slate-200'}`}
                        >
                          <option value="Due on Receipt">Due on Receipt</option>
                          <option value="Net 15 Days">Net 15 Days</option>
                          <option value="Net 30 Days">Net 30 Days</option>
                          <option value="Net 60 Days">Net 60 Days</option>
                        </select>
                      </div>
                    </div>
                  </div>

                  {/* Line Items Table with Catalog Quick-Insert */}
                  <div className={`p-6 rounded-xl border shadow-sm space-y-4 ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}>
                    <div className="flex items-center justify-between">
                      <h4 className="font-bold text-xs uppercase tracking-wider text-slate-500">Line Items Grid</h4>
                      {savedItems.length > 0 && (
                        <select
                          onChange={(e) => {
                            const it = savedItems.find(s => s.id === e.target.value);
                            if (it) {
                              setEditorItems(prev => [
                                ...prev,
                                {
                                  id: `ed-${Date.now()}`,
                                  description: it.title,
                                  sac_hsn: it.sac_hsn || '',
                                  unitPriceCents: it.default_price_cents,
                                  quantity: 1,
                                  taxSlab: 10,
                                  totalCents: it.default_price_cents,
                                }
                              ]);
                            }
                            e.target.value = '';
                          }}
                          defaultValue=""
                          className="px-2.5 py-1 text-xs border border-indigo-200 bg-indigo-50 text-indigo-700 rounded-lg font-bold"
                        >
                          <option value="" disabled>+ Quick Insert Catalog Item</option>
                          {savedItems.map(it => (
                            <option key={it.id} value={it.id}>{it.title} ({formatMoney(it.default_price_cents)})</option>
                          ))}
                        </select>
                      )}
                    </div>

                    <div className="space-y-3">
                      {editorItems.map((item, idx) => (
                        <div key={item.id} className="p-3 bg-slate-50/80 rounded-xl border border-slate-200 space-y-2 text-xs">
                          <div className="flex gap-2">
                            <input
                              type="text"
                              value={item.description}
                              onChange={(e) => {
                                const val = e.target.value;
                                setEditorItems(prev => prev.map((it, i) => i === idx ? { ...it, description: val } : it));
                              }}
                              placeholder="Description *"
                              className="flex-1 px-3 py-1.5 rounded-lg border border-slate-200 bg-white"
                            />
                            <input
                              type="text"
                              value={item.sac_hsn}
                              onChange={(e) => {
                                const val = e.target.value;
                                setEditorItems(prev => prev.map((it, i) => i === idx ? { ...it, sac_hsn: val } : it));
                              }}
                              placeholder="SAC/HSN"
                              className="w-24 px-2 py-1.5 rounded-lg border border-slate-200 bg-white"
                            />
                            <button
                              onClick={() => {
                                if (editorItems.length > 1) {
                                  setEditorItems(prev => prev.filter((_, i) => i !== idx));
                                }
                              }}
                              className="p-1.5 text-slate-400 hover:text-red-600 rounded-lg"
                            >
                              <Trash2 className="w-4 h-4" />
                            </button>
                          </div>
                          <div className="flex items-center gap-3">
                            <div className="flex items-center gap-1">
                              <span className="text-slate-500">Qty:</span>
                              <input
                                type="number"
                                min="1"
                                value={item.quantity}
                                onChange={(e) => {
                                  const q = Math.max(1, parseInt(e.target.value, 10) || 1);
                                  setEditorItems(prev => prev.map((it, i) => i === idx ? { ...it, quantity: q, totalCents: q * it.unitPriceCents } : it));
                                }}
                                className="w-16 px-2 py-1 rounded-lg border border-slate-200 bg-white text-center font-bold"
                              />
                            </div>
                            <div className="flex items-center gap-1">
                              <span className="text-slate-500">Rate:</span>
                              <input
                                type="number"
                                step={dec === 0 ? "1" : "0.01"}
                                value={formatDecimal(item.unitPriceCents)}
                                onChange={(e) => {
                                  const rate = parsePriceToUnits(e.target.value, dec);
                                  setEditorItems(prev => prev.map((it, i) => i === idx ? { ...it, unitPriceCents: rate, totalCents: rate * it.quantity } : it));
                                }}
                                className="w-24 px-2 py-1 rounded-lg border border-slate-200 bg-white text-right font-bold"
                              />
                            </div>
                            <div className="flex items-center gap-1">
                              <span className="text-slate-500">Tax:</span>
                              <select
                                value={item.taxSlab}
                                onChange={(e) => {
                                  const s = parseInt(e.target.value, 10) || 0;
                                  setEditorItems(prev => prev.map((it, i) => i === idx ? { ...it, taxSlab: s } : it));
                                }}
                                className="px-2 py-1 rounded-lg border border-slate-200 bg-white font-semibold"
                              >
                                <option value={0}>0%</option>
                                <option value={5}>5%</option>
                                <option value={10}>10%</option>
                                <option value={12}>12%</option>
                                <option value={18}>18%</option>
                              </select>
                            </div>
                            <span className="ml-auto font-bold text-indigo-700">{formatMoney(item.unitPriceCents * item.quantity)}</span>
                          </div>
                        </div>
                      ))}
                    </div>

                    <button
                      onClick={() => setEditorItems(prev => [...prev, { id: `ed-${Date.now()}`, description: '', sac_hsn: '', unitPriceCents: 0, quantity: 1, taxSlab: 10, totalCents: 0 }])}
                      className="px-3 py-1.5 border border-dashed border-slate-300 rounded-xl text-xs font-bold text-slate-600 hover:bg-slate-50 w-full flex items-center justify-center gap-1.5"
                    >
                      <Plus className="w-3.5 h-3.5" />
                      <span>Add Another Line Item</span>
                    </button>

                    {/* Discount & Terms */}
                    <div className="pt-3 border-t border-slate-100 grid grid-cols-2 gap-3">
                      <div>
                        <label className="block text-xs font-bold text-slate-600 mb-1">Discount Type</label>
                        <select
                          value={editorDiscountType}
                          onChange={(e) => setEditorDiscountType(e.target.value as any)}
                          className="w-full px-3 py-1.5 rounded-lg border border-slate-200 bg-slate-50 text-xs"
                        >
                          <option value="none">No Discount</option>
                          <option value="percent">Percentage (%)</option>
                          <option value="flat">Flat Amount ({sym})</option>
                        </select>
                      </div>
                      {editorDiscountType !== 'none' && (
                        <div>
                          <label className="block text-xs font-bold text-slate-600 mb-1">
                            {editorDiscountType === 'percent' ? 'Discount %' : `Discount Amount (${sym})`}
                          </label>
                          <input
                            type="number"
                            value={editorDiscountValue}
                            onChange={(e) => setEditorDiscountValue(e.target.value)}
                            className="w-full px-3 py-1.5 rounded-lg border border-slate-200 bg-slate-50 text-xs"
                          />
                        </div>
                      )}
                    </div>

                    <div className="space-y-2">
                      <label className="block text-xs font-bold text-slate-600">Terms & Conditions</label>
                      <textarea
                        value={editorTerms}
                        onChange={(e) => setEditorTerms(e.target.value)}
                        rows={2}
                        className="w-full p-2.5 rounded-xl border border-slate-200 bg-slate-50 text-xs"
                      />
                    </div>
                  </div>
                </div>

                {/* RIGHT PANE: Interactive Live A4 Canvas */}
                <div className={`p-8 rounded-xl border shadow-sm ${mobileEditorTab === 'form' ? 'hidden lg:block' : 'block'} ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}>
                  <div className="border border-slate-200 p-6 rounded-xl bg-white text-slate-900 shadow-sm space-y-6 max-w-xl mx-auto">
                    {/* Header */}
                    <div className="flex justify-between items-start border-b border-slate-100 pb-4">
                      <div>
                        <h3 className="font-bold text-base text-slate-900">{businessProfile.business_name}</h3>
                        <p className="text-xs text-slate-500 whitespace-pre-line">{businessProfile.address}</p>
                        <p className="text-xs text-slate-500">{businessProfile.email} • {businessProfile.phone}</p>
                        {businessProfile.tax_id && <p className="text-xs text-slate-500 font-mono">Tax ID: {businessProfile.tax_id}</p>}
                      </div>
                      <div className="text-right">
                        <span className="px-2.5 py-1 bg-indigo-50 text-indigo-700 font-bold rounded-lg text-xs uppercase tracking-wider">
                          {editorMode === 'invoice' ? 'TAX INVOICE' : 'PROPOSAL / QUOTE'}
                        </span>
                        <p className="font-mono font-bold text-sm text-slate-900 mt-2">
                          {editorMode === 'invoice' ? nextInvoiceNumber : nextEstimateNumber}
                        </p>
                      </div>
                    </div>

                    {/* Bill To */}
                    <div className="flex justify-between text-xs">
                      <div>
                        <span className="font-bold text-slate-400 uppercase tracking-wider text-[10px]">BILL TO</span>
                        <h4 className="font-bold text-sm text-slate-900 mt-1">{clients.find(c => c.id === editorClientId)?.name}</h4>
                        <p className="text-slate-500">{clients.find(c => c.id === editorClientId)?.email}</p>
                        <p className="text-slate-500 font-mono">{clients.find(c => c.id === editorClientId)?.tax_id}</p>
                      </div>
                      <div className="text-right space-y-1">
                        <div><span className="text-slate-400">Issue Date:</span> <span className="font-bold">{editorIssueDate}</span></div>
                        <div><span className="text-slate-400">Terms:</span> <span className="font-bold">{editorPaymentTerms}</span></div>
                      </div>
                    </div>

                    {/* Items Table */}
                    <table className="w-full text-left text-xs">
                      <thead className="border-b border-slate-200 text-slate-600 font-bold">
                        <tr>
                          <th className="py-2">Description</th>
                          <th className="py-2 text-center">Qty</th>
                          <th className="py-2 text-right">Unit Rate</th>
                          <th className="py-2 text-right">Amount</th>
                        </tr>
                      </thead>
                      <tbody className="divide-y divide-slate-100">
                        {editorItems.map((it, idx) => (
                          <tr key={idx}>
                            <td className="py-2">{it.description || '—'}</td>
                            <td className="py-2 text-center">{it.quantity}</td>
                            <td className="py-2 text-right">{formatMoney(it.unitPriceCents)}</td>
                            <td className="py-2 text-right font-bold">{formatMoney(it.unitPriceCents * it.quantity)}</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>

                    {/* Totals */}
                    <div className="flex justify-end pt-3 border-t border-slate-200 text-xs">
                      <div className="w-56 space-y-1.5">
                        <div className="flex justify-between"><span>Subtotal:</span><span>{formatMoney(editorSubtotalCents)}</span></div>
                        {editorDiscountCents > 0 && (
                          <div className="flex justify-between text-orange-600 font-semibold">
                            <span>Discount:</span>
                            <span>-{formatMoney(editorDiscountCents)}</span>
                          </div>
                        )}
                        <div className="flex justify-between"><span>Tax:</span><span>{formatMoney(editorTaxCents)}</span></div>
                        <div className="flex justify-between font-bold text-sm text-indigo-700 border-t pt-1.5">
                          <span>Total Amount:</span>
                          <span>{formatMoney(editorTotalCents)}</span>
                        </div>
                      </div>
                    </div>

                    {businessProfile.payment_details && (
                      <div className="p-3 bg-slate-50 rounded-xl border border-slate-200 text-[11px] text-slate-700 whitespace-pre-line">
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
                      <h3 className={`text-xl font-bold ${isDarkMode ? 'text-white' : 'text-slate-900'}`}>Business Pulse & Action Center</h3>
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
                        className={`px-3.5 py-2 border text-xs font-bold rounded-xl shadow-sm transition flex items-center gap-1.5 cursor-pointer ${isDarkMode ? 'bg-[#0F172A] border-slate-800 text-slate-200 hover:bg-slate-800' : 'bg-white hover:bg-slate-50 text-slate-700 border-slate-200'}`}
                      >
                        <FileText className="w-4 h-4 text-indigo-600" />
                        <span>New Quote</span>
                      </button>
                      <button
                        onClick={() => setIsExpenseDrawerOpen(true)}
                        className={`px-3.5 py-2 border text-xs font-bold rounded-xl shadow-sm transition flex items-center gap-1.5 cursor-pointer ${isDarkMode ? 'bg-[#0F172A] border-slate-800 text-slate-200 hover:bg-slate-800' : 'bg-white hover:bg-slate-50 text-slate-700 border-slate-200'}`}
                      >
                        <Wallet className="w-4 h-4 text-orange-600" />
                        <span>Log Expense</span>
                      </button>
                    </div>
                  </div>

                  {/* Financial Pulse Row - Card 1 is Unpaid Receivables */}
                  <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
                    <div className="bg-red-50/70 p-5 rounded-xl border border-red-200 shadow-xs space-y-2">
                      <span className="text-xs font-bold text-red-900 uppercase tracking-wider">Unpaid Receivables</span>
                      <div className="text-2xl font-bold text-red-900">
                        {formatMoney(invoices.reduce((sum, inv) => inv.status !== 'PAID' && inv.status !== 'VOID' ? sum + getInvoiceBalanceDueCents(inv) : sum, 0))}
                      </div>
                      <div className="inline-block px-2 py-0.5 rounded text-[11px] font-bold bg-red-100 text-red-700">
                        Overdue: {formatMoney(invoices.filter(i => isInvoiceOverdue(i.status, i.due_date) && i.status !== 'PAID' && i.status !== 'VOID').reduce((sum, i) => sum + getInvoiceBalanceDueCents(i), 0))}
                      </div>
                    </div>
                    <div className={`p-5 rounded-xl border shadow-xs space-y-2 ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}>
                      <span className="text-xs font-bold text-slate-400 uppercase tracking-wider">Gross Collected</span>
                      <div className={`text-2xl font-bold ${isDarkMode ? 'text-white' : 'text-slate-900'}`}>{formatMoney(totalCollectedGrossCents)}</div>
                      <p className="text-xs text-slate-500">Total cash wire + TDS received</p>
                    </div>
                    <div className={`p-5 rounded-xl border shadow-xs space-y-2 ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}>
                      <span className="text-xs font-bold text-amber-600 uppercase tracking-wider">Tax Liability / GST</span>
                      <div className="text-2xl font-bold text-amber-700">{formatMoney(Math.max(0, taxLiabilityCents))}</div>
                      <p className="text-xs text-slate-500">Owed to tax authorities (Govt Share)</p>
                    </div>
                    <div className={`p-5 rounded-xl border shadow-xs space-y-2 ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}>
                      <span className="text-xs font-bold text-indigo-600 uppercase tracking-wider">Real Net Profit</span>
                      <div className="text-2xl font-bold text-indigo-700">{formatMoney(realNetProfitCents)}</div>
                      <p className="text-xs text-slate-500">Net Revenue minus business expenses</p>
                    </div>
                  </div>

                  {/* Action Required Triage Inbox */}
                  <div className={`border rounded-xl p-6 shadow-sm space-y-4 ${isDarkMode ? 'bg-[#0F172A] border-amber-900/40' : 'bg-amber-50/60 border-amber-200'}`}>
                    <div className="flex items-center gap-2">
                      <AlertTriangle className="w-5 h-5 text-amber-600" />
                      <h4 className="font-bold text-base text-amber-900">Action Required Triage Inbox</h4>
                    </div>
                    {invoices.filter(i => isInvoiceOverdue(i.status, i.due_date) && getInvoiceBalanceDueCents(i) > 0 && i.status !== 'VOID').length === 0 &&
                     estimates.filter(e => e.status !== 'CONVERTED').length === 0 ? (
                      <p className="text-xs text-emerald-700 font-semibold">All client balances and estimates are up to date. No urgent action required.</p>
                    ) : (
                      <div className="space-y-3">
                        {invoices
                          .filter(i => isInvoiceOverdue(i.status, i.due_date) && getInvoiceBalanceDueCents(i) > 0 && i.status !== 'VOID')
                          .map(inv => (
                            <div key={inv.id} className={`flex items-center justify-between p-3.5 rounded-xl border shadow-xs ${isDarkMode ? 'bg-slate-800 border-slate-700' : 'bg-white border-amber-100'}`}>
                              <div className="flex items-center gap-3">
                                <span className="w-2.5 h-2.5 rounded-full bg-red-500 shrink-0"></span>
                                <div>
                                  <span className={`font-bold text-sm ${isDarkMode ? 'text-white' : 'text-slate-900'}`}>{inv.client_name}</span>
                                  <p className="text-xs text-slate-500">Invoice {inv.invoice_number} is overdue ({formatMoney(getInvoiceBalanceDueCents(inv))} due)</p>
                                </div>
                              </div>
                              <button
                                onClick={() => setReminderModalInvoice(inv)}
                                className="px-3 py-1.5 bg-red-50 hover:bg-red-100 text-red-700 text-xs font-bold rounded-lg transition cursor-pointer flex items-center gap-1"
                              >
                                <Send className="w-3.5 h-3.5" />
                                <span>Send Reminder</span>
                              </button>
                            </div>
                          ))}
                        {estimates
                          .filter(e => e.status !== 'CONVERTED')
                          .map(est => (
                            <div key={est.id} className={`flex items-center justify-between p-3.5 rounded-xl border shadow-xs ${isDarkMode ? 'bg-slate-800 border-slate-700' : 'bg-white border-amber-100'}`}>
                              <div className="flex items-center gap-3">
                                <span className="w-2.5 h-2.5 rounded-full bg-indigo-500 shrink-0"></span>
                                <div>
                                  <span className={`font-bold text-sm ${isDarkMode ? 'text-white' : 'text-slate-900'}`}>{est.client_name}</span>
                                  <p className="text-xs text-slate-500">Quote {est.estimate_number} ({formatMoney(est.total_cents)}) is ready to convert</p>
                                </div>
                              </div>
                              <button
                                onClick={() => handleConvertQuote(est)}
                                className="px-3 py-1.5 bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-bold rounded-lg transition cursor-pointer flex items-center gap-1"
                              >
                                <CheckCircle2 className="w-3.5 h-3.5" />
                                <span>Convert to Invoice</span>
                              </button>
                            </div>
                          ))}
                      </div>
                    )}
                  </div>
                </div>
              )}

              {/* ===================================================================== */}
              {/* TAB 1: SALES (Invoices & Quotes with Segmented Control) */}
              {/* ===================================================================== */}
              {activeTab === 1 && (
                <div className="space-y-6">
                  <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
                    <div>
                      <h3 className={`text-xl font-bold ${isDarkMode ? 'text-white' : 'text-slate-900'}`}>Sales & Proposals Hub</h3>
                      <p className="text-xs text-slate-500">Manage client invoices, proposals, and track receivables</p>
                    </div>

                    <div className="flex flex-wrap items-center gap-3">
                      {/* Segmented Control */}
                      <div className={`flex p-1 rounded-xl border ${isDarkMode ? 'bg-slate-800 border-slate-700' : 'bg-slate-100 border-slate-200'}`}>
                        <button
                          onClick={() => setSalesSubTab('invoices')}
                          className={`px-3.5 py-1.5 rounded-lg text-xs font-bold transition cursor-pointer flex items-center gap-1.5 ${
                            salesSubTab === 'invoices' ? 'bg-white text-indigo-700 shadow-xs' : 'text-slate-600 hover:text-slate-900'
                          }`}
                        >
                          <ReceiptText className="w-4 h-4" />
                          <span>Invoices ({invoices.length})</span>
                        </button>
                        <button
                          onClick={() => setSalesSubTab('quotes')}
                          className={`px-3.5 py-1.5 rounded-lg text-xs font-bold transition cursor-pointer flex items-center gap-1.5 ${
                            salesSubTab === 'quotes' ? 'bg-white text-indigo-700 shadow-xs' : 'text-slate-600 hover:text-slate-900'
                          }`}
                        >
                          <FileText className="w-4 h-4" />
                          <span>Quotes / Estimates ({estimates.length})</span>
                        </button>
                      </div>

                      {salesSubTab === 'invoices' ? (
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
                      ) : (
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
                      )}
                    </div>
                  </div>

                  {salesSubTab === 'invoices' ? (
                    <div className={`rounded-xl border overflow-hidden shadow-sm ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}>
                      <div className={`p-4 border-b flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3 ${isDarkMode ? 'border-slate-800' : 'border-slate-100'}`}>
                        <span className="font-bold text-sm">Invoices Directory ({invoices.length})</span>
                        <div className="flex items-center gap-2 w-full sm:w-auto">
                          <div className="relative flex-1 sm:w-60">
                            <Search className="absolute left-3 top-2.5 w-3.5 h-3.5 text-slate-400" />
                            <input
                              type="text"
                              value={invoiceSearchQuery}
                              onChange={(e) => setInvoiceSearchQuery(e.target.value)}
                              placeholder="Search invoice or client..."
                              className={`w-full pl-8 pr-3 py-1.5 rounded-xl border text-xs ${isDarkMode ? 'bg-slate-800 border-slate-700 text-white' : 'bg-slate-50 border-slate-200'}`}
                            />
                          </div>
                          <select
                            value={invoiceStatusFilter}
                            onChange={(e) => setInvoiceStatusFilter(e.target.value)}
                            className={`px-2.5 py-1.5 rounded-xl border text-xs font-semibold ${isDarkMode ? 'bg-slate-800 border-slate-700 text-white' : 'bg-slate-50 border-slate-200'}`}
                          >
                            <option value="ALL">All Statuses</option>
                            <option value="PENDING">Pending</option>
                            <option value="OVERDUE">Overdue</option>
                            <option value="PAID">Paid</option>
                            <option value="PARTIALLY_PAID">Partially Paid</option>
                            <option value="VOID">Void</option>
                          </select>
                        </div>
                      </div>
                      <div className="overflow-x-auto">
                        <table className="w-full text-left text-xs">
                          <thead className={`font-bold border-b ${isDarkMode ? 'bg-slate-800 text-slate-300 border-slate-700' : 'bg-slate-50 text-slate-700 border-slate-200'}`}>
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
                            {invoices
                              .filter(inv => {
                                const matchesSearch = inv.invoice_number.toLowerCase().includes(invoiceSearchQuery.toLowerCase()) || inv.client_name.toLowerCase().includes(invoiceSearchQuery.toLowerCase());
                                const status = getComputedInvoiceStatus(inv);
                                const matchesFilter = invoiceStatusFilter === 'ALL' || status === invoiceStatusFilter;
                                return matchesSearch && matchesFilter;
                              })
                              .map(inv => {
                                const bal = getInvoiceBalanceDueCents(inv);
                                const status = getComputedInvoiceStatus(inv);
                                return (
                                  <tr key={inv.id} className="hover:bg-slate-50/50">
                                    <td className="p-3">
                                      <span className={`px-2.5 py-0.5 rounded-full text-[10px] font-bold uppercase tracking-wider ${
                                        status === 'PAID' ? 'bg-emerald-500/15 text-emerald-600 border border-emerald-500/20' :
                                        status === 'OVERDUE' ? 'bg-rose-500/15 text-rose-600 border border-rose-500/20' :
                                        status === 'PARTIALLY_PAID' ? 'bg-amber-500/15 text-amber-600 border border-amber-500/20' :
                                        status === 'VOID' ? 'bg-slate-500/15 text-slate-500 border border-slate-500/20' : 'bg-indigo-500/15 text-indigo-600 border border-indigo-500/20'
                                      }`}>
                                        {status}
                                      </span>
                                    </td>
                                    <td className="p-3 font-mono font-bold text-indigo-600">{inv.invoice_number}</td>
                                    <td className="p-3 font-bold">{inv.client_name}</td>
                                    <td className="p-3 text-slate-500">{inv.issue_date}</td>
                                    <td className="p-3 text-right font-bold">{formatMoney(inv.total_cents)}</td>
                                    <td className="p-3 text-right font-bold text-indigo-700">{formatMoney(bal)}</td>
                                    <td className="p-3 text-center">
                                      <div className="flex items-center justify-center gap-1.5">
                                        <button onClick={() => setPreviewInvoice(inv)} className="p-1.5 bg-indigo-50 hover:bg-indigo-100 text-indigo-700 rounded-lg cursor-pointer" title="View / Print PDF">
                                          <Printer className="w-3.5 h-3.5" />
                                        </button>
                                        <button onClick={() => handleDuplicateInvoice(inv)} className="p-1.5 bg-slate-100 hover:bg-slate-200 text-slate-700 rounded-lg cursor-pointer" title="Duplicate Invoice">
                                          <Copy className="w-3.5 h-3.5" />
                                        </button>
                                        {bal > 0 && inv.status !== 'VOID' && (
                                          <>
                                            <button onClick={() => { setRecordPaymentInvoice(inv); setPaymentAmountReceived((bal / 100).toFixed(2)); }} className="p-1.5 bg-emerald-50 hover:bg-emerald-100 text-emerald-700 rounded-lg cursor-pointer" title="Record Payment">
                                              <CreditCard className="w-3.5 h-3.5" />
                                            </button>
                                            <button onClick={() => setReminderModalInvoice(inv)} className="p-1.5 bg-amber-50 hover:bg-amber-100 text-amber-700 rounded-lg cursor-pointer" title="Send Payment Reminder">
                                              <Send className="w-3.5 h-3.5" />
                                            </button>
                                          </>
                                        )}
                                        {inv.status !== 'VOID' && (
                                          <button onClick={() => handleVoidInvoice(inv)} className="p-1.5 bg-red-50 hover:bg-red-100 text-red-600 rounded-lg cursor-pointer" title="Void Invoice">
                                            <Ban className="w-3.5 h-3.5" />
                                          </button>
                                        )}
                                      </div>
                                    </td>
                                  </tr>
                                );
                              })}
                          </tbody>
                        </table>
                      </div>
                    </div>
                  ) : (
                    <div className={`rounded-xl border overflow-hidden shadow-sm ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}>
                      <div className={`p-4 border-b flex items-center justify-between ${isDarkMode ? 'border-slate-800' : 'border-slate-100'}`}>
                        <span className="font-bold text-sm">Quotes & Proposals List ({estimates.length})</span>
                      </div>
                      {estimates.length === 0 ? (
                        <div className="p-8 text-center text-slate-400 text-sm">No quotes recorded yet. Click &quot;+ New Quote&quot; to create one.</div>
                      ) : (
                        <table className="w-full text-left text-xs">
                          <thead className={`font-bold border-b ${isDarkMode ? 'bg-slate-800 text-slate-300 border-slate-700' : 'bg-slate-50 text-slate-700 border-slate-200'}`}>
                            <tr>
                              <th className="p-3">Status</th>
                              <th className="p-3">Quote #</th>
                              <th className="p-3">Client</th>
                              <th className="p-3">Expiry Date</th>
                              <th className="p-3 text-right">Total</th>
                              <th className="p-3 text-center">Action</th>
                            </tr>
                          </thead>
                          <tbody className="divide-y divide-slate-100">
                            {estimates.map(est => {
                              const convertedInv = est.converted_invoice_id ? invoices.find(i => i.id === est.converted_invoice_id) : null;
                              return (
                                <tr key={est.id} className="hover:bg-slate-50/50">
                                  <td className="p-3">
                                    <span className={`px-2.5 py-0.5 rounded-full text-[10px] font-bold uppercase tracking-wider ${est.status === 'CONVERTED' ? 'bg-emerald-500/15 text-emerald-600 border border-emerald-500/20' : 'bg-amber-500/15 text-amber-600 border border-amber-500/20'}`}>
                                      {est.status}
                                    </span>
                                  </td>
                                  <td className="p-3 font-mono font-bold text-indigo-600">{est.estimate_number}</td>
                                  <td className="p-3 font-bold">{est.client_name}</td>
                                  <td className="p-3 text-slate-500">{est.expiry_date}</td>
                                  <td className="p-3 text-right font-bold">{formatMoney(est.total_cents)}</td>
                                  <td className="p-3 text-center">
                                    {est.status === 'CONVERTED' ? (
                                      <button
                                        onClick={() => {
                                          setSalesSubTab('invoices');
                                          if (convertedInv) setInvoiceSearchQuery(convertedInv.invoice_number);
                                        }}
                                        className="px-3 py-1 bg-green-50 hover:bg-green-100 text-green-800 border border-green-300 font-bold rounded-lg text-xs cursor-pointer shadow-xs inline-flex items-center gap-1"
                                      >
                                        <span>View Invoice: {convertedInv?.invoice_number || 'Linked'}</span>
                                        <span>→</span>
                                      </button>
                                    ) : (
                                      <button
                                        onClick={() => handleConvertQuote(est)}
                                        className="px-3 py-1 bg-emerald-600 hover:bg-emerald-700 text-white font-bold rounded-lg text-xs cursor-pointer shadow-xs"
                                      >
                                        Convert to Invoice
                                      </button>
                                    )}
                                  </td>
                                </tr>
                              );
                            })}
                          </tbody>
                        </table>
                      )}
                    </div>
                  )}
                </div>
              )}

              {/* ===================================================================== */}
              {/* TAB 2: EXPENSES HUB */}
              {/* ===================================================================== */}
              {activeTab === 2 && (
                <div className="space-y-6">
                  <div className="flex items-center justify-between">
                    <div>
                      <h3 className={`text-xl font-bold ${isDarkMode ? 'text-white' : 'text-slate-900'}`}>Expenses & Receipts Hub</h3>
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

                  <div className={`rounded-xl border overflow-hidden shadow-sm ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}>
                    <div className={`p-4 border-b font-bold text-sm ${isDarkMode ? 'border-slate-800' : 'border-slate-100'}`}>
                      Recorded Expenses ({expenses.length})
                    </div>
                    {expenses.length === 0 ? (
                      <div className="p-8 text-center text-slate-400 text-sm">No expenses logged yet. Click &quot;+ Log Expense&quot; above.</div>
                    ) : (
                      <table className="w-full text-left text-xs">
                        <thead className={`font-bold border-b ${isDarkMode ? 'bg-slate-800 text-slate-300 border-slate-700' : 'bg-slate-50 text-slate-700 border-slate-200'}`}>
                          <tr>
                            <th className="p-3">Vendor</th>
                            <th className="p-3">Category</th>
                            <th className="p-3">Date</th>
                            <th className="p-3">Receipt</th>
                            <th className="p-3 text-right">Total Amount</th>
                            <th className="p-3 text-center">Action</th>
                          </tr>
                        </thead>
                        <tbody className="divide-y divide-slate-100">
                          {expenses.map(exp => (
                            <tr key={exp.id} className="hover:bg-slate-50/50">
                              <td className="p-3 font-bold">{exp.vendor}</td>
                              <td className="p-3 text-slate-500">{exp.category}</td>
                              <td className="p-3 text-slate-500">{exp.expense_date}</td>
                              <td className="p-3 text-slate-500">{exp.receipt_name ? `📎 ${exp.receipt_name}` : 'None'}</td>
                              <td className="p-3 text-right font-bold text-orange-600">{formatMoney(exp.total_cents)}</td>
                              <td className="p-3 text-center">
                                <button
                                  onClick={() => {
                                    if (window.confirm(`Delete expense for ${exp.vendor}?`)) {
                                      setExpenses(prev => prev.filter(e => e.id !== exp.id));
                                    }
                                  }}
                                  className="p-1 text-slate-400 hover:text-red-600 rounded"
                                  title="Delete Expense"
                                >
                                  <Trash2 className="w-3.5 h-3.5" />
                                </button>
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
              {/* TAB 3: HUB & SETTINGS (Clients, Catalog, Settings) */}
              {/* ===================================================================== */}
              {activeTab === 3 && (
                <div className="space-y-6">
                  <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
                    <div>
                      <h3 className={`text-xl font-bold ${isDarkMode ? 'text-white' : 'text-slate-900'}`}>Hub & Settings</h3>
                      <p className="text-xs text-slate-500">Manage clients, service catalog, business branding & disaster recovery</p>
                    </div>
                    <div className={`flex p-1 rounded-xl border ${isDarkMode ? 'bg-slate-800 border-slate-700' : 'bg-slate-100 border-slate-200'}`}>
                      <button
                        onClick={() => setHubSubTab('clients')}
                        className={`px-3.5 py-1.5 rounded-lg text-xs font-bold transition cursor-pointer flex items-center gap-1.5 ${
                          hubSubTab === 'clients' ? 'bg-white text-indigo-700 shadow-xs' : 'text-slate-600 hover:text-slate-900'
                        }`}
                      >
                        <Users className="w-4 h-4" />
                        <span>Clients ({clients.length})</span>
                      </button>
                      <button
                        onClick={() => setHubSubTab('catalog')}
                        className={`px-3.5 py-1.5 rounded-lg text-xs font-bold transition cursor-pointer flex items-center gap-1.5 ${
                          hubSubTab === 'catalog' ? 'bg-white text-indigo-700 shadow-xs' : 'text-slate-600 hover:text-slate-900'
                        }`}
                      >
                        <Package className="w-4 h-4" />
                        <span>Catalog ({savedItems.length})</span>
                      </button>
                      <button
                        onClick={() => setHubSubTab('settings')}
                        className={`px-3.5 py-1.5 rounded-lg text-xs font-bold transition cursor-pointer flex items-center gap-1.5 ${
                          hubSubTab === 'settings' ? 'bg-white text-indigo-700 shadow-xs' : 'text-slate-600 hover:text-slate-900'
                        }`}
                      >
                        <Settings className="w-4 h-4" />
                        <span>Settings & Backup</span>
                      </button>
                    </div>
                  </div>

                  {/* SUB-TAB A: CLIENT CRM & STATEMENTS */}
                  {hubSubTab === 'clients' && (
                    <div className="space-y-4">
                      <div className="flex items-center justify-between">
                        <div>
                          <h4 className="font-bold text-base">Client CRM Dossier</h4>
                          <p className="text-xs text-slate-500">Master-detail enterprise CRM & Account Statements</p>
                        </div>
                        <button
                          onClick={() => {
                            setClientFormName('');
                            setClientFormEmail('');
                            setClientFormPhone('');
                            setClientFormAddress('');
                            setClientFormTaxId('');
                            setIsAddClientModalOpen(true);
                          }}
                          className="px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white text-xs font-bold rounded-xl shadow-sm transition flex items-center gap-1.5 cursor-pointer"
                        >
                          <Plus className="w-4 h-4" />
                          <span>+ Add Client</span>
                        </button>
                      </div>

                      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6 items-start">
                        {/* LEFT PANE (30%): Searchable Client List */}
                        <div className={`lg:col-span-4 p-4 rounded-xl border shadow-sm space-y-3 ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}>
                          <div className="relative">
                            <Search className="absolute left-3 top-3 w-4 h-4 text-slate-400" />
                            <input
                              type="text"
                              value={clientSearchQuery}
                              onChange={(e) => setClientSearchQuery(e.target.value)}
                              placeholder="Search clients..."
                              className={`w-full pl-9 pr-4 py-2 rounded-xl border text-xs ${isDarkMode ? 'bg-slate-800 border-slate-700 text-white' : 'bg-slate-50 border-slate-200'}`}
                            />
                          </div>
                          <div className="space-y-2 max-h-[500px] overflow-y-auto">
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
                                      isSelected
                                        ? 'bg-indigo-50/80 border-indigo-300 shadow-sm'
                                        : isDarkMode ? 'bg-slate-800/50 hover:bg-slate-800 border-slate-700' : 'bg-slate-50 hover:bg-slate-100 border-slate-200'
                                    }`}
                                  >
                                    <div>
                                      <div className={`font-bold text-sm ${isSelected ? 'text-indigo-900' : isDarkMode ? 'text-white' : 'text-slate-900'}`}>{c.name}</div>
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
                        <div className={`lg:col-span-8 p-6 rounded-xl border shadow-sm space-y-6 ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}>
                          {(() => {
                            const client = clients.find(c => c.id === selectedDossierClientId) || clients[0];
                            if (!client) return <div className="p-8 text-center text-slate-400">Select a client to view dossier.</div>;

                            const clientInvoices = invoices.filter(i => i.client_id === client.id);
                            const totalBilled = clientInvoices.reduce((sum, i) => sum + i.total_cents, 0);
                            const totalCollected = clientInvoices.reduce((sum, i) => sum + getInvoicePaidCents(i.id), 0);
                            const outstanding = clientInvoices.reduce((sum, i) => sum + getInvoiceBalanceDueCents(i), 0);

                            return (
                              <div className="space-y-6">
                                <div className={`flex items-center justify-between border-b pb-4 ${isDarkMode ? 'border-slate-800' : 'border-slate-100'}`}>
                                  <div>
                                    <h3 className={`text-xl font-bold ${isDarkMode ? 'text-white' : 'text-slate-900'}`}>{client.name}</h3>
                                    <p className="text-xs text-slate-500">{client.email} • {client.phone} • Tax ID: {client.tax_id || 'N/A'}</p>
                                    {client.address && <p className="text-xs text-slate-400 mt-0.5">{client.address}</p>}
                                  </div>
                                  <div className="flex items-center gap-2">
                                    <button
                                      onClick={() => {
                                        setEditingClient(client);
                                        setClientFormName(client.name);
                                        setClientFormEmail(client.email || '');
                                        setClientFormPhone(client.phone || '');
                                        setClientFormAddress(client.address || '');
                                        setClientFormTaxId(client.tax_id || '');
                                      }}
                                      className="px-3 py-1.5 border border-slate-200 rounded-xl text-xs font-bold text-slate-700 hover:bg-slate-50 cursor-pointer flex items-center gap-1"
                                    >
                                      <Edit className="w-3.5 h-3.5" />
                                      <span>Edit Client</span>
                                    </button>
                                    <button
                                      onClick={() => handleDeleteClient(client)}
                                      className="p-1.5 border border-red-200 text-red-600 hover:bg-red-50 rounded-xl cursor-pointer"
                                      title="Delete Client"
                                    >
                                      <Trash2 className="w-3.5 h-3.5" />
                                    </button>
                                  </div>
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
                                  <div className="p-4 bg-amber-50/60 rounded-xl border border-amber-200">
                                    <span className="text-[10px] font-bold text-amber-700 uppercase tracking-wider">Outstanding Balance</span>
                                    <div className="text-lg font-bold text-amber-800">{formatMoney(outstanding)}</div>
                                  </div>
                                </div>

                                {/* Dossier Sub-Tabs */}
                                <div className={`flex items-center gap-2 border-b pb-2 ${isDarkMode ? 'border-slate-800' : 'border-slate-100'}`}>
                                  <button
                                    onClick={() => setClientDossierSubTab('invoices')}
                                    className={`px-3.5 py-1.5 rounded-xl text-xs font-bold transition cursor-pointer ${
                                      clientDossierSubTab === 'invoices' ? 'bg-indigo-600 text-white' : 'bg-slate-100 text-slate-600 hover:bg-slate-200'
                                    }`}
                                  >
                                    Invoices ({clientInvoices.length})
                                  </button>
                                  <button
                                    onClick={() => setClientDossierSubTab('statement')}
                                    className={`px-3.5 py-1.5 rounded-xl text-xs font-bold transition cursor-pointer ${
                                      clientDossierSubTab === 'statement' ? 'bg-indigo-600 text-white' : 'bg-slate-100 text-slate-600 hover:bg-slate-200'
                                    }`}
                                  >
                                    Statement of Account
                                  </button>
                                  <button
                                    onClick={() => setClientDossierSubTab('notes')}
                                    className={`px-3.5 py-1.5 rounded-xl text-xs font-bold transition cursor-pointer ${
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
                                        <div key={inv.id} className="flex items-center justify-between p-3 bg-slate-50 rounded-xl border border-slate-200 text-xs">
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
                                      <h5 className="font-bold text-xs text-slate-700 uppercase tracking-wider">Itemized Account Ledger</h5>
                                      <button
                                        onClick={() => setStatementClient(client)}
                                        className="px-3 py-1.5 bg-indigo-50 hover:bg-indigo-100 text-indigo-700 font-bold rounded-lg text-xs flex items-center gap-1.5 cursor-pointer"
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
                                    <label className="block text-xs font-bold text-slate-600 uppercase tracking-wider">Internal Client Notes & Special Retainer Terms</label>
                                    <textarea
                                      value={client.notes || ''}
                                      onChange={(e) => {
                                        const val = e.target.value;
                                        setClients(prev => prev.map(c => c.id === client.id ? { ...c, notes: val } : c));
                                      }}
                                      rows={4}
                                      className="w-full p-3 rounded-xl border border-slate-200 text-xs bg-slate-50"
                                      placeholder="Enter client preferences, retainer agreements, or internal billing notes..."
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

                  {/* SUB-TAB B: SERVICE CATALOG */}
                  {hubSubTab === 'catalog' && (
                    <div className="space-y-6">
                      <div className="flex items-center justify-between">
                        <div>
                          <h4 className="font-bold text-base">Service Catalog & Preset Library</h4>
                          <p className="text-xs text-slate-500">Preset service items for 1-click auto-fill in invoice and quote builders</p>
                        </div>
                        <button
                          onClick={() => {
                            setItemFormTitle('');
                            setItemFormSacHsn('');
                            setItemFormPrice('');
                            setItemFormDesc('');
                            setIsAddItemModalOpen(true);
                          }}
                          className="px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white text-xs font-bold rounded-xl shadow-sm transition flex items-center gap-1.5 cursor-pointer"
                        >
                          <Plus className="w-4 h-4" />
                          <span>+ Add Item</span>
                        </button>
                      </div>

                      <div className={`rounded-xl border overflow-hidden shadow-sm ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}>
                        <table className="w-full text-left text-xs">
                          <thead className={`font-bold border-b ${isDarkMode ? 'bg-slate-800 text-slate-300 border-slate-700' : 'bg-slate-50 text-slate-700 border-slate-200'}`}>
                            <tr>
                              <th className="p-3">Service Title</th>
                              <th className="p-3">SAC / HSN</th>
                              <th className="p-3">Description</th>
                              <th className="p-3 text-right">Default Unit Price</th>
                              <th className="p-3 text-center">Actions</th>
                            </tr>
                          </thead>
                          <tbody className="divide-y divide-slate-100">
                            {savedItems.map(item => (
                              <tr key={item.id} className="hover:bg-slate-50/50">
                                <td className="p-3 font-bold">{item.title}</td>
                                <td className="p-3 font-mono">{item.sac_hsn || '—'}</td>
                                <td className="p-3 text-slate-500">{item.description || '—'}</td>
                                <td className="p-3 text-right font-bold text-indigo-700">{formatMoney(item.default_price_cents)}</td>
                                <td className="p-3 text-center">
                                  <div className="flex items-center justify-center gap-1.5">
                                    <button
                                      onClick={() => {
                                        setEditingItem(item);
                                        setItemFormTitle(item.title);
                                        setItemFormSacHsn(item.sac_hsn || '');
                                        setItemFormPrice((item.default_price_cents / 100).toFixed(2));
                                        setItemFormDesc(item.description || '');
                                      }}
                                      className="p-1.5 text-slate-500 hover:text-indigo-600 rounded"
                                      title="Edit Item"
                                    >
                                      <Edit className="w-3.5 h-3.5" />
                                    </button>
                                    <button
                                      onClick={() => {
                                        if (window.confirm(`Delete item "${item.title}" from catalog?`)) {
                                          setSavedItems(prev => prev.filter(i => i.id !== item.id));
                                        }
                                      }}
                                      className="p-1.5 text-slate-500 hover:text-red-600 rounded"
                                      title="Delete Item"
                                    >
                                      <Trash2 className="w-3.5 h-3.5" />
                                    </button>
                                  </div>
                                </td>
                              </tr>
                            ))}
                          </tbody>
                        </table>
                      </div>
                    </div>
                  )}

                  {/* SUB-TAB C: SETTINGS & BACKUP */}
                  {hubSubTab === 'settings' && (
                    <div className="space-y-6">
                      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                        {/* Branding & Profile */}
                        <div className={`p-6 rounded-xl border shadow-sm space-y-4 ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}>
                          <h4 className="font-bold text-base">Business Profile & Defaults</h4>
                          <p className="text-xs text-slate-500">Configure your business details displayed on issued invoices and estimates.</p>
                          <div className="space-y-3 text-xs">
                            <div>
                              <label className="block font-bold text-slate-600 mb-1">Business Name</label>
                              <input
                                type="text"
                                value={businessProfile.business_name}
                                onChange={(e) => setBusinessProfile(prev => ({ ...prev, business_name: e.target.value }))}
                                className="w-full px-3 py-2 rounded-xl border border-slate-200 bg-slate-50 font-semibold"
                              />
                            </div>
                            <div className="grid grid-cols-2 gap-3">
                              <div>
                                <label className="block font-bold text-slate-600 mb-1">Currency Code</label>
                                <input
                                  type="text"
                                  value={businessProfile.currency_code}
                                  onChange={(e) => setBusinessProfile(prev => ({ ...prev, currency_code: e.target.value }))}
                                  className="w-full px-3 py-2 rounded-xl border border-slate-200 bg-slate-50"
                                />
                              </div>
                              <div>
                                <label className="block font-bold text-slate-600 mb-1">Currency Symbol</label>
                                <input
                                  type="text"
                                  value={businessProfile.currency_symbol}
                                  onChange={(e) => setBusinessProfile(prev => ({ ...prev, currency_symbol: e.target.value }))}
                                  className="w-full px-3 py-2 rounded-xl border border-slate-200 bg-slate-50"
                                />
                              </div>
                            </div>
                            <div>
                              <label className="block font-bold text-slate-600 mb-1">Billing Email</label>
                              <input
                                type="text"
                                value={businessProfile.email}
                                onChange={(e) => setBusinessProfile(prev => ({ ...prev, email: e.target.value }))}
                                className="w-full px-3 py-2 rounded-xl border border-slate-200 bg-slate-50"
                              />
                            </div>
                            <div>
                              <label className="block font-bold text-slate-600 mb-1">Tax ID / GSTIN</label>
                              <input
                                type="text"
                                value={businessProfile.tax_id}
                                onChange={(e) => setBusinessProfile(prev => ({ ...prev, tax_id: e.target.value }))}
                                className="w-full px-3 py-2 rounded-xl border border-slate-200 bg-slate-50"
                              />
                            </div>
                            <div>
                              <label className="block font-bold text-slate-600 mb-1">Payment Details / Bank Instructions</label>
                              <textarea
                                value={businessProfile.payment_details}
                                onChange={(e) => setBusinessProfile(prev => ({ ...prev, payment_details: e.target.value }))}
                                rows={3}
                                className="w-full p-2.5 rounded-xl border border-slate-200 bg-slate-50"
                              />
                            </div>
                          </div>
                        </div>

                        {/* Disaster Recovery & SQLite Backup */}
                        <div className={`p-6 rounded-xl border shadow-sm space-y-4 ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}>
                          <h4 className="font-bold text-base">Disaster Recovery & SQLite Backup</h4>
                          <p className="text-xs text-slate-500">Export or restore your complete ledger database instantly to prevent data loss.</p>
                          <div className="space-y-4 pt-2">
                            <div className="p-4 bg-slate-50 rounded-xl border border-slate-200 space-y-2 text-xs">
                              <span className="font-bold text-slate-800">Export Full JSON Backup</span>
                              <p className="text-slate-500">Generates a complete JSON snapshot of all clients, invoices, expenses, items, and settings.</p>
                              <button
                                onClick={() => {
                                  const backup = {
                                    version: 1,
                                    exported_at: new Date().toISOString(),
                                    tables: { clients, invoices, invoiceItems, payments, expenses, estimates, estimateItems, savedItems, businessProfile }
                                  };
                                  const blob = new Blob([JSON.stringify(backup, null, 2)], { type: 'application/json' });
                                  const url = URL.createObjectURL(blob);
                                  const a = document.createElement('a');
                                  a.href = url;
                                  a.download = `freelance_ledger_backup_${new Date().toISOString().split('T')[0]}.json`;
                                  a.click();
                                  URL.revokeObjectURL(url);
                                }}
                                className="px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white font-bold rounded-xl flex items-center gap-2 cursor-pointer shadow-sm"
                              >
                                <Download className="w-4 h-4" />
                                <span>Export JSON Snapshot</span>
                              </button>
                            </div>

                            <div className="p-4 bg-slate-50 rounded-xl border border-slate-200 space-y-2 text-xs">
                              <span className="font-bold text-slate-800">Restore Database from Backup</span>
                              <p className="text-slate-500">Upload a previously exported JSON snapshot to restore ledger state.</p>
                              <label className="inline-flex items-center gap-2 px-4 py-2 bg-slate-800 hover:bg-slate-900 text-white font-bold rounded-xl cursor-pointer shadow-sm">
                                <Upload className="w-4 h-4" />
                                <span>Choose JSON File to Restore</span>
                                <input
                                  type="file"
                                  accept=".json,application/json"
                                  className="hidden"
                                  onChange={(e) => {
                                    const file = e.target.files?.[0];
                                    if (file) handleRestoreDatabase(file);
                                  }}
                                />
                              </label>
                            </div>
                          </div>
                        </div>
                      </div>
                    </div>
                  )}
                </div>
              )}
            </>
          )}
        </main>
      </div>

      {/* Mobile Bottom Navigation Bar (4 destinations) */}
      <nav className={`md:hidden fixed bottom-0 left-0 right-0 border-t flex items-center justify-around py-2 z-40 shadow-lg ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}>
        {[
          { id: 0, label: 'Dashboard', icon: LayoutDashboard },
          { id: 1, label: 'Sales', icon: ReceiptText },
          { id: 2, label: 'Expenses', icon: Wallet },
          { id: 3, label: 'Hub', icon: Settings },
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
              className={`flex flex-col items-center justify-center py-1 px-3 rounded-lg text-[11px] font-bold transition cursor-pointer ${
                isActive ? 'text-indigo-600' : 'text-slate-500 hover:text-slate-800'
              }`}
            >
              <Icon className="w-5 h-5 mb-0.5" />
              <span>{item.label}</span>
            </button>
          );
        })}
      </nav>

      {/* ===================================================================== */}
      {/* 2. EXPENSE LOGGING SLIDE-OVER DRAWER */}
      {/* ===================================================================== */}
      {isExpenseDrawerOpen && (
        <div className="fixed inset-0 bg-slate-950/60 backdrop-blur-md z-50 flex justify-end">
          <div className={`w-full max-w-md h-full shadow-2xl p-6 flex flex-col justify-between overflow-y-auto animate-in slide-in-from-right duration-200 border-l ${isDarkMode ? 'bg-[#0F172A] border-slate-800 text-slate-100' : 'bg-white border-slate-200 text-slate-900'}`}>
            <div className="space-y-6">
              <div className={`flex items-center justify-between border-b pb-4 ${isDarkMode ? 'border-slate-800' : 'border-slate-100'}`}>
                <h4 className={`font-bold text-base ${isDarkMode ? 'text-white' : 'text-slate-900'}`}>Log New Business Expense</h4>
                <button onClick={() => setIsExpenseDrawerOpen(false)} className="text-slate-400 hover:text-slate-600 cursor-pointer">
                  <X className="w-5 h-5" />
                </button>
              </div>

              <div className="space-y-4 text-xs">
                <div>
                  <label className={`block font-bold uppercase tracking-wider mb-1 ${isDarkMode ? 'text-slate-400' : 'text-slate-600'}`}>Vendor Name *</label>
                  <input
                    type="text"
                    value={expenseVendor}
                    onChange={(e) => setExpenseVendor(e.target.value)}
                    placeholder="e.g. AWS Cloud / GitHub"
                    className={`w-full px-3 py-2.5 rounded-xl border text-sm font-semibold ${isDarkMode ? 'bg-slate-800 border-slate-700 text-white placeholder-slate-500' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
                  />
                </div>
                <div>
                  <label className={`block font-bold uppercase tracking-wider mb-1 ${isDarkMode ? 'text-slate-400' : 'text-slate-600'}`}>Category</label>
                  <select
                    value={expenseCategory}
                    onChange={(e) => setExpenseCategory(e.target.value)}
                    className={`w-full px-3 py-2.5 rounded-xl border text-sm ${isDarkMode ? 'bg-slate-800 border-slate-700 text-white' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
                  >
                    <option value="Software & Tools">Software & Tools</option>
                    <option value="Cloud Hosting">Cloud Hosting</option>
                    <option value="Hardware & Equipment">Hardware & Equipment</option>
                    <option value="Professional Services">Professional Services</option>
                    <option value="Travel & Meals">Travel & Meals</option>
                  </select>
                </div>
                <div>
                  <label className={`block font-bold uppercase tracking-wider mb-1 ${isDarkMode ? 'text-slate-400' : 'text-slate-600'}`}>Expense Date</label>
                  <input
                    type="date"
                    value={expenseDate}
                    onChange={(e) => setExpenseDate(e.target.value)}
                    className={`w-full px-3 py-2.5 rounded-xl border text-sm ${isDarkMode ? 'bg-slate-800 border-slate-700 text-white' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
                  />
                </div>
                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <label className={`block font-bold uppercase tracking-wider mb-1 ${isDarkMode ? 'text-slate-400' : 'text-slate-600'}`}>Base Amount ({sym})</label>
                    <input
                      type="number"
                      step={dec === 0 ? "1" : "0.01"}
                      value={expenseAmount}
                      onChange={(e) => setExpenseAmount(e.target.value)}
                      placeholder={dec === 0 ? "100" : "100.00"}
                      className={`w-full px-3 py-2.5 rounded-xl border text-sm font-bold font-mono tabular-nums ${isDarkMode ? 'bg-slate-800 border-slate-700 text-white' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
                    />
                  </div>
                  <div>
                    <label className={`block font-bold uppercase tracking-wider mb-1 ${isDarkMode ? 'text-slate-400' : 'text-slate-600'}`}>Tax Amount ({sym})</label>
                    <input
                      type="number"
                      step={dec === 0 ? "1" : "0.01"}
                      value={expenseTax}
                      onChange={(e) => setExpenseTax(e.target.value)}
                      placeholder={dec === 0 ? "10" : "10.00"}
                      className={`w-full px-3 py-2.5 rounded-xl border text-sm font-bold font-mono tabular-nums ${isDarkMode ? 'bg-slate-800 border-slate-700 text-white' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
                    />
                  </div>
                </div>

                {/* Receipt Dropzone */}
                <div>
                  <label className={`block font-bold uppercase tracking-wider mb-1 ${isDarkMode ? 'text-slate-400' : 'text-slate-600'}`}>Receipt Attachment</label>
                  <label className={`border-2 border-dashed rounded-xl p-4 flex flex-col items-center justify-center cursor-pointer transition ${isDarkMode ? 'border-slate-700 hover:bg-slate-800/50' : 'border-slate-200 hover:bg-slate-50'}`}>
                    <Paperclip className="w-5 h-5 text-indigo-500 mb-1" />
                    <span className={`font-semibold text-xs ${isDarkMode ? 'text-slate-300' : 'text-slate-700'}`}>{expenseReceiptName || 'Click to attach receipt photo/PDF'}</span>
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
                  <label className={`block font-bold uppercase tracking-wider mb-1 ${isDarkMode ? 'text-slate-400' : 'text-slate-600'}`}>Notes / Memo</label>
                  <textarea
                    value={expenseNotes}
                    onChange={(e) => setExpenseNotes(e.target.value)}
                    rows={2}
                    className={`w-full p-3 rounded-xl border text-xs ${isDarkMode ? 'bg-slate-800 border-slate-700 text-white placeholder-slate-500' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
                    placeholder="Optional expense memo..."
                  />
                </div>
              </div>
            </div>

            <div className={`flex gap-3 pt-4 border-t ${isDarkMode ? 'border-slate-800' : 'border-slate-100'}`}>
              <button
                onClick={() => setIsExpenseDrawerOpen(false)}
                className={`flex-1 py-2.5 font-bold rounded-xl text-xs cursor-pointer ${isDarkMode ? 'bg-slate-800 hover:bg-slate-700 text-slate-300' : 'bg-slate-100 hover:bg-slate-200 text-slate-700'}`}
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
                className="flex-1 py-2.5 bg-orange-600 hover:bg-orange-700 text-white font-bold rounded-xl text-xs shadow-sm cursor-pointer"
              >
                Save Expense
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ===================================================================== */}
      {/* 3. MODALS & DIALOGS */}
      {/* ===================================================================== */}

      {/* Payment Reminder Modal */}
      {reminderModalInvoice && (
        <div className="fixed inset-0 bg-slate-950/60 backdrop-blur-md z-50 flex items-center justify-center p-4">
          <div className={`rounded-2xl p-6 shadow-2xl max-w-sm w-full space-y-4 border ${isDarkMode ? 'bg-[#0F172A] border-slate-800 text-slate-100 shadow-[0_24px_50px_-12px_rgba(0,0,0,0.7)]' : 'bg-white border-slate-200 text-slate-900 shadow-[0_20px_40px_-15px_rgba(0,0,0,0.1)]'}`}>
            <div className={`flex items-center justify-between border-b pb-2 ${isDarkMode ? 'border-slate-800' : 'border-slate-100'}`}>
              <h4 className={`font-bold text-base ${isDarkMode ? 'text-white' : 'text-slate-900'}`}>Send Payment Reminder</h4>
              <button onClick={() => setReminderModalInvoice(null)} className="text-slate-400 hover:text-slate-600 cursor-pointer"><X className="w-4 h-4" /></button>
            </div>
            <p className={`text-xs ${isDarkMode ? 'text-slate-400' : 'text-slate-600'}`}>Invoice {reminderModalInvoice.invoice_number} for {reminderModalInvoice.client_name} (<span className="font-mono tabular-nums font-bold">{formatMoney(getInvoiceBalanceDueCents(reminderModalInvoice))}</span> due)</p>
            <div className="space-y-2">
              <button
                onClick={() => {
                  navigator.clipboard.writeText(`Payment Reminder: Invoice ${reminderModalInvoice.invoice_number} for ${formatMoney(getInvoiceBalanceDueCents(reminderModalInvoice))} is overdue. Please remit payment at your earliest convenience.`);
                  alert('Reminder message copied to clipboard!');
                  setReminderModalInvoice(null);
                }}
                className={`w-full text-left px-4 py-2.5 rounded-xl font-bold text-xs cursor-pointer flex items-center gap-2 ${isDarkMode ? 'bg-slate-800 hover:bg-slate-700 text-slate-200' : 'bg-slate-100 hover:bg-slate-200 text-slate-700'}`}
              >
                <Copy className="w-4 h-4 text-slate-400" />
                <span>Copy Reminder Message</span>
              </button>
              <a
                href={`https://wa.me/?text=${encodeURIComponent(`Payment Reminder: Invoice ${reminderModalInvoice.invoice_number} for ${formatMoney(getInvoiceBalanceDueCents(reminderModalInvoice))} is overdue. Please settle payment.`)}`}
                target="_blank"
                rel="noreferrer"
                onClick={() => setReminderModalInvoice(null)}
                className="w-full text-left px-4 py-2.5 bg-emerald-500/15 hover:bg-emerald-500/25 text-emerald-500 rounded-xl font-bold text-xs cursor-pointer flex items-center gap-2 border border-emerald-500/30"
              >
                <span>💬 Send via WhatsApp</span>
              </a>
              <a
                href={`mailto:?subject=${encodeURIComponent(`Payment Reminder: Invoice ${reminderModalInvoice.invoice_number}`)}&body=${encodeURIComponent(`Dear ${reminderModalInvoice.client_name},\n\nThis is a polite reminder that Invoice ${reminderModalInvoice.invoice_number} for ${formatMoney(getInvoiceBalanceDueCents(reminderModalInvoice))} was due on ${reminderModalInvoice.due_date}.\n\nThank you,\n${businessProfile.business_name}`)}`}
                onClick={() => setReminderModalInvoice(null)}
                className="w-full text-left px-4 py-2.5 bg-indigo-500/15 hover:bg-indigo-500/25 text-indigo-400 rounded-xl font-bold text-xs cursor-pointer flex items-center gap-2 border border-indigo-500/30"
              >
                <span>✉️ Send Email</span>
              </a>
            </div>
          </div>
        </div>
      )}

      {/* Record Payment Modal */}
      {recordPaymentInvoice && (
        <div className="fixed inset-0 bg-slate-950/60 backdrop-blur-md z-50 flex items-center justify-center p-4">
          <div className={`rounded-2xl max-w-md w-full p-6 shadow-2xl space-y-4 border ${isDarkMode ? 'bg-[#0F172A] border-slate-800 text-slate-100 shadow-[0_24px_50px_-12px_rgba(0,0,0,0.7)]' : 'bg-white border-slate-200 text-slate-900 shadow-[0_20px_40px_-15px_rgba(0,0,0,0.1)]'}`}>
            <div className={`flex items-center justify-between border-b pb-2 ${isDarkMode ? 'border-slate-800' : 'border-slate-100'}`}>
              <h4 className={`font-bold text-base ${isDarkMode ? 'text-white' : 'text-slate-900'}`}>Record Payment for {recordPaymentInvoice.invoice_number}</h4>
              <button onClick={() => setRecordPaymentInvoice(null)} className="text-slate-400 hover:text-slate-600 cursor-pointer"><X className="w-4 h-4" /></button>
            </div>
            <div className="space-y-3 text-xs">
              <div>
                <label className={`block font-bold mb-1 ${isDarkMode ? 'text-slate-400' : 'text-slate-600'}`}>Amount Received in Bank ({sym}) *</label>
                <input
                  type="number"
                  step={dec === 0 ? "1" : "0.01"}
                  value={paymentAmountReceived}
                  onChange={(e) => setPaymentAmountReceived(e.target.value)}
                  className={`w-full px-3 py-2 rounded-xl border text-sm font-bold font-mono tabular-nums ${isDarkMode ? 'bg-slate-800 border-slate-700 text-white' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
                />
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className={`block font-bold mb-1 ${isDarkMode ? 'text-slate-400' : 'text-slate-600'}`}>TDS Withheld ({sym})</label>
                  <input
                    type="number"
                    step={dec === 0 ? "1" : "0.01"}
                    value={paymentTds}
                    onChange={(e) => setPaymentTds(e.target.value)}
                    className={`w-full px-3 py-2 rounded-xl border text-sm font-mono tabular-nums ${isDarkMode ? 'bg-slate-800 border-slate-700 text-white' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
                  />
                </div>
                <div>
                  <label className={`block font-bold mb-1 ${isDarkMode ? 'text-slate-400' : 'text-slate-600'}`}>Payment Method</label>
                  <select
                    value={paymentMethod}
                    onChange={(e) => setPaymentMethod(e.target.value)}
                    className={`w-full px-3 py-2 rounded-xl border text-sm ${isDarkMode ? 'bg-slate-800 border-slate-700 text-white' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
                  >
                    <option value="Bank Wire">Bank Wire</option>
                    <option value="UPI / PayPal">UPI / PayPal</option>
                    <option value="Cheque">Cheque</option>
                    <option value="Cash">Cash</option>
                  </select>
                </div>
              </div>
              <div>
                <label className={`block font-bold mb-1 ${isDarkMode ? 'text-slate-400' : 'text-slate-600'}`}>Reference / UTR Number</label>
                <input
                  type="text"
                  value={paymentRefNumber}
                  onChange={(e) => setPaymentRefNumber(e.target.value)}
                  placeholder="e.g. UTR-98765432"
                  className={`w-full px-3 py-2 rounded-xl border text-sm ${isDarkMode ? 'bg-slate-800 border-slate-700 text-white placeholder-slate-500' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
                />
              </div>
            </div>
            <div className={`flex justify-end gap-3 pt-3 border-t ${isDarkMode ? 'border-slate-800' : 'border-slate-100'}`}>
              <button onClick={() => setRecordPaymentInvoice(null)} className={`px-4 py-2 text-xs font-semibold cursor-pointer ${isDarkMode ? 'text-slate-400 hover:text-slate-200' : 'text-slate-600 hover:text-slate-900'}`}>Cancel</button>
              <button
                onClick={() => {
                  const amt = parsePriceToCents(paymentAmountReceived);
                  const tds = parsePriceToCents(paymentTds);
                  if (amt + tds <= 0) {
                    alert('Please enter a valid received amount.');
                    return;
                  }
                  const bal = getInvoiceBalanceDueCents(recordPaymentInvoice);
                  if (amt + tds > bal) {
                    alert(`Total payment credit (${formatMoney(amt + tds)}) cannot exceed remaining balance due (${formatMoney(bal)}).`);
                    return;
                  }
                  const newPay: StoredPayment = {
                    id: `pay-${Date.now()}`,
                    invoice_id: recordPaymentInvoice.id,
                    amount_cents: amt + tds,
                    amount_received_cents: amt,
                    tds_cents: tds,
                    reference_number: paymentRefNumber.trim(),
                    payment_method: paymentMethod,
                    payment_date: new Date().toISOString().split('T')[0],
                    notes: paymentRefNumber ? `Ref: ${paymentRefNumber}` : '',
                    created_at: new Date().toISOString(),
                  };
                  setPayments(prev => [...prev, newPay]);
                  setRecordPaymentInvoice(null);
                  alert(`Payment of ${formatMoney(amt + tds)} recorded for ${recordPaymentInvoice.invoice_number}!`);
                }}
                className="px-5 py-2 bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-bold rounded-xl cursor-pointer"
              >
                Confirm Payment
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Add / Edit Client Modal */}
      {(isAddClientModalOpen || editingClient) && (
        <div className="fixed inset-0 bg-slate-950/60 backdrop-blur-md z-50 flex items-center justify-center p-4">
          <div className={`rounded-2xl max-w-md w-full p-6 shadow-2xl space-y-4 border ${isDarkMode ? 'bg-[#0F172A] border-slate-800 text-slate-100 shadow-[0_24px_50px_-12px_rgba(0,0,0,0.7)]' : 'bg-white border-slate-200 text-slate-900 shadow-[0_20px_40px_-15px_rgba(0,0,0,0.1)]'}`}>
            <div className={`flex items-center justify-between border-b pb-2 ${isDarkMode ? 'border-slate-800' : 'border-slate-100'}`}>
              <h4 className={`font-bold text-base ${isDarkMode ? 'text-white' : 'text-slate-900'}`}>{editingClient ? 'Edit Client Details' : 'Add New Client'}</h4>
              <button onClick={() => { setIsAddClientModalOpen(false); setEditingClient(null); }} className="text-slate-400 hover:text-slate-600 cursor-pointer"><X className="w-4 h-4" /></button>
            </div>
            <div className="space-y-3 text-xs">
              <div>
                <label className={`block font-bold mb-1 ${isDarkMode ? 'text-slate-400' : 'text-slate-600'}`}>Client / Company Name *</label>
                <input
                  type="text"
                  value={clientFormName}
                  onChange={(e) => setClientFormName(e.target.value)}
                  placeholder="e.g. Acme Corp"
                  className={`w-full px-3 py-2 rounded-xl border text-sm font-semibold ${isDarkMode ? 'bg-slate-800 border-slate-700 text-white placeholder-slate-500' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
                />
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className={`block font-bold mb-1 ${isDarkMode ? 'text-slate-400' : 'text-slate-600'}`}>Billing Email</label>
                  <input
                    type="email"
                    value={clientFormEmail}
                    onChange={(e) => setClientFormEmail(e.target.value)}
                    placeholder="billing@acme.com"
                    className={`w-full px-3 py-2 rounded-xl border text-xs ${isDarkMode ? 'bg-slate-800 border-slate-700 text-white placeholder-slate-500' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
                  />
                </div>
                <div>
                  <label className={`block font-bold mb-1 ${isDarkMode ? 'text-slate-400' : 'text-slate-600'}`}>Phone</label>
                  <input
                    type="text"
                    value={clientFormPhone}
                    onChange={(e) => setClientFormPhone(e.target.value)}
                    placeholder="+1 555-0199"
                    className={`w-full px-3 py-2 rounded-xl border text-xs ${isDarkMode ? 'bg-slate-800 border-slate-700 text-white placeholder-slate-500' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
                  />
                </div>
              </div>
              <div>
                <label className={`block font-bold mb-1 ${isDarkMode ? 'text-slate-400' : 'text-slate-600'}`}>Billing Address</label>
                <textarea
                  value={clientFormAddress}
                  onChange={(e) => setClientFormAddress(e.target.value)}
                  rows={2}
                  placeholder="Street, City, State, ZIP..."
                  className={`w-full p-2.5 rounded-xl border text-xs ${isDarkMode ? 'bg-slate-800 border-slate-700 text-white placeholder-slate-500' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
                />
              </div>
              <div>
                <label className={`block font-bold mb-1 ${isDarkMode ? 'text-slate-400' : 'text-slate-600'}`}>GSTIN / Tax ID</label>
                <input
                  type="text"
                  value={clientFormTaxId}
                  onChange={(e) => setClientFormTaxId(e.target.value)}
                  placeholder="e.g. GSTIN29ABCDE1234F1Z5"
                  className={`w-full px-3 py-2 rounded-xl border text-xs ${isDarkMode ? 'bg-slate-800 border-slate-700 text-white placeholder-slate-500' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
                />
              </div>
            </div>
            <div className={`flex justify-end gap-3 pt-3 border-t ${isDarkMode ? 'border-slate-800' : 'border-slate-100'}`}>
              <button onClick={() => { setIsAddClientModalOpen(false); setEditingClient(null); }} className={`px-4 py-2 text-xs font-semibold cursor-pointer ${isDarkMode ? 'text-slate-400 hover:text-slate-200' : 'text-slate-600 hover:text-slate-900'}`}>Cancel</button>
              <button
                onClick={() => {
                  if (!clientFormName.trim()) {
                    alert('Please enter client name.');
                    return;
                  }
                  if (editingClient) {
                    setClients(prev => prev.map(c => c.id === editingClient.id ? {
                      ...c,
                      name: clientFormName.trim(),
                      email: clientFormEmail.trim(),
                      phone: clientFormPhone.trim(),
                      address: clientFormAddress.trim(),
                      tax_id: clientFormTaxId.trim(),
                    } : c));
                    setEditingClient(null);
                    alert('Client details updated!');
                  } else {
                    const newC: Client = {
                      id: `client-${Date.now()}`,
                      name: clientFormName.trim(),
                      email: clientFormEmail.trim(),
                      phone: clientFormPhone.trim(),
                      address: clientFormAddress.trim(),
                      tax_id: clientFormTaxId.trim(),
                      created_at: new Date().toISOString(),
                    };
                    setClients(prev => [...prev, newC]);
                    setSelectedDossierClientId(newC.id);
                    setIsAddClientModalOpen(false);
                    alert('Client added successfully!');
                  }
                }}
                className="px-5 py-2 bg-indigo-600 hover:bg-indigo-700 text-white text-xs font-bold rounded-xl cursor-pointer"
              >
                {editingClient ? 'Save Changes' : 'Create Client'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Add / Edit Catalog Item Modal */}
      {(isAddItemModalOpen || editingItem) && (
        <div className="fixed inset-0 bg-slate-950/60 backdrop-blur-md z-50 flex items-center justify-center p-4">
          <div className={`rounded-2xl max-w-md w-full p-6 shadow-2xl space-y-4 border ${isDarkMode ? 'bg-[#0F172A] border-slate-800 text-slate-100 shadow-[0_24px_50px_-12px_rgba(0,0,0,0.7)]' : 'bg-white border-slate-200 text-slate-900 shadow-[0_20px_40px_-15px_rgba(0,0,0,0.1)]'}`}>
            <div className={`flex items-center justify-between border-b pb-2 ${isDarkMode ? 'border-slate-800' : 'border-slate-100'}`}>
              <h4 className={`font-bold text-base ${isDarkMode ? 'text-white' : 'text-slate-900'}`}>{editingItem ? 'Edit Catalog Item' : 'Add Item to Catalog'}</h4>
              <button onClick={() => { setIsAddItemModalOpen(false); setEditingItem(null); }} className="text-slate-400 hover:text-slate-600 cursor-pointer"><X className="w-4 h-4" /></button>
            </div>
            <div className="space-y-3 text-xs">
              <div>
                <label className={`block font-bold mb-1 ${isDarkMode ? 'text-slate-400' : 'text-slate-600'}`}>Item / Service Title *</label>
                <input
                  type="text"
                  value={itemFormTitle}
                  onChange={(e) => setItemFormTitle(e.target.value)}
                  placeholder="e.g. Full-Stack Engineering Rate"
                  className={`w-full px-3 py-2 rounded-xl border text-sm font-semibold ${isDarkMode ? 'bg-slate-800 border-slate-700 text-white placeholder-slate-500' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
                />
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className={`block font-bold mb-1 ${isDarkMode ? 'text-slate-400' : 'text-slate-600'}`}>SAC / HSN Code</label>
                  <input
                    type="text"
                    value={itemFormSacHsn}
                    onChange={(e) => setItemFormSacHsn(e.target.value)}
                    placeholder="998311"
                    className={`w-full px-3 py-2 rounded-xl border text-xs ${isDarkMode ? 'bg-slate-800 border-slate-700 text-white placeholder-slate-500' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
                  />
                </div>
                <div>
                  <label className={`block font-bold mb-1 ${isDarkMode ? 'text-slate-400' : 'text-slate-600'}`}>Default Price ({sym}) *</label>
                  <input
                    type="number"
                    step={dec === 0 ? "1" : "0.01"}
                    value={itemFormPrice}
                    onChange={(e) => setItemFormPrice(e.target.value)}
                    placeholder={dec === 0 ? "100" : "100.00"}
                    className={`w-full px-3 py-2 rounded-xl border text-xs font-bold font-mono tabular-nums ${isDarkMode ? 'bg-slate-800 border-slate-700 text-white' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
                  />
                </div>
              </div>
              <div>
                <label className={`block font-bold mb-1 ${isDarkMode ? 'text-slate-400' : 'text-slate-600'}`}>Description (optional)</label>
                <textarea
                  value={itemFormDesc}
                  onChange={(e) => setItemFormDesc(e.target.value)}
                  rows={2}
                  placeholder="Scope deliverables..."
                  className={`w-full p-2.5 rounded-xl border text-xs ${isDarkMode ? 'bg-slate-800 border-slate-700 text-white placeholder-slate-500' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
                />
              </div>
            </div>
            <div className={`flex justify-end gap-3 pt-3 border-t ${isDarkMode ? 'border-slate-800' : 'border-slate-100'}`}>
              <button onClick={() => { setIsAddItemModalOpen(false); setEditingItem(null); }} className={`px-4 py-2 text-xs font-semibold cursor-pointer ${isDarkMode ? 'text-slate-400 hover:text-slate-200' : 'text-slate-600 hover:text-slate-900'}`}>Cancel</button>
              <button
                onClick={() => {
                  if (!itemFormTitle.trim()) {
                    alert('Please enter item title.');
                    return;
                  }
                  const priceCents = parsePriceToCents(itemFormPrice);
                  if (priceCents < 0) {
                    alert('Please enter a valid price.');
                    return;
                  }
                  if (editingItem) {
                    setSavedItems(prev => prev.map(i => i.id === editingItem.id ? {
                      ...i,
                      title: itemFormTitle.trim(),
                      sac_hsn: itemFormSacHsn.trim(),
                      default_price_cents: priceCents,
                      description: itemFormDesc.trim(),
                    } : i));
                    setEditingItem(null);
                    alert('Catalog item updated!');
                  } else {
                    const newItem: StoredItem = {
                      id: `si-${Date.now()}`,
                      title: itemFormTitle.trim(),
                      sac_hsn: itemFormSacHsn.trim(),
                      default_price_cents: priceCents,
                      description: itemFormDesc.trim(),
                      created_at: new Date().toISOString(),
                    };
                    setSavedItems(prev => [...prev, newItem]);
                    setIsAddItemModalOpen(false);
                    alert('Catalog item added!');
                  }
                }}
                className="px-5 py-2 bg-indigo-600 hover:bg-indigo-700 text-white text-xs font-bold rounded-xl cursor-pointer"
              >
                {editingItem ? 'Save Item' : 'Add to Catalog'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Statement of Account Preview Dialog */}
      {statementClient && (
        <div className="fixed inset-0 bg-slate-950/60 backdrop-blur-md z-50 flex items-center justify-center p-4">
          <div className={`rounded-2xl max-w-2xl w-full p-6 shadow-2xl space-y-4 max-h-[90vh] overflow-y-auto border ${isDarkMode ? 'bg-[#0F172A] border-slate-800 text-slate-100 shadow-[0_24px_50px_-12px_rgba(0,0,0,0.7)]' : 'bg-white border-slate-200 text-slate-900 shadow-[0_20px_40px_-15px_rgba(0,0,0,0.1)]'}`}>
            <div className={`flex items-center justify-between border-b pb-3 ${isDarkMode ? 'border-slate-800' : 'border-slate-100'}`}>
              <h4 className={`font-bold text-base ${isDarkMode ? 'text-white' : 'text-slate-900'}`}>Statement of Account: {statementClient.name}</h4>
              <button onClick={() => setStatementClient(null)} className="text-slate-400 hover:text-slate-600 cursor-pointer"><X className="w-4 h-4" /></button>
            </div>
            <div className="space-y-4 text-xs">
              <div className="flex justify-between items-start">
                <div>
                  <h5 className={`font-bold text-sm ${isDarkMode ? 'text-white' : 'text-slate-900'}`}>{businessProfile.business_name}</h5>
                  <p className="text-slate-400">{businessProfile.email} • {businessProfile.phone}</p>
                </div>
                <div className="text-right">
                  <span className="font-bold text-slate-400 uppercase tracking-wider text-[10px]">CLIENT</span>
                  <p className={`font-bold ${isDarkMode ? 'text-white' : 'text-slate-900'}`}>{statementClient.name}</p>
                  <p className="text-slate-400">{statementClient.email}</p>
                </div>
              </div>
              <div className={`border rounded-xl overflow-hidden ${isDarkMode ? 'border-slate-800' : 'border-slate-200'}`}>
                <table className="w-full text-left text-xs">
                  <thead className={`font-bold border-b ${isDarkMode ? 'bg-slate-800 text-slate-300 border-slate-700' : 'bg-slate-50 text-slate-700 border-slate-200'}`}>
                    <tr>
                      <th className="p-2.5">Date</th>
                      <th className="p-2.5">Reference</th>
                      <th className="p-2.5 text-right">Debit</th>
                      <th className="p-2.5 text-right">Credit</th>
                    </tr>
                  </thead>
                  <tbody className={`divide-y ${isDarkMode ? 'divide-slate-800 text-slate-200' : 'divide-slate-100'}`}>
                    {invoices.filter(i => i.client_id === statementClient.id).map(inv => (
                      <tr key={inv.id}>
                        <td className="p-2.5">{inv.issue_date}</td>
                        <td className="p-2.5 font-mono font-bold text-indigo-500">{inv.invoice_number}</td>
                        <td className={`p-2.5 text-right font-bold font-mono tabular-nums ${isDarkMode ? 'text-white' : 'text-slate-900'}`}>{formatMoney(inv.total_cents)}</td>
                        <td className="p-2.5 text-right text-slate-400">-</td>
                      </tr>
                    ))}
                    {payments.filter(p => invoices.some(i => i.id === p.invoice_id && i.client_id === statementClient.id)).map(pay => (
                      <tr key={pay.id}>
                        <td className="p-2.5">{pay.payment_date}</td>
                        <td className="p-2.5 font-mono text-emerald-500">Payment ({pay.payment_method})</td>
                        <td className="p-2.5 text-right text-slate-400">-</td>
                        <td className="p-2.5 text-right font-bold font-mono tabular-nums text-emerald-500">{formatMoney(pay.amount_cents)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
            <div className={`flex justify-end gap-3 pt-3 border-t ${isDarkMode ? 'border-slate-800' : 'border-slate-100'}`}>
              <button onClick={() => window.print()} className="px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white text-xs font-bold rounded-xl flex items-center gap-1.5 cursor-pointer">
                <Printer className="w-4 h-4" />
                <span>Print Statement</span>
              </button>
            </div>
          </div>
        </div>
      )}

      {/* CSV Export Modal */}
      {isCsvModalOpen && (
        <div className="fixed inset-0 bg-slate-950/60 backdrop-blur-md z-50 flex items-center justify-center p-4">
          <div className={`rounded-2xl max-w-md w-full p-6 shadow-2xl space-y-4 border ${isDarkMode ? 'bg-[#0F172A] border-slate-800 text-slate-100 shadow-[0_24px_50px_-12px_rgba(0,0,0,0.7)]' : 'bg-white border-slate-200 text-slate-900 shadow-[0_20px_40px_-15px_rgba(0,0,0,0.1)]'}`}>
            <div className={`flex items-center justify-between border-b pb-2 ${isDarkMode ? 'border-slate-800' : 'border-slate-100'}`}>
              <h4 className={`font-bold text-base ${isDarkMode ? 'text-white' : 'text-slate-900'}`}>Export Accounting CSV</h4>
              <button onClick={() => setIsCsvModalOpen(false)} className="text-slate-400 hover:text-slate-600 cursor-pointer"><X className="w-4 h-4" /></button>
            </div>
            <p className={`text-xs ${isDarkMode ? 'text-slate-400' : 'text-slate-500'}`}>Download formatted accounting exports compatible with QuickBooks, Xero, Tally, and Excel.</p>
            <div className="space-y-3">
              <button onClick={handleExportInvoicesCsv} className={`w-full py-3 text-xs font-bold rounded-xl border transition flex items-center justify-center gap-2 cursor-pointer ${isDarkMode ? 'bg-indigo-500/15 hover:bg-indigo-500/25 text-indigo-400 border-indigo-500/30' : 'bg-indigo-50 hover:bg-indigo-100 text-indigo-700 border-indigo-200'}`}>
                <FileSpreadsheet className="w-4 h-4" />
                <span>Export Invoices Ledger CSV ({invoices.length} records)</span>
              </button>
              <button onClick={handleExportExpensesCsv} className={`w-full py-3 text-xs font-bold rounded-xl border transition flex items-center justify-center gap-2 cursor-pointer ${isDarkMode ? 'bg-orange-500/15 hover:bg-orange-500/25 text-orange-400 border-orange-500/30' : 'bg-orange-50 hover:bg-orange-100 text-orange-700 border-orange-200'}`}>
                <FileSpreadsheet className="w-4 h-4" />
                <span>Export Expenses Ledger CSV ({expenses.length} records)</span>
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Business Profile Modal */}
      {isProfileModalOpen && (
        <div className="fixed inset-0 bg-slate-950/60 backdrop-blur-md z-50 flex items-center justify-center p-4">
          <div className={`rounded-2xl max-w-lg w-full p-6 shadow-2xl space-y-4 max-h-[90vh] overflow-y-auto border ${isDarkMode ? 'bg-[#0F172A] border-slate-800 text-slate-100 shadow-[0_24px_50px_-12px_rgba(0,0,0,0.7)]' : 'bg-white border-slate-200 text-slate-900 shadow-[0_20px_40px_-15px_rgba(0,0,0,0.1)]'}`}>
            <div className={`flex items-center justify-between border-b pb-2 ${isDarkMode ? 'border-slate-800' : 'border-slate-100'}`}>
              <h4 className={`font-bold text-base ${isDarkMode ? 'text-white' : 'text-slate-900'}`}>Business Profile & Branding Settings</h4>
              <button onClick={() => setIsProfileModalOpen(false)} className="text-slate-400 hover:text-slate-600 cursor-pointer"><X className="w-4 h-4" /></button>
            </div>
            <div className="space-y-3 text-xs">
              <div>
                <label className={`block font-bold mb-1 ${isDarkMode ? 'text-slate-400' : 'text-slate-600'}`}>Business Name</label>
                <input
                  type="text"
                  value={businessProfile.business_name}
                  onChange={(e) => setBusinessProfile(prev => ({ ...prev, business_name: e.target.value }))}
                  className={`w-full px-3 py-2 rounded-xl border font-bold ${isDarkMode ? 'bg-slate-800 border-slate-700 text-white placeholder-slate-500' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
                />
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className={`block font-bold mb-1 ${isDarkMode ? 'text-slate-400' : 'text-slate-600'}`}>Currency Preset</label>
                  <select
                    value={businessProfile.currency_code}
                    onChange={(e) => {
                      const val = e.target.value;
                      const presets: Record<string, { symbol: string; dec: number }> = {
                        USD: { symbol: '$', dec: 2 },
                        INR: { symbol: '₹', dec: 2 },
                        EUR: { symbol: '€', dec: 2 },
                        GBP: { symbol: '£', dec: 2 },
                        CAD: { symbol: 'C$', dec: 2 },
                        AUD: { symbol: 'A$', dec: 2 },
                        AED: { symbol: 'AED', dec: 2 },
                        SAR: { symbol: 'SAR', dec: 2 },
                        JPY: { symbol: '¥', dec: 0 },
                        KRW: { symbol: '₩', dec: 0 },
                        VND: { symbol: '₫', dec: 0 },
                      };
                      const found = presets[val] || { symbol: '$', dec: 2 };
                      setBusinessProfile(prev => ({
                        ...prev,
                        currency_code: val,
                        currency_symbol: found.symbol,
                        currency_decimals: found.dec,
                      }));
                    }}
                    className={`w-full px-3 py-2 rounded-xl border font-bold text-xs ${isDarkMode ? 'bg-slate-800 border-slate-700 text-white' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
                  >
                    <option value="USD">USD ($) - US Dollar</option>
                    <option value="INR">INR (₹) - Indian Rupee</option>
                    <option value="EUR">EUR (€) - Euro</option>
                    <option value="GBP">GBP (£) - British Pound</option>
                    <option value="CAD">CAD (C$) - Canadian Dollar</option>
                    <option value="AUD">AUD (A$) - Australian Dollar</option>
                    <option value="AED">AED - UAE Dirham</option>
                    <option value="SAR">SAR - Saudi Riyal</option>
                    <option value="JPY">JPY (¥) - Japanese Yen (0-Decimal)</option>
                    <option value="KRW">KRW (₩) - S. Korean Won (0-Decimal)</option>
                    <option value="VND">VND (₫) - Vietnamese Dong (0-Decimal)</option>
                  </select>
                </div>
                <div>
                  <label className={`block font-bold mb-1 ${isDarkMode ? 'text-slate-400' : 'text-slate-600'}`}>Currency Symbol</label>
                  <input
                    type="text"
                    value={businessProfile.currency_symbol}
                    onChange={(e) => setBusinessProfile(prev => ({ ...prev, currency_symbol: e.target.value }))}
                    className={`w-full px-3 py-2 rounded-xl border font-bold ${isDarkMode ? 'bg-slate-800 border-slate-700 text-white' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
                  />
                </div>
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className={`block font-bold mb-1 ${isDarkMode ? 'text-slate-400' : 'text-slate-600'}`}>Email</label>
                  <input
                    type="email"
                    value={businessProfile.email}
                    onChange={(e) => setBusinessProfile(prev => ({ ...prev, email: e.target.value }))}
                    className={`w-full px-3 py-2 rounded-xl border ${isDarkMode ? 'bg-slate-800 border-slate-700 text-white placeholder-slate-500' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
                  />
                </div>
                <div>
                  <label className={`block font-bold mb-1 ${isDarkMode ? 'text-slate-400' : 'text-slate-600'}`}>Phone</label>
                  <input
                    type="text"
                    value={businessProfile.phone}
                    onChange={(e) => setBusinessProfile(prev => ({ ...prev, phone: e.target.value }))}
                    className={`w-full px-3 py-2 rounded-xl border ${isDarkMode ? 'bg-slate-800 border-slate-700 text-white placeholder-slate-500' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
                  />
                </div>
              </div>
              <div>
                <label className={`block font-bold mb-1 ${isDarkMode ? 'text-slate-400' : 'text-slate-600'}`}>Address</label>
                <textarea
                  value={businessProfile.address}
                  onChange={(e) => setBusinessProfile(prev => ({ ...prev, address: e.target.value }))}
                  rows={2}
                  className={`w-full p-2.5 rounded-xl border ${isDarkMode ? 'bg-slate-800 border-slate-700 text-white placeholder-slate-500' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
                />
              </div>
              <div>
                <label className={`block font-bold mb-1 ${isDarkMode ? 'text-slate-400' : 'text-slate-600'}`}>Tax ID / GSTIN</label>
                <input
                  type="text"
                  value={businessProfile.tax_id}
                  onChange={(e) => setBusinessProfile(prev => ({ ...prev, tax_id: e.target.value }))}
                  className={`w-full px-3 py-2 rounded-xl border ${isDarkMode ? 'bg-slate-800 border-slate-700 text-white placeholder-slate-500' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
                />
              </div>
              <div>
                <label className={`block font-bold mb-1 ${isDarkMode ? 'text-slate-400' : 'text-slate-600'}`}>Payment Instructions</label>
                <textarea
                  value={businessProfile.payment_details}
                  onChange={(e) => setBusinessProfile(prev => ({ ...prev, payment_details: e.target.value }))}
                  rows={3}
                  className={`w-full p-2.5 rounded-xl border ${isDarkMode ? 'bg-slate-800 border-slate-700 text-white placeholder-slate-500' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
                />
              </div>
            </div>
            <div className={`flex justify-end pt-3 border-t ${isDarkMode ? 'border-slate-800' : 'border-slate-100'}`}>
              <button
                onClick={() => {
                  setIsProfileModalOpen(false);
                  alert('Business profile updated successfully!');
                }}
                className="px-5 py-2 bg-indigo-600 hover:bg-indigo-700 text-white text-xs font-bold rounded-xl cursor-pointer"
              >
                Save Settings
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Invoice PDF Preview Modal */}
      {previewInvoice && (
        <div className="fixed inset-0 bg-slate-950/60 backdrop-blur-md z-50 flex items-center justify-center p-4">
          <div className={`rounded-2xl max-w-2xl w-full p-6 shadow-2xl space-y-4 max-h-[90vh] overflow-y-auto border ${isDarkMode ? 'bg-[#0F172A] border-slate-800 text-slate-100 shadow-[0_24px_50px_-12px_rgba(0,0,0,0.7)]' : 'bg-white border-slate-200 text-slate-900 shadow-[0_20px_40px_-15px_rgba(0,0,0,0.1)]'}`}>
            <div className={`flex items-center justify-between border-b pb-3 ${isDarkMode ? 'border-slate-800' : 'border-slate-100'}`}>
              <h4 className={`font-bold text-base ${isDarkMode ? 'text-white' : 'text-slate-900'}`}>TAX INVOICE — {previewInvoice.invoice_number}</h4>
              <button onClick={() => setPreviewInvoice(null)} className="text-slate-400 hover:text-slate-600 cursor-pointer"><X className="w-4 h-4" /></button>
            </div>
            <div className="space-y-4 text-xs">
              <div className="flex justify-between items-start">
                <div>
                  <h5 className={`font-bold text-sm ${isDarkMode ? 'text-white' : 'text-slate-900'}`}>{businessProfile.business_name}</h5>
                  <p className="text-slate-400 whitespace-pre-line">{businessProfile.address}</p>
                  <p className="text-slate-400">{businessProfile.email} • {businessProfile.phone}</p>
                  {businessProfile.tax_id && <p className="text-slate-400 font-mono">Tax ID: {businessProfile.tax_id}</p>}
                </div>
                <div className="text-right">
                  <span className="px-2.5 py-1 bg-indigo-500/15 text-indigo-400 border border-indigo-500/30 font-bold rounded-lg text-xs uppercase tracking-wider">TAX INVOICE</span>
                  <p className="font-mono font-bold text-sm text-indigo-400 mt-2">{previewInvoice.invoice_number}</p>
                  <p className="text-slate-400 font-mono">Date: {previewInvoice.issue_date}</p>
                </div>
              </div>
              <div className={`border-t pt-3 flex justify-between ${isDarkMode ? 'border-slate-800' : 'border-slate-100'}`}>
                <div>
                  <span className="font-bold text-slate-400 uppercase tracking-wider text-[10px]">BILL TO</span>
                  <p className={`font-bold ${isDarkMode ? 'text-white' : 'text-slate-900'}`}>{previewInvoice.client_name}</p>
                  <p className="text-slate-400">Terms: {previewInvoice.payment_terms} • Due: {previewInvoice.due_date}</p>
                </div>
              </div>
              {/* Statutory Compliance Notice Banner */}
              {previewInvoice.tax_cents === 0 && (() => {
                const targetClient = clients.find(c => c.id === previewInvoice.client_id);
                const cTax = (targetClient?.tax_id || '').trim().toUpperCase();
                const cAddr = (targetClient?.address || '').trim().toUpperCase();
                const invNotes = (previewInvoice.notes || '').toUpperCase();
                const invTerms = (previewInvoice.terms || '').toUpperCase();
                const isExport = cAddr.includes('USA') || cAddr.includes('UNITED STATES') || cAddr.includes('EXPORT') || cAddr.includes('INTERNATIONAL') || cAddr.includes('UK') || cAddr.includes('LONDON') || cAddr.includes('DUBAI') || cAddr.includes('SINGAPORE') || cAddr.includes('LUT') || invNotes.includes('EXPORT') || invTerms.includes('EXPORT');
                const isEuVat = cTax.startsWith('GB') || cTax.startsWith('DE') || cTax.startsWith('FR') || cTax.startsWith('NL') || cTax.startsWith('IE') || cTax.startsWith('IT') || cTax.startsWith('ES') || cTax.startsWith('BE') || cTax.startsWith('AT') || cTax.startsWith('SE') || cTax.startsWith('DK') || cTax.startsWith('FI') || cTax.startsWith('PL') || cTax.startsWith('CZ') || cTax.startsWith('PT') || cTax.startsWith('RO') || cTax.startsWith('HU') || cTax.startsWith('GR') || cTax.includes('VAT');

                if (isExport) {
                  return (
                    <div className="p-2.5 bg-indigo-500/15 border border-indigo-500/30 rounded-xl text-center text-[11px] font-bold text-indigo-300">
                      SUPPLY MEANT FOR EXPORT UNDER BOND OR LETTER OF UNDERTAKING WITHOUT PAYMENT OF INTEGRATED TAX
                    </div>
                  );
                }
                if (isEuVat) {
                  return (
                    <div className="p-2.5 bg-emerald-500/15 border border-emerald-500/30 rounded-xl text-center text-[11px] font-bold text-emerald-300">
                      Reverse charge: Customer to account for VAT under Article 196 of Council Directive 2006/112/EC.
                    </div>
                  );
                }
                return null;
              })()}

              <div className={`border rounded-xl overflow-hidden ${isDarkMode ? 'border-slate-800' : 'border-slate-200'}`}>
                <table className="w-full text-left text-xs">
                  <thead className={`font-bold border-b ${isDarkMode ? 'bg-slate-800 text-slate-300 border-slate-700' : 'bg-slate-50 text-slate-700 border-slate-200'}`}>
                    <tr>
                      <th className="p-2.5">Item</th>
                      <th className="p-2.5 text-center">Qty</th>
                      <th className="p-2.5 text-right">Price</th>
                      <th className="p-2.5 text-right">Total</th>
                    </tr>
                  </thead>
                  <tbody className={`divide-y ${isDarkMode ? 'divide-slate-800 text-slate-200' : 'divide-slate-100'}`}>
                    {invoiceItems.filter(i => i.invoice_id === previewInvoice.id).map(item => (
                      <tr key={item.id}>
                        <td className="p-2.5">{item.description}</td>
                        <td className="p-2.5 text-center font-mono tabular-nums">{item.quantity}</td>
                        <td className="p-2.5 text-right font-mono tabular-nums">{formatMoney(item.unit_price_cents)}</td>
                        <td className={`p-2.5 text-right font-bold font-mono tabular-nums ${isDarkMode ? 'text-white' : 'text-slate-900'}`}>{formatMoney(item.total_cents)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
              <div className={`flex justify-end pt-3 border-t ${isDarkMode ? 'border-slate-800' : 'border-slate-200'}`}>
                <div className="w-56 space-y-1 text-right">
                  <div className="flex justify-between"><span>Subtotal:</span><span className="font-mono tabular-nums">{formatMoney(previewInvoice.subtotal_cents)}</span></div>
                  {previewInvoice.discount_cents && previewInvoice.discount_cents > 0 ? (
                    <div className="flex justify-between text-amber-500 font-semibold">
                      <span>Discount:</span>
                      <span className="font-mono tabular-nums">-{formatMoney(previewInvoice.discount_cents)}</span>
                    </div>
                  ) : null}
                  {previewInvoice.tax_cents > 0 ? (
                    (() => {
                      const cgst = Math.floor(previewInvoice.tax_cents / 2);
                      const sgst = previewInvoice.tax_cents - cgst;
                      return (
                        <>
                          <div className={`flex justify-between ${isDarkMode ? 'text-slate-400' : 'text-slate-600'}`}><span>CGST (50%):</span><span className="font-mono tabular-nums">{formatMoney(cgst)}</span></div>
                          <div className={`flex justify-between ${isDarkMode ? 'text-slate-400' : 'text-slate-600'}`}><span>SGST (50%):</span><span className="font-mono tabular-nums">{formatMoney(sgst)}</span></div>
                        </>
                      );
                    })()
                  ) : (
                    <div className="flex justify-between text-slate-400"><span>Tax (0% / Exempt):</span><span className="font-mono tabular-nums">{formatMoney(0)}</span></div>
                  )}
                  <div className={`flex justify-between font-bold text-sm border-t pt-1 ${isDarkMode ? 'text-indigo-400 border-slate-800' : 'text-indigo-700 border-slate-200'}`}>
                    <span>Total Amount:</span>
                    <span className="font-mono tabular-nums">{formatMoney(previewInvoice.total_cents)}</span>
                  </div>
                  <div className={`flex justify-between font-bold text-xs ${isDarkMode ? 'text-slate-300' : 'text-slate-700'}`}>
                    <span>Balance Due:</span>
                    <span className="font-mono tabular-nums">{formatMoney(getInvoiceBalanceDueCents(previewInvoice))}</span>
                  </div>
                </div>
              </div>
            </div>
            <div className={`flex justify-end gap-3 pt-3 border-t ${isDarkMode ? 'border-slate-800' : 'border-slate-100'}`}>
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
