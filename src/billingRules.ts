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
  status: string; // 'DRAFT' | 'PENDING' | 'PARTIALLY_PAID' | 'PAID' | 'OVERDUE' | 'VOID'
  issueDate: string;
  dueDate: string;
  paymentTerms: string;
  poNumber?: string;
  currencyCode?: string;
  currencySymbol?: string;
  currencyDecimals?: number;
  taxMode?: string;
  pstRatePercentage?: number;
  taxExemptionId?: string;
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
  poNumber?: string;
  currencyCode?: string;
  currencySymbol?: string;
  currencyDecimals?: number;
  taxMode?: string;
  pstRatePercentage?: number;
  taxExemptionId?: string;
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
  defaultTaxMode?: TaxMode;
  defaultPstRatePercentage?: number;
}

export type TaxMode =
  | 'standard'
  | 'in_intra'
  | 'in_inter'
  | 'in_lut'
  | 'eu_vat'
  | 'eu_reverse_charge'
  | 'ca_dual'
  | 'gulf_vat'
  | 'us_exempt';

export const TAX_MODE_LABELS: Record<TaxMode, string> = {
  standard: 'Standard Tax',
  in_intra: 'India GST — Intra-State (CGST + SGST)',
  in_inter: 'India GST — Inter-State (IGST)',
  in_lut: 'India GST — Export under LUT (0%)',
  eu_vat: 'EU / UK VAT — Standard',
  eu_reverse_charge: 'EU / UK B2B Reverse Charge (0%)',
  ca_dual: 'Canada Dual Tax (GST + PST)',
  gulf_vat: 'Gulf / GCC VAT (KSA / UAE)',
  us_exempt: 'US Sales Tax-Exempt (0%)',
};

export interface TaxBreakdownLine {
  label: string;
  cents: number;
}

export interface RegionalTaxBreakdown {
  effectiveMode: TaxMode;
  lines: TaxBreakdownLine[];
  totalTaxCents: number;
  noticeTitle: string;
  noticeText: string;
  isZeroRated: boolean;
}

/**
 * Determines decimal exponent (0 or 2) for currency code or symbol.
 */
export function getCurrencyDecimals(codeOrSymbol: string): number {
  const upper = codeOrSymbol.trim().toUpperCase();
  if (
    upper === 'JPY' ||
    upper === 'KRW' ||
    upper === 'VND' ||
    upper === 'CLP' ||
    upper === '¥' ||
    upper === '₩' ||
    upper === '₫'
  ) {
    return 0;
  }
  return 2;
}

/**
 * Parses user input price into minor units based on currency decimals exponent.
 */
export function parsePriceToUnits(input: string, decimals: number = 2): number {
  const cleaned = input.trim().replace(/[^\d.]/g, '');
  if (!cleaned) return 0;

  if (decimals === 0) {
    const wholeStr = cleaned.split('.')[0];
    return parseInt(wholeStr, 10) || 0;
  }

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
 * Parses user input price (e.g. "15.50" or "$15.50") into integer cents without float imprecision.
 */
export function parsePriceToCents(input: string, decimals: number = 2): number {
  return parsePriceToUnits(input, decimals);
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
 * Calculates tax in integer minor units using strict integer round-half-up math:
 * floor((net * pct + 50) / 100).
 */
export function calculateTaxCents(netSubtotalCents: number, taxPercentage: number): number {
  const safeSub = Math.max(0, Math.round(netSubtotalCents));
  const safeTax = Math.max(0, Math.floor(taxPercentage));
  return Math.floor((safeSub * safeTax + 50) / 100);
}

/**
 * Calculates collected tax portion on partial/full payments using round-half-up integer math.
 */
export function calculateCollectedTaxPortion(
  paidCents: number,
  taxCents: number,
  totalCents: number
): number {
  if (totalCents <= 0 || paidCents <= 0 || taxCents <= 0) return 0;
  if (paidCents >= totalCents) return taxCents;
  return Math.floor((paidCents * taxCents + Math.floor(totalCents / 2)) / totalCents);
}

/**
 * Calculates Subtotal, Tax, and Total strictly in integer cents for multi-line items.
 */
export function calculateCartTotals(
  subtotalCents: number,
  taxPercentage: number
): InvoiceCalculation {
  const taxCents = calculateTaxCents(subtotalCents, taxPercentage);
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
  if (isFullyPaid || status.toUpperCase() === 'PAID' || status.toUpperCase() === 'DRAFT' || status.toUpperCase() === 'VOID') return false;
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
): 'DRAFT' | 'PAID' | 'PARTIALLY_PAID' | 'OVERDUE' | 'PENDING' | 'VOID' {
  if (manualStatus.toUpperCase() === 'VOID') {
    return 'VOID';
  }
  if (manualStatus.toUpperCase() === 'DRAFT') {
    return 'DRAFT';
  }
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
 * Formats minor units as formatted currency string.
 */
export function formatMoney(units: number, symbol = '$', decimals = 2): string {
  const safeUnits = Math.round(units);
  if (decimals === 0) {
    const formatted = new Intl.NumberFormat('en-US', {
      maximumFractionDigits: 0,
      minimumFractionDigits: 0,
    }).format(safeUnits);
    return `${symbol}${formatted}`;
  }
  const formatted = new Intl.NumberFormat('en-US', {
    maximumFractionDigits: 2,
    minimumFractionDigits: 2,
  }).format(safeUnits / 100);
  return `${symbol}${formatted}`;
}

/**
 * Formats minor units into an input-friendly or CSV decimal string (0 or 2 decimals).
 */
export function formatDecimalUnits(units: number, decimals = 2): string {
  const safeUnits = Math.round(units);
  if (decimals === 0) {
    return String(safeUnits);
  }
  return (safeUnits / 100).toFixed(2);
}

/**
 * UI display formatting with dynamic currency symbol and decimal exponent.
 */
export function formatCents(cents: number, symbol = '$', decimals = 2): string {
  return formatMoney(cents, symbol, decimals);
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

/**
 * Computes discount in integer cents based on discount type and value.
 * Clamps flat discounts to subtotal.
 */
export function calculateDiscountCents(
  subtotalCents: number,
  discountType: 'none' | 'percent' | 'flat',
  discountValue: number
): number {
  if (subtotalCents <= 0 || discountValue <= 0 || discountType === 'none') return 0;
  if (discountType === 'percent') {
    const safePct = Math.min(100, Math.max(0, discountValue));
    return Math.floor((subtotalCents * safePct + 50) / 100);
  }
  return Math.min(discountValue, subtotalCents);
}

/**
 * Computes Indian GST CGST/SGST (50%/50%) split for intra-state or IGST (100%) for inter-state.
 */
export function calculateGstSplit(totalTaxCents: number, isIntraState: boolean): {
  cgstCents: number;
  sgstCents: number;
  igstCents: number;
} {
  if (totalTaxCents <= 0) {
    return { cgstCents: 0, sgstCents: 0, igstCents: 0 };
  }
  if (isIntraState) {
    const cgst = Math.floor(totalTaxCents / 2);
    const sgst = totalTaxCents - cgst; // absorbs odd cent
    return { cgstCents: cgst, sgstCents: sgst, igstCents: 0 };
  }
  return { cgstCents: 0, sgstCents: 0, igstCents: totalTaxCents };
}

/**
 * Returns Indian statutory LUT export notice if zero-rated export under LUT.
 */
export function getLutNotice(isExportUnderLut: boolean): string {
  if (!isExportUnderLut) return '';
  return 'SUPPLY MEANT FOR EXPORT UNDER BOND OR LETTER OF UNDERTAKING WITHOUT PAYMENT OF INTEGRATED TAX';
}

/**
 * Returns EU/UK B2B Reverse Charge notice.
 */
export function getEuReverseChargeNotice(isEuCrossBorderB2B: boolean): string {
  if (!isEuCrossBorderB2B) return '';
  return 'Reverse charge: Customer to account for VAT under Article 196 of Council Directive 2006/112/EC.';
}

/**
 * Calculates Canadian dual tax (GST + PST).
 */
export function calculateCanadaTax(
  subtotalCents: number,
  gstRatePct: number,
  pstRatePct: number
): { gstCents: number; pstCents: number; totalTaxCents: number } {
  const gstCents = Math.floor((subtotalCents * Math.max(0, gstRatePct) + 50) / 100);
  const pstCents = Math.floor((subtotalCents * Math.max(0, pstRatePct) + 50) / 100);
  return {
    gstCents,
    pstCents,
    totalTaxCents: gstCents + pstCents,
  };
}

/**
 * Parses zero-decimal currencies (JPY, KRW) without fractional cent division.
 */
export function parseZeroDecimalPrice(input: string): number {
  const cleaned = input.trim().replace(/[^\d]/g, '');
  if (!cleaned) return 0;
  return parseInt(cleaned, 10) || 0;
}

/**
 * Extracts sequence number for custom prefixes using dynamic prefix length offset.
 * Safely ignores DRAFT- entries and mismatched prefixes.
 */
export function extractSequenceNumber(invoiceNumber: string, prefix: string): number {
  const trimmed = invoiceNumber.trim();
  if (!trimmed || trimmed.toUpperCase().startsWith('DRAFT-')) {
    return 0;
  }
  if (!trimmed.startsWith(prefix)) {
    return 0;
  }
  const numericPart = trimmed.substring(prefix.length);
  if (!/^\d+$/.test(numericPart)) return 0;
  const parsed = parseInt(numericPart, 10);
  return isNaN(parsed) ? 0 : parsed;
}

/**
 * Generates the next sequential document number from existing numbers without .length+1 collisions.
 */
export function getNextSequentialDocNumber(
  existingNumbers: string[],
  prefix: string,
  minNext = 1
): string {
  let maxSeq = 0;
  for (const numStr of existingNumbers) {
    const seq = extractSequenceNumber(numStr, prefix);
    if (seq > maxSeq) maxSeq = seq;
  }
  const nextNum = Math.max(maxSeq + 1, minNext);
  return `${prefix}${String(nextNum).padStart(4, '0')}`;
}

export interface DashboardMetrics {
  totalInvoicedCents: number;
  totalCollectedCents: number;
  pendingBalanceCents: number;
  overdueAmountCents: number;
  overdueInvoices: any[];
  taxCollectedOnPaymentsCents: number;
  totalExpenseGrossCents: number;
  totalExpenseTaxCents: number;
  taxLiabilityCents: number;
  netRevenueExclTaxCents: number;
  netExpenseExclTaxCents: number;
  netProfitCents: number;
}

/**
 * Computes executive dashboard cash-flow metrics with strict Net Profit tax isolation.
 */
export function calculateDashboardMetrics(invoices: any[], expenses: any[]): DashboardMetrics {
  const activeInvoices = invoices.filter((inv) => {
    const st = String(inv.status || '').toUpperCase();
    return st !== 'DRAFT' && st !== 'VOID';
  });

  const today = new Date();
  today.setHours(0, 0, 0, 0);

  let totalInvoicedCents = 0;
  let totalCollectedCents = 0;
  let pendingBalanceCents = 0;
  let overdueAmountCents = 0;
  let taxCollectedOnPaymentsCents = 0;
  const overdueInvoices: any[] = [];

  for (const inv of activeInvoices) {
    const total = inv.total_cents || 0;
    const paid = inv.paid_cents || 0;
    const balance = inv.balance_due_cents ?? Math.max(0, total - paid);
    const tax = inv.tax_cents || 0;

    totalInvoicedCents += total;
    totalCollectedCents += paid;
    pendingBalanceCents += balance;
    taxCollectedOnPaymentsCents += calculateCollectedTaxPortion(paid, tax, total);

    if (inv.due_date && balance > 0) {
      const due = new Date(inv.due_date);
      if (!isNaN(due.getTime())) {
        due.setHours(0, 0, 0, 0);
        if (today > due) {
          overdueInvoices.push(inv);
          overdueAmountCents += balance;
        }
      }
    }
  }

  let totalExpenseGrossCents = 0;
  let totalExpenseTaxCents = 0;
  for (const exp of expenses) {
    totalExpenseGrossCents += exp.total_cents || 0;
    totalExpenseTaxCents += exp.tax_cents || 0;
  }

  const netRevenueExclTaxCents = totalCollectedCents - taxCollectedOnPaymentsCents;
  const netExpenseExclTaxCents = Math.max(0, totalExpenseGrossCents - totalExpenseTaxCents);
  const taxLiabilityCents = taxCollectedOnPaymentsCents - totalExpenseTaxCents;
  const netProfitCents = netRevenueExclTaxCents - netExpenseExclTaxCents;

  return {
    totalInvoicedCents,
    totalCollectedCents,
    pendingBalanceCents,
    overdueAmountCents,
    overdueInvoices,
    taxCollectedOnPaymentsCents,
    totalExpenseGrossCents,
    totalExpenseTaxCents,
    taxLiabilityCents,
    netRevenueExclTaxCents,
    netExpenseExclTaxCents,
    netProfitCents,
  };
}

/**
 * Dynamically constructs standard UPI payment URL or appends invoice reference to payment URLs.
 */
export function generateDynamicQrPayload(
  rawPayload: string,
  businessName: string,
  balanceDueUnits: number,
  currencyDecimals: number,
  invoiceNumber: string,
  currencyCode = 'INR'
): string {
  const trimmed = rawPayload.trim();
  if (!trimmed) return '';

  let vpa = '';
  if (trimmed.startsWith('upi://pay')) {
    try {
      const url = new URL(trimmed);
      vpa = url.searchParams.get('pa') || '';
    } catch {
      const match = trimmed.match(/[?&]pa=([^&]+)/);
      if (match) vpa = decodeURIComponent(match[1]);
    }
  } else if (trimmed.includes('@') && !trimmed.startsWith('http')) {
    vpa = trimmed;
  }

  if (vpa) {
    const encodedName = encodeURIComponent(businessName.trim() || 'Business');
    const amountStr = currencyDecimals === 0
      ? Math.max(0, Math.round(balanceDueUnits)).toString()
      : (Math.max(0, Math.round(balanceDueUnits)) / 100).toFixed(2);
    const safeInv = encodeURIComponent(`Invoice-${invoiceNumber}`);
    const safeCu = encodeURIComponent(currencyCode || 'INR');
    return `upi://pay?pa=${encodeURIComponent(vpa)}&pn=${encodedName}&am=${amountStr}&tn=${safeInv}&cu=${safeCu}`;
  }

  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    try {
      const url = new URL(trimmed);
      if (!url.searchParams.has('ref') && !url.searchParams.has('invoice')) {
        url.searchParams.set('invoice', invoiceNumber);
      }
      return url.toString();
    } catch {
      const sep = trimmed.includes('?') ? '&' : '?';
      return `${trimmed}${sep}invoice=${encodeURIComponent(invoiceNumber)}`;
    }
  }

  return trimmed;
}

/**
 * Validates parsed backup JSON snapshot before mutating application state.
 */
export function validateBackupPayload(data: unknown): {
  valid: boolean;
  error?: string;
} {
  if (!data || typeof data !== 'object' || Array.isArray(data)) {
    return {
      valid: false,
      error: 'Invalid backup file: Root payload must be a JSON object.',
    };
  }

  const record = data as Record<string, unknown>;
  if (!Array.isArray(record.clients) || !Array.isArray(record.invoices)) {
    return {
      valid: false,
      error: 'Invalid backup file: Missing required "clients" or "invoices" collections.',
    };
  }

  const tableKeys = ['clients', 'invoices', 'estimates', 'expenses', 'savedItems'] as const;
  for (const key of tableKeys) {
    const val = record[key];
    if (val === undefined) continue;
    if (!Array.isArray(val)) {
      return {
        valid: false,
        error: `Invalid backup file: "${key}" must be an array.`,
      };
    }
    for (const item of val) {
      if (!item || typeof item !== 'object' || Array.isArray(item)) {
        return {
          valid: false,
          error: `Invalid backup file: Entries in "${key}" must be JSON objects.`,
        };
      }
    }
  }

  if (
    record.businessProfile !== undefined &&
    (!record.businessProfile ||
      typeof record.businessProfile !== 'object' ||
      Array.isArray(record.businessProfile))
  ) {
    return {
      valid: false,
      error: 'Invalid backup file: "businessProfile" must be a JSON object.',
    };
  }

  return { valid: true };
}

/**
 * Normalizes a raw phone string for tel:/sms: URIs.
 * Preserves a single leading '+' for E.164 numbers and strips formatting characters.
 */
export function normalizePhoneForUri(phone: string): string {
  const trimmed = phone.trim();
  if (!trimmed) return '';
  const hasPlus = trimmed.startsWith('+');
  const digits = trimmed.replace(/[^0-9]/g, '');
  if (!digits) return '';
  return hasPlus ? `+${digits}` : digits;
}

/**
 * Returns digits-only phone number for wa.me links (strips '+').
 */
export function buildWhatsAppDigits(phone: string): string {
  return phone.replace(/[^0-9]/g, '');
}

/**
 * Builds a standardized, currency-aware payment reminder message.
 */
export function buildPaymentReminderMessage(params: {
  invoiceNumber: string;
  clientName: string;
  balanceDueUnits: number;
  currencySymbol: string;
  currencyDecimals: number;
  dueDate: string;
  businessName: string;
}): string {
  const formattedAmount = formatMoney(
    params.balanceDueUnits,
    params.currencySymbol,
    params.currencyDecimals
  );
  const safeClient = params.clientName.trim() || 'Client';
  const safeBusiness = params.businessName.trim() || 'Accounts Team';
  const safeDue = params.dueDate.trim() || 'recently';

  return `Hi ${safeClient}, hope you're doing well! This is a polite note that Invoice ${params.invoiceNumber} for ${formattedAmount} was due on ${safeDue}. Please let us know if you need any assistance with remittance. Thank you! - ${safeBusiness}`;
}

/**
 * Builds a WhatsApp wa.me URL, pre-filling recipient digits when available.
 */
export function buildWhatsAppUrl(phone: string, message: string): string {
  const digits = buildWhatsAppDigits(phone);
  return `https://wa.me/${digits}?text=${encodeURIComponent(message)}`;
}

/**
 * Builds a mailto: URL, pre-filling recipient email when available.
 */
export function buildMailtoUrl(email: string, subject: string, body: string): string {
  const cleanEmail = email.trim();
  return `mailto:${cleanEmail}?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(body)}`;
}

/**
 * Builds an sms: URL for a normalized phone number, or null when phone is empty.
 */
export function buildSmsUrl(phone: string, body = ''): string | null {
  const normalized = normalizePhoneForUri(phone);
  if (!normalized) return null;
  if (!body) return `sms:${normalized}`;
  return `sms:${normalized}?body=${encodeURIComponent(body)}`;
}

/**
 * Builds a tel: URL for a normalized phone number, or null when phone is empty.
 */
export function buildTelUrl(phone: string): string | null {
  const normalized = normalizePhoneForUri(phone);
  if (!normalized) return null;
  return `tel:${normalized}`;
}

export function normalizeTaxMode(raw?: string | null): TaxMode {
  const trimmed = (raw ?? '').trim();
  if ((Object.keys(TAX_MODE_LABELS) as string[]).includes(trimmed)) {
    return trimmed as TaxMode;
  }
  return 'standard';
}

export function isZeroRatedTaxMode(mode?: string | null): boolean {
  const normalized = normalizeTaxMode(mode);
  return (
    normalized === 'in_lut' ||
    normalized === 'eu_reverse_charge' ||
    normalized === 'us_exempt'
  );
}

/**
 * Computes authoritative total tax minor units for a document based on its tax compliance mode.
 */
export function computeRegionalTaxCents(params: {
  netSubtotalCents: number;
  taxMode: string;
  taxPercentage: number;
  pstRatePercentage?: number;
  itemsTaxSumCents?: number;
}): number {
  const mode = normalizeTaxMode(params.taxMode);
  if (isZeroRatedTaxMode(mode)) return 0;

  const itemsTaxSum = params.itemsTaxSumCents ?? 0;
  if (mode === 'ca_dual') {
    const gstCents =
      itemsTaxSum > 0
        ? itemsTaxSum
        : calculateTaxCents(params.netSubtotalCents, params.taxPercentage);
    const pstCents = calculateTaxCents(
      params.netSubtotalCents,
      params.pstRatePercentage ?? 0
    );
    return gstCents + pstCents;
  }

  return itemsTaxSum > 0
    ? itemsTaxSum
    : calculateTaxCents(params.netSubtotalCents, params.taxPercentage);
}

/**
 * Resolves itemized tax summary lines and statutory compliance banners for UI rendering.
 */
export function resolveRegionalTaxBreakdown(params: {
  taxMode?: string;
  netSubtotalCents: number;
  taxCents: number;
  pstRatePercentage?: number;
  taxExemptionId?: string;
  businessTaxId?: string;
  clientTaxId?: string;
  fallbackAutoDetect?: boolean;
  clientAddress?: string;
  notes?: string;
  terms?: string;
}): RegionalTaxBreakdown {
  let effectiveMode = normalizeTaxMode(params.taxMode);
  const safeTax = Math.max(0, Math.round(params.taxCents || 0));

  if (params.fallbackAutoDetect && effectiveMode === 'standard' && safeTax === 0) {
    const cTax = (params.clientTaxId || '').trim().toUpperCase();
    const cAddr = (params.clientAddress || '').trim().toUpperCase();
    const invNotes = (params.notes || '').toUpperCase();
    const invTerms = (params.terms || '').toUpperCase();

    const isExport =
      cAddr.includes('USA') ||
      cAddr.includes('UNITED STATES') ||
      cAddr.includes('EXPORT') ||
      cAddr.includes('INTERNATIONAL') ||
      cAddr.includes('UK') ||
      cAddr.includes('LONDON') ||
      cAddr.includes('DUBAI') ||
      cAddr.includes('SINGAPORE') ||
      cAddr.includes('LUT') ||
      invNotes.includes('EXPORT') ||
      invTerms.includes('EXPORT');

    const isEuVat =
      cTax.startsWith('GB') ||
      cTax.startsWith('DE') ||
      cTax.startsWith('FR') ||
      cTax.startsWith('NL') ||
      cTax.startsWith('IE') ||
      cTax.startsWith('IT') ||
      cTax.startsWith('ES') ||
      cTax.startsWith('BE') ||
      cTax.startsWith('AT') ||
      cTax.startsWith('SE') ||
      cTax.startsWith('DK') ||
      cTax.startsWith('FI') ||
      cTax.startsWith('PL') ||
      cTax.startsWith('CZ') ||
      cTax.startsWith('PT') ||
      cTax.startsWith('RO') ||
      cTax.startsWith('HU') ||
      cTax.startsWith('GR') ||
      cTax.includes('VAT');

    if (isExport) {
      effectiveMode = 'in_lut';
    } else if (isEuVat) {
      effectiveMode = 'eu_reverse_charge';
    }
  }

  switch (effectiveMode) {
    case 'in_intra': {
      if (safeTax === 0) {
        return {
          effectiveMode: 'in_intra',
          lines: [{ label: 'CGST / SGST (0%)', cents: 0 }],
          totalTaxCents: 0,
          noticeTitle: '',
          noticeText: '',
          isZeroRated: false,
        };
      }
      const split = calculateGstSplit(safeTax, true);
      return {
        effectiveMode: 'in_intra',
        lines: [
          { label: 'CGST (50% Split)', cents: split.cgstCents },
          { label: 'SGST (50% Split)', cents: split.sgstCents },
        ],
        totalTaxCents: safeTax,
        noticeTitle: '',
        noticeText: '',
        isZeroRated: false,
      };
    }

    case 'in_inter': {
      const split = calculateGstSplit(safeTax, false);
      return {
        effectiveMode: 'in_inter',
        lines: [{ label: 'IGST (100%)', cents: split.igstCents }],
        totalTaxCents: safeTax,
        noticeTitle: '',
        noticeText: '',
        isZeroRated: false,
      };
    }

    case 'in_lut':
      return {
        effectiveMode: 'in_lut',
        lines: [{ label: 'IGST (0% Export LUT)', cents: 0 }],
        totalTaxCents: 0,
        noticeTitle: 'EXPORT UNDER LUT (RULE 96A)',
        noticeText: getLutNotice(true),
        isZeroRated: true,
      };

    case 'eu_vat':
      return {
        effectiveMode: 'eu_vat',
        lines: [{ label: safeTax > 0 ? 'VAT' : 'VAT (0%)', cents: safeTax }],
        totalTaxCents: safeTax,
        noticeTitle: '',
        noticeText: '',
        isZeroRated: false,
      };

    case 'eu_reverse_charge':
      return {
        effectiveMode: 'eu_reverse_charge',
        lines: [{ label: 'VAT (0% Reverse Charge)', cents: 0 }],
        totalTaxCents: 0,
        noticeTitle: 'EU / UK B2B REVERSE CHARGE',
        noticeText: getEuReverseChargeNotice(true),
        isZeroRated: true,
      };

    case 'ca_dual': {
      if (safeTax === 0) {
        return {
          effectiveMode: 'ca_dual',
          lines: [
            { label: 'GST', cents: 0 },
            { label: 'PST', cents: 0 },
          ],
          totalTaxCents: 0,
          noticeTitle: '',
          noticeText: '',
          isZeroRated: false,
        };
      }
      const pstPct = params.pstRatePercentage ?? 0;
      const rawPst = calculateTaxCents(params.netSubtotalCents, pstPct);
      const pstCents = Math.min(safeTax, rawPst);
      const gstCents = safeTax - pstCents;
      return {
        effectiveMode: 'ca_dual',
        lines: [
          { label: 'GST', cents: gstCents },
          { label: pstPct > 0 ? `PST (${pstPct}%)` : 'PST', cents: pstCents },
        ],
        totalTaxCents: safeTax,
        noticeTitle: '',
        noticeText: '',
        isZeroRated: false,
      };
    }

    case 'gulf_vat': {
      const trnParts: string[] = [];
      if ((params.businessTaxId || '').trim()) {
        trnParts.push(`Supplier TRN / VAT ID: ${(params.businessTaxId || '').trim()}`);
      }
      if ((params.clientTaxId || '').trim()) {
        trnParts.push(`Customer TRN / VAT ID: ${(params.clientTaxId || '').trim()}`);
      }
      return {
        effectiveMode: 'gulf_vat',
        lines: [{ label: safeTax > 0 ? 'VAT' : 'VAT (0%)', cents: safeTax }],
        totalTaxCents: safeTax,
        noticeTitle: trnParts.length > 0 ? 'GCC / GULF TAX INVOICE' : '',
        noticeText: trnParts.join('  •  '),
        isZeroRated: false,
      };
    }

    case 'us_exempt': {
      const cleanExemptId = (params.taxExemptionId || '').trim();
      return {
        effectiveMode: 'us_exempt',
        lines: [{ label: 'Tax (0% Exempt)', cents: 0 }],
        totalTaxCents: 0,
        noticeTitle: 'US SALES TAX-EXEMPT SUPPLY',
        noticeText: cleanExemptId
          ? `Tax-Exempt Supply — Client Exemption Certificate ID: ${cleanExemptId}`
          : 'Tax-Exempt Supply — Zero sales tax assessed.',
        isZeroRated: true,
      };
    }

    case 'standard':
    default:
      return {
        effectiveMode: 'standard',
        lines: [
          {
            label: safeTax > 0 ? 'Tax' : 'Tax (0% / Exempt)',
            cents: safeTax,
          },
        ],
        totalTaxCents: safeTax,
        noticeTitle: '',
        noticeText: '',
        isZeroRated: false,
      };
  }
}

export function getRegionalTaxIdLabel(taxMode?: string | null, isClient = false): string {
  const mode = normalizeTaxMode(taxMode);
  const prefix = isClient ? 'Client ' : '';
  if (mode === 'in_intra' || mode === 'in_inter' || mode === 'in_lut') {
    return `${prefix}GSTIN`;
  }
  if (mode === 'gulf_vat') {
    return `${prefix}TRN / VAT ID`;
  }
  if (mode === 'eu_vat' || mode === 'eu_reverse_charge') {
    return `${prefix}VAT ID`;
  }
  return `${prefix}Tax ID`;
}


