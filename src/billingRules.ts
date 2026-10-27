/**
 * Pure domain logic for integer-based financial calculations
 * Strictly matches the Dart / SQLite desktop specifications.
 */

export interface InvoiceCalculation {
  subtotalCents: number;
  taxCents: number;
  totalCents: number;
}

export interface LineItemDraft {
  description: string;
  unitPriceCents: number;
  quantity: number;
  totalCents: number;
}

export interface ClientRecord {
  id: string;
  name: string;
  email: string;
  phone: string;
  address: string;
  taxId: string;
  createdAt: string;
}

export interface InvoiceItemRecord {
  id: string;
  invoiceId: string;
  description: string;
  quantity: number;
  unitPriceCents: number;
  totalCents: number;
  createdAt: string;
}

export interface PaymentRecord {
  id: string;
  invoiceId: string;
  amountCents: number;
  paymentMethod: string;
  paymentDate: string;
  notes: string;
  createdAt: string;
}

export interface InvoiceRecord {
  id: string;
  clientId: string;
  clientName: string;
  invoiceNumber: string;
  subtotalCents: number;
  taxCents: number;
  totalCents: number;
  paidCents: number;
  balanceDueCents: number;
  status: string;
  issueDate: string;
  dueDate: string;
  paymentTerms: string;
  createdAt: string;
}

export interface EstimateRecord {
  id: string;
  clientId: string;
  clientName: string;
  estimateNumber: string;
  subtotalCents: number;
  taxCents: number;
  totalCents: number;
  status: string; // 'PENDING', 'ACCEPTED', 'DECLINED', 'CONVERTED'
  issueDate: string;
  expiryDate: string;
  convertedInvoiceId?: string;
  createdAt: string;
}

export interface EstimateItemRecord {
  id: string;
  estimateId: string;
  description: string;
  quantity: number;
  unitPriceCents: number;
  totalCents: number;
  createdAt: string;
}

export interface BusinessProfile {
  id: string;
  businessName: string;
  email: string;
  phone: string;
  address: string;
  taxId: string;
  paymentDetails: string;
  currencySymbol: string;
}

/**
 * Parses user input price (e.g. "15.50" or "$15.50") into integer cents without float imprecision.
 */
export function parsePriceToCents(input: string): number {
  const cleaned = input.trim().replace(/[^\d.]/g, '');
  if (!cleaned) return 0;
  const parts = cleaned.split('.');
  const dollars = parseInt(parts[0], 10) || 0;
  let cents = 0;
  if (parts.length > 1) {
    const centsPart = (parts[1] + '00').slice(0, 2);
    cents = parseInt(centsPart, 10) || 0;
  }
  return dollars * 100 + cents;
}

/**
 * Calculates Subtotal, Tax, and Total strictly in integer cents for a single item.
 */
export function calculateInvoice(
  priceCents: number,
  quantity: number,
  taxPercentage: number
): InvoiceCalculation {
  const safeQty = Math.max(1, Math.floor(quantity));
  const subtotalCents = priceCents * safeQty;
  return calculateCartTotals(subtotalCents, taxPercentage);
}

/**
 * Calculates Subtotal, Tax, and Total strictly in integer cents for multi-line items.
 */
export function calculateCartTotals(
  subtotalCents: number,
  taxPercentage: number
): InvoiceCalculation {
  const safeTax = Math.max(0, Math.floor(taxPercentage));
  const taxCents = Math.floor((subtotalCents * safeTax + 50) / 100);
  const totalCents = subtotalCents + taxCents;

  return {
    subtotalCents,
    taxCents,
    totalCents,
  };
}

/**
 * Calculates payments balance and settlement state.
 */
export function calculateBalance(totalCents: number, paidCents: number): {
  balanceDueCents: number;
  isFullyPaid: boolean;
  isPartiallyPaid: boolean;
} {
  const safeTotal = Math.max(0, Math.floor(totalCents));
  const safePaid = Math.max(0, Math.floor(paidCents));
  const balanceDueCents = Math.max(0, safeTotal - safePaid);
  const isFullyPaid = safePaid >= safeTotal && safeTotal > 0;
  const isPartiallyPaid = safePaid > 0 && safePaid < safeTotal;

  return {
    balanceDueCents,
    isFullyPaid,
    isPartiallyPaid,
  };
}

/**
 * Validates a payment amount against the remaining balance.
 */
export function validatePaymentAmount(amountCents: number, balanceDueCents: number): {
  valid: boolean;
  error?: string;
} {
  if (amountCents <= 0) {
    return { valid: false, error: 'Payment amount must be greater than zero.' };
  }
  if (amountCents > balanceDueCents) {
    return {
      valid: false,
      error: `Payment amount (${formatCents(amountCents)}) cannot exceed balance due (${formatCents(balanceDueCents)}).`,
    };
  }
  return { valid: true };
}

/**
 * Generates sequential invoice number starting at INV-0001.
 */
export function formatNextInvoiceNumber(existingCount: number): string {
  const nextNum = existingCount + 1;
  return `INV-${String(nextNum).padStart(4, '0')}`;
}

/**
 * Generates sequential estimate number starting at EST-0001.
 */
export function formatNextEstimateNumber(existingCount: number): string {
  const nextNum = existingCount + 1;
  return `EST-${String(nextNum).padStart(4, '0')}`;
}

/**
 * Calculates due date string (YYYY-MM-DD) based on issue date and payment terms.
 */
export function calculateDueDate(issueDateStr: string, paymentTerms: string): string {
  let issueDate: Date;
  try {
    issueDate = new Date(issueDateStr);
    if (isNaN(issueDate.getTime())) {
      issueDate = new Date();
    }
  } catch {
    issueDate = new Date();
  }

  let daysToAdd = 0;
  if (paymentTerms === 'Net 15 Days') daysToAdd = 15;
  if (paymentTerms === 'Net 30 Days') daysToAdd = 30;
  if (paymentTerms === 'Net 60 Days') daysToAdd = 60;

  const due = new Date(issueDate);
  due.setDate(due.getDate() + daysToAdd);

  const y = due.getFullYear();
  const m = String(due.getMonth() + 1).padStart(2, '0');
  const d = String(due.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

/**
 * Determines whether an invoice is overdue based on status, paid state, and due date.
 */
export function isInvoiceOverdue(status: string, dueDateStr: string, isFullyPaid = false): boolean {
  if (isFullyPaid || status.toUpperCase() === 'PAID') return false;
  if (!dueDateStr) return false;
  try {
    const due = new Date(dueDateStr);
    if (isNaN(due.getTime())) return false;
    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const dueDay = new Date(due.getFullYear(), due.getMonth(), due.getDate());
    return today.getTime() > dueDay.getTime();
  } catch {
    return false;
  }
}

/**
 * Resolves real-time dynamic status for an invoice.
 */
export function resolveDynamicStatus(
  totalCents: number,
  paidCents: number,
  dueDateStr: string,
  manualStatus = 'PENDING'
): 'PAID' | 'PARTIALLY_PAID' | 'OVERDUE' | 'PENDING' {
  if (manualStatus.toUpperCase() === 'PAID' || (totalCents > 0 && paidCents >= totalCents)) {
    return 'PAID';
  }
  if (paidCents > 0 && paidCents < totalCents) {
    return 'PARTIALLY_PAID';
  }
  if (isInvoiceOverdue(manualStatus, dueDateStr, false)) {
    return 'OVERDUE';
  }
  return 'PENDING';
}

/**
 * Calculates number of days an invoice is past due.
 */
export function calculateDaysOverdue(dueDateStr: string): number {
  try {
    const due = new Date(dueDateStr);
    if (isNaN(due.getTime())) return 0;
    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const dueDay = new Date(due.getFullYear(), due.getMonth(), due.getDate());
    const diffMs = today.getTime() - dueDay.getTime();
    const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));
    return diffDays > 0 ? diffDays : 0;
  } catch {
    return 0;
  }
}

/**
 * UI display formatting with dynamic currency symbol.
 */
export function formatCents(cents: number, symbol = '$'): string {
  const dollars = (cents / 100).toFixed(2);
  return `${symbol}${dollars}`;
}

/**
 * Generates Accountant CSV Export string from invoices list.
 */
export function generateInvoicesCsvString(
  invoices: InvoiceRecord[],
  clients: ClientRecord[],
  symbol = '$'
): string {
  const clientTaxMap: Record<string, string> = {};
  for (const c of clients) {
    clientTaxMap[c.id] = c.taxId || '';
  }

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

  const rows: string[][] = [headers];

  for (const inv of invoices) {
    const clientTaxId = clientTaxMap[inv.clientId] || '';
    rows.push([
      inv.invoiceNumber,
      inv.issueDate,
      inv.dueDate,
      inv.clientName,
      clientTaxId,
      formatCents(inv.subtotalCents, symbol),
      formatCents(inv.taxCents, symbol),
      formatCents(inv.totalCents, symbol),
      formatCents(inv.paidCents || 0, symbol),
      formatCents(inv.balanceDueCents || inv.totalCents, symbol),
      inv.status,
    ]);
  }

  return rows
    .map((row) =>
      row
        .map((field) => {
          const escaped = String(field).replace(/"/g, '""');
          if (escaped.includes(',') || escaped.includes('"') || escaped.includes('\n')) {
            return `"${escaped}"`;
          }
          return escaped;
        })
        .join(',')
    )
    .join('\n');
}
