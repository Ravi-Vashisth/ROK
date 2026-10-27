import { useState, useEffect } from 'react';
import {
  Building2,
  FileText,
  Plus,
  Save,
  Database,
  Copy,
  Check,
  Download,
  Monitor,
  HardDrive,
  FolderTree,
  FileCode,
  Trash2,
  ChevronDown,
  ChevronUp,
  Printer,
  X,
  Calendar,
  Clock,
  AlertTriangle,
  CheckCircle,
  CreditCard,
  Receipt,
  FileSpreadsheet,
  ArrowRight,
  Sparkles,
} from 'lucide-react';

import {
  parsePriceToCents,
  formatCents,
  calculateDueDate,
  isInvoiceOverdue,
  calculateDaysOverdue,
} from './billingRules';
import { MODULAR_FILES } from './modularFiles';

interface Client {
  id: string;
  name: string;
  email: string;
  phone: string;
  address: string;
  tax_id: string;
  created_at: string;
}

interface StoredInvoiceItem {
  id: string;
  invoice_id: string;
  description: string;
  quantity: number;
  unit_price_cents: number;
  total_cents: number;
  created_at: string;
}

interface StoredPayment {
  id: string;
  invoice_id: string;
  amount_cents: number;
  payment_method: string;
  payment_date: string;
  notes: string;
  created_at: string;
}

interface InvoiceRecord {
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
  created_at: string;
}

interface StoredEstimateRecord {
  id: string;
  client_id: string;
  client_name: string;
  estimate_number: string;
  subtotal_cents: number;
  tax_cents: number;
  total_cents: number;
  status: string; // 'PENDING', 'ACCEPTED', 'DECLINED', 'CONVERTED'
  issue_date: string;
  expiry_date: string;
  converted_invoice_id?: string;
  created_at: string;
}

interface StoredEstimateItem {
  id: string;
  estimate_id: string;
  description: string;
  quantity: number;
  unit_price_cents: number;
  total_cents: number;
  created_at: string;
}

interface DraftLineItem {
  description: string;
  unitPriceCents: number;
  quantity: number;
  totalCents: number;
}

interface BusinessProfile {
  id: string;
  business_name: string;
  email: string;
  phone: string;
  address: string;
  tax_id: string;
  payment_details: string;
  currency_symbol: string;
}

const DEFAULT_BUSINESS_PROFILE: BusinessProfile = {
  id: 'default',
  business_name: 'My Freelance Studio',
  email: 'billing@studio.com',
  phone: '+1 (555) 019-2834',
  address: '100 Tech Plaza, Suite 400, San Francisco, CA 94107',
  tax_id: 'US-EIN-987654321',
  payment_details:
    'Bank: Silicon Valley Bank\nAccount: 987654321098\nRouting / SWIFT: SVB12345\nPayPal / UPI: pay@studio.com',
  currency_symbol: '\$',
};

export default function App() {
  const [topNavTab, setTopNavTab] = useState<'app' | 'flutter_code' | 'schema'>('app');
  const [selectedFile, setSelectedFile] = useState<string>('lib/main.dart');

  // Business Profile state
  const [businessProfile, setBusinessProfile] = useState<BusinessProfile>(() => {
    try {
      const saved = localStorage.getItem('sqlite_business_profile');
      if (saved) return JSON.parse(saved);
    } catch (_) {}
    return DEFAULT_BUSINESS_PROFILE;
  });

  const [isProfileModalOpen, setIsProfileModalOpen] = useState(false);
  const [profileForm, setProfileForm] = useState<BusinessProfile>(businessProfile);

  useEffect(() => {
    try {
      localStorage.setItem('sqlite_business_profile', JSON.stringify(businessProfile));
    } catch (_) {}
  }, [businessProfile]);

  // Clients state
  const [clients, setClients] = useState<Client[]>(() => {
    try {
      const saved = localStorage.getItem('sqlite_clients_sprint2');
      if (saved) return JSON.parse(saved);
    } catch (_) {}
    return [
      {
        id: '1714000000000-101',
        name: 'Acme Corporation',
        email: 'accounts@acme.com',
        phone: '+1 (555) 234-5678',
        address: '500 Corporate Way, New York, NY 10001',
        tax_id: 'US-EIN-123456789',
        created_at: '2026-10-01T10:00:00Z',
      },
      {
        id: '1714000000000-102',
        name: 'Apex Design Studio',
        email: 'billing@apexdesign.io',
        phone: '+1 (555) 876-5432',
        address: '22 Creative Blvd, Austin, TX 78701',
        tax_id: 'VAT-TX-998877',
        created_at: '2026-10-05T14:30:00Z',
      },
    ];
  });

  useEffect(() => {
    try {
      localStorage.setItem('sqlite_clients_sprint2', JSON.stringify(clients));
    } catch (_) {}
  }, [clients]);

  // Invoices state
  const [invoices, setInvoices] = useState<InvoiceRecord[]>(() => {
    try {
      const saved = localStorage.getItem('sqlite_invoices_sprint2');
      if (saved) return JSON.parse(saved);
    } catch (_) {}
    return [
      {
        id: '1714000000000-201',
        client_id: '1714000000000-101',
        client_name: 'Acme Corporation',
        invoice_number: 'INV-0001',
        subtotal_cents: 22500, // $225.00
        tax_cents: 2250, // $22.50
        total_cents: 24750, // $247.50
        status: 'PAID',
        issue_date: '2026-10-01',
        due_date: '2026-10-16',
        payment_terms: 'Net 15 Days',
        created_at: '2026-10-01T12:00:00Z',
      },
      {
        id: '1714000000000-202',
        client_id: '1714000000000-102',
        client_name: 'Apex Design Studio',
        invoice_number: 'INV-0002',
        subtotal_cents: 18000,
        tax_cents: 1800,
        total_cents: 19800,
        status: 'PENDING',
        issue_date: '2026-10-05',
        due_date: '2026-10-19',
        payment_terms: 'Net 14 Days',
        created_at: '2026-10-05T12:00:00Z',
      },
    ];
  });

  useEffect(() => {
    try {
      localStorage.setItem('sqlite_invoices_sprint2', JSON.stringify(invoices));
    } catch (_) {}
  }, [invoices]);

  // Invoice Items state
  const [invoiceItems, setInvoiceItems] = useState<StoredInvoiceItem[]>(() => {
    try {
      const saved = localStorage.getItem('sqlite_invoice_items_sprint2');
      if (saved) return JSON.parse(saved);
    } catch (_) {}
    return [
      {
        id: '1714000000000-301',
        invoice_id: '1714000000000-201',
        description: 'System Architecture Consultation',
        quantity: 2,
        unit_price_cents: 10000,
        total_cents: 20000,
        created_at: '2026-10-01T12:00:00Z',
      },
      {
        id: '1714000000000-302',
        invoice_id: '1714000000000-201',
        description: 'SSL Certificate & Domain Setup',
        quantity: 1,
        unit_price_cents: 2500,
        total_cents: 2500,
        created_at: '2026-10-01T12:00:00Z',
      },
      {
        id: '1714000000000-303',
        invoice_id: '1714000000000-202',
        description: 'Brand Identity & Design System',
        quantity: 1,
        unit_price_cents: 18000,
        total_cents: 18000,
        created_at: '2026-10-05T12:00:00Z',
      },
    ];
  });

  useEffect(() => {
    try {
      localStorage.setItem('sqlite_invoice_items_sprint2', JSON.stringify(invoiceItems));
    } catch (_) {}
  }, [invoiceItems]);

  // Payments state (Sprint 3)
  const [payments, setPayments] = useState<StoredPayment[]>(() => {
    try {
      const saved = localStorage.getItem('sqlite_payments_sprint3');
      if (saved) return JSON.parse(saved);
    } catch (_) {}
    return [
      {
        id: '1714000000000-401',
        invoice_id: '1714000000000-201',
        amount_cents: 24750,
        payment_method: 'Bank Wire',
        payment_date: '2026-10-02',
        notes: 'Wire Ref #BW-88219',
        created_at: '2026-10-02T12:00:00Z',
      },
    ];
  });

  useEffect(() => {
    try {
      localStorage.setItem('sqlite_payments_sprint3', JSON.stringify(payments));
    } catch (_) {}
  }, [payments]);

  // Estimates State (Sprint 4)
  const [billingSubTab, setBillingSubTab] = useState<'invoices' | 'estimates'>('invoices');

  const [estimates, setEstimates] = useState<StoredEstimateRecord[]>(() => {
    try {
      const saved = localStorage.getItem('sqlite_estimates_sprint4');
      if (saved) return JSON.parse(saved);
    } catch (_) {}
    return [
      {
        id: '1714000000000-501',
        client_id: '1714000000000-101',
        client_name: 'Acme Corporation',
        estimate_number: 'EST-0001',
        subtotal_cents: 20000,
        tax_cents: 2000,
        total_cents: 22000,
        status: 'PENDING',
        issue_date: '2026-10-20',
        expiry_date: '2026-11-20',
        created_at: '2026-10-20T12:00:00Z',
      },
    ];
  });

  useEffect(() => {
    try {
      localStorage.setItem('sqlite_estimates_sprint4', JSON.stringify(estimates));
    } catch (_) {}
  }, [estimates]);

  const [estimateItems, setEstimateItems] = useState<StoredEstimateItem[]>(() => {
    try {
      const saved = localStorage.getItem('sqlite_estimate_items_sprint4');
      if (saved) return JSON.parse(saved);
    } catch (_) {}
    return [
      {
        id: '1714000000000-601',
        estimate_id: '1714000000000-501',
        description: 'Phase 2 Infrastructure Proposal',
        quantity: 1,
        unit_price_cents: 20000,
        total_cents: 20000,
        created_at: '2026-10-20T12:00:00Z',
      },
    ];
  });

  useEffect(() => {
    try {
      localStorage.setItem('sqlite_estimate_items_sprint4', JSON.stringify(estimateItems));
    } catch (_) {}
  }, [estimateItems]);

  // Client Selection State & Expandable details
  const [newClientName, setNewClientName] = useState('');
  const [newClientEmail, setNewClientEmail] = useState('');
  const [newClientPhone, setNewClientPhone] = useState('');
  const [newClientAddress, setNewClientAddress] = useState('');
  const [newClientTaxId, setNewClientTaxId] = useState('');
  const [showAdvancedClientDetails, setShowAdvancedClientDetails] = useState(false);
  const [selectedClientId, setSelectedClientId] = useState<string>('1714000000000-101');

  // Payment Terms & Date State
  const getTodayStr = () => {
    const d = new Date();
    const y = d.getFullYear();
    const m = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    return `${y}-${m}-${day}`;
  };

  const [issueDate, setIssueDate] = useState<string>(getTodayStr());
  const [expiryDate, setExpiryDate] = useState<string>(() => {
    const d = new Date();
    d.setDate(d.getDate() + 30);
    const y = d.getFullYear();
    const m = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    return `${y}-${m}-${day}`;
  });
  const [paymentTerms, setPaymentTerms] = useState<string>('Due on Receipt');

  // Cart / Line Items Input State
  const [cartItems, setCartItems] = useState<DraftLineItem[]>([
    { description: 'Cloud Infrastructure Setup', unitPriceCents: 15000, quantity: 1, totalCents: 15000 },
    { description: 'Monthly Maintenance Service', unitPriceCents: 3500, quantity: 2, totalCents: 7000 },
  ]);
  const [itemDescription, setItemDescription] = useState('');
  const [priceInput, setPriceInput] = useState('');
  const [quantityInput, setQuantityInput] = useState('1');
  const [taxPctInput, setTaxPctInput] = useState('10');

  // Expanded Invoices & Record Payment Modal State
  const [expandedInvoiceIds, setExpandedInvoiceIds] = useState<Set<string>>(new Set(['1714000000000-202']));
  const [isRecordPaymentOpen, setIsRecordPaymentOpen] = useState(false);
  const [paymentTargetInvoice, setPaymentTargetInvoice] = useState<InvoiceRecord | null>(null);
  const [paymentAmountInput, setPaymentAmountInput] = useState('');
  const [paymentMethod, setPaymentMethod] = useState('Bank Wire');
  const [paymentDateInput, setPaymentDateInput] = useState(getTodayStr());
  const [paymentNotesInput, setPaymentNotesInput] = useState('');
  const [paymentError, setPaymentError] = useState<string | null>(null);

  // PDF Preview Modals
  const [previewInvoice, setPreviewInvoice] = useState<{ invoice: InvoiceRecord; items: StoredInvoiceItem[] } | null>(null);
  const [previewEstimate, setPreviewEstimate] = useState<{ estimate: StoredEstimateRecord; items: StoredEstimateItem[] } | null>(null);
  const [isCsvModalOpen, setIsCsvModalOpen] = useState(false);

  // Feedback states
  const [copiedKey, setCopiedKey] = useState<string | null>(null);
  const [toastMessage, setToastMessage] = useState<string | null>(null);

  const formatMoney = (cents: number) => {
    const sym = businessProfile.currency_symbol || '\$';
    return `${sym}${(cents / 100).toFixed(2)}`;
  };

  const showToast = (msg: string) => {
    setToastMessage(msg);
    setTimeout(() => setToastMessage(null), 3500);
  };

  const handleCopyCode = (code: string, key: string) => {
    navigator.clipboard.writeText(code);
    setCopiedKey(key);
    setTimeout(() => setCopiedKey(null), 2000);
  };

  const getNextInvoiceNumber = () => {
    return `INV-${String(invoices.length + 1).padStart(4, '0')}`;
  };

  const getNextEstimateNumber = () => {
    return `EST-${String(estimates.length + 1).padStart(4, '0')}`;
  };

  const getInvoicePaidCents = (invId: string) => {
    return payments
      .filter((p) => p.invoice_id === invId)
      .reduce((sum, p) => sum + p.amount_cents, 0);
  };

  const getInvoiceBalanceDueCents = (inv: InvoiceRecord) => {
    const paid = getInvoicePaidCents(inv.id);
    return Math.max(0, inv.total_cents - paid);
  };

  const getInvoicePayments = (invId: string) => {
    return payments
      .filter((p) => p.invoice_id === invId)
      .sort((a, b) => b.payment_date.localeCompare(a.payment_date));
  };

  const handleAddClient = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newClientName.trim()) return;

    const newId = `${Date.now()}-${Math.floor(Math.random() * 900000 + 100000)}`;
    const newClient: Client = {
      id: newId,
      name: newClientName.trim(),
      email: newClientEmail.trim(),
      phone: newClientPhone.trim(),
      address: newClientAddress.trim(),
      tax_id: newClientTaxId.trim(),
      created_at: new Date().toISOString(),
    };

    setClients((prev) => [newClient, ...prev]);
    setSelectedClientId(newId);
    setNewClientName('');
    setNewClientEmail('');
    setNewClientPhone('');
    setNewClientAddress('');
    setNewClientTaxId('');
    setShowAdvancedClientDetails(false);
    showToast(`Client "${newClient.name}" created!`);
  };

  const handleAddCartItem = (e: React.FormEvent) => {
    e.preventDefault();
    if (!itemDescription.trim()) return;

    const unitPriceCents = parsePriceToCents(priceInput);
    const qty = parseInt(quantityInput, 10) || 1;
    if (unitPriceCents <= 0 || qty <= 0) return;

    const newDraft: DraftLineItem = {
      description: itemDescription.trim(),
      unitPriceCents,
      quantity: qty,
      totalCents: unitPriceCents * qty,
    };

    setCartItems((prev) => [...prev, newDraft]);
    setItemDescription('');
    setPriceInput('');
    setQuantityInput('1');
  };

  const handleRemoveCartItem = (index: number) => {
    setCartItems((prev) => prev.filter((_, i) => i !== index));
  };

  const cartSubtotalCents = cartItems.reduce((sum, item) => sum + item.totalCents, 0);
  const cartTaxPct = parseInt(taxPctInput, 10) || 0;
  const cartTaxCents = Math.floor((cartSubtotalCents * cartTaxPct + 50) / 100);
  const cartTotalCents = cartSubtotalCents + cartTaxCents;

  const handleSaveInvoice = (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedClientId) {
      showToast('Please select or add a client first.');
      return;
    }
    if (cartItems.length === 0) {
      showToast('Please add at least one line item to the invoice cart.');
      return;
    }

    const selectedClient = clients.find((c) => c.id === selectedClientId);
    const invoiceId = `${Date.now()}-${Math.floor(Math.random() * 900000 + 100000)}`;
    const invoiceNumber = getNextInvoiceNumber();
    const computedDue = calculateDueDate(issueDate, paymentTerms);
    const createdAt = new Date().toISOString();

    const newInvoice: InvoiceRecord = {
      id: invoiceId,
      client_id: selectedClientId,
      client_name: selectedClient ? selectedClient.name : 'Selected Client',
      invoice_number: invoiceNumber,
      subtotal_cents: cartSubtotalCents,
      tax_cents: cartTaxCents,
      total_cents: cartTotalCents,
      status: 'PENDING',
      issue_date: issueDate,
      due_date: computedDue,
      payment_terms: paymentTerms,
      created_at: createdAt,
    };

    const newItems: StoredInvoiceItem[] = cartItems.map((item, idx) => ({
      id: `${Date.now()}-${idx}-${Math.floor(Math.random() * 900000 + 100000)}`,
      invoice_id: invoiceId,
      description: item.description,
      quantity: item.quantity,
      unit_price_cents: item.unitPriceCents,
      total_cents: item.totalCents,
      created_at: createdAt,
    }));

    setInvoices((prev) => [newInvoice, ...prev]);
    setInvoiceItems((prev) => [...prev, ...newItems]);
    setCartItems([]);
    showToast(`Invoice ${invoiceNumber} created!`);
  };

  const handleSaveEstimate = (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedClientId) {
      showToast('Please select or add a client first.');
      return;
    }
    if (cartItems.length === 0) {
      showToast('Please add at least one line item to the proposal.');
      return;
    }

    const selectedClient = clients.find((c) => c.id === selectedClientId);
    const estId = `${Date.now()}-${Math.floor(Math.random() * 900000 + 100000)}`;
    const estNum = getNextEstimateNumber();
    const createdAt = new Date().toISOString();

    const newEstimate: StoredEstimateRecord = {
      id: estId,
      client_id: selectedClientId,
      client_name: selectedClient ? selectedClient.name : 'Selected Client',
      estimate_number: estNum,
      subtotal_cents: cartSubtotalCents,
      tax_cents: cartTaxCents,
      total_cents: cartTotalCents,
      status: 'PENDING',
      issue_date: issueDate,
      expiry_date: expiryDate,
      created_at: createdAt,
    };

    const newEstItems: StoredEstimateItem[] = cartItems.map((item, idx) => ({
      id: `${Date.now()}-${idx}-${Math.floor(Math.random() * 900000 + 100000)}`,
      estimate_id: estId,
      description: item.description,
      quantity: item.quantity,
      unit_price_cents: item.unitPriceCents,
      total_cents: item.totalCents,
      created_at: createdAt,
    }));

    setEstimates((prev) => [newEstimate, ...prev]);
    setEstimateItems((prev) => [...prev, ...newEstItems]);
    setCartItems([]);
    showToast(`Estimate ${estNum} created successfully!`);
  };

  const handleConvertEstimateToInvoice = (est: StoredEstimateRecord) => {
    const estLineItems = estimateItems.filter((it) => it.estimate_id === est.id);
    const invId = `${Date.now()}-${Math.floor(Math.random() * 900000 + 100000)}`;
    const invNum = getNextInvoiceNumber();
    const createdAt = new Date().toISOString();

    const newInvoice: InvoiceRecord = {
      id: invId,
      client_id: est.client_id,
      client_name: est.client_name,
      invoice_number: invNum,
      subtotal_cents: est.subtotal_cents,
      tax_cents: est.tax_cents,
      total_cents: est.total_cents,
      status: 'PENDING',
      issue_date: getTodayStr(),
      due_date: calculateDueDate(getTodayStr(), 'Net 15 Days'),
      payment_terms: 'Net 15 Days',
      created_at: createdAt,
    };

    const newInvItems: StoredInvoiceItem[] = estLineItems.map((item, idx) => ({
      id: `${Date.now()}-${idx}-${Math.floor(Math.random() * 900000 + 100000)}`,
      invoice_id: invId,
      description: item.description,
      quantity: item.quantity,
      unit_price_cents: item.unit_price_cents,
      total_cents: item.total_cents,
      created_at: createdAt,
    }));

    setInvoices((prev) => [newInvoice, ...prev]);
    setInvoiceItems((prev) => [...prev, ...newInvItems]);

    // Mark estimate as CONVERTED
    setEstimates((prev) =>
      prev.map((e) => (e.id === est.id ? { ...e, status: 'CONVERTED', converted_invoice_id: invId } : e))
    );

    showToast(`Converted Estimate ${est.estimate_number} into Invoice ${invNum}!`);
    setBillingSubTab('invoices');
  };

  const openRecordPaymentModal = (inv: InvoiceRecord) => {
    setPaymentTargetInvoice(inv);
    const bal = getInvoiceBalanceDueCents(inv);
    setPaymentAmountInput((bal / 100).toFixed(2));
    setPaymentMethod('Bank Wire');
    setPaymentDateInput(getTodayStr());
    setPaymentNotesInput('');
    setPaymentError(null);
    setIsRecordPaymentOpen(true);
  };

  const handleSavePayment = (e: React.FormEvent) => {
    e.preventDefault();
    if (!paymentTargetInvoice) return;

    const amountCents = parsePriceToCents(paymentAmountInput);
    if (amountCents <= 0) {
      setPaymentError('Payment amount must be greater than $0.00');
      return;
    }

    const currentBalance = getInvoiceBalanceDueCents(paymentTargetInvoice);
    if (amountCents > currentBalance) {
      setPaymentError(`Amount cannot exceed balance due of ${formatMoney(currentBalance)}`);
      return;
    }

    const newPayment: StoredPayment = {
      id: `${Date.now()}-${Math.floor(Math.random() * 900000 + 100000)}`,
      invoice_id: paymentTargetInvoice.id,
      amount_cents: amountCents,
      payment_method: paymentMethod,
      payment_date: paymentDateInput || getTodayStr(),
      notes: paymentNotesInput.trim(),
      created_at: new Date().toISOString(),
    };

    setPayments((prev) => [...prev, newPayment]);

    const newPaidTotal = getInvoicePaidCents(paymentTargetInvoice.id) + amountCents;
    if (newPaidTotal >= paymentTargetInvoice.total_cents) {
      setInvoices((prev) =>
        prev.map((i) => (i.id === paymentTargetInvoice.id ? { ...i, status: 'PAID' } : i))
      );
    }

    setIsRecordPaymentOpen(false);
    showToast(`Recorded payment of ${formatMoney(amountCents)} for ${paymentTargetInvoice.invoice_number}!`);
  };

  const generateCsvContent = () => {
    const headers = [
      'Invoice Number',
      'Issue Date',
      'Due Date',
      'Client Name',
      'Client Tax ID',
      'Subtotal',
      'Tax',
      'Total',
      'Amount Paid',
      'Balance Due',
      'Status',
    ];

    const clientTaxMap: Record<string, string> = {};
    clients.forEach((c) => (clientTaxMap[c.id] = c.tax_id || ''));

    const rows = [headers];
    invoices.forEach((inv) => {
      const paid = getInvoicePaidCents(inv.id);
      const bal = getInvoiceBalanceDueCents(inv);
      rows.push([
        inv.invoice_number,
        inv.issue_date,
        inv.due_date,
        inv.client_name,
        clientTaxMap[inv.client_id] || '',
        formatMoney(inv.subtotal_cents),
        formatMoney(inv.tax_cents),
        formatMoney(inv.total_cents),
        formatMoney(paid),
        formatMoney(bal),
        inv.status,
      ]);
    });

    return rows
      .map((row) =>
        row
          .map((f) => {
            const escaped = String(f).replace(/"/g, '""');
            if (escaped.includes(',') || escaped.includes('"') || escaped.includes('\n')) {
              return `"${escaped}"`;
            }
            return escaped;
          })
          .join(',')
      )
      .join('\n');
  };

  const handleSaveProfile = (e: React.FormEvent) => {
    e.preventDefault();
    setBusinessProfile(profileForm);
    setIsProfileModalOpen(false);
    showToast('Business profile & currency settings saved!');
  };

  const selectedClientObj = clients.find((c) => c.id === selectedClientId);

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 font-sans flex flex-col antialiased">
      {/* Toast Notification */}
      {toastMessage && (
        <div className="fixed bottom-6 right-6 z-50 bg-emerald-500 text-slate-950 font-bold px-4 py-2.5 rounded-xl shadow-2xl flex items-center gap-2 animate-bounce text-sm">
          <CheckCircle className="w-4 h-4" />
          <span>{toastMessage}</span>
        </div>
      )}

      {/* Main Top Header */}
      <header className="border-b border-slate-800 bg-slate-900/80 backdrop-blur-md sticky top-0 z-40 px-4 py-3 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="bg-indigo-600/20 border border-indigo-500/40 p-2 rounded-xl text-indigo-400">
            <Building2 className="w-5 h-5" />
          </div>
          <div>
            <h1 className="font-bold text-base text-slate-100 flex items-center gap-2">
              <span>{businessProfile.business_name}</span>
              <span className="text-[10px] font-bold uppercase tracking-wider bg-indigo-500/10 text-indigo-400 border border-indigo-500/30 px-2 py-0.5 rounded">
                Sprint 4 Complete
              </span>
            </h1>
            <p className="text-xs text-slate-400">
              Modular Architecture • Multi-Line Items • Partial Payments • Quotes • CSV Export
            </p>
          </div>
        </div>

        {/* View Switching Navigation */}
        <div className="flex items-center bg-slate-950 border border-slate-800 p-1 rounded-xl">
          <button
            type="button"
            onClick={() => setTopNavTab('app')}
            className={`px-3 py-1.5 rounded-lg text-xs font-bold transition flex items-center gap-1.5 cursor-pointer ${
              topNavTab === 'app' ? 'bg-indigo-600 text-white shadow-md' : 'text-slate-400 hover:text-slate-200'
            }`}
          >
            <Monitor className="w-3.5 h-3.5" />
            <span>App Preview</span>
          </button>
          <button
            type="button"
            onClick={() => setTopNavTab('flutter_code')}
            className={`px-3 py-1.5 rounded-lg text-xs font-bold transition flex items-center gap-1.5 cursor-pointer ${
              topNavTab === 'flutter_code' ? 'bg-indigo-600 text-white shadow-md' : 'text-slate-400 hover:text-slate-200'
            }`}
          >
            <FolderTree className="w-3.5 h-3.5" />
            <span>Modular Code (30 files)</span>
          </button>
          <button
            type="button"
            onClick={() => setTopNavTab('schema')}
            className={`px-3 py-1.5 rounded-lg text-xs font-bold transition flex items-center gap-1.5 cursor-pointer ${
              topNavTab === 'schema' ? 'bg-indigo-600 text-white shadow-md' : 'text-slate-400 hover:text-slate-200'
            }`}
          >
            <Database className="w-3.5 h-3.5" />
            <span>SQLite Schema</span>
          </button>
        </div>

        <div className="flex items-center gap-2">
          {/* Export CSV Button */}
          <button
            type="button"
            onClick={() => setIsCsvModalOpen(true)}
            className="px-3 py-1.5 rounded-lg text-xs font-semibold bg-emerald-600/20 hover:bg-emerald-600/30 text-emerald-300 border border-emerald-500/40 transition cursor-pointer flex items-center gap-1.5"
            title="Export Accountant CSV"
          >
            <FileSpreadsheet className="w-3.5 h-3.5 text-emerald-400" />
            <span>Export CSV</span>
          </button>

          {/* Business Profile Settings Dialog Button */}
          <button
            type="button"
            onClick={() => {
              setProfileForm(businessProfile);
              setIsProfileModalOpen(true);
            }}
            className="px-3 py-1.5 rounded-lg text-xs font-semibold bg-slate-800 hover:bg-slate-700 text-slate-200 border border-slate-700 transition cursor-pointer flex items-center gap-1.5"
          >
            <Building2 className="w-3.5 h-3.5 text-indigo-400" />
            <span>Profile & Currency ({businessProfile.currency_symbol})</span>
          </button>
        </div>
      </header>

      {/* Main View Area */}
      {topNavTab === 'app' && (
        <div className="p-6 max-w-7xl mx-auto w-full space-y-6 flex-1">
          {/* Shared Client Selection Card */}
          <div className="border border-slate-800 bg-slate-900/60 rounded-2xl p-5 shadow-xl space-y-4">
            <div className="flex items-center justify-between">
              <h2 className="text-sm font-bold text-slate-200 flex items-center gap-2">
                <Building2 className="w-4 h-4 text-indigo-400" />
                <span>Client Selection & Full Billing Details</span>
              </h2>
              <button
                type="button"
                onClick={() => setShowAdvancedClientDetails(!showAdvancedClientDetails)}
                className="text-xs font-medium text-indigo-400 hover:text-indigo-300 flex items-center gap-1 cursor-pointer"
              >
                <Plus className="w-3.5 h-3.5" />
                <span>{showAdvancedClientDetails ? 'Cancel New Client' : 'Add New Client'}</span>
              </button>
            </div>

            {showAdvancedClientDetails ? (
              <form onSubmit={handleAddClient} className="bg-slate-950 border border-slate-800 rounded-xl p-4 space-y-3">
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  <div>
                    <label className="block text-xs text-slate-400 mb-1">Client Name *</label>
                    <input
                      type="text"
                      required
                      placeholder="e.g. Acme Corporation"
                      value={newClientName}
                      onChange={(e) => setNewClientName(e.target.value)}
                      className="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-1.5 text-xs text-slate-100 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                    />
                  </div>
                  <div>
                    <label className="block text-xs text-slate-400 mb-1">Billing Email</label>
                    <input
                      type="email"
                      placeholder="accounts@client.com"
                      value={newClientEmail}
                      onChange={(e) => setNewClientEmail(e.target.value)}
                      className="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-1.5 text-xs text-slate-100 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                    />
                  </div>
                </div>
                <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                  <div>
                    <label className="block text-xs text-slate-400 mb-1">Phone</label>
                    <input
                      type="text"
                      placeholder="+1 555-0199"
                      value={newClientPhone}
                      onChange={(e) => setNewClientPhone(e.target.value)}
                      className="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-1.5 text-xs text-slate-100 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                    />
                  </div>
                  <div>
                    <label className="block text-xs text-slate-400 mb-1">Address</label>
                    <input
                      type="text"
                      placeholder="100 Plaza, City, State"
                      value={newClientAddress}
                      onChange={(e) => setNewClientAddress(e.target.value)}
                      className="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-1.5 text-xs text-slate-100 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                    />
                  </div>
                  <div>
                    <label className="block text-xs text-slate-400 mb-1">Tax ID / VAT</label>
                    <input
                      type="text"
                      placeholder="VAT-12345"
                      value={newClientTaxId}
                      onChange={(e) => setNewClientTaxId(e.target.value)}
                      className="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-1.5 text-xs text-slate-100 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                    />
                  </div>
                </div>
                <div className="flex justify-end pt-1">
                  <button
                    type="submit"
                    className="px-3 py-1.5 bg-indigo-600 hover:bg-indigo-500 text-white rounded-lg text-xs font-bold transition cursor-pointer"
                  >
                    Save Client to Local SQLite
                  </button>
                </div>
              </form>
            ) : (
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                <div className="sm:col-span-1">
                  <label className="block text-xs font-medium text-slate-400 mb-1">Select Active Client</label>
                  <select
                    value={selectedClientId || ''}
                    onChange={(e) => setSelectedClientId(e.target.value)}
                    className="w-full bg-slate-950 border border-slate-800 rounded-xl px-3 py-2 text-xs text-slate-100 focus:outline-none focus:ring-2 focus:ring-indigo-500"
                  >
                    {clients.map((c) => (
                      <option key={c.id} value={c.id}>
                        {c.name} {c.tax_id ? `(${c.tax_id})` : ''}
                      </option>
                    ))}
                  </select>
                </div>
                {selectedClientObj && (
                  <div className="sm:col-span-2 bg-slate-950 border border-slate-800/80 rounded-xl p-3 flex flex-wrap items-center justify-between text-xs gap-2">
                    <div>
                      <span className="font-bold text-slate-200 block">{selectedClientObj.name}</span>
                      <span className="text-slate-400 block">{selectedClientObj.email || 'No email provided'}</span>
                    </div>
                    <div>
                      <span className="text-slate-400 block">{selectedClientObj.address || 'No address provided'}</span>
                      <span className="text-indigo-400 font-mono block">Tax ID: {selectedClientObj.tax_id || 'N/A'}</span>
                    </div>
                  </div>
                )}
              </div>
            )}
          </div>

          {/* Sub Navigation Bar: Invoices vs Estimates / Quotes (Sprint 4) */}
          <div className="flex border-b border-slate-800">
            <button
              type="button"
              onClick={() => setBillingSubTab('invoices')}
              className={`pb-3 px-4 font-bold text-sm border-b-2 transition flex items-center gap-2 cursor-pointer ${
                billingSubTab === 'invoices'
                  ? 'border-indigo-500 text-indigo-400'
                  : 'border-transparent text-slate-400 hover:text-slate-200'
              }`}
            >
              <FileText className="w-4 h-4" />
              <span>Invoices ({invoices.length})</span>
            </button>
            <button
              type="button"
              onClick={() => setBillingSubTab('estimates')}
              className={`pb-3 px-4 font-bold text-sm border-b-2 transition flex items-center gap-2 cursor-pointer ${
                billingSubTab === 'estimates'
                  ? 'border-indigo-500 text-indigo-400'
                  : 'border-transparent text-slate-400 hover:text-slate-200'
              }`}
            >
              <Receipt className="w-4 h-4" />
              <span>Estimates / Quotes ({estimates.length})</span>
            </button>
          </div>

          {/* Tab 1: INVOICES TAB */}
          {billingSubTab === 'invoices' && (
            <div className="space-y-6">
              {/* Create Invoice Inputs Card */}
              <div className="border border-slate-800 bg-slate-900/60 rounded-2xl p-5 shadow-xl space-y-4">
                <div className="flex items-center justify-between">
                  <h2 className="text-sm font-bold text-slate-200 flex items-center gap-2">
                    <FileText className="w-4 h-4 text-indigo-400" />
                    <span>Create Invoice with Multi-Line Items Cart</span>
                  </h2>
                  <span className="font-mono text-xs font-bold text-indigo-400 bg-indigo-500/10 px-2.5 py-1 rounded border border-indigo-500/30">
                    {getNextInvoiceNumber()}
                  </span>
                </div>

                {/* Line Item Inputs Row */}
                <form onSubmit={handleAddCartItem} className="grid grid-cols-1 sm:grid-cols-12 gap-2 bg-slate-950 p-3 rounded-xl border border-slate-800">
                  <div className="sm:col-span-6">
                    <input
                      type="text"
                      placeholder="Item / Service Description (e.g. Website Consultation)"
                      value={itemDescription}
                      onChange={(e) => setItemDescription(e.target.value)}
                      className="w-full bg-slate-900 border border-slate-800 rounded-lg px-3 py-1.5 text-xs text-slate-100 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                    />
                  </div>
                  <div className="sm:col-span-3">
                    <input
                      type="number"
                      step="0.01"
                      placeholder={`Price (${businessProfile.currency_symbol})`}
                      value={priceInput}
                      onChange={(e) => setPriceInput(e.target.value)}
                      className="w-full bg-slate-900 border border-slate-800 rounded-lg px-3 py-1.5 text-xs text-slate-100 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                    />
                  </div>
                  <div className="sm:col-span-2">
                    <input
                      type="number"
                      min="1"
                      placeholder="Qty"
                      value={quantityInput}
                      onChange={(e) => setQuantityInput(e.target.value)}
                      className="w-full bg-slate-900 border border-slate-800 rounded-lg px-3 py-1.5 text-xs text-slate-100 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                    />
                  </div>
                  <div className="sm:col-span-1 flex items-center justify-end">
                    <button
                      type="submit"
                      className="w-full py-1.5 bg-indigo-600 hover:bg-indigo-500 text-white rounded-lg text-xs font-bold transition flex items-center justify-center cursor-pointer"
                      title="Add to Cart"
                    >
                      <Plus className="w-4 h-4" />
                    </button>
                  </div>
                </form>

                {/* Cart Items List */}
                {cartItems.length > 0 ? (
                  <div className="border border-slate-800 rounded-xl overflow-hidden bg-slate-950/60 divide-y divide-slate-800/60">
                    {cartItems.map((item, index) => (
                      <div key={index} className="p-3 flex items-center justify-between text-xs">
                        <div>
                          <span className="font-semibold text-slate-200">{item.description}</span>
                          <span className="text-slate-400 ml-2">
                            ({item.quantity} × {formatMoney(item.unitPriceCents)})
                          </span>
                        </div>
                        <div className="flex items-center gap-3">
                          <span className="font-mono font-bold text-slate-200">{formatMoney(item.totalCents)}</span>
                          <button
                            type="button"
                            onClick={() => handleRemoveCartItem(index)}
                            className="text-slate-500 hover:text-rose-400 transition cursor-pointer"
                          >
                            <Trash2 className="w-3.5 h-3.5" />
                          </button>
                        </div>
                      </div>
                    ))}
                  </div>
                ) : (
                  <p className="text-xs text-slate-500 italic">No line items added yet. Add items above.</p>
                )}

                {/* Terms, Tax %, Dates */}
                <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 pt-2">
                  <div>
                    <label className="block text-xs text-slate-400 mb-1">Issue Date</label>
                    <input
                      type="date"
                      value={issueDate}
                      onChange={(e) => setIssueDate(e.target.value)}
                      className="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-1.5 text-xs text-slate-100"
                    />
                  </div>
                  <div>
                    <label className="block text-xs text-slate-400 mb-1">Payment Terms</label>
                    <select
                      value={paymentTerms}
                      onChange={(e) => setPaymentTerms(e.target.value)}
                      className="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-1.5 text-xs text-slate-100"
                    >
                      <option value="Due on Receipt">Due on Receipt</option>
                      <option value="Net 15 Days">Net 15 Days</option>
                      <option value="Net 30 Days">Net 30 Days</option>
                      <option value="Net 60 Days">Net 60 Days</option>
                    </select>
                  </div>
                  <div>
                    <label className="block text-xs text-slate-400 mb-1">Tax Rate (%)</label>
                    <input
                      type="number"
                      value={taxPctInput}
                      onChange={(e) => setTaxPctInput(e.target.value)}
                      className="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-1.5 text-xs text-slate-100"
                    />
                  </div>
                </div>

                {/* Financial Summary & Save */}
                <div className="bg-slate-950 border border-slate-800 rounded-xl p-3 flex flex-wrap items-center justify-between gap-3">
                  <div className="flex items-center gap-4 text-xs font-mono">
                    <span className="text-slate-400">Subtotal: <strong className="text-slate-200">{formatMoney(cartSubtotalCents)}</strong></span>
                    <span className="text-slate-400">Tax ({cartTaxPct}%): <strong className="text-slate-200">{formatMoney(cartTaxCents)}</strong></span>
                    <span className="text-emerald-400 font-bold">Total: {formatMoney(cartTotalCents)}</span>
                  </div>
                  <button
                    type="button"
                    onClick={handleSaveInvoice}
                    className="px-4 py-2 bg-emerald-600 hover:bg-emerald-500 text-white rounded-lg text-xs font-bold transition shadow-lg shadow-emerald-600/20 cursor-pointer flex items-center gap-1.5"
                  >
                    <Save className="w-4 h-4" />
                    <span>Save Invoice to Local SQLite</span>
                  </button>
                </div>
              </div>

              {/* Offline Invoices List */}
              <div className="border border-slate-800 bg-slate-900/60 rounded-2xl p-5 shadow-xl space-y-4">
                <h2 className="text-sm font-bold text-slate-200 flex items-center gap-2">
                  <FileText className="w-4 h-4 text-indigo-400" />
                  <span>Saved Invoices ({invoices.length})</span>
                </h2>

                <div className="space-y-3">
                  {invoices.map((inv) => {
                    const isExpanded = expandedInvoiceIds.has(inv.id);
                    const items = invoiceItems.filter((item) => item.invoice_id === inv.id);
                    const invPayments = getInvoicePayments(inv.id);
                    const paidCents = getInvoicePaidCents(inv.id);
                    const balanceDueCents = getInvoiceBalanceDueCents(inv);
                    const isFullyPaid = paidCents >= inv.total_cents || inv.status.toUpperCase() === 'PAID';
                    const isPartial = paidCents > 0 && !isFullyPaid;
                    const isOverdue = !isFullyPaid && isInvoiceOverdue(inv.status, inv.due_date);
                    const daysLate = calculateDaysOverdue(inv.due_date);

                    return (
                      <div
                        key={inv.id}
                        className={`border rounded-xl overflow-hidden transition ${
                          isOverdue
                            ? 'border-rose-900/60 bg-rose-950/20 hover:bg-rose-950/30'
                            : 'border-slate-800 bg-slate-950/60 hover:bg-slate-950/80'
                        }`}
                      >
                        <div
                          onClick={() => {
                            const newSet = new Set(expandedInvoiceIds);
                            if (newSet.has(inv.id)) newSet.delete(inv.id);
                            else newSet.add(inv.id);
                            setExpandedInvoiceIds(newSet);
                          }}
                          className="p-4 flex flex-wrap sm:flex-nowrap items-center justify-between cursor-pointer select-none gap-3"
                        >
                          <div className="flex items-center gap-3">
                            <span className={`font-mono font-bold text-xs px-2.5 py-1 rounded border ${
                              isOverdue
                                ? 'bg-rose-500/20 text-rose-300 border-rose-500/40'
                                : 'bg-indigo-500/10 text-indigo-400 border-indigo-500/30'
                            }`}>
                              {inv.invoice_number}
                            </span>
                            <div>
                              <div className="flex items-center gap-2">
                                <p className="font-semibold text-sm text-slate-200">{inv.client_name}</p>
                                {isFullyPaid ? (
                                  <span className="px-2 py-0.5 rounded text-[10px] font-bold bg-emerald-500/10 text-emerald-400 border border-emerald-500/30">
                                    PAID IN FULL
                                  </span>
                                ) : isPartial ? (
                                  <span className="px-2 py-0.5 rounded text-[10px] font-bold bg-amber-500/10 text-amber-300 border border-amber-500/30">
                                    PARTIAL ({formatMoney(paidCents)} / {formatMoney(inv.total_cents)})
                                  </span>
                                ) : isOverdue ? (
                                  <span className="px-2 py-0.5 rounded text-[10px] font-bold bg-rose-500/20 text-rose-300 border border-rose-500/40 flex items-center gap-1">
                                    <AlertTriangle className="w-3 h-3" />
                                    OVERDUE ({daysLate}d late)
                                  </span>
                                ) : (
                                  <span className="px-2 py-0.5 rounded text-[10px] font-medium bg-slate-800 text-slate-300 border border-slate-700">
                                    Due: {inv.due_date} ({inv.payment_terms})
                                  </span>
                                )}
                              </div>
                              <p className="text-xs text-slate-400 mt-0.5">
                                Terms: {inv.payment_terms} • Issue: {inv.issue_date || inv.created_at.split('T')[0]} • Total: {formatMoney(inv.total_cents)} • {items.length} item{items.length === 1 ? '' : 's'}
                              </p>
                            </div>
                          </div>

                          <div className="flex items-center gap-3 ml-auto">
                            <div className="text-right">
                              <span className={`text-base font-bold font-mono block ${isFullyPaid ? 'text-emerald-400' : isOverdue ? 'text-rose-400' : 'text-slate-200'}`}>
                                {formatMoney(inv.total_cents)}
                              </span>
                              {balanceDueCents > 0 && (
                                <span className="text-[11px] font-bold font-mono text-indigo-400 block">
                                  Due: {formatMoney(balanceDueCents)}
                                </span>
                              )}
                            </div>

                            {/* Record Payment Button */}
                            {balanceDueCents > 0 && (
                              <button
                                type="button"
                                onClick={(e) => {
                                  e.stopPropagation();
                                  openRecordPaymentModal(inv);
                                }}
                                className="inline-flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg text-xs font-bold bg-emerald-600/20 hover:bg-emerald-600/30 text-emerald-300 border border-emerald-500/40 transition cursor-pointer shrink-0"
                              >
                                <CreditCard className="w-3.5 h-3.5 text-emerald-400" />
                                <span>Pay</span>
                              </button>
                            )}

                            {/* PDF Print Button */}
                            <button
                              type="button"
                              onClick={(e) => {
                                e.stopPropagation();
                                setPreviewInvoice({ invoice: inv, items });
                              }}
                              className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-bold bg-indigo-600 hover:bg-indigo-500 text-white shadow-md shadow-indigo-600/30 transition cursor-pointer shrink-0"
                            >
                              <Printer className="w-3.5 h-3.5" />
                              <span>PDF / Print</span>
                            </button>

                            <div className="text-slate-400">
                              {isExpanded ? <ChevronUp className="w-4 h-4" /> : <ChevronDown className="w-4 h-4" />}
                            </div>
                          </div>
                        </div>

                        {/* Expandable Line Items & Payments */}
                        {isExpanded && (
                          <div className="border-t border-slate-800 bg-slate-950/80 p-4 space-y-4">
                            <div>
                              <h4 className="text-xs font-bold text-slate-300 uppercase tracking-wider mb-2">
                                Line Items Breakdown:
                              </h4>
                              <div className="divide-y divide-slate-800">
                                {items.map((item) => (
                                  <div key={item.id} className="py-1.5 flex items-center justify-between text-xs">
                                    <span className="text-slate-300">• {item.description} ({item.quantity} × {formatMoney(item.unit_price_cents)})</span>
                                    <span className="font-mono font-semibold text-slate-200">{formatMoney(item.total_cents)}</span>
                                  </div>
                                ))}
                              </div>
                            </div>

                            {invPayments.length > 0 && (
                              <div className="border-t border-slate-800 pt-3">
                                <h4 className="text-xs font-bold text-emerald-400 uppercase tracking-wider mb-2 flex items-center gap-1.5">
                                  <Receipt className="w-3.5 h-3.5" />
                                  <span>Payments Received ({invPayments.length}):</span>
                                </h4>
                                <div className="bg-slate-900/60 border border-slate-800 rounded-lg p-2 divide-y divide-slate-800">
                                  {invPayments.map((p) => (
                                    <div key={p.id} className="py-1 flex items-center justify-between text-xs">
                                      <span className="text-emerald-300">{p.payment_date} • {p.payment_method} {p.notes ? `(${p.notes})` : ''}</span>
                                      <span className="font-mono font-bold text-emerald-400">{formatMoney(p.amount_cents)}</span>
                                    </div>
                                  ))}
                                </div>
                              </div>
                            )}
                          </div>
                        )}
                      </div>
                    );
                  })}
                </div>
              </div>
            </div>
          )}

          {/* Tab 2: ESTIMATES / QUOTES TAB (Sprint 4) */}
          {billingSubTab === 'estimates' && (
            <div className="space-y-6">
              {/* Create Estimate / Proposal Form */}
              <div className="border border-slate-800 bg-slate-900/60 rounded-2xl p-5 shadow-xl space-y-4">
                <div className="flex items-center justify-between">
                  <h2 className="text-sm font-bold text-slate-200 flex items-center gap-2">
                    <Receipt className="w-4 h-4 text-indigo-400" />
                    <span>Create Proposal / Estimate Quote</span>
                  </h2>
                  <span className="font-mono text-xs font-bold text-indigo-400 bg-indigo-500/10 px-2.5 py-1 rounded border border-indigo-500/30">
                    {getNextEstimateNumber()}
                  </span>
                </div>

                {/* Line Item Inputs Row */}
                <form onSubmit={handleAddCartItem} className="grid grid-cols-1 sm:grid-cols-12 gap-2 bg-slate-950 p-3 rounded-xl border border-slate-800">
                  <div className="sm:col-span-6">
                    <input
                      type="text"
                      placeholder="Proposed Item / Service Description"
                      value={itemDescription}
                      onChange={(e) => setItemDescription(e.target.value)}
                      className="w-full bg-slate-900 border border-slate-800 rounded-lg px-3 py-1.5 text-xs text-slate-100 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                    />
                  </div>
                  <div className="sm:col-span-3">
                    <input
                      type="number"
                      step="0.01"
                      placeholder={`Unit Price (${businessProfile.currency_symbol})`}
                      value={priceInput}
                      onChange={(e) => setPriceInput(e.target.value)}
                      className="w-full bg-slate-900 border border-slate-800 rounded-lg px-3 py-1.5 text-xs text-slate-100 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                    />
                  </div>
                  <div className="sm:col-span-2">
                    <input
                      type="number"
                      min="1"
                      placeholder="Qty"
                      value={quantityInput}
                      onChange={(e) => setQuantityInput(e.target.value)}
                      className="w-full bg-slate-900 border border-slate-800 rounded-lg px-3 py-1.5 text-xs text-slate-100 focus:outline-none focus:ring-1 focus:ring-indigo-500"
                    />
                  </div>
                  <div className="sm:col-span-1 flex items-center justify-end">
                    <button
                      type="submit"
                      className="w-full py-1.5 bg-indigo-600 hover:bg-indigo-500 text-white rounded-lg text-xs font-bold transition flex items-center justify-center cursor-pointer"
                    >
                      <Plus className="w-4 h-4" />
                    </button>
                  </div>
                </form>

                {/* Proposal Cart Items */}
                {cartItems.length > 0 ? (
                  <div className="border border-slate-800 rounded-xl overflow-hidden bg-slate-950/60 divide-y divide-slate-800/60">
                    {cartItems.map((item, index) => (
                      <div key={index} className="p-3 flex items-center justify-between text-xs">
                        <div>
                          <span className="font-semibold text-slate-200">{item.description}</span>
                          <span className="text-slate-400 ml-2">
                            ({item.quantity} × {formatMoney(item.unitPriceCents)})
                          </span>
                        </div>
                        <div className="flex items-center gap-3">
                          <span className="font-mono font-bold text-slate-200">{formatMoney(item.totalCents)}</span>
                          <button
                            type="button"
                            onClick={() => handleRemoveCartItem(index)}
                            className="text-slate-500 hover:text-rose-400 transition cursor-pointer"
                          >
                            <Trash2 className="w-3.5 h-3.5" />
                          </button>
                        </div>
                      </div>
                    ))}
                  </div>
                ) : (
                  <p className="text-xs text-slate-500 italic">No line items added yet.</p>
                )}

                {/* Proposal Expiry & Tax */}
                <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 pt-2">
                  <div>
                    <label className="block text-xs text-slate-400 mb-1">Issue Date</label>
                    <input
                      type="date"
                      value={issueDate}
                      onChange={(e) => setIssueDate(e.target.value)}
                      className="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-1.5 text-xs text-slate-100"
                    />
                  </div>
                  <div>
                    <label className="block text-xs text-slate-400 mb-1">Expiry Date (Valid Until)</label>
                    <input
                      type="date"
                      value={expiryDate}
                      onChange={(e) => setExpiryDate(e.target.value)}
                      className="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-1.5 text-xs text-slate-100"
                    />
                  </div>
                  <div>
                    <label className="block text-xs text-slate-400 mb-1">Tax Rate (%)</label>
                    <input
                      type="number"
                      value={taxPctInput}
                      onChange={(e) => setTaxPctInput(e.target.value)}
                      className="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-1.5 text-xs text-slate-100"
                    />
                  </div>
                </div>

                {/* Save Estimate Button */}
                <div className="bg-slate-950 border border-slate-800 rounded-xl p-3 flex flex-wrap items-center justify-between gap-3">
                  <div className="flex items-center gap-4 text-xs font-mono">
                    <span className="text-slate-400">Subtotal: <strong className="text-slate-200">{formatMoney(cartSubtotalCents)}</strong></span>
                    <span className="text-indigo-400 font-bold">Estimated Total: {formatMoney(cartTotalCents)}</span>
                  </div>
                  <button
                    type="button"
                    onClick={handleSaveEstimate}
                    className="px-4 py-2 bg-indigo-600 hover:bg-indigo-500 text-white rounded-lg text-xs font-bold transition shadow-lg shadow-indigo-600/20 cursor-pointer flex items-center gap-1.5"
                  >
                    <Save className="w-4 h-4" />
                    <span>Save Estimate / Proposal</span>
                  </button>
                </div>
              </div>

              {/* Saved Estimates List */}
              <div className="border border-slate-800 bg-slate-900/60 rounded-2xl p-5 shadow-xl space-y-4">
                <h2 className="text-sm font-bold text-slate-200 flex items-center gap-2">
                  <Receipt className="w-4 h-4 text-indigo-400" />
                  <span>Saved Estimates & Proposals ({estimates.length})</span>
                </h2>

                <div className="space-y-3">
                  {estimates.map((est) => {
                    const items = estimateItems.filter((item) => item.estimate_id === est.id);
                    const isConverted = est.status === 'CONVERTED';

                    return (
                      <div
                        key={est.id}
                        className="border border-slate-800 bg-slate-950/60 rounded-xl p-4 flex flex-wrap sm:flex-nowrap items-center justify-between gap-3"
                      >
                        <div className="space-y-1">
                          <div className="flex items-center gap-2">
                            <span className="font-mono font-bold text-xs px-2.5 py-1 rounded border bg-indigo-500/10 text-indigo-400 border-indigo-500/30">
                              {est.estimate_number}
                            </span>
                            <span className="font-semibold text-sm text-slate-200">{est.client_name}</span>
                            <span className={`px-2 py-0.5 rounded text-[10px] font-bold border ${
                              isConverted
                                ? 'bg-emerald-500/10 text-emerald-400 border-emerald-500/30'
                                : 'bg-amber-500/10 text-amber-300 border-amber-500/30'
                            }`}>
                              {est.status}
                            </span>
                          </div>
                          <p className="text-xs text-slate-400">
                            Issue: {est.issue_date} • Valid Until: {est.expiry_date} • {items.length} item{items.length === 1 ? '' : 's'}
                          </p>
                        </div>

                        <div className="flex items-center gap-3 ml-auto">
                          <span className="text-base font-bold font-mono text-indigo-400">
                            {formatMoney(est.total_cents)}
                          </span>

                          {/* 1-Click Convert to Invoice Button */}
                          {!isConverted && (
                            <button
                              type="button"
                              onClick={() => handleConvertEstimateToInvoice(est)}
                              className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-bold bg-emerald-600 hover:bg-emerald-500 text-white shadow-md shadow-emerald-600/30 transition cursor-pointer shrink-0"
                              title="1-Click Convert Estimate to Invoice"
                            >
                              <Sparkles className="w-3.5 h-3.5" />
                              <span>Convert to Invoice</span>
                            </button>
                          )}

                          {/* Estimate PDF Button */}
                          <button
                            type="button"
                            onClick={() => setPreviewEstimate({ estimate: est, items })}
                            className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-bold bg-slate-800 hover:bg-slate-700 text-slate-200 border border-slate-700 transition cursor-pointer shrink-0"
                          >
                            <Printer className="w-3.5 h-3.5" />
                            <span>PDF / Print</span>
                          </button>
                        </div>
                      </div>
                    );
                  })}
                </div>
              </div>
            </div>
          )}
        </div>
      )}

      {/* Top Level Nav 2: Modular Code Explorer */}
      {topNavTab === 'flutter_code' && (
        <div className="p-6 max-w-7xl mx-auto w-full flex-1 flex flex-col sm:flex-row gap-6">
          <div className="w-full sm:w-80 bg-slate-900/60 border border-slate-800 rounded-2xl p-4 shrink-0 space-y-2 max-h-[75vh] overflow-y-auto">
            <h3 className="font-bold text-xs uppercase tracking-wider text-slate-400 mb-3 flex items-center gap-2">
              <FolderTree className="w-4 h-4 text-indigo-400" />
              <span>Modular Files ({Object.keys(MODULAR_FILES).length})</span>
            </h3>
            {Object.keys(MODULAR_FILES).map((filePath) => (
              <button
                key={filePath}
                type="button"
                onClick={() => setSelectedFile(filePath)}
                className={`w-full text-left px-3 py-2 rounded-xl text-xs font-mono transition flex items-center gap-2 cursor-pointer truncate ${
                  selectedFile === filePath
                    ? 'bg-indigo-600 text-white font-bold'
                    : 'text-slate-400 hover:bg-slate-800 hover:text-slate-200'
                }`}
              >
                <FileCode className="w-3.5 h-3.5 shrink-0" />
                <span className="truncate">{filePath}</span>
              </button>
            ))}
          </div>

          <div className="flex-1 bg-slate-900/60 border border-slate-800 rounded-2xl p-4 flex flex-col min-h-[500px]">
            <div className="flex items-center justify-between border-b border-slate-800 pb-3 mb-3">
              <span className="font-mono text-xs font-bold text-indigo-400 flex items-center gap-2">
                <FileCode className="w-4 h-4" />
                <span>{selectedFile}</span>
              </span>
              <button
                type="button"
                onClick={() => handleCopyCode(MODULAR_FILES[selectedFile] || '', 'modular_code')}
                className="px-3 py-1 bg-slate-800 hover:bg-slate-700 text-slate-200 rounded-lg text-xs font-medium border border-slate-700 transition cursor-pointer flex items-center gap-1.5"
              >
                {copiedKey === 'modular_code' ? <Check className="w-3.5 h-3.5 text-emerald-400" /> : <Copy className="w-3.5 h-3.5" />}
                <span>{copiedKey === 'modular_code' ? 'Copied' : 'Copy File'}</span>
              </button>
            </div>
            <pre className="text-xs font-mono text-slate-300 bg-slate-950 p-4 rounded-xl border border-slate-800/80 overflow-auto flex-1 leading-relaxed">
              {MODULAR_FILES[selectedFile] || '// File content empty'}
            </pre>
          </div>
        </div>
      )}

      {/* Top Level Nav 3: SQLite Schema Explorer */}
      {topNavTab === 'schema' && (
        <div className="p-6 max-w-5xl mx-auto w-full flex-1 space-y-4">
          <div className="border border-slate-800 bg-slate-900/60 rounded-2xl p-6 space-y-4">
            <h2 className="text-base font-bold text-slate-200 flex items-center gap-2">
              <Database className="w-5 h-5 text-indigo-400" />
              <span>Local SQLite Relational Database Schema</span>
            </h2>
            <p className="text-xs text-slate-400">
              Stores client billing details, multi-line invoice items, partial payments, estimates, and business profile settings locally via SQLite.
            </p>

            <div className="space-y-4">
              <div className="border border-slate-800 rounded-xl p-4 bg-slate-950">
                <span className="font-mono font-bold text-xs text-indigo-400">TABLE clients</span>
                <pre className="text-xs font-mono text-slate-300 mt-2">
{`CREATE TABLE clients (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT DEFAULT '',
  phone TEXT DEFAULT '',
  address TEXT DEFAULT '',
  tax_id TEXT DEFAULT '',
  created_at TEXT NOT NULL
);`}
                </pre>
              </div>

              <div className="border border-slate-800 rounded-xl p-4 bg-slate-950">
                <span className="font-mono font-bold text-xs text-indigo-400">TABLE invoices</span>
                <pre className="text-xs font-mono text-slate-300 mt-2">
{`CREATE TABLE invoices (
  id TEXT PRIMARY KEY,
  client_id TEXT NOT NULL,
  invoice_number TEXT NOT NULL UNIQUE,
  subtotal_cents INTEGER NOT NULL,
  tax_cents INTEGER NOT NULL,
  total_cents INTEGER NOT NULL,
  status TEXT NOT NULL,
  issue_date TEXT NOT NULL DEFAULT '',
  due_date TEXT NOT NULL DEFAULT '',
  payment_terms TEXT NOT NULL DEFAULT 'Due on Receipt',
  created_at TEXT NOT NULL,
  FOREIGN KEY (client_id) REFERENCES clients (id) ON DELETE RESTRICT
);`}
                </pre>
              </div>

              <div className="border border-slate-800 rounded-xl p-4 bg-slate-950">
                <span className="font-mono font-bold text-xs text-indigo-400">TABLE estimates (Sprint 4)</span>
                <pre className="text-xs font-mono text-slate-300 mt-2">
{`CREATE TABLE estimates (
  id TEXT PRIMARY KEY,
  client_id TEXT NOT NULL,
  estimate_number TEXT NOT NULL UNIQUE,
  subtotal_cents INTEGER NOT NULL,
  tax_cents INTEGER NOT NULL,
  total_cents INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'PENDING',
  issue_date TEXT NOT NULL,
  expiry_date TEXT NOT NULL,
  converted_invoice_id TEXT DEFAULT '',
  created_at TEXT NOT NULL,
  FOREIGN KEY (client_id) REFERENCES clients (id) ON DELETE RESTRICT
);`}
                </pre>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Record Payment Modal (Sprint 3) */}
      {isRecordPaymentOpen && paymentTargetInvoice && (
        <div className="fixed inset-0 z-50 bg-black/75 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="bg-slate-950 border border-slate-800 rounded-2xl w-full max-w-md overflow-hidden shadow-2xl flex flex-col">
            <div className="p-4 border-b border-slate-800 flex items-center justify-between">
              <div>
                <h3 className="font-bold text-sm text-slate-100 flex items-center gap-2">
                  <CreditCard className="w-4 h-4 text-emerald-400" />
                  <span>Record Payment: {paymentTargetInvoice.invoice_number}</span>
                </h3>
                <p className="text-xs text-slate-400 mt-0.5">{paymentTargetInvoice.client_name}</p>
              </div>
              <button
                type="button"
                onClick={() => setIsRecordPaymentOpen(false)}
                className="p-1.5 text-slate-400 hover:text-slate-200 hover:bg-slate-900 rounded-lg cursor-pointer"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            <form onSubmit={handleSavePayment} className="p-4 space-y-4">
              <div className="bg-slate-900/60 border border-slate-800 rounded-lg p-3 grid grid-cols-3 gap-2 text-center">
                <div>
                  <span className="text-[10px] text-slate-400 block font-semibold uppercase">Total</span>
                  <span className="text-xs font-bold text-slate-200 font-mono">
                    {formatMoney(paymentTargetInvoice.total_cents)}
                  </span>
                </div>
                <div>
                  <span className="text-[10px] text-slate-400 block font-semibold uppercase">Paid</span>
                  <span className="text-xs font-bold text-emerald-400 font-mono">
                    {formatMoney(getInvoicePaidCents(paymentTargetInvoice.id))}
                  </span>
                </div>
                <div>
                  <span className="text-[10px] text-slate-400 block font-semibold uppercase">Balance Due</span>
                  <span className="text-xs font-bold text-indigo-400 font-mono">
                    {formatMoney(getInvoiceBalanceDueCents(paymentTargetInvoice))}
                  </span>
                </div>
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-1">
                  Payment Amount ({businessProfile.currency_symbol}) *
                </label>
                <input
                  type="number"
                  step="0.01"
                  required
                  value={paymentAmountInput}
                  onChange={(e) => {
                    setPaymentAmountInput(e.target.value);
                    setPaymentError(null);
                  }}
                  className="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-2 text-sm text-slate-100 font-mono focus:outline-none focus:ring-2 focus:ring-emerald-500"
                />
                {paymentError && <p className="text-xs text-rose-400 mt-1 font-medium">{paymentError}</p>}
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-1">Payment Method</label>
                <select
                  value={paymentMethod}
                  onChange={(e) => setPaymentMethod(e.target.value)}
                  className="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-2 text-sm text-slate-100"
                >
                  <option value="Bank Wire">Bank Wire</option>
                  <option value="Credit Card">Credit Card</option>
                  <option value="Cash">Cash</option>
                  <option value="UPI / PayPal">UPI / PayPal</option>
                  <option value="Check">Check</option>
                </select>
              </div>

              <div className="pt-2 flex justify-end gap-2 border-t border-slate-800">
                <button
                  type="button"
                  onClick={() => setIsRecordPaymentOpen(false)}
                  className="px-4 py-2 rounded-lg text-xs font-semibold bg-slate-900 text-slate-300 border border-slate-700"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-4 py-2 rounded-lg text-xs font-bold bg-emerald-600 hover:bg-emerald-500 text-white cursor-pointer"
                >
                  Save Payment
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Accountant CSV Export Modal (Sprint 4) */}
      {isCsvModalOpen && (
        <div className="fixed inset-0 z-50 bg-black/75 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="bg-slate-950 border border-slate-800 rounded-2xl w-full max-w-xl overflow-hidden shadow-2xl flex flex-col">
            <div className="p-4 border-b border-slate-800 flex items-center justify-between">
              <h3 className="font-bold text-sm text-slate-100 flex items-center gap-2">
                <FileSpreadsheet className="w-4 h-4 text-emerald-400" />
                <span>Accountant CSV Export</span>
              </h3>
              <button
                type="button"
                onClick={() => setIsCsvModalOpen(false)}
                className="p-1.5 text-slate-400 hover:text-slate-200 rounded-lg cursor-pointer"
              >
                <X className="w-4 h-4" />
              </button>
            </div>
            <div className="p-4 space-y-3">
              <p className="text-xs text-slate-400">
                Standard CSV containing all invoice numbers, client tax IDs, subtotals, tax, totals, amount paid, balance due, and payment status.
              </p>
              <pre className="text-xs font-mono text-emerald-400 bg-slate-900 p-3 rounded-xl border border-slate-800 overflow-auto max-h-60 leading-relaxed">
                {generateCsvContent()}
              </pre>
              <div className="flex justify-end gap-2 pt-2 border-t border-slate-800">
                <button
                  type="button"
                  onClick={() => setIsCsvModalOpen(false)}
                  className="px-4 py-2 rounded-lg text-xs font-semibold bg-slate-900 text-slate-300 border border-slate-700"
                >
                  Close
                </button>
                <button
                  type="button"
                  onClick={() => {
                    navigator.clipboard.writeText(generateCsvContent());
                    setIsCsvModalOpen(false);
                    showToast('Invoices CSV copied to clipboard!');
                  }}
                  className="px-4 py-2 rounded-lg text-xs font-bold bg-emerald-600 hover:bg-emerald-500 text-white flex items-center gap-1.5 cursor-pointer"
                >
                  <Copy className="w-4 h-4" />
                  <span>Copy CSV to Clipboard</span>
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Business Profile & Currency Settings Modal */}
      {isProfileModalOpen && (
        <div className="fixed inset-0 z-50 bg-black/75 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="bg-slate-950 border border-slate-800 rounded-2xl w-full max-w-lg overflow-hidden shadow-2xl flex flex-col">
            <div className="p-4 border-b border-slate-800 flex items-center justify-between">
              <h3 className="font-bold text-sm text-slate-100 flex items-center gap-2">
                <Building2 className="w-4 h-4 text-indigo-400" />
                <span>Business Profile & Currency Settings</span>
              </h3>
              <button
                type="button"
                onClick={() => setIsProfileModalOpen(false)}
                className="p-1.5 text-slate-400 hover:text-slate-200 rounded-lg cursor-pointer"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            <form onSubmit={handleSaveProfile} className="p-4 space-y-3">
              <div className="grid grid-cols-3 gap-2">
                <div className="col-span-2">
                  <label className="block text-xs text-slate-400 mb-1">Business / Studio Name *</label>
                  <input
                    type="text"
                    required
                    value={profileForm.business_name}
                    onChange={(e) => setProfileForm({ ...profileForm, business_name: e.target.value })}
                    className="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-1.5 text-xs text-slate-100"
                  />
                </div>
                <div>
                  <label className="block text-xs text-slate-400 mb-1">Currency Symbol</label>
                  <select
                    value={profileForm.currency_symbol || '\$'}
                    onChange={(e) => setProfileForm({ ...profileForm, currency_symbol: e.target.value })}
                    className="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-1.5 text-xs text-slate-100 font-bold"
                  >
                    <option value="\$">\$ (USD)</option>
                    <option value="€">€ (EUR)</option>
                    <option value="£">£ (GBP)</option>
                    <option value="₹">₹ (INR)</option>
                    <option value="C\$">C\$ (CAD)</option>
                    <option value="A\$">A\$ (AUD)</option>
                    <option value="¥">¥ (JPY)</option>
                  </select>
                </div>
              </div>

              <div className="grid grid-cols-2 gap-2">
                <div>
                  <label className="block text-xs text-slate-400 mb-1">Email</label>
                  <input
                    type="email"
                    value={profileForm.email}
                    onChange={(e) => setProfileForm({ ...profileForm, email: e.target.value })}
                    className="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-1.5 text-xs text-slate-100"
                  />
                </div>
                <div>
                  <label className="block text-xs text-slate-400 mb-1">Phone</label>
                  <input
                    type="text"
                    value={profileForm.phone}
                    onChange={(e) => setProfileForm({ ...profileForm, phone: e.target.value })}
                    className="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-1.5 text-xs text-slate-100"
                  />
                </div>
              </div>

              <div>
                <label className="block text-xs text-slate-400 mb-1">Business Address</label>
                <input
                  type="text"
                  value={profileForm.address}
                  onChange={(e) => setProfileForm({ ...profileForm, address: e.target.value })}
                  className="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-1.5 text-xs text-slate-100"
                />
              </div>

              <div>
                <label className="block text-xs text-slate-400 mb-1">Tax ID / VAT / GSTIN / EIN</label>
                <input
                  type="text"
                  value={profileForm.tax_id}
                  onChange={(e) => setProfileForm({ ...profileForm, tax_id: e.target.value })}
                  className="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-1.5 text-xs text-slate-100"
                />
              </div>

              <div>
                <label className="block text-xs text-slate-400 mb-1">Payment Instructions</label>
                <textarea
                  rows={3}
                  value={profileForm.payment_details}
                  onChange={(e) => setProfileForm({ ...profileForm, payment_details: e.target.value })}
                  className="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-1.5 text-xs text-slate-100"
                />
              </div>

              <div className="pt-2 flex justify-end gap-2 border-t border-slate-800">
                <button
                  type="button"
                  onClick={() => setIsProfileModalOpen(false)}
                  className="px-4 py-2 rounded-lg text-xs font-semibold bg-slate-900 text-slate-300 border border-slate-700"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-4 py-2 rounded-lg text-xs font-bold bg-indigo-600 hover:bg-indigo-500 text-white cursor-pointer"
                >
                  Save Settings
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Invoice PDF Preview Modal */}
      {previewInvoice && (
        <div className="fixed inset-0 z-50 bg-black/80 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-800 rounded-2xl w-full max-w-2xl overflow-hidden shadow-2xl flex flex-col max-h-[90vh]">
            <div className="p-4 border-b border-slate-800 flex items-center justify-between">
              <h3 className="font-bold text-sm text-slate-100 flex items-center gap-2">
                <Printer className="w-4 h-4 text-indigo-400" />
                <span>A4 Invoice Print Preview: {previewInvoice.invoice.invoice_number}</span>
              </h3>
              <div className="flex items-center gap-2">
                <button
                  type="button"
                  onClick={() => window.print()}
                  className="px-3 py-1.5 bg-indigo-600 hover:bg-indigo-500 text-white rounded-lg text-xs font-bold transition flex items-center gap-1.5 cursor-pointer"
                >
                  <Printer className="w-3.5 h-3.5" />
                  <span>Print Document</span>
                </button>
                <button
                  type="button"
                  onClick={() => setPreviewInvoice(null)}
                  className="p-1.5 text-slate-400 hover:text-slate-200 rounded-lg cursor-pointer"
                >
                  <X className="w-4 h-4" />
                </button>
              </div>
            </div>

            <div className="p-6 overflow-y-auto bg-slate-950 flex-1">
              <div className="bg-white text-slate-900 p-8 rounded-xl shadow-2xl max-w-xl mx-auto space-y-6 text-xs font-sans">
                <div className="flex justify-between items-start">
                  <div>
                    <h1 className="text-2xl font-bold tracking-tight text-slate-900">INVOICE</h1>
                    <p className="font-bold text-indigo-600 text-sm">{previewInvoice.invoice.invoice_number}</p>
                  </div>
                  <div className="text-right">
                    <span className="px-2 py-1 rounded text-[10px] font-bold uppercase bg-slate-100 text-slate-800 border border-slate-300">
                      {previewInvoice.invoice.status}
                    </span>
                    <p className="text-[11px] text-slate-500 mt-2">Issue Date: {previewInvoice.invoice.issue_date}</p>
                    <p className="text-[11px] text-slate-900 font-bold">Due Date: {previewInvoice.invoice.due_date}</p>
                  </div>
                </div>

                <div className="border-t border-b border-slate-200 py-4 grid grid-cols-2 gap-4">
                  <div>
                    <p className="font-bold text-[10px] text-slate-400 uppercase">Billed From</p>
                    <p className="font-bold text-slate-900 mt-0.5">{businessProfile.business_name}</p>
                    <p className="text-slate-600">{businessProfile.email}</p>
                    <p className="text-slate-600">{businessProfile.phone}</p>
                    <p className="text-slate-500">{businessProfile.address}</p>
                  </div>
                  <div>
                    <p className="font-bold text-[10px] text-slate-400 uppercase">Billed To</p>
                    <p className="font-bold text-slate-900 mt-0.5">{previewInvoice.invoice.client_name}</p>
                    <p className="text-slate-600">Tax ID: {selectedClientObj?.tax_id || 'N/A'}</p>
                  </div>
                </div>

                <div>
                  <p className="font-bold text-[10px] text-slate-400 uppercase mb-2">Line Items</p>
                  <table className="w-full border-collapse">
                    <thead>
                      <tr className="border-b border-slate-300 text-left font-bold text-slate-600">
                        <th className="py-2">Description</th>
                        <th className="py-2 text-center">Qty</th>
                        <th className="py-2 text-right">Price</th>
                        <th className="py-2 text-right">Total</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-slate-100">
                      {previewInvoice.items.map((it) => (
                        <tr key={it.id}>
                          <td className="py-2 text-slate-900">{it.description}</td>
                          <td className="py-2 text-center text-slate-600">{it.quantity}</td>
                          <td className="py-2 text-right text-slate-600">{formatMoney(it.unit_price_cents)}</td>
                          <td className="py-2 text-right font-bold text-slate-900">{formatMoney(it.total_cents)}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>

                <div className="flex justify-end pt-2">
                  <div className="w-56 space-y-1 text-right">
                    <div className="flex justify-between text-slate-600">
                      <span>Subtotal:</span>
                      <span>{formatMoney(previewInvoice.invoice.subtotal_cents)}</span>
                    </div>
                    <div className="flex justify-between text-slate-600">
                      <span>Tax:</span>
                      <span>{formatMoney(previewInvoice.invoice.tax_cents)}</span>
                    </div>
                    <div className="flex justify-between font-bold text-slate-900 text-sm border-t border-slate-300 pt-1">
                      <span>Total:</span>
                      <span>{formatMoney(previewInvoice.invoice.total_cents)}</span>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Estimate PDF Preview Modal (Sprint 4) */}
      {previewEstimate && (
        <div className="fixed inset-0 z-50 bg-black/80 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-slate-800 rounded-2xl w-full max-w-2xl overflow-hidden shadow-2xl flex flex-col max-h-[90vh]">
            <div className="p-4 border-b border-slate-800 flex items-center justify-between">
              <h3 className="font-bold text-sm text-slate-100 flex items-center gap-2">
                <Printer className="w-4 h-4 text-indigo-400" />
                <span>Estimate Quote Print Preview: {previewEstimate.estimate.estimate_number}</span>
              </h3>
              <div className="flex items-center gap-2">
                <button
                  type="button"
                  onClick={() => window.print()}
                  className="px-3 py-1.5 bg-indigo-600 hover:bg-indigo-500 text-white rounded-lg text-xs font-bold transition flex items-center gap-1.5 cursor-pointer"
                >
                  <Printer className="w-3.5 h-3.5" />
                  <span>Print Quote</span>
                </button>
                <button
                  type="button"
                  onClick={() => setPreviewEstimate(null)}
                  className="p-1.5 text-slate-400 hover:text-slate-200 rounded-lg cursor-pointer"
                >
                  <X className="w-4 h-4" />
                </button>
              </div>
            </div>

            <div className="p-6 overflow-y-auto bg-slate-950 flex-1">
              <div className="bg-white text-slate-900 p-8 rounded-xl shadow-2xl max-w-xl mx-auto space-y-6 text-xs font-sans">
                <div className="flex justify-between items-start">
                  <div>
                    <h1 className="text-2xl font-bold tracking-tight text-slate-900">ESTIMATE / QUOTE</h1>
                    <p className="font-bold text-indigo-600 text-sm">{previewEstimate.estimate.estimate_number}</p>
                  </div>
                  <div className="text-right">
                    <span className="px-2 py-1 rounded text-[10px] font-bold uppercase bg-slate-100 text-slate-800 border border-slate-300">
                      {previewEstimate.estimate.status}
                    </span>
                    <p className="text-[11px] text-slate-500 mt-2">Issue Date: {previewEstimate.estimate.issue_date}</p>
                    <p className="text-[11px] text-slate-900 font-bold">Valid Until: {previewEstimate.estimate.expiry_date}</p>
                  </div>
                </div>

                <div className="border-t border-b border-slate-200 py-4 grid grid-cols-2 gap-4">
                  <div>
                    <p className="font-bold text-[10px] text-slate-400 uppercase">Prepared By</p>
                    <p className="font-bold text-slate-900 mt-0.5">{businessProfile.business_name}</p>
                    <p className="text-slate-600">{businessProfile.email}</p>
                  </div>
                  <div>
                    <p className="font-bold text-[10px] text-slate-400 uppercase">Prepared For</p>
                    <p className="font-bold text-slate-900 mt-0.5">{previewEstimate.estimate.client_name}</p>
                  </div>
                </div>

                <div>
                  <p className="font-bold text-[10px] text-slate-400 uppercase mb-2">Proposed Line Items</p>
                  <table className="w-full border-collapse">
                    <thead>
                      <tr className="border-b border-slate-300 text-left font-bold text-slate-600">
                        <th className="py-2">Description</th>
                        <th className="py-2 text-center">Qty</th>
                        <th className="py-2 text-right">Price</th>
                        <th className="py-2 text-right">Total</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-slate-100">
                      {previewEstimate.items.map((it) => (
                        <tr key={it.id}>
                          <td className="py-2 text-slate-900">{it.description}</td>
                          <td className="py-2 text-center text-slate-600">{it.quantity}</td>
                          <td className="py-2 text-right text-slate-600">{formatMoney(it.unit_price_cents)}</td>
                          <td className="py-2 text-right font-bold text-slate-900">{formatMoney(it.total_cents)}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>

                <div className="flex justify-end pt-2">
                  <div className="w-56 space-y-1 text-right">
                    <div className="flex justify-between font-bold text-slate-900 text-sm border-t border-slate-300 pt-1">
                      <span>Estimated Total:</span>
                      <span>{formatMoney(previewEstimate.estimate.total_cents)}</span>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
