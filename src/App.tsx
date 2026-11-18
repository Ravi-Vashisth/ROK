import React, { useState, useEffect, useRef } from 'react';
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
  TaxMode,
  calculateDueDate,
  extractSequenceNumber,
  formatDecimalUnits,
  formatLocalCalendarDate,
  formatMoney as formatMoneyUnits,
  generateUniqueId,
  getCurrencyDecimals,
  getNextSequentialDocNumber,
  parsePriceToCents,
  validateBackupPayload,
} from './billingRules';

import { DashboardTab } from './components/dashboard/DashboardTab';
import { SalesTab } from './components/billing/SalesTab';
import { InvoiceEditorScreen } from './components/invoices/InvoiceEditorScreen';
import { ExpensesTab } from './components/expenses/ExpensesTab';
import { SettingsTab } from './components/settings/SettingsTab';
import { BusinessProfileDialog } from './components/business_profile/BusinessProfileDialog';
import { RecordPaymentModal } from './components/payments/RecordPaymentModal';
import { PaymentReminderModal } from './components/billing/PaymentReminderModal';
import { ConfirmDialog } from './components/common/ConfirmDialog';
import { ExpenseDrawerModal } from './components/expenses/ExpenseDrawerModal';

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
  items?: any[];
  terms?: string;
  notes?: string;
  discount_type?: 'none' | 'percent' | 'flat';
  discount_value?: number;
  discount_cents?: number;
  po_number?: string;
  currency_code?: string;
  currency_symbol?: string;
  currency_decimals?: number;
  tax_mode?: TaxMode;
  pst_rate_percentage?: number;
  tax_exemption_id?: string;
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
  payment_terms?: string;
  items?: any[];
  terms?: string;
  notes?: string;
  discount_type?: 'none' | 'percent' | 'flat';
  discount_value?: number;
  discount_cents?: number;
  po_number?: string;
  currency_code?: string;
  currency_symbol?: string;
  currency_decimals?: number;
  tax_mode?: TaxMode;
  pst_rate_percentage?: number;
  tax_exemption_id?: string;
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
  notes?: string;
  receipt_base64?: string;
  receipt_name?: string;
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

  // Modals & Toast Feedback
  const [isProfileModalOpen, setIsProfileModalOpen] = useState<boolean>(false);
  const [isCsvModalOpen, setIsCsvModalOpen] = useState<boolean>(false);
  const [isExpenseModalOpen, setIsExpenseModalOpen] = useState<boolean>(false);
  const [editingExpense, setEditingExpense] = useState<ExpenseRecord | null>(null);
  const [confirmState, setConfirmState] = useState<{
    title: string;
    message: string;
    confirmLabel?: string;
    isDestructive?: boolean;
    onConfirm: () => void;
  } | null>(null);
  const [paymentModalInvoice, setPaymentModalInvoice] = useState<InvoiceRecord | null>(null);
  const [reminderModalInvoice, setReminderModalInvoice] = useState<InvoiceRecord | null>(null);
  const [toast, setToast] = useState<{ message: string; isError?: boolean } | null>(null);

  const showToast = (message: string, isError = false) => {
    setToast({ message, isError });
  };

  useEffect(() => {
    if (!toast) return;
    const timer = setTimeout(() => setToast(null), 4000);
    return () => clearTimeout(timer);
  }, [toast]);

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
      default_tax_mode: 'standard',
      default_pst_rate_percentage: 0,
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
  const curDec =
    businessProfile.currency_decimals ??
    getCurrencyDecimals(businessProfile.currency_code || sym);

  const formatMoney = (units: number) => formatMoneyUnits(units, sym, curDec);

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
    const invPrefix = businessProfile.invoice_prefix || 'INV-';
    const estPrefix = businessProfile.estimate_prefix || 'EST-';
    const invMinNext = Math.max(1, Number(businessProfile.next_invoice_number) || 1);

    const syncProfileNextInvoiceNumber = (issuedNum: string) => {
      const seq = extractSequenceNumber(issuedNum, invPrefix);
      setBusinessProfile((prevProf: any) => {
        const curNext = Math.max(1, Number(prevProf.next_invoice_number) || 1);
        const nextVal = Math.max(curNext + 1, seq + 1);
        return { ...prevProf, next_invoice_number: nextVal };
      });
    };

    if (editorMode === 'invoice') {
      if (docData.existingId) {
        let promotedNum: string | null = null;
        setInvoices((prev) =>
          prev.map((i) => {
            if (i.id !== docData.existingId) return i;
            let invNum = i.invoice_number;
            if (!docData.isDraft && invNum.startsWith('DRAFT-')) {
              invNum = getNextSequentialDocNumber(
                prev.map((x) => x.invoice_number),
                invPrefix,
                invMinNext
              );
              promotedNum = invNum;
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
              items: docData.items,
              terms: docData.terms,
              notes: docData.notes,
              discount_type: docData.discountType,
              discount_value: docData.discountValue,
              discount_cents: docData.discountCents,
              po_number: docData.poNumber,
              currency_code: docData.currencyCode,
              currency_symbol: docData.currencySymbol,
              currency_decimals: docData.currencyDecimals,
              tax_mode: docData.taxMode,
              pst_rate_percentage: docData.pstRatePercentage,
              tax_exemption_id: docData.taxExemptionId,
            };
          })
        );
        if (promotedNum) syncProfileNextInvoiceNumber(promotedNum);
      } else {
        const invNumber = docData.isDraft
          ? `DRAFT-${generateUniqueId().slice(0, 8).toUpperCase()}`
          : getNextSequentialDocNumber(
              invoices.map((x) => x.invoice_number),
              invPrefix,
              invMinNext
            );
        const newInv: InvoiceRecord = {
          id: generateUniqueId(),
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
          items: docData.items,
          terms: docData.terms,
          notes: docData.notes,
          discount_type: docData.discountType,
          discount_value: docData.discountValue,
          discount_cents: docData.discountCents,
          po_number: docData.poNumber,
          currency_code: docData.currencyCode,
          currency_symbol: docData.currencySymbol,
          currency_decimals: docData.currencyDecimals,
          tax_mode: docData.taxMode,
          pst_rate_percentage: docData.pstRatePercentage,
          tax_exemption_id: docData.taxExemptionId,
          created_at: new Date().toISOString(),
        };
        setInvoices((prev) => [newInv, ...prev]);
        if (!docData.isDraft) syncProfileNextInvoiceNumber(invNumber);
      }
    } else {
      if (docData.existingId) {
        setEstimates((prev) =>
          prev.map((e) => {
            if (e.id !== docData.existingId) return e;
            let estNum = e.estimate_number;
            if (!docData.isDraft && estNum.startsWith('DRAFT-')) {
              estNum = getNextSequentialDocNumber(
                prev.map((x) => x.estimate_number),
                estPrefix
              );
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
              expiry_date:
                docData.expiryDate ||
                e.expiry_date ||
                calculateDueDate(docData.issueDate, docData.paymentTerms || 'Net 30 Days'),
              payment_terms: docData.paymentTerms || 'Net 30 Days',
              items: docData.items,
              terms: docData.terms,
              notes: docData.notes,
              discount_type: docData.discountType,
              discount_value: docData.discountValue,
              discount_cents: docData.discountCents,
              po_number: docData.poNumber,
              currency_code: docData.currencyCode,
              currency_symbol: docData.currencySymbol,
              currency_decimals: docData.currencyDecimals,
              tax_mode: docData.taxMode,
              pst_rate_percentage: docData.pstRatePercentage,
              tax_exemption_id: docData.taxExemptionId,
            };
          })
        );
      } else {
        const estNumber = docData.isDraft
          ? `DRAFT-${generateUniqueId().slice(0, 8).toUpperCase()}`
          : getNextSequentialDocNumber(
              estimates.map((x) => x.estimate_number),
              estPrefix
            );
        const newEst: StoredEstimateRecord = {
          id: generateUniqueId(),
          client_id: docData.clientId,
          client_name: docData.clientName,
          estimate_number: estNumber,
          subtotal_cents: docData.subtotalCents,
          tax_cents: docData.taxCents,
          total_cents: docData.totalCents,
          status: docData.isDraft ? 'DRAFT' : 'PENDING',
          issue_date: docData.issueDate,
          expiry_date:
            docData.expiryDate ||
            calculateDueDate(docData.issueDate, docData.paymentTerms || 'Net 30 Days'),
          payment_terms: docData.paymentTerms || 'Net 30 Days',
          items: docData.items,
          terms: docData.terms,
          notes: docData.notes,
          discount_type: docData.discountType,
          discount_value: docData.discountValue,
          discount_cents: docData.discountCents,
          po_number: docData.poNumber,
          currency_code: docData.currencyCode,
          currency_symbol: docData.currencySymbol,
          currency_decimals: docData.currencyDecimals,
          tax_mode: docData.taxMode,
          pst_rate_percentage: docData.pstRatePercentage,
          tax_exemption_id: docData.taxExemptionId,
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
    setConfirmState({
      title: 'Delete Invoice',
      message: `Are you sure you want to delete invoice ${inv.invoice_number}?`,
      confirmLabel: 'Delete Invoice',
      isDestructive: true,
      onConfirm: () => {
        setInvoices((prev) => prev.filter((i) => i.id !== inv.id));
        setConfirmState(null);
        showToast(`Deleted invoice ${inv.invoice_number}.`);
      },
    });
  };

  const handleFinalizeInvoice = (inv: InvoiceRecord) => {
    const invPrefix = businessProfile.invoice_prefix || 'INV-';
    const invMinNext = Math.max(1, Number(businessProfile.next_invoice_number) || 1);
    let issuedNum: string | null = null;
    setInvoices((prev) =>
      prev.map((i) => {
        if (i.id !== inv.id) return i;
        let num = i.invoice_number;
        if (num.startsWith('DRAFT-')) {
          num = getNextSequentialDocNumber(
            prev.map((x) => x.invoice_number),
            invPrefix,
            invMinNext
          );
          issuedNum = num;
        }
        return { ...i, invoice_number: num, status: 'PENDING', computed_status: 'PENDING' };
      })
    );
    if (issuedNum) {
      const seq = extractSequenceNumber(issuedNum, invPrefix);
      setBusinessProfile((prevProf: any) => ({
        ...prevProf,
        next_invoice_number: Math.max((Number(prevProf.next_invoice_number) || 1) + 1, seq + 1),
      }));
    }
  };

  const handleFinalizeEstimate = (est: StoredEstimateRecord) => {
    const estPrefix = businessProfile.estimate_prefix || 'EST-';
    setEstimates((prev) =>
      prev.map((e) => {
        if (e.id !== est.id) return e;
        let num = e.estimate_number;
        if (num.startsWith('DRAFT-')) {
          num = getNextSequentialDocNumber(
            prev.map((x) => x.estimate_number),
            estPrefix
          );
        }
        return { ...e, estimate_number: num, status: 'PENDING' };
      })
    );
  };

  const handleConvertEstimate = (est: StoredEstimateRecord) => {
    const todayIso = formatLocalCalendarDate();
    const invPrefix = businessProfile.invoice_prefix || 'INV-';
    const invMinNext = Math.max(1, Number(businessProfile.next_invoice_number) || 1);
    const nextInvNum = getNextSequentialDocNumber(
      invoices.map((x) => x.invoice_number),
      invPrefix,
      invMinNext
    );
    const newInv: InvoiceRecord = {
      id: generateUniqueId(),
      client_id: est.client_id,
      client_name: est.client_name,
      invoice_number: nextInvNum,
      subtotal_cents: est.subtotal_cents,
      tax_cents: est.tax_cents,
      total_cents: est.total_cents,
      status: 'PENDING',
      computed_status: 'PENDING',
      issue_date: todayIso,
      due_date: calculateDueDate(todayIso, 'Net 15 Days'),
      payment_terms: 'Net 15 Days',
      paid_cents: 0,
      balance_due_cents: est.total_cents,
      items: est.items,
      terms: est.terms,
      notes: est.notes,
      discount_type: est.discount_type,
      discount_value: est.discount_value,
      discount_cents: est.discount_cents,
      po_number: est.po_number,
      currency_code: est.currency_code,
      currency_symbol: est.currency_symbol,
      currency_decimals: est.currency_decimals,
      tax_mode: est.tax_mode,
      pst_rate_percentage: est.pst_rate_percentage,
      tax_exemption_id: est.tax_exemption_id,
      created_at: new Date().toISOString(),
    };
    setInvoices((prev) => [newInv, ...prev]);
    setEstimates((prev) => prev.map((e) => (e.id === est.id ? { ...e, status: 'CONVERTED' } : e)));
    const convSeq = extractSequenceNumber(nextInvNum, invPrefix);
    setBusinessProfile((prevProf: any) => ({
      ...prevProf,
      next_invoice_number: Math.max((Number(prevProf.next_invoice_number) || 1) + 1, convSeq + 1),
    }));
    showToast(`Converted quote ${est.estimate_number} into live invoice ${newInv.invoice_number}.`);
  };

  const handleDeleteEstimate = (est: StoredEstimateRecord) => {
    setConfirmState({
      title: 'Delete Quote / Estimate',
      message: `Are you sure you want to delete quote ${est.estimate_number}?`,
      confirmLabel: 'Delete Quote',
      isDestructive: true,
      onConfirm: () => {
        setEstimates((prev) => prev.filter((e) => e.id !== est.id));
        setConfirmState(null);
        showToast(`Deleted quote ${est.estimate_number}.`);
      },
    });
  };

  const handleAddExpense = () => {
    setEditingExpense(null);
    setIsExpenseModalOpen(true);
  };

  const handleEditExpense = (exp: ExpenseRecord) => {
    setEditingExpense(exp);
    setIsExpenseModalOpen(true);
  };

  const handleSaveExpense = (expData: {
    id?: string;
    vendor: string;
    category: string;
    amount_cents: number;
    tax_cents: number;
    total_cents: number;
    expense_date: string;
    notes: string;
    receipt_base64: string;
    receipt_name: string;
  }) => {
    if (expData.id) {
      setExpenses((prev) =>
        prev.map((e) =>
          e.id === expData.id
            ? {
                ...e,
                vendor: expData.vendor,
                category: expData.category,
                amount_cents: expData.amount_cents,
                tax_cents: expData.tax_cents,
                total_cents: expData.total_cents,
                expense_date: expData.expense_date,
                notes: expData.notes,
                receipt_base64: expData.receipt_base64,
                receipt_name: expData.receipt_name,
              }
            : e
        )
      );
      showToast(`Expense updated for ${expData.vendor}.`);
      return;
    }

    const newExp: ExpenseRecord = {
      id: generateUniqueId(),
      vendor: expData.vendor,
      category: expData.category,
      amount_cents: expData.amount_cents,
      tax_cents: expData.tax_cents,
      total_cents: expData.total_cents,
      expense_date: expData.expense_date,
      notes: expData.notes,
      receipt_base64: expData.receipt_base64,
      receipt_name: expData.receipt_name,
      created_at: new Date().toISOString(),
    };
    setExpenses((prev) => [newExp, ...prev]);
    showToast(`Expense logged for ${expData.vendor}.`);
  };

  const handleDeleteExpense = (exp: ExpenseRecord) => {
    setConfirmState({
      title: 'Delete Expense',
      message: `Delete expense record from "${exp.vendor}"?`,
      confirmLabel: 'Delete Expense',
      isDestructive: true,
      onConfirm: () => {
        setExpenses((prev) => prev.filter((e) => e.id !== exp.id));
        setConfirmState(null);
        showToast(`Deleted expense for ${exp.vendor}.`);
      },
    });
  };

  const handleAddClient = (cData: any) => {
    const newC: Client = {
      id: generateUniqueId(),
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
      showToast(
        `Cannot delete client "${client.name}" because active invoices exist for this client.`,
        true
      );
      return;
    }
    setConfirmState({
      title: 'Delete Client',
      message: `Are you sure you want to delete client "${client.name}"?`,
      confirmLabel: 'Delete Client',
      isDestructive: true,
      onConfirm: () => {
        setClients((prev) => prev.filter((c) => c.id !== client.id));
        setConfirmState(null);
        showToast(`Deleted client ${client.name}.`);
      },
    });
  };

  const handleAddItem = (iData: any) => {
    const newI = {
      id: generateUniqueId(),
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
    setConfirmState({
      title: 'Delete Catalog Item',
      message: `Are you sure you want to delete preset service "${item.title}"?`,
      confirmLabel: 'Delete Item',
      isDestructive: true,
      onConfirm: () => {
        setSavedItems((prev) => prev.filter((i) => i.id !== item.id));
        setConfirmState(null);
        showToast(`Deleted catalog item ${item.title}.`);
      },
    });
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
    const dateStr = formatLocalCalendarDate();
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
        const validation = validateBackupPayload(data);
        if (!validation.valid) {
          showToast(validation.error || 'Invalid database backup file.', true);
          return;
        }
        setClients(data.clients);
        setInvoices(data.invoices);
        if (data.estimates) setEstimates(data.estimates);
        if (data.expenses) setExpenses(data.expenses);
        if (data.savedItems) setSavedItems(data.savedItems);
        if (data.businessProfile) setBusinessProfile(data.businessProfile);
        showToast('Database restored successfully from backup JSON.');
      } catch (_) {
        showToast('Invalid database backup file: Unable to parse JSON.', true);
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
  const paletteRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!isPaletteOpen) return;
    const handleMouseDown = (event: MouseEvent) => {
      if (paletteRef.current && !paletteRef.current.contains(event.target as Node)) {
        setIsPaletteOpen(false);
      }
    };
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        setIsPaletteOpen(false);
      }
    };
    document.addEventListener('mousedown', handleMouseDown);
    document.addEventListener('keydown', handleKeyDown);
    return () => {
      document.removeEventListener('mousedown', handleMouseDown);
      document.removeEventListener('keydown', handleKeyDown);
    };
  }, [isPaletteOpen]);

  return (
    <div className={`min-h-screen font-sans flex antialiased ${isDarkMode ? 'bg-[#0B0F19] text-slate-100' : 'bg-slate-50 text-slate-900'}`}>
      {/* 1. MASTER SIDEBAR NAVIGATION (4 First-Class Desktop Tabs) */}
      <aside className={`hidden min-[900px]:flex flex-col w-[220px] border-r select-none sticky top-0 h-screen shrink-0 ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}>
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
      <div className="flex-1 flex flex-col min-w-0 pb-24 min-[900px]:pb-0">
        <main className="flex-1 p-4 min-[900px]:p-6 overflow-y-auto max-w-7xl mx-auto w-full space-y-6">
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
            <div className="relative" ref={paletteRef}>
              <button
                onClick={() => setIsPaletteOpen((p) => !p)}
                aria-expanded={isPaletteOpen}
                aria-haspopup="true"
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
                      className={`w-full flex items-center gap-2.5 px-2.5 py-1.5 rounded-xl text-xs font-semibold cursor-pointer transition ${accentColor === key ? 'bg-slate-100 dark:bg-slate-800' : 'hover:bg-slate-50 dark:hover:bg-slate-800/50'}`}
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
              nextDocNumber={
                editorMode === 'estimate'
                  ? getNextSequentialDocNumber(
                      estimates.map((e) => e.estimate_number),
                      businessProfile.estimate_prefix || 'EST-'
                    )
                  : getNextSequentialDocNumber(
                      invoices.map((i) => i.invoice_number),
                      businessProfile.invoice_prefix || 'INV-',
                      Math.max(1, Number(businessProfile.next_invoice_number) || 1)
                    )
              }
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
              onNotify={showToast}
            />
          ) : activeTab === 0 ? (
            <DashboardTab
              invoices={invoices}
              expenses={expenses}
              clients={clients}
              isDarkMode={isDarkMode}
              currencySymbol={sym}
              currencyCode={businessProfile.currency_code || 'USD'}
              currencyDecimals={curDec}
              formatMoney={formatMoney}
              onNavigateToSales={() => setActiveTab(1)}
              onNavigateToExpenses={() => setActiveTab(2)}
              onCreateInvoice={handleCreateInvoice}
              onSendReminder={(inv) => setReminderModalInvoice(inv)}
            />
          ) : activeTab === 1 ? (
            <SalesTab
              invoices={invoices}
              estimates={estimates}
              clients={clients}
              isDarkMode={isDarkMode}
              currencyCode={businessProfile.currency_code || 'USD'}
              currencySymbol={sym}
              currencyDecimals={curDec}
              formatMoney={formatMoney}
              initialSubTab={salesSubTab}
              onCreateInvoice={handleCreateInvoice}
              onCreateQuote={handleCreateQuote}
              onRecordPayment={handleRecordPayment}
              onSendReminder={(inv) => setReminderModalInvoice(inv)}
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
              onNotify={showToast}
            />
          ) : activeTab === 2 ? (
            <ExpensesTab
              expenses={expenses}
              isDarkMode={isDarkMode}
              formatMoney={formatMoney}
              onAddExpense={handleAddExpense}
              onEditExpense={handleEditExpense}
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
              onNotify={showToast}
            />
          )}
        </main>
      </div>

      {/* Mobile Bottom Navigation Bar (STRICTLY 4 DESTINATIONS) */}
      <nav
        aria-label="Mobile navigation"
        className={`min-[900px]:hidden fixed bottom-0 left-0 right-0 border-t flex items-center justify-around pt-2 pb-[calc(0.5rem+env(safe-area-inset-bottom))] px-2 z-40 ${isDarkMode ? 'bg-[#0F172A] border-slate-800 text-slate-400' : 'bg-white border-slate-200 text-slate-600'}`}
      >
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
              className={`flex-1 min-w-0 flex flex-col items-center gap-1 text-[10px] font-bold cursor-pointer truncate px-1 ${isActive ? 'text-indigo-600' : ''}`}
            >
              <Icon className="w-5 h-5 shrink-0" />
              <span className="truncate max-w-full">{item.label}</span>
            </button>
          );
        })}
      </nav>

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
          <div className={`w-full max-w-md max-h-[90vh] overflow-y-auto rounded-xl border p-6 space-y-4 ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}>
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
                    const paidUnits = i.paid_cents || 0;
                    const totalUnits = i.total_cents || 0;
                    const dueUnits = isVoid ? 0 : Math.max(0, totalUnits - paidUnits);
                    const client = clients.find((c) => c.id === i.client_id);
                    const taxId = client?.tax_id || '';
                    const isoCode = i.currency_code || businessProfile.currency_code || 'USD';
                    const dec = i.currency_decimals ?? getCurrencyDecimals(isoCode);
                    lines.push(
                      `"${i.invoice_number}","${i.issue_date}","${i.due_date}","${isoCode}","${(i.client_name || '').replace(/"/g, '""')}","${taxId}",${formatDecimalUnits(i.subtotal_cents || 0, dec)},${formatDecimalUnits(i.tax_cents || 0, dec)},${formatDecimalUnits(totalUnits, dec)},${formatDecimalUnits(paidUnits, dec)},${formatDecimalUnits(dueUnits, dec)},"${isVoid ? 'VOID' : status}"`
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
                    const safeNotes = (e.notes || '').replace(/"/g, '""');
                    lines.push(
                      `"${e.id}","${e.expense_date}","${e.category}","${(e.vendor || '').replace(/"/g, '""')}","${isoCode}",${formatDecimalUnits(e.amount_cents || 0, curDec)},${formatDecimalUnits(e.tax_cents || 0, curDec)},${formatDecimalUnits(e.total_cents || 0, curDec)},"${safeNotes}"`
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

      {/* Payment Reminder Modal */}
      {reminderModalInvoice && (
        <PaymentReminderModal
          invoice={reminderModalInvoice}
          client={clients.find((c) => c.id === reminderModalInvoice.client_id)}
          businessProfile={businessProfile}
          isDarkMode={isDarkMode}
          onClose={() => setReminderModalInvoice(null)}
          onCopied={(msg) => showToast(msg)}
        />
      )}

      {/* Expense Drawer Modal */}
      <ExpenseDrawerModal
        isOpen={isExpenseModalOpen}
        isDarkMode={isDarkMode}
        currencySymbol={sym}
        currencyDecimals={curDec}
        initialExpense={editingExpense}
        onClose={() => {
          setIsExpenseModalOpen(false);
          setEditingExpense(null);
        }}
        onSave={handleSaveExpense}
      />

      {/* Reusable Confirm Dialog */}
      <ConfirmDialog
        isOpen={!!confirmState}
        title={confirmState?.title || ''}
        message={confirmState?.message || ''}
        confirmLabel={confirmState?.confirmLabel}
        isDestructive={confirmState?.isDestructive}
        isDarkMode={isDarkMode}
        onConfirm={() => confirmState?.onConfirm()}
        onCancel={() => setConfirmState(null)}
      />

      {/* Non-blocking Toast Banner */}
      {toast && (
        <div
          role="status"
          className={`fixed bottom-[calc(5rem+env(safe-area-inset-bottom))] min-[900px]:bottom-6 right-4 min-[900px]:right-6 z-50 max-w-sm rounded-xl border px-4 py-3 shadow-lg flex items-center gap-3 text-xs font-semibold ${
            toast.isError
              ? 'bg-rose-600 border-rose-500 text-white'
              : isDarkMode
                ? 'bg-slate-800 border-slate-700 text-slate-100'
                : 'bg-slate-900 border-slate-800 text-white'
          }`}
        >
          <span className="flex-1">{toast.message}</span>
          <button
            onClick={() => setToast(null)}
            className="text-white/75 hover:text-white cursor-pointer"
            aria-label="Dismiss notification"
          >
            <X className="w-3.5 h-3.5" />
          </button>
        </div>
      )}
    </div>
  );
};

export default App;
