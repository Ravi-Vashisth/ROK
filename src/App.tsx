import React, { useState, useEffect, useMemo, useRef } from 'react';
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
  Edit2,
  X,
  Search,
  Upload,
  ArrowRight,
  TrendingDown,
  ChevronDown,
  ChevronUp,
  Download,
  QrCode,
  ShieldAlert,
  Save,
  Check,
  Ban,
  Calendar,
} from 'lucide-react';
import { parsePriceToCents, calculateDueDate, isInvoiceOverdue } from './billingRules';

// --- Parity Models & Interfaces (strictly checked by scripts/verify_parity.cjs) ---
export interface Client {
  id: string;
  name: string;
  email: string;
  phone: string;
  address: string;
  tax_id: string;
  created_at: string;
}

export interface StoredInvoiceItem {
  id: string;
  invoice_id: string;
  description: string;
  quantity: number;
  unit_price_cents: number;
  total_cents: number;
  created_at: string;
}

export interface StoredPayment {
  id: string;
  invoice_id: string;
  amount_cents: number;
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
  status: string;
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
  created_at: string;
}

export interface StoredItem {
  id: string;
  title: string;
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
};

export default function App() {
  useEffect(() => {
    document.title = 'Freelance Ledger';
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
      },
      {
        id: 'client-2',
        name: 'Mohan Enterprises',
        email: 'billing@mohan.io',
        phone: '+91 98765 43210',
        address: '22 Creative Blvd, Bangalore, KA 560001',
        tax_id: 'GSTIN29ABCDE1234F1Z5',
        created_at: '2026-10-27T14:30:00Z',
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
    return [];
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

  // Save changes to localStorage
  useEffect(() => { localStorage.setItem('fl_business_profile', JSON.stringify(businessProfile)); }, [businessProfile]);
  useEffect(() => { localStorage.setItem('fl_clients', JSON.stringify(clients)); }, [clients]);
  useEffect(() => { localStorage.setItem('fl_invoices', JSON.stringify(invoices)); }, [invoices]);
  useEffect(() => { localStorage.setItem('fl_invoice_items', JSON.stringify(invoiceItems)); }, [invoiceItems]);
  useEffect(() => { localStorage.setItem('fl_payments', JSON.stringify(payments)); }, [payments]);
  useEffect(() => { localStorage.setItem('fl_expenses', JSON.stringify(expenses)); }, [expenses]);
  useEffect(() => { localStorage.setItem('fl_saved_items', JSON.stringify(savedItems)); }, [savedItems]);
  useEffect(() => { localStorage.setItem('fl_estimates', JSON.stringify(estimates)); }, [estimates]);
  useEffect(() => { localStorage.setItem('fl_estimate_items', JSON.stringify(estimateItems)); }, [estimateItems]);

  // --- Active Tab Navigation ---
  // 0: Dashboard, 1: Sales, 2: Expenses, 3: Directory
  const [activeTab, setActiveTab] = useState(0);

  // Sales sub-tab: 0 = Invoices, 1 = Estimates
  const [salesSubTab, setSalesSubTab] = useState<0 | 1>(0);

  // Directory sub-tab: 0 = Clients, 1 = Catalog, 2 = Branding & Prefs
  const [dirSubTab, setDirSubTab] = useState<0 | 1 | 2>(0);

  // Modals & UI Controls
  const [isProfileModalOpen, setIsProfileModalOpen] = useState(false);
  const [recordPaymentInvoice, setRecordPaymentInvoice] = useState<InvoiceRecord | null>(null);
  const [previewInvoice, setPreviewInvoice] = useState<InvoiceRecord | null>(null);
  const [clientStatementClient, setClientStatementClient] = useState<Client | null>(null);
  const [editingClient, setEditingClient] = useState<Client | null>(null);
  const [editingItem, setEditingItem] = useState<StoredItem | null>(null);

  // Currency Formatter
  const sym = businessProfile.currency_symbol || '₹';
  const formatMoney = (cents: number) => {
    return `${sym}${(cents / 100).toFixed(2)}`;
  };
  const formatDecimal = (cents: number) => (cents / 100).toFixed(2);
  const quote = (text: string) => `"${(text || '').replace(/"/g, '""')}"`;

  // --- Financial Ledger Calculations (Single Source of Truth) ---
  const getInvoicePaidCents = (invoiceId: string) => {
    return payments
      .filter((p) => p.invoice_id === invoiceId)
      .reduce((sum, p) => sum + p.amount_cents, 0);
  };

  const getInvoiceBalanceDueCents = (inv: InvoiceRecord) => {
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

  // Cash-flow top bar numbers
  const totalInvoicedCents = invoices.filter(i => i.status !== 'VOID').reduce((sum, i) => sum + i.total_cents, 0);
  const totalCollectedCents = payments.reduce((sum, p) => sum + p.amount_cents, 0);
  const totalExpensesCents = expenses.reduce((sum, e) => sum + e.total_cents, 0);
  const netProfitCents = totalCollectedCents - totalExpensesCents;

  // Next Invoice & Estimate Numbers (strictly parsed: MAX + 1)
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

  // --- CSV Export (UTF-8 BOM + Accountant Grade) ---
  const handleExportCsv = () => {
    const lines: string[] = [];
    lines.push('\uFEFF'); // UTF-8 BOM to prevent Excel mojibake

    // Section 1: Invoices
    lines.push('=== SECTION 1: INVOICES ===');
    lines.push('Invoice Number,Issue Date,Due Date,Currency,Client Name,Client Tax ID,Subtotal,Tax,Total,Amount Paid,Balance Due,Status');
    for (const inv of invoices) {
      const client = clients.find(c => c.id === inv.client_id);
      const paid = getInvoicePaidCents(inv.id);
      const bal = Math.max(0, inv.total_cents - paid);
      const status = getComputedInvoiceStatus(inv);

      lines.push([
        inv.invoice_number,
        inv.issue_date,
        inv.due_date,
        businessProfile.currency_code || 'INR',
        quote(inv.client_name),
        quote(client?.tax_id || ''),
        formatDecimal(inv.subtotal_cents),
        formatDecimal(inv.tax_cents),
        formatDecimal(inv.total_cents),
        formatDecimal(paid),
        formatDecimal(bal),
        status,
      ].join(','));
    }
    lines.push(',,,,,,,,,,,'); // 12-column padding

    // Section 2: Expenses
    lines.push('=== SECTION 2: EXPENSES ===');
    lines.push('Date,Category,Vendor,Currency,Expense Amount,Tax,Total Cost,Notes,,,,');
    for (const exp of expenses) {
      lines.push([
        exp.expense_date,
        quote(exp.category),
        quote(exp.vendor),
        businessProfile.currency_code || 'INR',
        formatDecimal(exp.amount_cents),
        formatDecimal(exp.tax_cents),
        formatDecimal(exp.total_cents),
        quote(exp.notes),
        '', '', '', '',
      ].join(','));
    }
    lines.push(',,,,,,,,,,,');

    // Section 3: Financial Summary
    lines.push('=== SECTION 3: FINANCIAL SUMMARY ===');
    lines.push('Metric,Amount,Currency,,,,,,,,,,');
    lines.push(`Total Invoiced Revenue,${formatDecimal(totalInvoicedCents)},${businessProfile.currency_code || 'INR'},,,,,,,,,`);
    lines.push(`Total Collected Revenue,${formatDecimal(totalCollectedCents)},${businessProfile.currency_code || 'INR'},,,,,,,,,`);
    lines.push(`Total Business Expenses,${formatDecimal(totalExpensesCents)},${businessProfile.currency_code || 'INR'},,,,,,,,,`);
    lines.push(`Net Profit (Collected - Expenses),${formatDecimal(netProfitCents)},${businessProfile.currency_code || 'INR'},,,,,,,,,`);

    const blob = new Blob([lines.join('\n')], { type: 'text/csv;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `financial_report_${new Date().toISOString().split('T')[0]}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  };

  // --- Sales Tab Creation Form State ---
  const [selectedClientId, setSelectedClientId] = useState<string>('client-1');
  const [showClientDetailsToggle, setShowClientDetailsToggle] = useState(false);
  const [newClientName, setNewClientName] = useState('');
  const [newClientEmail, setNewClientEmail] = useState('');
  const [newClientPhone, setNewClientPhone] = useState('');
  const [newClientAddress, setNewClientAddress] = useState('');
  const [newClientTaxId, setNewClientTaxId] = useState('');

  const [issueDate, setIssueDate] = useState(() => new Date().toISOString().split('T')[0]);
  const [paymentTerms, setPaymentTerms] = useState('Due on Receipt');
  const [itemDescription, setItemDescription] = useState('');
  const [itemPrice, setItemPrice] = useState('');
  const [itemQty, setItemQty] = useState('1');
  const [saveAsPreset, setSaveAsPreset] = useState(false);
  const [discountType, setDiscountType] = useState<'none' | 'percent' | 'flat'>('none');
  const [discountValue, setDiscountValue] = useState('0');
  const [taxPct, setTaxPct] = useState('10');
  const [invoiceTerms, setInvoiceTerms] = useState(businessProfile.default_terms);
  const [invoiceNotes, setInvoiceNotes] = useState(businessProfile.default_notes);
  const [cartItems, setCartItems] = useState<{ id: string; description: string; unitPriceCents: number; quantity: number; totalCents: number }[]>([]);

  // Computed due date
  const computedDueDate = useMemo(() => {
    return calculateDueDate(issueDate, paymentTerms);
  }, [issueDate, paymentTerms]);

  // Cart calculations
  const cartSubtotal = cartItems.reduce((sum, item) => sum + item.totalCents, 0);
  const parsedDiscountVal = discountType === 'percent' ? parseInt(discountValue, 10) || 0 : parsePriceToCents(discountValue);
  const cartDiscountCents = discountType === 'percent'
    ? Math.floor((cartSubtotal * Math.min(100, Math.max(0, parsedDiscountVal))) / 100)
    : Math.min(cartSubtotal, parsedDiscountVal);
  const cartNetSubtotal = Math.max(0, cartSubtotal - cartDiscountCents);
  const parsedTaxPct = parseInt(taxPct, 10) || 0;
  const cartTaxCents = Math.floor((cartNetSubtotal * parsedTaxPct) / 100);
  const cartTotalCents = cartNetSubtotal + cartTaxCents;

  const handleAddCartItem = (e: React.FormEvent) => {
    e.preventDefault();
    if (!itemDescription.trim()) return;
    const priceCents = parsePriceToCents(itemPrice);
    const qty = parseInt(itemQty, 10) || 1;
    if (priceCents <= 0 || qty <= 0) return;

    if (saveAsPreset) {
      const newItem: StoredItem = {
        id: `si-${Date.now()}`,
        title: itemDescription.trim(),
        default_price_cents: priceCents,
        description: '',
        created_at: new Date().toISOString(),
      };
      setSavedItems(prev => [...prev, newItem]);
    }

    setCartItems(prev => [
      ...prev,
      {
        id: `draft-${Date.now()}-${Math.random()}`,
        description: itemDescription.trim(),
        unitPriceCents: priceCents,
        quantity: qty,
        totalCents: priceCents * qty,
      },
    ]);

    setItemDescription('');
    setItemPrice('');
    setItemQty('1');
    setSaveAsPreset(false);
  };

  const handleCreateClientQuick = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newClientName.trim()) return;
    const newC: Client = {
      id: `client-${Date.now()}`,
      name: newClientName.trim(),
      email: newClientEmail.trim(),
      phone: newClientPhone.trim(),
      address: newClientAddress.trim(),
      tax_id: newClientTaxId.trim(),
      created_at: new Date().toISOString(),
    };
    setClients(prev => [...prev, newC]);
    setSelectedClientId(newC.id);
    setNewClientName('');
    setNewClientEmail('');
    setNewClientPhone('');
    setNewClientAddress('');
    setNewClientTaxId('');
    setShowClientDetailsToggle(false);
  };

  const handleSaveInvoice = () => {
    if (!selectedClientId) {
      alert('Please select or add a client first.');
      return;
    }
    if (cartItems.length === 0) {
      alert('Please add at least one line item to the invoice.');
      return;
    }

    const client = clients.find(c => c.id === selectedClientId);
    const newInv: InvoiceRecord = {
      id: `inv-${Date.now()}`,
      client_id: selectedClientId,
      client_name: client?.name || 'Selected Client',
      invoice_number: nextInvoiceNumber,
      subtotal_cents: cartSubtotal,
      tax_cents: cartTaxCents,
      total_cents: cartTotalCents,
      status: 'PENDING',
      issue_date: issueDate,
      due_date: computedDueDate,
      payment_terms: paymentTerms,
      terms: invoiceTerms,
      notes: invoiceNotes,
      discount_type: discountType,
      discount_value: parsedDiscountVal,
      discount_cents: cartDiscountCents,
      created_at: new Date().toISOString(),
    };

    const newItems: StoredInvoiceItem[] = cartItems.map(it => ({
      id: `ii-${Date.now()}-${Math.random()}`,
      invoice_id: newInv.id,
      description: it.description,
      quantity: it.quantity,
      unit_price_cents: it.unitPriceCents,
      total_cents: it.totalCents,
      created_at: new Date().toISOString(),
    }));

    setInvoices(prev => [newInv, ...prev]);
    setInvoiceItems(prev => [...prev, ...newItems]);
    setCartItems([]);
  };

  const handleDuplicateInvoice = (inv: InvoiceRecord) => {
    const newInvId = `inv-${Date.now()}`;
    const today = new Date().toISOString().split('T')[0];
    const newDueDate = calculateDueDate(today, inv.payment_terms || 'Due on Receipt');
    const items = invoiceItems.filter(i => i.invoice_id === inv.id);

    const duplicated: InvoiceRecord = {
      ...inv,
      id: newInvId,
      invoice_number: nextInvoiceNumber,
      status: 'PENDING',
      issue_date: today,
      due_date: newDueDate,
      created_at: new Date().toISOString(),
    };

    const dupItems = items.map(it => ({
      ...it,
      id: `ii-${Date.now()}-${Math.random()}`,
      invoice_id: newInvId,
      created_at: new Date().toISOString(),
    }));

    setInvoices(prev => [duplicated, ...prev]);
    setInvoiceItems(prev => [...prev, ...dupItems]);
  };

  const handleVoidInvoice = (invId: string) => {
    if (confirm('Are you sure you want to VOID this invoice? It will be cancelled and removed from active balances.')) {
      setInvoices(prev => prev.map(inv => inv.id === invId ? { ...inv, status: 'VOID' } : inv));
    }
  };

  // --- Expenses Tab State ---
  const [expCategory, setExpCategory] = useState('Software');
  const [expVendor, setExpVendor] = useState('');
  const [expDate, setExpDate] = useState(() => new Date().toISOString().split('T')[0]);
  const [expAmount, setExpAmount] = useState('');
  const [expTax, setExpTax] = useState('0');
  const [expNotes, setExpNotes] = useState('');
  const [expenseSearch, setExpenseSearch] = useState('');

  const handleAddExpense = (e: React.FormEvent) => {
    e.preventDefault();
    if (!expVendor.trim()) {
      alert('Please enter vendor / payee');
      return;
    }
    const amtCents = parsePriceToCents(expAmount);
    const taxCents = parsePriceToCents(expTax);
    if (amtCents <= 0) {
      alert('Please enter a valid amount');
      return;
    }

    const newExp: ExpenseRecord = {
      id: `exp-${Date.now()}`,
      category: expCategory,
      vendor: expVendor.trim(),
      amount_cents: amtCents,
      tax_cents: taxCents,
      total_cents: amtCents + taxCents,
      expense_date: expDate,
      notes: expNotes.trim(),
      created_at: new Date().toISOString(),
    };

    setExpenses(prev => [newExp, ...prev]);
    setExpVendor('');
    setExpAmount('');
    setExpTax('0');
    setExpNotes('');
  };

  const filteredExpenses = useMemo(() => {
    if (!expenseSearch.trim()) return expenses;
    const q = expenseSearch.toLowerCase();
    return expenses.filter(e => e.vendor.toLowerCase().includes(q) || e.category.toLowerCase().includes(q) || e.notes.toLowerCase().includes(q));
  }, [expenses, expenseSearch]);

  // --- Client Deletion Check ---
  const handleDeleteClient = (client: Client) => {
    const hasInvoices = invoices.some(i => i.client_id === client.id);
    if (hasInvoices) {
      alert(`Cannot delete client "${client.name}" because they have existing invoices recorded in the ledger. To preserve financial integrity, clients with billing history cannot be deleted.`);
      return;
    }
    if (confirm(`Are you sure you want to delete client "${client.name}"?`)) {
      setClients(prev => prev.filter(c => c.id !== client.id));
    }
  };

  return (
    <div className="min-h-screen bg-slate-50 text-slate-900 font-sans flex antialiased">
      {/* ========================================================================= */}
      {/* 1. DESKTOP ADAPTIVE SIDEBAR (width >= 900px, 220px wide) */}
      {/* ========================================================================= */}
      <aside className="hidden md:flex flex-col w-[220px] bg-white border-r border-slate-200 select-none">
        <div className="p-5 border-b border-slate-100 flex items-center gap-3">
          <div className="w-9 h-9 rounded-full bg-indigo-100 text-indigo-700 flex items-center justify-center font-bold text-sm shrink-0">
            {businessProfile.business_name ? businessProfile.business_name[0].toUpperCase() : 'M'}
          </div>
          <div className="min-w-0">
            <h1 className="font-bold text-sm text-slate-900 truncate leading-tight">
              {businessProfile.business_name || 'My Freelance Studio'}
            </h1>
            <p className="text-[11px] text-slate-400">Freelance Ledger</p>
          </div>
        </div>

        <nav className="flex-1 p-3 space-y-1">
          {[
            { id: 0, label: 'Dashboard', icon: LayoutDashboard },
            { id: 1, label: 'Sales', icon: ReceiptText },
            { id: 2, label: 'Expenses', icon: Wallet },
            { id: 3, label: 'Directory', icon: Users },
          ].map(item => {
            const Icon = item.icon;
            const isActive = activeTab === item.id;
            return (
              <button
                key={item.id}
                onClick={() => setActiveTab(item.id)}
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

      {/* ========================================================================= */}
      {/* 2. MAIN VIEWPORT SHELL */}
      {/* ========================================================================= */}
      <div className="flex-1 flex flex-col min-w-0 pb-16 md:pb-0">
        {/* Top Header */}
        <header className="h-16 bg-white border-b border-slate-200 px-6 flex items-center justify-between sticky top-0 z-30">
          <div className="flex items-center gap-3">
            <h2 className="font-bold text-lg text-slate-900">Local Billing & Financial Ledger</h2>
          </div>

          <div className="flex items-center gap-3">
            {/* Single Prominent Export Accountant CSV Button */}
            <button
              onClick={handleExportCsv}
              className="flex items-center gap-2 px-3.5 py-2 rounded-xl text-xs font-bold bg-indigo-50 hover:bg-indigo-100 text-indigo-700 border border-indigo-200 transition shadow-sm cursor-pointer"
              title="Download UTF-8 BOM Accountant-Ready CSV"
            >
              <Download className="w-4 h-4 text-indigo-600" />
              <span>Export Financial CSV</span>
            </button>

            {/* Business Profile Dialog Trigger */}
            <button
              onClick={() => setIsProfileModalOpen(true)}
              className="p-2 rounded-xl text-slate-600 hover:bg-slate-100 hover:text-slate-900 transition border border-transparent hover:border-slate-200 cursor-pointer"
              title="Business Profile & Branding Settings"
            >
              <Building2 className="w-5 h-5" />
            </button>

            <span className="w-8 h-8 rounded-lg bg-slate-100 text-slate-700 font-bold text-sm flex items-center justify-center border border-slate-200">
              {sym}
            </span>
          </div>
        </header>

        {/* Content Body */}
        <main className="flex-1 p-6 overflow-y-auto max-w-7xl mx-auto w-full space-y-6">
          {/* ===================================================================== */}
          {/* TAB 0: DASHBOARD */}
          {/* ===================================================================== */}
          {activeTab === 0 && (
            <div className="space-y-6">
              <div className="flex items-center justify-between">
                <h3 className="text-xl font-bold text-slate-900">Financial Overview & Dashboard</h3>
              </div>

              {/* 4 Cash-Flow Metric Tiles (matching image_5c0a4deb.png exactly) */}
              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
                {/* Total Invoiced */}
                <div className="bg-white border border-slate-200 rounded-xl p-5 shadow-sm">
                  <div className="flex items-center gap-2 text-indigo-600 font-semibold text-xs mb-2">
                    <FileText className="w-4 h-4" />
                    <span>Total Invoiced</span>
                  </div>
                  <p className="text-2xl font-bold font-mono text-slate-900 tabular-nums">
                    {formatMoney(totalInvoicedCents)}
                  </p>
                </div>

                {/* Total Collected */}
                <div className="bg-white border border-green-200 rounded-xl p-5 shadow-sm bg-green-50/20">
                  <div className="flex items-center gap-2 text-green-700 font-semibold text-xs mb-2">
                    <CheckCircle className="w-4 h-4" />
                    <span>Total Collected</span>
                  </div>
                  <p className="text-2xl font-bold font-mono text-green-700 tabular-nums">
                    {formatMoney(totalCollectedCents)}
                  </p>
                </div>

                {/* Total Expenses */}
                <div className="bg-white border border-orange-200 rounded-xl p-5 shadow-sm bg-orange-50/20">
                  <div className="flex items-center gap-2 text-orange-700 font-semibold text-xs mb-2">
                    <TrendingDown className="w-4 h-4" />
                    <span>Total Expenses</span>
                  </div>
                  <p className="text-2xl font-bold font-mono text-orange-700 tabular-nums">
                    {formatMoney(totalExpensesCents)}
                  </p>
                </div>

                {/* Net Profit */}
                <div className="bg-white border border-blue-200 rounded-xl p-5 shadow-sm bg-blue-50/20">
                  <div className="flex items-center gap-2 text-blue-700 font-semibold text-xs mb-2">
                    <CreditCard className="w-4 h-4" />
                    <span>Net Profit (Coll. - Exp.)</span>
                  </div>
                  <p className="text-2xl font-bold font-mono text-blue-700 tabular-nums">
                    {formatMoney(netProfitCents)}
                  </p>
                </div>
              </div>

              {/* Recent Invoices & Recent Expenses Cards */}
              <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                {/* Recent Invoices */}
                <div className="bg-white border border-slate-200 rounded-xl p-5 shadow-sm space-y-4">
                  <div className="flex items-center justify-between border-b border-slate-100 pb-3">
                    <h4 className="font-bold text-slate-900 text-sm">Recent Invoices</h4>
                    <button
                      onClick={() => setActiveTab(1)}
                      className="text-xs font-bold text-indigo-600 hover:text-indigo-700 cursor-pointer"
                    >
                      View All
                    </button>
                  </div>

                  {invoices.length === 0 ? (
                    <p className="text-xs text-slate-400 py-8 text-center">No invoices recorded yet.</p>
                  ) : (
                    <div className="divide-y divide-slate-100">
                      {invoices.slice(0, 5).map(inv => {
                        const status = getComputedInvoiceStatus(inv);
                        const paid = getInvoicePaidCents(inv.id);
                        const isFullyPaid = status === 'PAID';

                        return (
                          <div key={inv.id} className="py-3 flex items-center justify-between text-xs">
                            <div>
                              <p className="font-bold text-slate-900">
                                {inv.invoice_number} • {inv.client_name}
                              </p>
                              <p className="text-slate-400 text-[11px] mt-0.5">
                                Due: {inv.due_date} •{' '}
                                <span className={isFullyPaid ? 'text-green-700 font-bold' : status === 'OVERDUE' ? 'text-rose-600 font-bold' : 'text-slate-600'}>
                                  {status}
                                </span>
                              </p>
                            </div>
                            <div className="text-right">
                              <span className={`font-mono font-bold ${isFullyPaid ? 'text-green-700' : 'text-indigo-700'}`}>
                                {formatMoney(inv.total_cents)}
                              </span>
                            </div>
                          </div>
                        );
                      })}
                    </div>
                  )}
                </div>

                {/* Recent Expenses */}
                <div className="bg-white border border-slate-200 rounded-xl p-5 shadow-sm space-y-4">
                  <div className="flex items-center justify-between border-b border-slate-100 pb-3">
                    <h4 className="font-bold text-slate-900 text-sm">Recent Expenses</h4>
                    <button
                      onClick={() => setActiveTab(2)}
                      className="text-xs font-bold text-indigo-600 hover:text-indigo-700 cursor-pointer"
                    >
                      View All
                    </button>
                  </div>

                  {expenses.length === 0 ? (
                    <p className="text-xs text-slate-400 py-12 text-center">No expenses recorded yet.</p>
                  ) : (
                    <div className="divide-y divide-slate-100">
                      {expenses.slice(0, 5).map(exp => (
                        <div key={exp.id} className="py-3 flex items-center justify-between text-xs">
                          <div>
                            <p className="font-bold text-slate-900">{exp.vendor} ({exp.category})</p>
                            <p className="text-slate-400 text-[11px] mt-0.5">
                              {exp.expense_date} {exp.notes ? `• ${exp.notes}` : ''}
                            </p>
                          </div>
                          <span className="font-mono font-bold text-orange-600">
                            {formatMoney(exp.total_cents)}
                          </span>
                        </div>
                      ))}
                    </div>
                  )}
                </div>
              </div>
            </div>
          )}

          {/* ===================================================================== */}
          {/* TAB 1: SALES & PROPOSALS HUB */}
          {/* ===================================================================== */}
          {activeTab === 1 && (
            <div className="space-y-6">
              <div className="flex items-center justify-between">
                <h3 className="text-xl font-bold text-slate-900">Sales & Proposals Hub</h3>

                {/* Segmented Control: Invoices vs Estimates */}
                <div className="bg-slate-100 p-1 rounded-xl flex items-center gap-1 border border-slate-200">
                  <button
                    onClick={() => setSalesSubTab(0)}
                    className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-bold transition cursor-pointer ${
                      salesSubTab === 0 ? 'bg-white text-indigo-700 shadow-sm' : 'text-slate-600 hover:text-slate-900'
                    }`}
                  >
                    <ReceiptText className="w-3.5 h-3.5" />
                    <span>Invoices</span>
                  </button>
                  <button
                    onClick={() => setSalesSubTab(1)}
                    className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-bold transition cursor-pointer ${
                      salesSubTab === 1 ? 'bg-white text-indigo-700 shadow-sm' : 'text-slate-600 hover:text-slate-900'
                    }`}
                  >
                    <FileText className="w-3.5 h-3.5" />
                    <span>Estimates</span>
                  </button>
                </div>
              </div>

              {/* 1. Client Selection & Billing Details */}
              <div className="bg-white border border-slate-200 rounded-xl p-5 shadow-sm space-y-4">
                <div className="flex items-center justify-between">
                  <h4 className="font-bold text-sm text-slate-900">1. Client Selection & Billing Details</h4>
                  <button
                    type="button"
                    onClick={() => setShowClientDetailsToggle(!showClientDetailsToggle)}
                    className="text-xs font-bold text-indigo-600 hover:text-indigo-700 flex items-center gap-1 cursor-pointer"
                  >
                    <Plus className="w-3.5 h-3.5" />
                    <span>{showClientDetailsToggle ? 'Cancel New Client' : '+ Client Details (Tax ID, Address)'}</span>
                  </button>
                </div>

                {showClientDetailsToggle ? (
                  <form onSubmit={handleCreateClientQuick} className="bg-slate-50 border border-slate-200 rounded-xl p-4 space-y-3">
                    <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                      <div>
                        <label className="block text-[11px] font-bold text-slate-600 mb-1">Client Name *</label>
                        <input
                          type="text"
                          required
                          value={newClientName}
                          onChange={e => setNewClientName(e.target.value)}
                          placeholder="e.g. Acme Corporation"
                          className="w-full bg-white border border-slate-300 rounded-lg px-3 py-1.5 text-xs text-slate-900 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                        />
                      </div>
                      <div>
                        <label className="block text-[11px] font-bold text-slate-600 mb-1">Billing Email</label>
                        <input
                          type="email"
                          value={newClientEmail}
                          onChange={e => setNewClientEmail(e.target.value)}
                          placeholder="accounts@acme.com"
                          className="w-full bg-white border border-slate-300 rounded-lg px-3 py-1.5 text-xs text-slate-900 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                        />
                      </div>
                    </div>
                    <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                      <div>
                        <label className="block text-[11px] font-bold text-slate-600 mb-1">Phone</label>
                        <input
                          type="text"
                          value={newClientPhone}
                          onChange={e => setNewClientPhone(e.target.value)}
                          placeholder="+1 555-0199"
                          className="w-full bg-white border border-slate-300 rounded-lg px-3 py-1.5 text-xs text-slate-900 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                        />
                      </div>
                      <div>
                        <label className="block text-[11px] font-bold text-slate-600 mb-1">Address</label>
                        <input
                          type="text"
                          value={newClientAddress}
                          onChange={e => setNewClientAddress(e.target.value)}
                          placeholder="100 Tech Plaza"
                          className="w-full bg-white border border-slate-300 rounded-lg px-3 py-1.5 text-xs text-slate-900 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                        />
                      </div>
                      <div>
                        <label className="block text-[11px] font-bold text-slate-600 mb-1">Tax ID / GSTIN</label>
                        <input
                          type="text"
                          value={newClientTaxId}
                          onChange={e => setNewClientTaxId(e.target.value)}
                          placeholder="GSTIN29ABCDE1234F1Z5"
                          className="w-full bg-white border border-slate-300 rounded-lg px-3 py-1.5 text-xs text-slate-900 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                        />
                      </div>
                    </div>
                    <div className="flex justify-end pt-1">
                      <button
                        type="submit"
                        className="px-3.5 py-1.5 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg text-xs font-bold shadow-sm transition cursor-pointer"
                      >
                        Save Client
                      </button>
                    </div>
                  </form>
                ) : (
                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                    <div>
                      <label className="block text-xs font-semibold text-slate-600 mb-1">Select Saved Client</label>
                      <select
                        value={selectedClientId}
                        onChange={e => setSelectedClientId(e.target.value)}
                        className="w-full bg-white border border-slate-300 rounded-xl px-3 py-2 text-xs text-slate-900 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                      >
                        <option value="">Choose a client</option>
                        {clients.map(c => (
                          <option key={c.id} value={c.id}>
                            {c.name} {c.tax_id ? `(${c.tax_id})` : ''}
                          </option>
                        ))}
                      </select>
                    </div>
                  </div>
                )}
              </div>

              {/* 2. Invoice Line Items & Payment Terms (matches image_3e3a85a3.png & image_7121113d.png) */}
              <div className="bg-white border border-slate-200 rounded-xl p-5 shadow-sm space-y-5">
                <div className="flex items-center justify-between border-b border-slate-100 pb-3">
                  <h4 className="font-bold text-sm text-slate-900">2. Invoice Line Items & Payment Terms</h4>
                  <span className="font-mono text-xs font-bold text-indigo-700 bg-indigo-50 px-2.5 py-1 rounded-md border border-indigo-200">
                    Next: {nextInvoiceNumber}
                  </span>
                </div>

                {/* Dates & Payment Terms */}
                <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                  <div>
                    <label className="block text-[11px] font-bold text-slate-600 mb-1">Issue Date (YYYY-MM-DD)</label>
                    <input
                      type="date"
                      value={issueDate}
                      onChange={e => setIssueDate(e.target.value)}
                      className="w-full bg-white border border-slate-300 rounded-xl px-3 py-2 text-xs text-slate-900 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                    />
                  </div>
                  <div>
                    <label className="block text-[11px] font-bold text-slate-600 mb-1">Payment Terms</label>
                    <select
                      value={paymentTerms}
                      onChange={e => setPaymentTerms(e.target.value)}
                      className="w-full bg-white border border-slate-300 rounded-xl px-3 py-2 text-xs text-slate-900 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                    >
                      <option value="Due on Receipt">Due on Receipt</option>
                      <option value="Net 15 Days">Net 15 Days</option>
                      <option value="Net 30 Days">Net 30 Days</option>
                      <option value="Net 60 Days">Net 60 Days</option>
                    </select>
                  </div>
                  <div>
                    <label className="block text-[11px] font-bold text-slate-600 mb-1">Computed Due Date</label>
                    <div className="w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-xs font-bold text-indigo-700">
                      {computedDueDate}
                    </div>
                  </div>
                </div>

                {/* Saved Service Library dropdown */}
                <div>
                  <label className="block text-[11px] font-bold text-slate-600 mb-1">Saved Service Library</label>
                  <select
                    onChange={e => {
                      const item = savedItems.find(s => s.id === e.target.value);
                      if (item) {
                        setItemDescription(item.title);
                        setItemPrice((item.default_price_cents / 100).toFixed(2));
                      }
                    }}
                    defaultValue=""
                    className="w-full bg-white border border-slate-300 rounded-xl px-3 py-2 text-xs text-slate-900 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                  >
                    <option value="" disabled>Select a preset service to 1-click auto-fill...</option>
                    {savedItems.map(item => (
                      <option key={item.id} value={item.id}>
                        {item.title} — {formatMoney(item.default_price_cents)}
                      </option>
                    ))}
                  </select>
                </div>

                {/* Add Item inputs form */}
                <form onSubmit={handleAddCartItem} className="space-y-3">
                  <div className="grid grid-cols-1 sm:grid-cols-12 gap-3">
                    <div className="sm:col-span-6">
                      <input
                        type="text"
                        placeholder="Item Description"
                        value={itemDescription}
                        onChange={e => setItemDescription(e.target.value)}
                        className="w-full bg-white border border-slate-300 rounded-xl px-3 py-2 text-xs text-slate-900 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                      />
                    </div>
                    <div className="sm:col-span-3">
                      <input
                        type="number"
                        step="0.01"
                        placeholder={`Price (${sym})`}
                        value={itemPrice}
                        onChange={e => setItemPrice(e.target.value)}
                        className="w-full bg-white border border-slate-300 rounded-xl px-3 py-2 text-xs text-slate-900 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                      />
                    </div>
                    <div className="sm:col-span-1">
                      <input
                        type="number"
                        min="1"
                        placeholder="Qty"
                        value={itemQty}
                        onChange={e => setItemQty(e.target.value)}
                        className="w-full bg-white border border-slate-300 rounded-xl px-3 py-2 text-xs text-slate-900 focus:outline-none focus:ring-1 focus:ring-indigo-500 text-center"
                      />
                    </div>
                    <div className="sm:col-span-2">
                      <button
                        type="submit"
                        className="w-full h-full min-h-[36px] bg-indigo-50 hover:bg-indigo-100 text-indigo-700 font-bold rounded-xl text-xs flex items-center justify-center gap-1.5 border border-indigo-200 transition cursor-pointer"
                      >
                        <Plus className="w-4 h-4" />
                        <span>Add Item</span>
                      </button>
                    </div>
                  </div>

                  <label className="flex items-center gap-2 text-xs text-slate-600 cursor-pointer pt-1">
                    <input
                      type="checkbox"
                      checked={saveAsPreset}
                      onChange={e => setSaveAsPreset(e.target.checked)}
                      className="rounded border-slate-300 text-indigo-600 focus:ring-indigo-500"
                    />
                    <span>Save as preset service in library for future 1-click use</span>
                  </label>
                </form>

                {/* Cart Line Items Box */}
                <div className="border border-slate-200 rounded-xl overflow-hidden bg-slate-50/50">
                  {cartItems.length === 0 ? (
                    <div className="py-10 text-center text-xs text-slate-400">
                      No items in this invoice yet. Enter item details above and click "Add Item".
                    </div>
                  ) : (
                    <table className="w-full text-xs text-left divide-y divide-slate-200">
                      <thead className="bg-slate-100/80 font-bold text-slate-600">
                        <tr>
                          <th className="py-2.5 px-3">Description</th>
                          <th className="py-2.5 px-3 text-center">Qty</th>
                          <th className="py-2.5 px-3 text-right">Price</th>
                          <th className="py-2.5 px-3 text-right">Total</th>
                          <th className="py-2.5 px-3 text-center">Action</th>
                        </tr>
                      </thead>
                      <tbody className="divide-y divide-slate-200 bg-white">
                        {cartItems.map((item, idx) => (
                          <tr key={item.id}>
                            <td className="py-2.5 px-3 font-medium text-slate-900">{item.description}</td>
                            <td className="py-2.5 px-3 text-center text-slate-600">{item.quantity}</td>
                            <td className="py-2.5 px-3 text-right text-slate-600">{formatMoney(item.unitPriceCents)}</td>
                            <td className="py-2.5 px-3 text-right font-bold text-slate-900">{formatMoney(item.totalCents)}</td>
                            <td className="py-2.5 px-3 text-center">
                              <button
                                type="button"
                                onClick={() => setCartItems(prev => prev.filter((_, i) => i !== idx))}
                                className="text-rose-500 hover:text-rose-700 cursor-pointer"
                              >
                                <Trash2 className="w-4 h-4" />
                              </button>
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  )}
                </div>

                {/* Terms and Notes Inputs */}
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  <div>
                    <label className="block text-[11px] font-bold text-slate-600 mb-1">Invoice Payment Terms / Legal Notice</label>
                    <input
                      type="text"
                      value={invoiceTerms}
                      onChange={e => setInvoiceTerms(e.target.value)}
                      className="w-full bg-white border border-slate-300 rounded-xl px-3 py-2 text-xs text-slate-900 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                    />
                  </div>
                  <div>
                    <label className="block text-[11px] font-bold text-slate-600 mb-1">Invoice Notes / Warranty</label>
                    <input
                      type="text"
                      value={invoiceNotes}
                      onChange={e => setInvoiceNotes(e.target.value)}
                      className="w-full bg-white border border-slate-300 rounded-xl px-3 py-2 text-xs text-slate-900 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                    />
                  </div>
                </div>

                {/* Discount & Tax Slabs */}
                <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 pt-1">
                  <div>
                    <label className="block text-[11px] font-bold text-slate-600 mb-1">Discount Type</label>
                    <select
                      value={discountType}
                      onChange={e => setDiscountType(e.target.value as any)}
                      className="w-full bg-white border border-slate-300 rounded-xl px-3 py-2 text-xs text-slate-900 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                    >
                      <option value="none">No Discount</option>
                      <option value="percent">Percentage (%)</option>
                      <option value="flat">Flat Amount ({sym})</option>
                    </select>
                  </div>
                  {discountType !== 'none' && (
                    <div>
                      <label className="block text-[11px] font-bold text-slate-600 mb-1">
                        Discount Value {discountType === 'percent' ? '(%)' : `(${sym})`}
                      </label>
                      <input
                        type="number"
                        value={discountValue}
                        onChange={e => setDiscountValue(e.target.value)}
                        className="w-full bg-white border border-slate-300 rounded-xl px-3 py-2 text-xs text-slate-900 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                      />
                    </div>
                  )}
                  <div>
                    <label className="block text-[11px] font-bold text-slate-600 mb-1">Tax Slab %</label>
                    <input
                      type="number"
                      value={taxPct}
                      onChange={e => setTaxPct(e.target.value)}
                      className="w-full bg-white border border-slate-300 rounded-xl px-3 py-2 text-xs text-slate-900 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                    />
                  </div>
                </div>

                {/* Bottom Total & Save Button */}
                <div className="flex flex-col sm:flex-row items-center justify-between border-t border-slate-100 pt-4 gap-4">
                  <div className="flex items-center gap-4 text-xs">
                    <span className="text-slate-500">Subtotal: <strong className="text-slate-900">{formatMoney(cartSubtotal)}</strong></span>
                    {cartDiscountCents > 0 && (
                      <span className="text-amber-600">Discount: <strong>-{formatMoney(cartDiscountCents)}</strong></span>
                    )}
                    <span className="text-slate-500">Tax: <strong className="text-slate-900">{formatMoney(cartTaxCents)}</strong></span>
                    <span className="text-sm font-bold text-indigo-900">Total: {formatMoney(cartTotalCents)}</span>
                  </div>

                  <button
                    onClick={handleSaveInvoice}
                    className="px-5 py-2.5 bg-slate-800 hover:bg-slate-900 text-white rounded-xl text-xs font-bold flex items-center gap-2 transition shadow-sm cursor-pointer"
                  >
                    <Save className="w-4 h-4" />
                    <span>Save Invoice Locally</span>
                  </button>
                </div>
              </div>

              {/* Offline Invoices (matches image_7121113d.png exactly) */}
              <div className="space-y-3">
                <div className="flex items-center justify-between">
                  <h4 className="text-lg font-bold text-slate-900">Offline Invoices ({invoices.length})</h4>
                  {invoices.some(i => getComputedInvoiceStatus(i) === 'OVERDUE') && (
                    <span className="text-xs font-bold text-rose-700 bg-rose-50 border border-rose-200 px-2.5 py-1 rounded-full flex items-center gap-1.5">
                      <AlertTriangle className="w-3.5 h-3.5" />
                      <span>{invoices.filter(i => getComputedInvoiceStatus(i) === 'OVERDUE').length} Overdue</span>
                    </span>
                  )}
                </div>

                <div className="space-y-2.5">
                  {invoices.map(inv => {
                    const status = getComputedInvoiceStatus(inv);
                    const paid = getInvoicePaidCents(inv.id);
                    const balance = Math.max(0, inv.total_cents - paid);
                    const isFullyPaid = status === 'PAID';

                    return (
                      <div
                        key={inv.id}
                        className="bg-white border border-slate-200 rounded-xl p-4 shadow-sm flex flex-col md:flex-row md:items-center justify-between gap-4 hover:border-slate-300 transition"
                      >
                        <div className="flex items-start gap-3">
                          <span className={`px-2.5 py-1 rounded-md text-xs font-bold font-mono ${
                            isFullyPaid ? 'bg-green-100 text-green-800' : status === 'OVERDUE' ? 'bg-rose-100 text-rose-800' : 'bg-indigo-50 text-indigo-700'
                          }`}>
                            {inv.invoice_number}
                          </span>

                          <div>
                            <div className="flex items-center gap-2">
                              <span className="font-bold text-sm text-slate-900">{inv.client_name}</span>
                              {isFullyPaid ? (
                                <span className="bg-green-100 text-green-800 text-[10px] font-bold px-2 py-0.5 rounded border border-green-200">
                                  PAID
                                </span>
                              ) : status === 'PARTIALLY_PAID' ? (
                                <span className="bg-amber-100 text-amber-800 text-[10px] font-bold px-2 py-0.5 rounded border border-amber-200">
                                  PARTIAL ({formatMoney(paid)} / {formatMoney(inv.total_cents)})
                                </span>
                              ) : status === 'OVERDUE' ? (
                                <span className="bg-rose-100 text-rose-800 text-[10px] font-bold px-2 py-0.5 rounded border border-rose-200">
                                  OVERDUE
                                </span>
                              ) : status === 'VOID' ? (
                                <span className="bg-slate-200 text-slate-700 text-[10px] font-bold px-2 py-0.5 rounded">
                                  VOID
                                </span>
                              ) : (
                                <span className="bg-slate-100 text-slate-700 text-[10px] font-semibold px-2 py-0.5 rounded">
                                  Due: {inv.due_date}
                                </span>
                              )}
                            </div>
                            <p className="text-xs text-slate-500 mt-0.5">
                              Terms: {inv.payment_terms} • Issued: {inv.issue_date} • Due: {inv.due_date}
                            </p>
                          </div>
                        </div>

                        {/* Trailing: Total, Balance line & Action Buttons */}
                        <div className="flex items-center gap-3 self-end md:self-center">
                          <div className="text-right mr-2">
                            <p className={`font-mono font-bold text-sm ${isFullyPaid ? 'text-green-700' : 'text-slate-900'}`}>
                              {formatMoney(inv.total_cents)}
                            </p>
                            <p className={`font-mono text-xs font-bold ${balance > 0 ? 'text-rose-600' : 'text-green-700'}`}>
                              {balance > 0 ? `Bal: ${formatMoney(balance)}` : '✓ Settled'}
                            </p>
                          </div>

                          {/* 1-Click Duplicate */}
                          <button
                            onClick={() => handleDuplicateInvoice(inv)}
                            className="px-2.5 py-1.5 bg-slate-50 hover:bg-slate-100 text-slate-700 rounded-lg text-xs font-semibold border border-slate-200 flex items-center gap-1 transition cursor-pointer"
                          >
                            <Copy className="w-3.5 h-3.5 text-slate-500" />
                            <span>Duplicate</span>
                          </button>

                          {/* Pay Button: Strictly hidden when balance is <= 0 */}
                          {balance > 0 && status !== 'VOID' && (
                            <button
                              onClick={() => setRecordPaymentInvoice(inv)}
                              className="px-2.5 py-1.5 bg-slate-50 hover:bg-slate-100 text-slate-700 rounded-lg text-xs font-semibold border border-slate-200 flex items-center gap-1 transition cursor-pointer"
                            >
                              <CreditCard className="w-3.5 h-3.5 text-indigo-600" />
                              <span>Pay</span>
                            </button>
                          )}

                          {/* PDF / Print */}
                          <button
                            onClick={() => setPreviewInvoice(inv)}
                            className="px-3 py-1.5 bg-indigo-50 hover:bg-indigo-100 text-indigo-700 rounded-lg text-xs font-bold border border-indigo-200 flex items-center gap-1 transition cursor-pointer"
                          >
                            <Printer className="w-3.5 h-3.5" />
                            <span>PDF / Print</span>
                          </button>

                          {/* Void Action */}
                          {status !== 'VOID' && balance > 0 && (
                            <button
                              onClick={() => handleVoidInvoice(inv.id)}
                              className="p-1.5 text-slate-400 hover:text-rose-600 rounded-lg hover:bg-rose-50 transition cursor-pointer"
                              title="Void Invoice"
                            >
                              <Ban className="w-4 h-4" />
                            </button>
                          )}
                        </div>
                      </div>
                    );
                  })}
                </div>
              </div>
            </div>
          )}

          {/* ===================================================================== */}
          {/* TAB 2: EXPENSES TAB */}
          {/* ===================================================================== */}
          {activeTab === 2 && (
            <div className="space-y-6">
              {/* Book New Business Expense (matches image_287ee9f7.png) */}
              <div className="bg-white border border-slate-200 rounded-xl p-5 shadow-sm space-y-4">
                <h4 className="font-bold text-sm text-slate-900">Book New Business Expense</h4>
                <form onSubmit={handleAddExpense} className="space-y-3">
                  <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                    <div>
                      <label className="block text-[11px] font-bold text-slate-600 mb-1">Category</label>
                      <select
                        value={expCategory}
                        onChange={e => setExpCategory(e.target.value)}
                        className="w-full bg-white border border-slate-300 rounded-xl px-3 py-2 text-xs text-slate-900 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                      >
                        <option value="Software">Software</option>
                        <option value="Hardware">Hardware</option>
                        <option value="Office">Office</option>
                        <option value="Travel">Travel</option>
                        <option value="Subcontracting">Subcontracting</option>
                        <option value="Marketing">Marketing</option>
                        <option value="Other">Other</option>
                      </select>
                    </div>
                    <div>
                      <label className="block text-[11px] font-bold text-slate-600 mb-1">Vendor / Payee</label>
                      <input
                        type="text"
                        required
                        value={expVendor}
                        onChange={e => setExpVendor(e.target.value)}
                        placeholder="e.g. AWS, Figma, Staples"
                        className="w-full bg-white border border-slate-300 rounded-xl px-3 py-2 text-xs text-slate-900 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                      />
                    </div>
                    <div>
                      <label className="block text-[11px] font-bold text-slate-600 mb-1">Expense Date (YYYY-MM-DD)</label>
                      <input
                        type="date"
                        value={expDate}
                        onChange={e => setExpDate(e.target.value)}
                        className="w-full bg-white border border-slate-300 rounded-xl px-3 py-2 text-xs text-slate-900 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                      />
                    </div>
                  </div>

                  <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                    <div>
                      <label className="block text-[11px] font-bold text-slate-600 mb-1">Amount (excl. tax)</label>
                      <input
                        type="number"
                        step="0.01"
                        required
                        value={expAmount}
                        onChange={e => setExpAmount(e.target.value)}
                        placeholder="0.00"
                        className="w-full bg-white border border-slate-300 rounded-xl px-3 py-2 text-xs text-slate-900 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                      />
                    </div>
                    <div>
                      <label className="block text-[11px] font-bold text-slate-600 mb-1">Tax Amount</label>
                      <input
                        type="number"
                        step="0.01"
                        value={expTax}
                        onChange={e => setExpTax(e.target.value)}
                        placeholder="0"
                        className="w-full bg-white border border-slate-300 rounded-xl px-3 py-2 text-xs text-slate-900 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                      />
                    </div>
                    <div>
                      <label className="block text-[11px] font-bold text-slate-600 mb-1">Notes / Purpose</label>
                      <input
                        type="text"
                        value={expNotes}
                        onChange={e => setExpNotes(e.target.value)}
                        placeholder="Project server hosting..."
                        className="w-full bg-white border border-slate-300 rounded-xl px-3 py-2 text-xs text-slate-900 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                      />
                    </div>
                  </div>

                  <div className="flex justify-end pt-1">
                    <button
                      type="submit"
                      className="px-4 py-2 bg-slate-800 hover:bg-slate-900 text-white rounded-xl text-xs font-bold flex items-center gap-1.5 transition cursor-pointer"
                    >
                      <Plus className="w-4 h-4" />
                      <span>Book Expense</span>
                    </button>
                  </div>
                </form>
              </div>

              {/* Expense Ledger */}
              <div className="space-y-3">
                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
                  <h4 className="text-lg font-bold text-slate-900">Expense Ledger ({filteredExpenses.length})</h4>
                  <div className="relative w-full sm:w-64">
                    <Search className="w-3.5 h-3.5 text-slate-400 absolute left-3 top-2.5" />
                    <input
                      type="text"
                      placeholder="Search vendor or category..."
                      value={expenseSearch}
                      onChange={e => setExpenseSearch(e.target.value)}
                      className="w-full bg-white border border-slate-200 rounded-xl pl-9 pr-3 py-1.5 text-xs text-slate-900 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                    />
                  </div>
                </div>

                {filteredExpenses.length === 0 ? (
                  <div className="bg-white border border-slate-200 rounded-xl p-12 text-center text-xs text-slate-400">
                    No expenses recorded matching criteria.
                  </div>
                ) : (
                  <div className="bg-white border border-slate-200 rounded-xl overflow-hidden shadow-sm">
                    <table className="w-full text-xs text-left divide-y divide-slate-200">
                      <thead className="bg-slate-50 font-bold text-slate-600">
                        <tr>
                          <th className="py-3 px-4">Date</th>
                          <th className="py-3 px-4">Category</th>
                          <th className="py-3 px-4">Vendor</th>
                          <th className="py-3 px-4 text-right">Amount</th>
                          <th className="py-3 px-4 text-right">Tax</th>
                          <th className="py-3 px-4 text-right">Total Cost</th>
                          <th className="py-3 px-4">Notes</th>
                          <th className="py-3 px-4 text-center">Action</th>
                        </tr>
                      </thead>
                      <tbody className="divide-y divide-slate-100 bg-white">
                        {filteredExpenses.map(exp => (
                          <tr key={exp.id} className="hover:bg-slate-50/60">
                            <td className="py-3 px-4 text-slate-600 font-mono">{exp.expense_date}</td>
                            <td className="py-3 px-4">
                              <span className="bg-slate-100 text-slate-700 px-2 py-0.5 rounded font-semibold text-[11px]">
                                {exp.category}
                              </span>
                            </td>
                            <td className="py-3 px-4 font-bold text-slate-900">{exp.vendor}</td>
                            <td className="py-3 px-4 text-right font-mono text-slate-600">{formatMoney(exp.amount_cents)}</td>
                            <td className="py-3 px-4 text-right font-mono text-slate-500">{formatMoney(exp.tax_cents)}</td>
                            <td className="py-3 px-4 text-right font-mono font-bold text-orange-600">{formatMoney(exp.total_cents)}</td>
                            <td className="py-3 px-4 text-slate-500 max-w-xs truncate">{exp.notes || '—'}</td>
                            <td className="py-3 px-4 text-center">
                              <button
                                onClick={() => setExpenses(prev => prev.filter(e => e.id !== exp.id))}
                                className="text-slate-400 hover:text-rose-600 cursor-pointer"
                              >
                                <Trash2 className="w-4 h-4" />
                              </button>
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                )}
              </div>
            </div>
          )}

          {/* ===================================================================== */}
          {/* TAB 3: DIRECTORY & BUSINESS SETTINGS */}
          {/* ===================================================================== */}
          {activeTab === 3 && (
            <div className="space-y-6">
              <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
                <h3 className="text-xl font-bold text-slate-900">Directory & Business Settings</h3>

                {/* Segmented Control: Clients vs Catalog vs Branding & Prefs */}
                <div className="bg-slate-100 p-1 rounded-xl flex items-center gap-1 border border-slate-200">
                  <button
                    onClick={() => setDirSubTab(0)}
                    className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-bold transition cursor-pointer ${
                      dirSubTab === 0 ? 'bg-white text-indigo-700 shadow-sm' : 'text-slate-600 hover:text-slate-900'
                    }`}
                  >
                    <Users className="w-3.5 h-3.5" />
                    <span>Clients</span>
                  </button>
                  <button
                    onClick={() => setDirSubTab(1)}
                    className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-bold transition cursor-pointer ${
                      dirSubTab === 1 ? 'bg-white text-indigo-700 shadow-sm' : 'text-slate-600 hover:text-slate-900'
                    }`}
                  >
                    <FileText className="w-3.5 h-3.5" />
                    <span>Catalog</span>
                  </button>
                  <button
                    onClick={() => setDirSubTab(2)}
                    className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-bold transition cursor-pointer ${
                      dirSubTab === 2 ? 'bg-white text-indigo-700 shadow-sm' : 'text-slate-600 hover:text-slate-900'
                    }`}
                  >
                    <Building2 className="w-3.5 h-3.5" />
                    <span>Branding & Prefs</span>
                  </button>
                </div>
              </div>

              {/* Sub-tab 0: Client Ledger & Statements (matches image_9ee19b67.png) */}
              {dirSubTab === 0 && (
                <div className="space-y-4">
                  <div className="flex items-center justify-between">
                    <h4 className="text-lg font-bold text-slate-900">Client Ledger & Statements ({clients.length})</h4>
                  </div>

                  {clients.length === 0 ? (
                    <div className="bg-white border border-slate-200 rounded-xl p-12 text-center text-xs text-slate-400">
                      No clients registered yet.
                    </div>
                  ) : (
                    <div className="bg-white border border-slate-200 rounded-xl overflow-hidden shadow-sm">
                      <div className="overflow-x-auto">
                        <table className="w-full text-xs text-left divide-y divide-slate-200">
                          <thead className="bg-slate-50 font-bold text-slate-600">
                            <tr>
                              <th className="py-3 px-4">Client Name</th>
                              <th className="py-3 px-4">Contact Info</th>
                              <th className="py-3 px-4">Tax ID / GSTIN</th>
                              <th className="py-3 px-4 text-right">Invoiced Total</th>
                              <th className="py-3 px-4 text-right">Balance Due</th>
                              <th className="py-3 px-4 text-center">Actions</th>
                            </tr>
                          </thead>
                          <tbody className="divide-y divide-slate-100 bg-white">
                            {clients.map(client => {
                              const clientInvs = invoices.filter(i => i.client_id === client.id && i.status !== 'VOID');
                              const billedTotal = clientInvs.reduce((sum, i) => sum + i.total_cents, 0);
                              const clientPayments = payments.filter(p => clientInvs.some(i => i.id === p.invoice_id));
                              const paidTotal = clientPayments.reduce((sum, p) => sum + p.amount_cents, 0);
                              const balanceDue = Math.max(0, billedTotal - paidTotal);

                              return (
                                <tr key={client.id} className="hover:bg-slate-50/60">
                                  <td className="py-3 px-4">
                                    <div className="flex items-center gap-2.5">
                                      <div className="w-7 h-7 rounded-full bg-indigo-100 text-indigo-700 font-bold flex items-center justify-center text-xs">
                                        {client.name ? client.name[0].toUpperCase() : 'C'}
                                      </div>
                                      <span className="font-bold text-slate-900">{client.name}</span>
                                    </div>
                                  </td>
                                  <td className="py-3 px-4 text-slate-600">
                                    {client.email || client.phone ? `${client.email || ''} ${client.phone ? `• ${client.phone}` : ''}` : 'N/A'}
                                  </td>
                                  <td className="py-3 px-4 text-slate-500 font-mono">{client.tax_id || 'N/A'}</td>
                                  <td className="py-3 px-4 text-right font-mono font-bold text-slate-900">
                                    {formatMoney(billedTotal)}
                                  </td>
                                  <td className="py-3 px-4 text-right font-mono font-bold">
                                    <span className={balanceDue > 0 ? 'text-rose-600' : 'text-green-700'}>
                                      {balanceDue > 0 ? formatMoney(balanceDue) : '✓ Settled'}
                                    </span>
                                  </td>
                                  <td className="py-3 px-4 text-center">
                                    <div className="flex items-center justify-center gap-2">
                                      <button
                                        onClick={() => setEditingClient(client)}
                                        className="p-1.5 text-slate-500 hover:text-indigo-600 rounded-lg hover:bg-slate-100 transition cursor-pointer"
                                        title="Edit Client"
                                      >
                                        <Edit2 className="w-3.5 h-3.5" />
                                      </button>
                                      <button
                                        onClick={() => setClientStatementClient(client)}
                                        className="px-2.5 py-1 bg-slate-100 hover:bg-slate-200 text-slate-800 rounded-md font-bold text-[11px] transition cursor-pointer"
                                      >
                                        Statement of Account
                                      </button>
                                      <button
                                        onClick={() => handleDeleteClient(client)}
                                        className="p-1.5 text-slate-400 hover:text-rose-600 rounded-lg hover:bg-slate-100 transition cursor-pointer"
                                        title="Delete Client"
                                      >
                                        <Trash2 className="w-3.5 h-3.5" />
                                      </button>
                                    </div>
                                  </td>
                                </tr>
                              );
                            })}
                          </tbody>
                        </table>
                      </div>
                    </div>
                  )}
                </div>
              )}

              {/* Sub-tab 1: Items & Services Catalog */}
              {dirSubTab === 1 && (
                <div className="space-y-6">
                  {/* Add Preset Item card */}
                  <div className="bg-white border border-slate-200 rounded-xl p-5 shadow-sm space-y-4">
                    <h4 className="font-bold text-sm text-slate-900">Add Preset Item / Service to Catalog</h4>
                    <form
                      onSubmit={e => {
                        e.preventDefault();
                        const form = e.currentTarget as HTMLFormElement;
                        const title = (form.elements.namedItem('catTitle') as HTMLInputElement).value;
                        const price = (form.elements.namedItem('catPrice') as HTMLInputElement).value;
                        const desc = (form.elements.namedItem('catDesc') as HTMLInputElement).value;
                        if (!title.trim()) return;
                        const priceCents = parsePriceToCents(price);

                        setSavedItems(prev => [
                          ...prev,
                          {
                            id: `si-${Date.now()}`,
                            title: title.trim(),
                            default_price_cents: priceCents,
                            description: desc.trim(),
                            created_at: new Date().toISOString(),
                          },
                        ]);
                        form.reset();
                      }}
                      className="space-y-3"
                    >
                      <div className="grid grid-cols-1 sm:grid-cols-12 gap-3">
                        <div className="sm:col-span-4">
                          <input
                            name="catTitle"
                            required
                            type="text"
                            placeholder="Item / Service Title *"
                            className="w-full bg-white border border-slate-300 rounded-xl px-3 py-2 text-xs text-slate-900 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                          />
                        </div>
                        <div className="sm:col-span-3">
                          <input
                            name="catPrice"
                            required
                            type="number"
                            step="0.01"
                            placeholder={`Default Price (${sym}) *`}
                            className="w-full bg-white border border-slate-300 rounded-xl px-3 py-2 text-xs text-slate-900 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                          />
                        </div>
                        <div className="sm:col-span-5">
                          <input
                            name="catDesc"
                            type="text"
                            placeholder="Description / deliverables..."
                            className="w-full bg-white border border-slate-300 rounded-xl px-3 py-2 text-xs text-slate-900 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                          />
                        </div>
                      </div>
                      <div className="flex justify-end">
                        <button
                          type="submit"
                          className="px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded-xl text-xs font-bold flex items-center gap-1.5 transition cursor-pointer"
                        >
                          <Plus className="w-4 h-4" />
                          <span>Add to Catalog</span>
                        </button>
                      </div>
                    </form>
                  </div>

                  {/* Catalog Widescreen Data Table */}
                  <div className="bg-white border border-slate-200 rounded-xl overflow-hidden shadow-sm">
                    <table className="w-full text-xs text-left divide-y divide-slate-200">
                      <thead className="bg-slate-50 font-bold text-slate-600">
                        <tr>
                          <th className="py-3 px-4">Title</th>
                          <th className="py-3 px-4">Description</th>
                          <th className="py-3 px-4 text-right">Default Unit Price</th>
                          <th className="py-3 px-4 text-center">Actions</th>
                        </tr>
                      </thead>
                      <tbody className="divide-y divide-slate-100 bg-white">
                        {savedItems.map(item => (
                          <tr key={item.id} className="hover:bg-slate-50/60">
                            <td className="py-3 px-4 font-bold text-slate-900">{item.title}</td>
                            <td className="py-3 px-4 text-slate-600">{item.description || '—'}</td>
                            <td className="py-3 px-4 text-right font-mono font-bold text-slate-900">
                              {formatMoney(item.default_price_cents)}
                            </td>
                            <td className="py-3 px-4 text-center">
                              <div className="flex items-center justify-center gap-2">
                                <button
                                  onClick={() => setEditingItem(item)}
                                  className="p-1.5 text-slate-500 hover:text-indigo-600 rounded-lg hover:bg-slate-100 transition cursor-pointer"
                                  title="Edit Item"
                                >
                                  <Edit2 className="w-3.5 h-3.5" />
                                </button>
                                <button
                                  onClick={() => setSavedItems(prev => prev.filter(i => i.id !== item.id))}
                                  className="p-1.5 text-slate-400 hover:text-rose-600 rounded-lg hover:bg-slate-100 transition cursor-pointer"
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

              {/* Sub-tab 2: Branding & Prefs */}
              {dirSubTab === 2 && (
                <div className="bg-white border border-slate-200 rounded-xl p-6 shadow-sm space-y-6">
                  <div className="flex items-center justify-between border-b border-slate-100 pb-4">
                    <div>
                      <h4 className="font-bold text-base text-slate-900">{businessProfile.business_name}</h4>
                      <p className="text-xs text-slate-500">{businessProfile.email || 'No email specified'}</p>
                    </div>
                    <button
                      onClick={() => setIsProfileModalOpen(true)}
                      className="px-3.5 py-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded-xl text-xs font-bold flex items-center gap-1.5 transition cursor-pointer"
                    >
                      <Edit2 className="w-3.5 h-3.5" />
                      <span>Edit Profile & Branding</span>
                    </button>
                  </div>

                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 text-xs">
                    <div>
                      <span className="text-slate-400 font-semibold block mb-0.5">Currency Symbol</span>
                      <span className="font-bold text-slate-800 text-sm">{businessProfile.currency_symbol} ({businessProfile.currency_code})</span>
                    </div>
                    <div>
                      <span className="text-slate-400 font-semibold block mb-0.5">Phone</span>
                      <span className="font-bold text-slate-800">{businessProfile.phone || 'Not specified'}</span>
                    </div>
                    <div>
                      <span className="text-slate-400 font-semibold block mb-0.5">Address</span>
                      <span className="font-bold text-slate-800">{businessProfile.address || 'Not specified'}</span>
                    </div>
                    <div>
                      <span className="text-slate-400 font-semibold block mb-0.5">Tax ID / VAT / GSTIN</span>
                      <span className="font-bold text-slate-800">{businessProfile.tax_id || 'Not specified'}</span>
                    </div>
                    <div>
                      <span className="text-slate-400 font-semibold block mb-0.5">Company Logo</span>
                      <span className="font-bold text-slate-800">{businessProfile.logo_base64 ? 'Uploaded' : 'None'}</span>
                    </div>
                    <div>
                      <span className="text-slate-400 font-semibold block mb-0.5">Digital Signature</span>
                      <span className="font-bold text-slate-800">
                        {businessProfile.signature_base64 ? `Configured (${businessProfile.signature_label})` : 'None'}
                      </span>
                    </div>
                  </div>

                  {/* Payment Instructions unescaped */}
                  <div className="bg-slate-50 border border-slate-200 rounded-xl p-4 space-y-1">
                    <span className="text-slate-400 text-[11px] font-bold uppercase tracking-wider block">
                      Payment Instructions & Remittance Details
                    </span>
                    <pre className="text-xs text-slate-800 font-mono whitespace-pre-wrap leading-relaxed">
                      {businessProfile.payment_details.replace(/\\n/g, '\n')}
                    </pre>
                  </div>
                </div>
              )}
            </div>
          )}
        </main>
      </div>

      {/* ========================================================================= */}
      {/* 3. MOBILE ADAPTIVE BOTTOM NAVIGATION (< 900px) */}
      {/* ========================================================================= */}
      <nav className="md:hidden fixed bottom-0 left-0 right-0 bg-white border-t border-slate-200 flex justify-around p-2 z-40 shadow-lg">
        {[
          { id: 0, label: 'Dashboard', icon: LayoutDashboard },
          { id: 1, label: 'Sales', icon: ReceiptText },
          { id: 2, label: 'Expenses', icon: Wallet },
          { id: 3, label: 'Directory', icon: Users },
        ].map(item => {
          const Icon = item.icon;
          const isActive = activeTab === item.id;
          return (
            <button
              key={item.id}
              onClick={() => setActiveTab(item.id)}
              className={`flex flex-col items-center gap-1 p-2 rounded-xl text-[11px] font-bold cursor-pointer transition ${
                isActive ? 'text-indigo-600' : 'text-slate-400 hover:text-slate-600'
              }`}
            >
              <Icon className="w-5 h-5" />
              <span>{item.label}</span>
            </button>
          );
        })}
      </nav>

      {/* ========================================================================= */}
      {/* 4. BUSINESS PROFILE & BRANDING MODAL (Native File Pickers & Unescaped Newlines) */}
      {/* ========================================================================= */}
      {isProfileModalOpen && (
        <div className="fixed inset-0 bg-slate-900/60 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-xl w-full p-6 shadow-2xl space-y-4 max-h-[90vh] overflow-y-auto">
            <div className="flex items-center justify-between border-b border-slate-100 pb-3">
              <h3 className="font-bold text-base text-slate-900 flex items-center gap-2">
                <Building2 className="w-5 h-5 text-indigo-600" />
                <span>Business Profile & Branding Settings</span>
              </h3>
              <button
                onClick={() => setIsProfileModalOpen(false)}
                className="text-slate-400 hover:text-slate-600 cursor-pointer"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <form
              onSubmit={e => {
                e.preventDefault();
                setIsProfileModalOpen(false);
              }}
              className="space-y-4 text-xs"
            >
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label className="block text-[11px] font-bold text-slate-600 mb-1">Business / Studio Name *</label>
                  <input
                    type="text"
                    required
                    value={businessProfile.business_name}
                    onChange={e => setBusinessProfile({ ...businessProfile, business_name: e.target.value })}
                    className="w-full bg-white border border-slate-300 rounded-xl px-3 py-2 text-xs text-slate-900 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                  />
                </div>
                <div>
                  <label className="block text-[11px] font-bold text-slate-600 mb-1">Currency Symbol</label>
                  <select
                    value={businessProfile.currency_symbol}
                    onChange={e => {
                      const symVal = e.target.value;
                      const code = symVal === '₹' ? 'INR' : symVal === '€' ? 'EUR' : symVal === '£' ? 'GBP' : 'USD';
                      setBusinessProfile({ ...businessProfile, currency_symbol: symVal, currency_code: code });
                    }}
                    className="w-full bg-white border border-slate-300 rounded-xl px-3 py-2 text-xs text-slate-900 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                  >
                    <option value="$">$ (USD)</option>
                    <option value="₹">₹ (INR)</option>
                    <option value="€">€ (EUR)</option>
                    <option value="£">£ (GBP)</option>
                    <option value="¥">¥ (JPY)</option>
                  </select>
                </div>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label className="block text-[11px] font-bold text-slate-600 mb-1">Billing Email</label>
                  <input
                    type="email"
                    value={businessProfile.email}
                    onChange={e => setBusinessProfile({ ...businessProfile, email: e.target.value })}
                    className="w-full bg-white border border-slate-300 rounded-xl px-3 py-2 text-xs text-slate-900 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                  />
                </div>
                <div>
                  <label className="block text-[11px] font-bold text-slate-600 mb-1">Phone</label>
                  <input
                    type="text"
                    value={businessProfile.phone}
                    onChange={e => setBusinessProfile({ ...businessProfile, phone: e.target.value })}
                    className="w-full bg-white border border-slate-300 rounded-xl px-3 py-2 text-xs text-slate-900 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                  />
                </div>
              </div>

              <div>
                <label className="block text-[11px] font-bold text-slate-600 mb-1">Business Address</label>
                <input
                  type="text"
                  value={businessProfile.address}
                  onChange={e => setBusinessProfile({ ...businessProfile, address: e.target.value })}
                  className="w-full bg-white border border-slate-300 rounded-xl px-3 py-2 text-xs text-slate-900 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                />
              </div>

              <div>
                <label className="block text-[11px] font-bold text-slate-600 mb-1">Tax ID / VAT / GSTIN / EIN</label>
                <input
                  type="text"
                  value={businessProfile.tax_id}
                  onChange={e => setBusinessProfile({ ...businessProfile, tax_id: e.target.value })}
                  className="w-full bg-white border border-slate-300 rounded-xl px-3 py-2 text-xs text-slate-900 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                />
              </div>

              {/* Native Image Upload for Logo & Signature */}
              <div className="border-t border-slate-100 pt-3 space-y-3">
                <span className="text-[11px] font-bold text-slate-800 uppercase tracking-wider block">
                  Branding: Company Logo & Digital Signature
                </span>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  {/* Logo Upload */}
                  <div className="space-y-1.5">
                    <label className="block text-[11px] font-bold text-slate-600">Company Logo File</label>
                    <label className="flex items-center gap-2 px-3 py-2 rounded-xl border border-slate-300 hover:bg-slate-50 cursor-pointer transition">
                      <Upload className="w-4 h-4 text-indigo-600 shrink-0" />
                      <span className="text-slate-600 truncate">
                        {businessProfile.logo_base64 ? 'Change Logo Image' : 'Upload Logo (.png/.jpg)'}
                      </span>
                      <input
                        type="file"
                        accept="image/*"
                        className="hidden"
                        onChange={e => {
                          const file = e.target.files?.[0];
                          if (file) {
                            const reader = new FileReader();
                            reader.onload = ev => {
                              setBusinessProfile({ ...businessProfile, logo_base64: ev.target?.result as string });
                            };
                            reader.readAsDataURL(file);
                          }
                        }}
                      />
                    </label>
                    {businessProfile.logo_base64 && (
                      <div className="flex items-center gap-2 p-2 bg-slate-50 border border-slate-200 rounded-lg">
                        <img src={businessProfile.logo_base64} alt="Logo" className="h-8 object-contain" />
                        <button
                          type="button"
                          onClick={() => setBusinessProfile({ ...businessProfile, logo_base64: '' })}
                          className="ml-auto text-rose-500 hover:text-rose-700 font-bold"
                        >
                          Remove
                        </button>
                      </div>
                    )}
                  </div>

                  {/* Signature Upload */}
                  <div className="space-y-1.5">
                    <label className="block text-[11px] font-bold text-slate-600">Signature Image</label>
                    <label className="flex items-center gap-2 px-3 py-2 rounded-xl border border-slate-300 hover:bg-slate-50 cursor-pointer transition">
                      <Upload className="w-4 h-4 text-indigo-600 shrink-0" />
                      <span className="text-slate-600 truncate">
                        {businessProfile.signature_base64 ? 'Change Signature' : 'Upload Signature'}
                      </span>
                      <input
                        type="file"
                        accept="image/*"
                        className="hidden"
                        onChange={e => {
                          const file = e.target.files?.[0];
                          if (file) {
                            const reader = new FileReader();
                            reader.onload = ev => {
                              setBusinessProfile({ ...businessProfile, signature_base64: ev.target?.result as string });
                            };
                            reader.readAsDataURL(file);
                          }
                        }}
                      />
                    </label>
                    {businessProfile.signature_base64 && (
                      <div className="flex items-center gap-2 p-2 bg-slate-50 border border-slate-200 rounded-lg">
                        <img src={businessProfile.signature_base64} alt="Signature" className="h-8 object-contain" />
                        <button
                          type="button"
                          onClick={() => setBusinessProfile({ ...businessProfile, signature_base64: '' })}
                          className="ml-auto text-rose-500 hover:text-rose-700 font-bold"
                        >
                          Remove
                        </button>
                      </div>
                    )}
                  </div>
                </div>

                <div>
                  <label className="block text-[11px] font-bold text-slate-600 mb-1">Signature Label</label>
                  <input
                    type="text"
                    value={businessProfile.signature_label}
                    onChange={e => setBusinessProfile({ ...businessProfile, signature_label: e.target.value })}
                    className="w-full bg-white border border-slate-300 rounded-xl px-3 py-2 text-xs text-slate-900 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                  />
                </div>
              </div>

              {/* Payment Instructions: properly handles multiline newlines */}
              <div>
                <label className="block text-[11px] font-bold text-slate-600 mb-1">
                  Payment Instructions & Remittance Details (Multi-line)
                </label>
                <textarea
                  rows={4}
                  value={businessProfile.payment_details.replace(/\\n/g, '\n')}
                  onChange={e => setBusinessProfile({ ...businessProfile, payment_details: e.target.value })}
                  className="w-full bg-white border border-slate-300 rounded-xl p-3 text-xs font-mono text-slate-900 focus:outline-none focus:ring-1 focus:ring-indigo-500 leading-relaxed"
                />
              </div>

              <div className="flex justify-end pt-2">
                <button
                  type="submit"
                  className="px-5 py-2.5 bg-indigo-600 hover:bg-indigo-700 text-white rounded-xl text-xs font-bold shadow-sm transition cursor-pointer"
                >
                  Save Profile & Branding
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ========================================================================= */}
      {/* 5. RECORD PAYMENT MODAL */}
      {/* ========================================================================= */}
      {recordPaymentInvoice && (
        <div className="fixed inset-0 bg-slate-900/60 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-md w-full p-6 shadow-2xl space-y-4">
            <div className="flex items-center justify-between border-b border-slate-100 pb-3">
              <h3 className="font-bold text-base text-slate-900 flex items-center gap-2">
                <CreditCard className="w-5 h-5 text-indigo-600" />
                <span>Record Payment — {recordPaymentInvoice.invoice_number}</span>
              </h3>
              <button
                onClick={() => setRecordPaymentInvoice(null)}
                className="text-slate-400 hover:text-slate-600 cursor-pointer"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <form
              onSubmit={e => {
                e.preventDefault();
                const form = e.currentTarget as HTMLFormElement;
                const amtStr = (form.elements.namedItem('payAmt') as HTMLInputElement).value;
                const method = (form.elements.namedItem('payMethod') as HTMLSelectElement).value;
                const date = (form.elements.namedItem('payDate') as HTMLInputElement).value;
                const notes = (form.elements.namedItem('payNotes') as HTMLInputElement).value;

                const cents = parsePriceToCents(amtStr);
                const currentBal = getInvoiceBalanceDueCents(recordPaymentInvoice);

                if (cents <= 0) {
                  alert('Payment amount must be greater than zero.');
                  return;
                }
                if (cents > currentBal) {
                  alert(`Payment amount cannot exceed balance due of ${formatMoney(currentBal)}`);
                  return;
                }

                const newPay: StoredPayment = {
                  id: `pay-${Date.now()}`,
                  invoice_id: recordPaymentInvoice.id,
                  amount_cents: cents,
                  payment_method: method,
                  payment_date: date,
                  notes: notes.trim(),
                  created_at: new Date().toISOString(),
                };

                setPayments(prev => [...prev, newPay]);
                setRecordPaymentInvoice(null);
              }}
              className="space-y-3 text-xs"
            >
              <div>
                <span className="text-slate-500 block mb-1">
                  Remaining Balance Due: <strong className="text-rose-600">{formatMoney(getInvoiceBalanceDueCents(recordPaymentInvoice))}</strong>
                </span>
                <input
                  name="payAmt"
                  type="number"
                  step="0.01"
                  required
                  defaultValue={(getInvoiceBalanceDueCents(recordPaymentInvoice) / 100).toFixed(2)}
                  className="w-full bg-white border border-slate-300 rounded-xl px-3 py-2 text-xs font-bold font-mono text-slate-900 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                />
              </div>

              <div>
                <label className="block text-[11px] font-bold text-slate-600 mb-1">Payment Method</label>
                <select
                  name="payMethod"
                  defaultValue="Bank Wire"
                  className="w-full bg-white border border-slate-300 rounded-xl px-3 py-2 text-xs text-slate-900 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                >
                  <option value="Bank Wire">Bank Wire</option>
                  <option value="UPI / Instant Pay">UPI / Instant Pay</option>
                  <option value="Credit Card">Credit Card</option>
                  <option value="PayPal">PayPal</option>
                  <option value="Cash / Cheque">Cash / Cheque</option>
                </select>
              </div>

              <div>
                <label className="block text-[11px] font-bold text-slate-600 mb-1">Payment Date</label>
                <input
                  name="payDate"
                  type="date"
                  required
                  defaultValue={new Date().toISOString().split('T')[0]}
                  className="w-full bg-white border border-slate-300 rounded-xl px-3 py-2 text-xs text-slate-900 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                />
              </div>

              <div>
                <label className="block text-[11px] font-bold text-slate-600 mb-1">Transaction Ref / Notes</label>
                <input
                  name="payNotes"
                  type="text"
                  placeholder="e.g. Wire Ref #BW-88219"
                  className="w-full bg-white border border-slate-300 rounded-xl px-3 py-2 text-xs text-slate-900 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                />
              </div>

              <div className="flex justify-end gap-2 pt-2">
                <button
                  type="button"
                  onClick={() => setRecordPaymentInvoice(null)}
                  className="px-4 py-2 text-slate-600 font-bold hover:bg-slate-100 rounded-xl cursor-pointer"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white font-bold rounded-xl shadow-sm transition cursor-pointer"
                >
                  Record Payment
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ========================================================================= */}
      {/* 6. PDF / PRINT PREVIEW MODAL */}
      {/* ========================================================================= */}
      {previewInvoice && (
        <div className="fixed inset-0 bg-slate-900/60 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-2xl w-full p-8 shadow-2xl space-y-6 max-h-[90vh] overflow-y-auto">
            <div className="flex items-center justify-between border-b border-slate-200 pb-4">
              <div>
                {businessProfile.logo_base64 && (
                  <img src={businessProfile.logo_base64} alt="Company Logo" className="h-10 object-contain mb-2" />
                )}
                <h3 className="font-bold text-xl text-slate-900">INVOICE</h3>
                <p className="font-mono font-bold text-indigo-700 text-sm">{previewInvoice.invoice_number}</p>
              </div>
              <div className="text-right">
                <button
                  onClick={() => window.print()}
                  className="px-3.5 py-1.5 bg-indigo-50 hover:bg-indigo-100 text-indigo-700 rounded-lg text-xs font-bold border border-indigo-200 flex items-center gap-1.5 cursor-pointer ml-auto mb-2"
                >
                  <Printer className="w-3.5 h-3.5" />
                  <span>Print A4</span>
                </button>
                <span className={`px-2.5 py-1 rounded text-[11px] font-bold ${
                  getComputedInvoiceStatus(previewInvoice) === 'PAID' ? 'bg-green-100 text-green-800' : 'bg-slate-100 text-slate-800'
                }`}>
                  {getComputedInvoiceStatus(previewInvoice)}
                </span>
                <p className="text-xs text-slate-500 mt-2">Issued: {previewInvoice.issue_date}</p>
                <p className="text-xs font-bold text-slate-800">Due: {previewInvoice.due_date}</p>
              </div>
            </div>

            <div className="grid grid-cols-2 gap-4 text-xs border-b border-slate-100 pb-4">
              <div>
                <p className="font-bold text-slate-400 uppercase text-[10px]">From</p>
                <p className="font-bold text-slate-900 text-sm mt-0.5">{businessProfile.business_name}</p>
                <p className="text-slate-600">{businessProfile.email}</p>
                <p className="text-slate-600">{businessProfile.phone}</p>
                <p className="text-slate-600">{businessProfile.address}</p>
              </div>
              <div>
                <p className="font-bold text-slate-400 uppercase text-[10px]">Billed To</p>
                <p className="font-bold text-slate-900 text-sm mt-0.5">{previewInvoice.client_name}</p>
              </div>
            </div>

            {/* Line Items Table */}
            <table className="w-full text-xs text-left divide-y divide-slate-200">
              <thead>
                <tr className="font-bold text-slate-600">
                  <th className="py-2">Description</th>
                  <th className="py-2 text-center">Qty</th>
                  <th className="py-2 text-right">Price</th>
                  <th className="py-2 text-right">Total</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {invoiceItems.filter(i => i.invoice_id === previewInvoice.id).map(it => (
                  <tr key={it.id}>
                    <td className="py-2.5 text-slate-900 font-medium">{it.description}</td>
                    <td className="py-2.5 text-center text-slate-600">{it.quantity}</td>
                    <td className="py-2.5 text-right font-mono text-slate-600">{formatMoney(it.unit_price_cents)}</td>
                    <td className="py-2.5 text-right font-mono font-bold text-slate-900">{formatMoney(it.total_cents)}</td>
                  </tr>
                ))}
              </tbody>
            </table>

            {/* Financial Summary */}
            <div className="border-t border-slate-200 pt-3 flex justify-end">
              <div className="w-64 space-y-1.5 text-xs text-right">
                <div className="flex justify-between text-slate-600">
                  <span>Subtotal:</span>
                  <span className="font-mono">{formatMoney(previewInvoice.subtotal_cents)}</span>
                </div>
                <div className="flex justify-between text-slate-600">
                  <span>Tax:</span>
                  <span className="font-mono">{formatMoney(previewInvoice.tax_cents)}</span>
                </div>
                <div className="flex justify-between text-slate-900 font-bold border-t border-slate-200 pt-1.5 text-sm">
                  <span>Total:</span>
                  <span className="font-mono">{formatMoney(previewInvoice.total_cents)}</span>
                </div>
                {getInvoicePaidCents(previewInvoice.id) > 0 && (
                  <div className="flex justify-between text-green-700 font-bold">
                    <span>Less Payments:</span>
                    <span className="font-mono">-{formatMoney(getInvoicePaidCents(previewInvoice.id))}</span>
                  </div>
                )}
                <div className="flex justify-between font-bold text-slate-900 bg-slate-50 p-2 rounded-lg">
                  <span>Balance Due:</span>
                  <span className="font-mono text-indigo-700">{formatMoney(getInvoiceBalanceDueCents(previewInvoice))}</span>
                </div>
              </div>
            </div>

            {/* Payment Details & Signature */}
            <div className="border-t border-slate-200 pt-4 flex items-end justify-between text-xs">
              <div className="max-w-xs space-y-1">
                <p className="font-bold text-[10px] text-slate-400 uppercase">Payment Instructions</p>
                <pre className="font-mono text-[11px] text-slate-700 whitespace-pre-wrap">
                  {businessProfile.payment_details.replace(/\\n/g, '\n')}
                </pre>
              </div>

              <div className="text-center w-48">
                {businessProfile.signature_base64 ? (
                  <img src={businessProfile.signature_base64} alt="Signature" className="h-10 mx-auto object-contain mb-1" />
                ) : (
                  <div className="h-10 border-b border-slate-300 mb-1" />
                )}
                <span className="text-[10px] font-bold text-slate-500 uppercase tracking-wider block">
                  {businessProfile.signature_label || 'Authorized Signatory'}
                </span>
              </div>
            </div>

            <div className="flex justify-end pt-2">
              <button
                onClick={() => setPreviewInvoice(null)}
                className="px-4 py-2 bg-slate-800 text-white font-bold rounded-xl text-xs cursor-pointer"
              >
                Close Preview
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ========================================================================= */}
      {/* 7. STATEMENT OF ACCOUNT MODAL */}
      {/* ========================================================================= */}
      {clientStatementClient && (
        <div className="fixed inset-0 bg-slate-900/60 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-xl w-full p-6 shadow-2xl space-y-4 max-h-[90vh] overflow-y-auto text-xs">
            <div className="flex items-center justify-between border-b border-slate-100 pb-3">
              <div>
                <h3 className="font-bold text-base text-slate-900">Statement of Account</h3>
                <p className="text-slate-500 font-semibold">{clientStatementClient.name}</p>
              </div>
              <button
                onClick={() => setClientStatementClient(null)}
                className="text-slate-400 hover:text-slate-600 cursor-pointer"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="space-y-3">
              <table className="w-full text-xs text-left divide-y divide-slate-200">
                <thead className="bg-slate-50 font-bold text-slate-600">
                  <tr>
                    <th className="py-2.5 px-3">Date</th>
                    <th className="py-2.5 px-3">Invoice #</th>
                    <th className="py-2.5 px-3 text-right">Invoiced</th>
                    <th className="py-2.5 px-3 text-right">Paid</th>
                    <th className="py-2.5 px-3 text-right">Balance</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100 bg-white">
                  {invoices.filter(i => i.client_id === clientStatementClient.id && i.status !== 'VOID').map(inv => {
                    const paid = getInvoicePaidCents(inv.id);
                    const bal = Math.max(0, inv.total_cents - paid);
                    return (
                      <tr key={inv.id}>
                        <td className="py-2 px-3 text-slate-600 font-mono">{inv.issue_date}</td>
                        <td className="py-2 px-3 font-bold text-slate-900">{inv.invoice_number}</td>
                        <td className="py-2 px-3 text-right font-mono text-slate-900">{formatMoney(inv.total_cents)}</td>
                        <td className="py-2 px-3 text-right font-mono text-green-700">{formatMoney(paid)}</td>
                        <td className="py-2 px-3 text-right font-mono font-bold text-rose-600">{formatMoney(bal)}</td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>

            <div className="border-t border-slate-200 pt-3 flex justify-between font-bold text-sm">
              <span>Total Outstanding Balance:</span>
              <span className="font-mono text-rose-600">
                {formatMoney(
                  invoices
                    .filter(i => i.client_id === clientStatementClient.id && i.status !== 'VOID')
                    .reduce((sum, inv) => sum + getInvoiceBalanceDueCents(inv), 0)
                )}
              </span>
            </div>

            <div className="flex justify-end pt-2">
              <button
                onClick={() => setClientStatementClient(null)}
                className="px-4 py-2 bg-slate-800 text-white font-bold rounded-xl cursor-pointer"
              >
                Close
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ========================================================================= */}
      {/* 8. EDIT CLIENT MODAL */}
      {/* ========================================================================= */}
      {editingClient && (
        <div className="fixed inset-0 bg-slate-900/60 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-md w-full p-6 shadow-2xl space-y-4 text-xs">
            <div className="flex items-center justify-between border-b border-slate-100 pb-3">
              <h3 className="font-bold text-base text-slate-900 flex items-center gap-2">
                <Edit2 className="w-4 h-4 text-indigo-600" />
                <span>Edit Client Profile</span>
              </h3>
              <button
                onClick={() => setEditingClient(null)}
                className="text-slate-400 hover:text-slate-600 cursor-pointer"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <form
              onSubmit={e => {
                e.preventDefault();
                setClients(prev => prev.map(c => c.id === editingClient.id ? editingClient : c));
                setEditingClient(null);
              }}
              className="space-y-3"
            >
              <div>
                <label className="block text-[11px] font-bold text-slate-600 mb-1">Client Name *</label>
                <input
                  type="text"
                  required
                  value={editingClient.name}
                  onChange={e => setEditingClient({ ...editingClient, name: e.target.value })}
                  className="w-full bg-white border border-slate-300 rounded-xl px-3 py-2 text-xs text-slate-900 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                />
              </div>

              <div>
                <label className="block text-[11px] font-bold text-slate-600 mb-1">Billing Email</label>
                <input
                  type="email"
                  value={editingClient.email}
                  onChange={e => setEditingClient({ ...editingClient, email: e.target.value })}
                  className="w-full bg-white border border-slate-300 rounded-xl px-3 py-2 text-xs text-slate-900 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                />
              </div>

              <div>
                <label className="block text-[11px] font-bold text-slate-600 mb-1">Phone Number</label>
                <input
                  type="text"
                  value={editingClient.phone}
                  onChange={e => setEditingClient({ ...editingClient, phone: e.target.value })}
                  className="w-full bg-white border border-slate-300 rounded-xl px-3 py-2 text-xs text-slate-900 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                />
              </div>

              <div>
                <label className="block text-[11px] font-bold text-slate-600 mb-1">Address</label>
                <input
                  type="text"
                  value={editingClient.address}
                  onChange={e => setEditingClient({ ...editingClient, address: e.target.value })}
                  className="w-full bg-white border border-slate-300 rounded-xl px-3 py-2 text-xs text-slate-900 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                />
              </div>

              <div>
                <label className="block text-[11px] font-bold text-slate-600 mb-1">Tax ID / VAT / GSTIN</label>
                <input
                  type="text"
                  value={editingClient.tax_id}
                  onChange={e => setEditingClient({ ...editingClient, tax_id: e.target.value })}
                  className="w-full bg-white border border-slate-300 rounded-xl px-3 py-2 text-xs text-slate-900 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                />
              </div>

              <div className="flex justify-end gap-2 pt-2">
                <button
                  type="button"
                  onClick={() => setEditingClient(null)}
                  className="px-4 py-2 text-slate-600 font-bold hover:bg-slate-100 rounded-xl cursor-pointer"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white font-bold rounded-xl shadow-sm transition cursor-pointer"
                >
                  Save Changes
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ========================================================================= */}
      {/* 9. EDIT CATALOG ITEM MODAL */}
      {/* ========================================================================= */}
      {editingItem && (
        <div className="fixed inset-0 bg-slate-900/60 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-md w-full p-6 shadow-2xl space-y-4 text-xs">
            <div className="flex items-center justify-between border-b border-slate-100 pb-3">
              <h3 className="font-bold text-base text-slate-900 flex items-center gap-2">
                <Edit2 className="w-4 h-4 text-indigo-600" />
                <span>Edit Catalog Item</span>
              </h3>
              <button
                onClick={() => setEditingItem(null)}
                className="text-slate-400 hover:text-slate-600 cursor-pointer"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <form
              onSubmit={e => {
                e.preventDefault();
                setSavedItems(prev => prev.map(i => i.id === editingItem.id ? editingItem : i));
                setEditingItem(null);
              }}
              className="space-y-3"
            >
              <div>
                <label className="block text-[11px] font-bold text-slate-600 mb-1">Item Title *</label>
                <input
                  type="text"
                  required
                  value={editingItem.title}
                  onChange={e => setEditingItem({ ...editingItem, title: e.target.value })}
                  className="w-full bg-white border border-slate-300 rounded-xl px-3 py-2 text-xs text-slate-900 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                />
              </div>

              <div>
                <label className="block text-[11px] font-bold text-slate-600 mb-1">Default Unit Price ({sym}) *</label>
                <input
                  type="number"
                  step="0.01"
                  required
                  value={(editingItem.default_price_cents / 100).toFixed(2)}
                  onChange={e => setEditingItem({ ...editingItem, default_price_cents: parsePriceToCents(e.target.value) })}
                  className="w-full bg-white border border-slate-300 rounded-xl px-3 py-2 text-xs text-slate-900 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                />
              </div>

              <div>
                <label className="block text-[11px] font-bold text-slate-600 mb-1">Description</label>
                <textarea
                  rows={2}
                  value={editingItem.description}
                  onChange={e => setEditingItem({ ...editingItem, description: e.target.value })}
                  className="w-full bg-white border border-slate-300 rounded-xl p-3 text-xs text-slate-900 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                />
              </div>

              <div className="flex justify-end gap-2 pt-2">
                <button
                  type="button"
                  onClick={() => setEditingItem(null)}
                  className="px-4 py-2 text-slate-600 font-bold hover:bg-slate-100 rounded-xl cursor-pointer"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white font-bold rounded-xl shadow-sm transition cursor-pointer"
                >
                  Save Item
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
