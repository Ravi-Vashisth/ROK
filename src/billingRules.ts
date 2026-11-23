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
 * Determines decimal exponent (0, 2, or 3) for currency code or symbol.
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
  if (
    upper === 'KWD' ||
    upper === 'BHD' ||
    upper === 'OMR' ||
    upper === 'JOD' ||
    upper === 'TND'
  ) {
    return 3;
  }
  return 2;
}

/**
 * Maps ISO currency code to its canonical display symbol cleanly.
 */
export function currencySymbolForCode(currencyCode: string): string {
  const upper = (currencyCode || '').trim().toUpperCase();
  switch (upper) {
    case 'USD':
      return '$';
    case 'INR':
      return '₹';
    case 'EUR':
      return '€';
    case 'GBP':
      return '£';
    case 'JPY':
      return '¥';
    case 'KRW':
      return '₩';
    case 'VND':
      return '₫';
    case 'CAD':
      return 'C$';
    case 'AUD':
      return 'A$';
    case '':
      return '$';
    default:
      return upper;
  }
}

/**
 * Formats an unsigned integer part with deterministic digit grouping independent of OS locale.
 * Uses Indian numbering (12,34,567) when currencyCode is 'INR', otherwise standard 3-digit grouping.
 */
export function formatIntegerGrouped(absWhole: number, currencyCode = ''): string {
  const digits = String(Math.floor(Math.abs(absWhole)));
  if (digits.length <= 3) return digits;

  if ((currencyCode || '').trim().toUpperCase() === 'INR') {
    const tail = digits.slice(-3);
    const prefix = digits.slice(0, -3);
    const chunks: string[] = [];
    for (let i = prefix.length; i > 0; i -= 2) {
      const start = Math.max(0, i - 2);
      chunks.push(prefix.slice(start, i));
    }
    return `${chunks.reverse().join(',')},${tail}`;
  }

  const chunks: string[] = [];
  for (let i = digits.length; i > 0; i -= 3) {
    const start = Math.max(0, i - 3);
    chunks.push(digits.slice(start, i));
  }
  return chunks.reverse().join(',');
}

function clampDecimals(decimals: number): number {
  const safe = Math.floor(decimals);
  if (safe < 0) return 0;
  if (safe > 6) return 6;
  return safe;
}

function pow10Int(decimals: number): number {
  const safe = clampDecimals(decimals);
  let scale = 1;
  for (let i = 0; i < safe; i++) {
    scale *= 10;
  }
  return scale;
}

/**
 * Parses user input price into minor units based on currency decimals exponent.
 * Rejects negative inputs cleanly (returns 0) and applies round-half-up on extra fractional digits
 * instead of silently truncating.
 */
export function parsePriceToUnits(input: string, decimals: number = 2): number {
  const trimmed = input.trim();
  if (!trimmed) return 0;

  // Reject negative sign anywhere before digits cleanly
  if (/^[^\d.]*-/.test(trimmed)) return 0;

  const cleaned = trimmed.replace(/[^\d.]/g, '');
  if (!cleaned) return 0;

  const safeDecimals = clampDecimals(decimals);
  const dotIdx = cleaned.indexOf('.');
  const wholeStr = dotIdx === -1 ? cleaned : cleaned.slice(0, dotIdx);
  const rawFrac = dotIdx === -1 ? '' : cleaned.slice(dotIdx + 1).replace(/\./g, '');
  const whole = wholeStr ? (parseInt(wholeStr, 10) || 0) : 0;

  if (safeDecimals === 0) {
    const roundUp = rawFrac.length > 0 && rawFrac.charCodeAt(0) >= 53;
    return whole + (roundUp ? 1 : 0);
  }

  const scale = pow10Int(safeDecimals);
  const padded = rawFrac.padEnd(safeDecimals, '0');
  const fracSlice = padded.slice(0, safeDecimals);
  let fracUnits = parseInt(fracSlice, 10) || 0;

  // Round half-up on the (decimals + 1)-th fractional digit instead of silent truncation
  if (rawFrac.length > safeDecimals && rawFrac.charCodeAt(safeDecimals) >= 53) {
    fracUnits += 1;
  }

  return whole * scale + fracUnits;
}

/**
 * Parses user input price (e.g. "15.50" or "$15.50") into integer minor units without float imprecision.
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
 * Parses a YYYY-MM-DD string as a local calendar Date (eliminates UTC-midnight -1 day shift).
 * Falls back cleanly for full ISO timestamps and rejects invalid calendar dates (e.g., 2026-02-31).
 */
export function parseLocalCalendarDate(dateStr: string): Date | null {
  if (!dateStr || typeof dateStr !== 'string') return null;
  const trimmed = dateStr.trim();
  if (!trimmed) return null;

  const ymdMatch = /^(\d{4})-(\d{1,2})-(\d{1,2})$/.exec(trimmed);
  if (ymdMatch) {
    const y = parseInt(ymdMatch[1], 10);
    const m = parseInt(ymdMatch[2], 10);
    const d = parseInt(ymdMatch[3], 10);
    const parsed = new Date(y, m - 1, d);
    if (
      parsed.getFullYear() !== y ||
      parsed.getMonth() !== m - 1 ||
      parsed.getDate() !== d
    ) {
      return null;
    }
    return parsed;
  }

  const parsed = new Date(trimmed);
  if (isNaN(parsed.getTime())) return null;
  return new Date(parsed.getFullYear(), parsed.getMonth(), parsed.getDate());
}

/**
 * Formats a Date into local calendar YYYY-MM-DD (never uses UTC toISOString()).
 */
export function formatLocalCalendarDate(date: Date = new Date()): string {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

/**
 * Calculates due date string (YYYY-MM-DD) based on issue date and payment terms.
 */
export function calculateDueDate(
  issueDateStr: string,
  paymentTerms: string,
  referenceNow?: Date
): string {
  const baseDate = parseLocalCalendarDate(issueDateStr) ?? (referenceNow ? new Date(referenceNow) : new Date());

  let daysToAdd = 0;
  if (paymentTerms === 'Net 15 Days') daysToAdd = 15;
  if (paymentTerms === 'Net 30 Days') daysToAdd = 30;
  if (paymentTerms === 'Net 60 Days') daysToAdd = 60;

  const due = new Date(
    baseDate.getFullYear(),
    baseDate.getMonth(),
    baseDate.getDate() + daysToAdd
  );

  return formatLocalCalendarDate(due);
}

/**
 * Determines whether an invoice is overdue based on status, paid state, and due date.
 */
export function isInvoiceOverdue(
  status: string,
  dueDateStr: string,
  isFullyPaid = false,
  referenceNow?: Date
): boolean {
  if (isFullyPaid || status.toUpperCase() === 'PAID' || status.toUpperCase() === 'DRAFT' || status.toUpperCase() === 'VOID') return false;
  const dueDay = parseLocalCalendarDate(dueDateStr);
  if (!dueDay) return false;
  const now = referenceNow ?? new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  return today.getTime() > dueDay.getTime();
}

/**
 * Resolves real-time dynamic status for an invoice.
 */
export function resolveDynamicStatus(
  totalCents: number,
  paidCents: number,
  dueDateStr: string,
  manualStatus = 'PENDING',
  referenceNow?: Date
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
  if (isInvoiceOverdue(manualStatus, dueDateStr, false, referenceNow)) {
    return 'OVERDUE';
  }
  return 'PENDING';
}

/**
 * Calculates number of days an invoice is past due using DST-safe calendar day arithmetic.
 */
export function calculateDaysOverdue(dueDateStr: string, referenceNow?: Date): number {
  const dueDay = parseLocalCalendarDate(dueDateStr);
  if (!dueDay) return 0;
  const now = referenceNow ?? new Date();
  const todayUtc = Date.UTC(now.getFullYear(), now.getMonth(), now.getDate());
  const dueUtc = Date.UTC(dueDay.getFullYear(), dueDay.getMonth(), dueDay.getDate());
  const diffDays = Math.floor((todayUtc - dueUtc) / 86400000);
  return diffDays > 0 ? diffDays : 0;
}

/**
 * Formats minor units as formatted currency string using pure integer arithmetic.
 */
export function formatMoney(
  units: number,
  symbol = '$',
  decimals = 2,
  currencyCode = ''
): string {
  const safeUnits = Math.round(units);
  const safeDecimals = clampDecimals(decimals);
  const isNegative = safeUnits < 0;
  const absUnits = isNegative ? -safeUnits : safeUnits;
  const effectiveCode = currencyCode.trim()
    ? currencyCode.trim().toUpperCase()
    : (symbol.trim() === '₹' ? 'INR' : '');

  if (safeDecimals === 0) {
    const wholeFormatted = formatIntegerGrouped(absUnits, effectiveCode);
    return `${isNegative ? '-' : ''}${symbol}${wholeFormatted}`;
  }

  const scale = pow10Int(safeDecimals);
  const whole = Math.floor(absUnits / scale);
  const frac = absUnits % scale;
  const wholeFormatted = formatIntegerGrouped(whole, effectiveCode);
  const fracStr = String(frac).padStart(safeDecimals, '0');
  return `${isNegative ? '-' : ''}${symbol}${wholeFormatted}.${fracStr}`;
}

/**
 * Formats minor units into an input-friendly or CSV decimal string (0, 2, or 3 decimals).
 */
export function formatDecimalUnits(units: number, decimals = 2): string {
  const safeUnits = Math.round(units);
  const safeDecimals = clampDecimals(decimals);
  if (safeDecimals === 0) {
    return String(safeUnits);
  }
  const isNegative = safeUnits < 0;
  const absUnits = isNegative ? -safeUnits : safeUnits;
  const scale = pow10Int(safeDecimals);
  const whole = Math.floor(absUnits / scale);
  const frac = absUnits % scale;
  const fracStr = String(frac).padStart(safeDecimals, '0');
  return `${isNegative ? '-' : ''}${whole}.${fracStr}`;
}

/**
 * UI display formatting with dynamic currency symbol and decimal exponent.
 */
export function formatCents(
  cents: number,
  symbol = '$',
  decimals = 2,
  currencyCode = ''
): string {
  return formatMoney(cents, symbol, decimals, currencyCode);
}

/**
 * Neutralizes spreadsheet formula-injection prefixes (=, +, -, @, \t, \r)
 * so Excel, Google Sheets, and LibreOffice treat exported cells as plain text.
 */
export function sanitizeCsvCell(value: string): string {
  if (!value) return value;
  const first = value[0];
  const trimmedLeft = value.trimStart();
  if (
    first === '=' ||
    first === '+' ||
    first === '-' ||
    first === '@' ||
    first === '\t' ||
    first === '\r' ||
    (trimmedLeft.length > 0 &&
      (trimmedLeft[0] === '=' ||
        trimmedLeft[0] === '+' ||
        trimmedLeft[0] === '-' ||
        trimmedLeft[0] === '@'))
  ) {
    return `'${value}`;
  }
  return value;
}

/**
 * Quotes and escapes a CSV text field after neutralizing formula-injection prefixes.
 */
export function quoteCsvField(value: string): string {
  const safe = sanitizeCsvCell(String(value ?? ''));
  return `"${safe.replace(/"/g, '""')}"`;
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
    const dec = inv.currencyDecimals ?? getCurrencyDecimals(inv.currencyCode || symbol);
    const invSym = inv.currencySymbol || symbol;
    rows.push([
      sanitizeCsvCell(inv.invoiceNumber),
      sanitizeCsvCell(inv.issueDate),
      sanitizeCsvCell(inv.dueDate),
      sanitizeCsvCell(inv.clientName),
      sanitizeCsvCell(clientTaxId),
      formatCents(inv.subtotalCents, invSym, dec),
      formatCents(inv.taxCents, invSym, dec),
      formatCents(inv.totalCents, invSym, dec),
      formatCents(inv.paidCents || 0, invSym, dec),
      formatCents(inv.balanceDueCents ?? inv.totalCents, invSym, dec),
      sanitizeCsvCell(inv.status),
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
 * Generates single-table Accountant Invoices CSV (1:1 mirror of Flutter CsvExportService.generateInvoicesCsv).
 */
export function exportInvoicesToCsv(
  invoices: any[],
  clients: any[],
  defaultCurrencyCode = 'USD'
): string {
  const fallbackCode = defaultCurrencyCode.trim() || 'USD';
  const lines = [
    'Invoice Number,Issue Date,Due Date,Currency Code,Client Name,Client Tax ID,Subtotal,Tax,Total,Amount Paid,Balance Due,Status',
  ];

  for (const inv of invoices) {
    const rawStatus = String(inv.computed_status || inv.status || '').toUpperCase();
    if (rawStatus === 'DRAFT') continue;

    const isVoid = rawStatus === 'VOID';
    const paidUnits = inv.paid_cents ?? inv.paidCents ?? 0;
    const totalUnits = inv.total_cents ?? inv.totalCents ?? 0;
    const subtotalUnits = inv.subtotal_cents ?? inv.subtotalCents ?? 0;
    const taxUnits = inv.tax_cents ?? inv.taxCents ?? 0;
    const dueUnits = isVoid ? 0 : Math.max(0, totalUnits - paidUnits);
    const clientId = inv.client_id ?? inv.clientId ?? '';
    const client = clients.find((c) => c.id === clientId);
    const taxId = client?.tax_id ?? client?.taxId ?? '';
    const rawCode = String(inv.currency_code ?? inv.currencyCode ?? '').trim();
    const isoCode = rawCode || fallbackCode;
    const rawDec = inv.currency_decimals ?? inv.currencyDecimals;
    const dec = rawCode && rawDec !== undefined && rawDec !== null ? clampDecimals(rawDec) : getCurrencyDecimals(isoCode);
    const invNum = inv.invoice_number ?? inv.invoiceNumber ?? '';
    const issueDate = inv.issue_date ?? inv.issueDate ?? '';
    const dueDate = inv.due_date ?? inv.dueDate ?? '';
    const clientName = inv.client_name ?? inv.clientName ?? '';

    lines.push(
      [
        quoteCsvField(invNum),
        quoteCsvField(issueDate),
        quoteCsvField(dueDate),
        quoteCsvField(isoCode),
        quoteCsvField(clientName),
        quoteCsvField(taxId),
        formatDecimalUnits(subtotalUnits, dec),
        formatDecimalUnits(taxUnits, dec),
        formatDecimalUnits(totalUnits, dec),
        formatDecimalUnits(paidUnits, dec),
        formatDecimalUnits(dueUnits, dec),
        quoteCsvField(isVoid ? 'VOID' : rawStatus),
      ].join(',')
    );
  }

  return '\uFEFF' + lines.join('\n');
}

/**
 * Generates single-table Accountant Expenses CSV (1:1 mirror of Flutter CsvExportService.generateExpensesCsv).
 */
export function exportExpensesToCsv(
  expenses: any[],
  currencyCode = 'USD'
): string {
  const fallbackCode = currencyCode.trim().toUpperCase() || 'USD';
  const fallbackDec = getCurrencyDecimals(fallbackCode);
  const lines = ['Expense ID,Date,Category,Vendor,Currency Code,Amount,Tax,Total,Notes'];

  for (const exp of expenses) {
    const recCode = String(exp.currency_code ?? exp.currencyCode ?? '').trim();
    const recDec = exp.currency_decimals ?? exp.currencyDecimals;
    const resolved = resolveEffectiveCurrency({
      recordCode: recCode,
      recordDecimals: recCode && typeof recDec === 'number' ? recDec : undefined,
      defaultCode: fallbackCode,
      defaultSymbol: currencySymbolForCode(fallbackCode),
      defaultDecimals: fallbackDec,
    });
    const amountUnits = exp.amount_cents ?? exp.amountCents ?? 0;
    const taxUnits = exp.tax_cents ?? exp.taxCents ?? 0;
    const totalUnits = exp.total_cents ?? exp.totalCents ?? (amountUnits + taxUnits);
    lines.push(
      [
        quoteCsvField(exp.id || ''),
        quoteCsvField(exp.expense_date ?? exp.expenseDate ?? ''),
        quoteCsvField(exp.category || ''),
        quoteCsvField(exp.vendor || ''),
        quoteCsvField(resolved.code),
        formatDecimalUnits(amountUnits, resolved.decimals),
        formatDecimalUnits(taxUnits, resolved.decimals),
        formatDecimalUnits(totalUnits, resolved.decimals),
        quoteCsvField(exp.notes || ''),
      ].join(',')
    );
  }

  return '\uFEFF' + lines.join('\n');
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
  return parsePriceToUnits(input, 0);
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

export interface ResolvedCurrency {
  code: string;
  symbol: string;
  decimals: number;
}

export interface CurrencyAmount {
  code: string;
  symbol: string;
  decimals: number;
  amountUnits: number;
}

export interface ClientRollupSummary {
  totalBilledByCurrency: CurrencyAmount[];
  totalPaidByCurrency: CurrencyAmount[];
  outstandingByCurrency: CurrencyAmount[];
  formattedTotalBilled: string;
  formattedTotalPaid: string;
  formattedOutstandingBalance: string;
  hasOutstandingBalance: boolean;
}

export interface CurrencyDashboardMetrics {
  currencyCode: string;
  currencySymbol: string;
  currencyDecimals: number;
  totalInvoicedCents: number;
  totalCollectedCents: number;
  pendingBalanceCents: number;
  overdueAmountCents: number;
  taxCollectedOnPaymentsCents: number;
  totalExpenseGrossCents: number;
  totalExpenseTaxCents: number;
  taxLiabilityCents: number;
  netRevenueExclTaxCents: number;
  netExpenseExclTaxCents: number;
  netProfitCents: number;
}

export function resolveEffectiveCurrency(params: {
  recordCode?: string;
  recordSymbol?: string;
  recordDecimals?: number;
  defaultCode?: string;
  defaultSymbol?: string;
  defaultDecimals?: number;
}): ResolvedCurrency {
  const fallbackCode = (params.defaultCode || '').trim().toUpperCase() || 'USD';
  const fallbackSymbol = (params.defaultSymbol || '').trim() || '$';
  const fallbackDecimals =
    params.defaultDecimals !== undefined && params.defaultDecimals !== null
      ? clampDecimals(params.defaultDecimals)
      : getCurrencyDecimals(fallbackCode);

  const trimmedCode = (params.recordCode || '').trim().toUpperCase();
  const trimmedSym = (params.recordSymbol || '').trim();

  const code = trimmedCode || fallbackCode;
  const symbol = trimmedSym
    ? trimmedSym
    : trimmedCode
      ? (trimmedCode === fallbackCode ? fallbackSymbol : currencySymbolForCode(code))
      : fallbackSymbol;
  const decimals = trimmedCode
    ? clampDecimals(
        params.recordDecimals !== undefined && params.recordDecimals !== null
          ? params.recordDecimals
          : getCurrencyDecimals(code)
      )
    : fallbackDecimals;

  return { code, symbol, decimals };
}

export function formatMultiCurrencyAmounts(
  amounts: CurrencyAmount[],
  emptyFallback: string,
  separator = ' + '
): string {
  const nonZero = amounts.filter((a) => a.amountUnits !== 0);
  if (nonZero.length === 0) return emptyFallback;
  return nonZero
    .map((a) => formatMoney(a.amountUnits, a.symbol, a.decimals, a.code))
    .join(separator);
}

function compareCurrencyOrder(a: string, b: string, defaultCode: string): number {
  if (a === defaultCode && b !== defaultCode) return -1;
  if (b === defaultCode && a !== defaultCode) return 1;
  return a.localeCompare(b);
}

/**
 * Groups active (non-draft, non-void) client invoices by currencyCode so
 * mixed currencies (e.g. USD + JPY + INR) are never summed into corrupt scalars.
 */
export function computeClientRollup(
  invoices: any[],
  defaultCurrency?: { code?: string; symbol?: string; decimals?: number }
): ClientRollupSummary {
  const base = resolveEffectiveCurrency({
    defaultCode: defaultCurrency?.code,
    defaultSymbol: defaultCurrency?.symbol,
    defaultDecimals: defaultCurrency?.decimals,
  });
  const zeroFallback = formatMoney(0, base.symbol, base.decimals);

  const meta: Record<string, ResolvedCurrency> = {};
  const billedMap: Record<string, number> = {};
  const paidMap: Record<string, number> = {};
  const dueMap: Record<string, number> = {};

  for (const inv of invoices) {
    const s = String(inv.computed_status || inv.status || '').toUpperCase();
    if (s === 'DRAFT' || s === 'VOID') continue;

    const recCode = inv.currency_code ?? inv.currencyCode ?? '';
    const recSym = inv.currency_symbol ?? inv.currencySymbol ?? '';
    const recDec = inv.currency_decimals ?? inv.currencyDecimals;

    const cur = resolveEffectiveCurrency({
      recordCode: recCode,
      recordSymbol: recSym,
      recordDecimals: String(recCode).trim() ? recDec : undefined,
      defaultCode: base.code,
      defaultSymbol: base.symbol,
      defaultDecimals: base.decimals,
    });

    const total = inv.total_cents ?? inv.totalCents ?? 0;
    const paid = inv.paid_cents ?? inv.paidCents ?? 0;
    const due = Math.max(0, total - paid);

    meta[cur.code] = cur;
    billedMap[cur.code] = (billedMap[cur.code] || 0) + total;
    paidMap[cur.code] = (paidMap[cur.code] || 0) + paid;
    dueMap[cur.code] = (dueMap[cur.code] || 0) + due;
  }

  const codes = Object.keys(meta).sort((a, b) => compareCurrencyOrder(a, b, base.code));

  const billedList: CurrencyAmount[] = codes.map((c) => ({
    code: c,
    symbol: meta[c].symbol,
    decimals: meta[c].decimals,
    amountUnits: billedMap[c] || 0,
  }));
  const paidList: CurrencyAmount[] = codes.map((c) => ({
    code: c,
    symbol: meta[c].symbol,
    decimals: meta[c].decimals,
    amountUnits: paidMap[c] || 0,
  }));
  const dueList: CurrencyAmount[] = codes.map((c) => ({
    code: c,
    symbol: meta[c].symbol,
    decimals: meta[c].decimals,
    amountUnits: dueMap[c] || 0,
  }));

  return {
    totalBilledByCurrency: billedList,
    totalPaidByCurrency: paidList,
    outstandingByCurrency: dueList,
    formattedTotalBilled: formatMultiCurrencyAmounts(billedList, zeroFallback),
    formattedTotalPaid: formatMultiCurrencyAmounts(paidList, zeroFallback),
    formattedOutstandingBalance: formatMultiCurrencyAmounts(dueList, zeroFallback),
    hasOutstandingBalance: dueList.some((d) => d.amountUnits > 0),
  };
}

export interface DashboardMetrics {
  activeInvoiceCount: number;
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
  byCurrency: CurrencyDashboardMetrics[];
  formattedTotalInvoiced: string;
  formattedTotalCollected: string;
  formattedPendingBalance: string;
  formattedOverdueAmount: string;
  formattedNetProfit: string;
  formattedNetRevenueExclTax: string;
  formattedNetExpenseExclTax: string;
  formattedTaxLiability: string;
}

/**
 * Computes executive dashboard cash-flow metrics grouped strictly by currencyCode
 * with Net Profit tax isolation. Home-currency scalar fields never sum foreign currencies.
 */
export function calculateDashboardMetrics(
  invoices: any[],
  expenses: any[],
  referenceNow?: Date,
  defaultCurrency?: { code?: string; symbol?: string; decimals?: number }
): DashboardMetrics {
  const base = resolveEffectiveCurrency({
    defaultCode: defaultCurrency?.code,
    defaultSymbol: defaultCurrency?.symbol,
    defaultDecimals: defaultCurrency?.decimals,
  });
  const zeroFallback = formatMoney(0, base.symbol, base.decimals);

  const activeInvoices = invoices.filter((inv) => {
    const st = String(inv.status || '').toUpperCase();
    return st !== 'DRAFT' && st !== 'VOID';
  });

  const now = referenceNow ?? new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());

  const meta: Record<string, ResolvedCurrency> = { [base.code]: base };
  const invoicedMap: Record<string, number> = {};
  const collectedMap: Record<string, number> = {};
  const pendingMap: Record<string, number> = {};
  const overdueMap: Record<string, number> = {};
  const taxCollectedMap: Record<string, number> = {};
  const overdueInvoices: any[] = [];

  for (const inv of activeInvoices) {
    const recCode = inv.currency_code ?? inv.currencyCode ?? '';
    const recSym = inv.currency_symbol ?? inv.currencySymbol ?? '';
    const recDec = inv.currency_decimals ?? inv.currencyDecimals;

    const cur = resolveEffectiveCurrency({
      recordCode: recCode,
      recordSymbol: recSym,
      recordDecimals: String(recCode).trim() ? recDec : undefined,
      defaultCode: base.code,
      defaultSymbol: base.symbol,
      defaultDecimals: base.decimals,
    });
    meta[cur.code] = cur;

    const total = inv.total_cents || 0;
    const paid = inv.paid_cents || 0;
    const balance = inv.balance_due_cents ?? Math.max(0, total - paid);
    const tax = inv.tax_cents || 0;

    invoicedMap[cur.code] = (invoicedMap[cur.code] || 0) + total;
    collectedMap[cur.code] = (collectedMap[cur.code] || 0) + paid;
    pendingMap[cur.code] = (pendingMap[cur.code] || 0) + balance;
    taxCollectedMap[cur.code] =
      (taxCollectedMap[cur.code] || 0) + calculateCollectedTaxPortion(paid, tax, total);

    if (inv.due_date && balance > 0) {
      const due = parseLocalCalendarDate(inv.due_date);
      if (due && today.getTime() > due.getTime()) {
        overdueInvoices.push(inv);
        overdueMap[cur.code] = (overdueMap[cur.code] || 0) + balance;
      }
    }
  }

  const expenseGrossMap: Record<string, number> = {};
  const expenseTaxMap: Record<string, number> = {};
  for (const exp of expenses) {
    const recCode = exp.currency_code ?? exp.currencyCode ?? '';
    const recDec = exp.currency_decimals ?? exp.currencyDecimals;
    const cur = resolveEffectiveCurrency({
      recordCode: recCode,
      recordDecimals: String(recCode).trim() ? recDec : undefined,
      defaultCode: base.code,
      defaultSymbol: base.symbol,
      defaultDecimals: base.decimals,
    });
    meta[cur.code] = cur;
    const expGross = exp.total_cents ?? exp.totalCents ?? ((exp.amount_cents || 0) + (exp.tax_cents || 0));
    const expTax = exp.tax_cents ?? exp.taxCents ?? 0;
    expenseGrossMap[cur.code] = (expenseGrossMap[cur.code] || 0) + expGross;
    expenseTaxMap[cur.code] = (expenseTaxMap[cur.code] || 0) + expTax;
  }

  const codes = Object.keys(meta).sort((a, b) => compareCurrencyOrder(a, b, base.code));

  const byCurrency: CurrencyDashboardMetrics[] = codes.map((code) => {
    const cur = meta[code];
    const totalInvoiced = invoicedMap[code] || 0;
    const totalCollected = collectedMap[code] || 0;
    const pendingBalance = pendingMap[code] || 0;
    const overdueAmount = overdueMap[code] || 0;
    const taxCollected = taxCollectedMap[code] || 0;
    const expGross = expenseGrossMap[code] || 0;
    const expTax = expenseTaxMap[code] || 0;
    const netRevenueExclTax = totalCollected - taxCollected;
    const netExpenseExclTax = Math.max(0, expGross - expTax);
    const taxLiability = taxCollected - expTax;
    const netProfit = netRevenueExclTax - netExpenseExclTax;

    return {
      currencyCode: code,
      currencySymbol: cur.symbol,
      currencyDecimals: cur.decimals,
      totalInvoicedCents: totalInvoiced,
      totalCollectedCents: totalCollected,
      pendingBalanceCents: pendingBalance,
      overdueAmountCents: overdueAmount,
      taxCollectedOnPaymentsCents: taxCollected,
      totalExpenseGrossCents: expGross,
      totalExpenseTaxCents: expTax,
      taxLiabilityCents: taxLiability,
      netRevenueExclTaxCents: netRevenueExclTax,
      netExpenseExclTaxCents: netExpenseExclTax,
      netProfitCents: netProfit,
    };
  });

  const homeBucket = byCurrency.find((b) => b.currencyCode === base.code)!;

  const pickAmounts = (picker: (b: CurrencyDashboardMetrics) => number): CurrencyAmount[] =>
    byCurrency.map((b) => ({
      code: b.currencyCode,
      symbol: b.currencySymbol,
      decimals: b.currencyDecimals,
      amountUnits: picker(b),
    }));

  return {
    activeInvoiceCount: activeInvoices.length,
    totalInvoicedCents: homeBucket.totalInvoicedCents,
    totalCollectedCents: homeBucket.totalCollectedCents,
    pendingBalanceCents: homeBucket.pendingBalanceCents,
    overdueAmountCents: homeBucket.overdueAmountCents,
    overdueInvoices,
    taxCollectedOnPaymentsCents: homeBucket.taxCollectedOnPaymentsCents,
    totalExpenseGrossCents: homeBucket.totalExpenseGrossCents,
    totalExpenseTaxCents: homeBucket.totalExpenseTaxCents,
    taxLiabilityCents: homeBucket.taxLiabilityCents,
    netRevenueExclTaxCents: homeBucket.netRevenueExclTaxCents,
    netExpenseExclTaxCents: homeBucket.netExpenseExclTaxCents,
    netProfitCents: homeBucket.netProfitCents,
    byCurrency,
    formattedTotalInvoiced: formatMultiCurrencyAmounts(
      pickAmounts((b) => b.totalInvoicedCents),
      zeroFallback
    ),
    formattedTotalCollected: formatMultiCurrencyAmounts(
      pickAmounts((b) => b.totalCollectedCents),
      zeroFallback
    ),
    formattedPendingBalance: formatMultiCurrencyAmounts(
      pickAmounts((b) => b.pendingBalanceCents),
      zeroFallback
    ),
    formattedOverdueAmount: formatMultiCurrencyAmounts(
      pickAmounts((b) => b.overdueAmountCents),
      zeroFallback
    ),
    formattedNetProfit: formatMultiCurrencyAmounts(
      pickAmounts((b) => b.netProfitCents),
      zeroFallback
    ),
    formattedNetRevenueExclTax: formatMultiCurrencyAmounts(
      pickAmounts((b) => b.netRevenueExclTaxCents),
      zeroFallback
    ),
    formattedNetExpenseExclTax: formatMultiCurrencyAmounts(
      pickAmounts((b) => b.netExpenseExclTaxCents),
      zeroFallback
    ),
    formattedTaxLiability: formatMultiCurrencyAmounts(
      pickAmounts((b) => b.taxLiabilityCents),
      zeroFallback
    ),
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
    const safeUnits = Math.max(0, Math.round(balanceDueUnits));
    const amountStr = formatDecimalUnits(safeUnits, currencyDecimals);
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

interface BackupTableRule {
  requiredNonEmptyStrings: string[];
  requiredInts: string[];
  optionalInts: string[];
  optionalStrings: string[];
}

const BACKUP_TABLE_RULES: Record<string, BackupTableRule> = {
  clients: {
    requiredNonEmptyStrings: ['id', 'name'],
    requiredInts: [],
    optionalInts: [],
    optionalStrings: [
      'email',
      'phone',
      'address',
      'tax_id',
      'taxId',
      'created_at',
      'updated_at',
      'deleted_at',
    ],
  },
  invoices: {
    requiredNonEmptyStrings: ['id', 'client_id', 'invoice_number', 'status'],
    requiredInts: ['subtotal_cents', 'tax_cents', 'total_cents'],
    optionalInts: [
      'paid_cents',
      'balance_due_cents',
      'discount_value',
      'discount_cents',
      'currency_decimals',
      'pst_rate_percentage',
    ],
    optionalStrings: [
      'client_name',
      'issue_date',
      'due_date',
      'payment_terms',
      'terms',
      'notes',
      'discount_type',
      'po_number',
      'currency_code',
      'currency_symbol',
      'tax_mode',
      'tax_exemption_id',
      'computed_status',
      'created_at',
      'updated_at',
      'deleted_at',
    ],
  },
  estimates: {
    requiredNonEmptyStrings: ['id', 'client_id', 'estimate_number', 'status'],
    requiredInts: ['subtotal_cents', 'tax_cents', 'total_cents'],
    optionalInts: [
      'discount_value',
      'discount_cents',
      'currency_decimals',
      'pst_rate_percentage',
    ],
    optionalStrings: [
      'client_name',
      'issue_date',
      'expiry_date',
      'payment_terms',
      'converted_invoice_id',
      'terms',
      'notes',
      'discount_type',
      'po_number',
      'currency_code',
      'currency_symbol',
      'tax_mode',
      'tax_exemption_id',
      'created_at',
      'updated_at',
      'deleted_at',
    ],
  },
  expenses: {
    requiredNonEmptyStrings: ['id', 'category', 'vendor', 'expense_date'],
    requiredInts: ['amount_cents'],
    optionalInts: ['tax_cents', 'total_cents', 'currency_decimals', 'currencyDecimals'],
    optionalStrings: [
      'notes',
      'receipt_base64',
      'receipt_name',
      'currency_code',
      'currencyCode',
      'created_at',
      'updated_at',
      'deleted_at',
    ],
  },
  savedItems: {
    requiredNonEmptyStrings: ['id', 'title'],
    requiredInts: [],
    optionalInts: [
      'default_price_cents',
      'defaultPriceCents',
      'currency_decimals',
      'currencyDecimals',
    ],
    optionalStrings: [
      'sac_hsn',
      'sacHsn',
      'description',
      'currency_code',
      'currencyCode',
      'created_at',
      'updated_at',
      'deleted_at',
    ],
  },
};

const FLUTTER_CHILD_TABLE_RULES: Record<string, BackupTableRule> = {
  invoice_items: {
    requiredNonEmptyStrings: ['id', 'invoice_id', 'description'],
    requiredInts: ['quantity', 'unit_price_cents', 'total_cents'],
    optionalInts: ['tax_rate_percentage', 'tax_cents'],
    optionalStrings: ['sac_hsn', 'created_at', 'updated_at', 'deleted_at'],
  },
  estimate_items: {
    requiredNonEmptyStrings: ['id', 'estimate_id', 'description'],
    requiredInts: ['quantity', 'unit_price_cents', 'total_cents'],
    optionalInts: ['tax_rate_percentage', 'tax_cents'],
    optionalStrings: ['sac_hsn', 'created_at', 'updated_at', 'deleted_at'],
  },
  payments: {
    requiredNonEmptyStrings: ['id', 'invoice_id', 'payment_method', 'payment_date'],
    requiredInts: ['amount_cents'],
    optionalInts: ['amount_received_cents', 'tds_cents'],
    optionalStrings: ['reference_number', 'notes', 'created_at', 'updated_at', 'deleted_at'],
  },
};

export interface NormalizedBackupPayload {
  clients: any[];
  invoices: any[];
  estimates?: any[];
  expenses?: any[];
  savedItems?: any[];
  businessProfile?: any;
}

function isNonEmptyString(value: unknown): value is string {
  return typeof value === 'string' && value.trim().length > 0;
}

function isStrictInteger(value: unknown): value is number {
  return typeof value === 'number' && Number.isInteger(value) && Number.isFinite(value);
}

function validateTableRows(
  key: string,
  val: unknown,
  rule: BackupTableRule
): string | null {
  if (!Array.isArray(val)) {
    return `Invalid backup file: "${key}" must be an array.`;
  }
  for (let i = 0; i < val.length; i++) {
    const item = val[i];
    if (!item || typeof item !== 'object' || Array.isArray(item)) {
      return `Invalid backup file: Entries in "${key}" must be JSON objects.`;
    }
    const row = item as Record<string, unknown>;

    for (const col of rule.requiredNonEmptyStrings) {
      if (!isNonEmptyString(row[col])) {
        return `Invalid backup file: "${key}" row ${i + 1} missing required non-empty string "${col}".`;
      }
    }

    for (const col of rule.requiredInts) {
      if (!isStrictInteger(row[col])) {
        return `Invalid backup file: "${key}" row ${i + 1} requires integer value for "${col}".`;
      }
    }

    if (key === 'savedItems' || key === 'saved_items') {
      const hasSnake = row.default_price_cents !== undefined;
      const hasCamel = row.defaultPriceCents !== undefined;
      if (!hasSnake && !hasCamel) {
        return `Invalid backup file: "${key}" row ${i + 1} requires integer "default_price_cents".`;
      }
    }

    if ((key === 'invoices' || key === 'estimates') && row.items !== undefined && !Array.isArray(row.items)) {
      return `Invalid backup file: "${key}" row ${i + 1} field "items" must be an array.`;
    }

    for (const col of rule.optionalInts) {
      if (row[col] !== undefined && row[col] !== null && !isStrictInteger(row[col])) {
        return `Invalid backup file: "${key}" row ${i + 1} expected integer for "${col}".`;
      }
    }

    for (const col of rule.optionalStrings) {
      if (row[col] !== undefined && row[col] !== null && typeof row[col] !== 'string') {
        return `Invalid backup file: "${key}" row ${i + 1} expected string for "${col}".`;
      }
    }
  }
  return null;
}

function validateProfileRecord(prof: Record<string, unknown>, label: string): string | null {
  if (!isNonEmptyString(prof.business_name)) {
    return `Invalid backup file: "${label}" missing required non-empty "business_name".`;
  }
  for (const intCol of [
    'currency_decimals',
    'next_invoice_number',
    'default_pst_rate_percentage',
    'accent_color',
  ]) {
    if (prof[intCol] !== undefined && prof[intCol] !== null && !isStrictInteger(prof[intCol])) {
      return `Invalid backup file: "${label}.${intCol}" must be an integer.`;
    }
  }
  if (
    prof.next_invoice_number !== undefined &&
    prof.next_invoice_number !== null &&
    (prof.next_invoice_number as number) < 1
  ) {
    return `Invalid backup file: "${label}.next_invoice_number" must be >= 1.`;
  }
  for (const strCol of [
    'theme_mode',
    'invoice_prefix',
    'estimate_prefix',
    'payment_qr_payload',
  ]) {
    if (prof[strCol] !== undefined && prof[strCol] !== null && typeof prof[strCol] !== 'string') {
      return `Invalid backup file: "${label}.${strCol}" must be a string.`;
    }
  }
  return null;
}

/**
 * Normalizes a validated React or Flutter SQLite JSON backup into the canonical React state structure.
 */
export function normalizeBackupPayloadForWeb(record: Record<string, unknown>): NormalizedBackupPayload {
  const fallbackTs = isNonEmptyString(record.exported_at)
    ? record.exported_at.trim()
    : new Date().toISOString();

  const rawClients = Array.isArray(record.clients)
    ? (record.clients as Record<string, unknown>[]).filter((c) => !c.deleted_at)
    : [];
  const clientNameById = new Map<string, string>();
  const clients = rawClients.map((c) => {
    const id = String(c.id ?? '');
    const name = String(c.name ?? '');
    if (id) clientNameById.set(id, name);
    return {
      ...c,
      id,
      name,
      email: typeof c.email === 'string' ? c.email : '',
      phone: typeof c.phone === 'string' ? c.phone : '',
      address: typeof c.address === 'string' ? c.address : '',
      tax_id: typeof c.tax_id === 'string' ? c.tax_id : (typeof c.taxId === 'string' ? c.taxId : ''),
      created_at: isNonEmptyString(c.created_at) ? c.created_at : fallbackTs,
    };
  });

  // Group active flat Flutter invoice_items by invoice_id
  const invItemsByParent = new Map<string, any[]>();
  if (Array.isArray(record.invoice_items)) {
    for (const rawIt of record.invoice_items as Record<string, unknown>[]) {
      if (rawIt.deleted_at) continue;
      const parentId = String(rawIt.invoice_id ?? '');
      if (!parentId) continue;
      const list = invItemsByParent.get(parentId) ?? [];
      const unitPriceCents = Number(rawIt.unit_price_cents ?? rawIt.unitPriceCents ?? 0) || 0;
      const taxSlab = Number(rawIt.tax_rate_percentage ?? rawIt.taxSlab ?? 0) || 0;
      const sacHsn = String(rawIt.sac_hsn ?? rawIt.sacHsn ?? '');
      list.push({
        id: String(rawIt.id ?? generateUniqueId()),
        description: String(rawIt.description ?? ''),
        sacHsn,
        sac_hsn: sacHsn,
        quantity: Number(rawIt.quantity ?? 1) || 1,
        unitPriceCents,
        unit_price_cents: unitPriceCents,
        taxSlab,
        tax_rate_percentage: taxSlab,
        tax_cents: Number(rawIt.tax_cents ?? 0) || 0,
        total_cents: Number(rawIt.total_cents ?? 0) || 0,
      });
      invItemsByParent.set(parentId, list);
    }
  }

  // Sum Flutter payments per invoice_id
  const paidByInvoiceId = new Map<string, number>();
  if (Array.isArray(record.payments)) {
    for (const pay of record.payments as Record<string, unknown>[]) {
      if (pay.deleted_at) continue;
      const invId = String(pay.invoice_id ?? '');
      if (!invId) continue;
      const amt = Number(pay.amount_cents ?? 0) || 0;
      paidByInvoiceId.set(invId, (paidByInvoiceId.get(invId) ?? 0) + amt);
    }
  }

  const rawInvoices = Array.isArray(record.invoices)
    ? (record.invoices as Record<string, unknown>[]).filter((inv) => !inv.deleted_at)
    : [];
  const invoices = rawInvoices.map((inv) => {
    const id = String(inv.id ?? '');
    const clientId = String(inv.client_id ?? '');
    const totalCents = Number(inv.total_cents ?? 0) || 0;
    const paidCents =
      typeof inv.paid_cents === 'number'
        ? inv.paid_cents
        : (paidByInvoiceId.get(id) ?? 0);
    const upperStatus = String(inv.status ?? 'PENDING').toUpperCase();
    const balanceDueCents =
      typeof inv.balance_due_cents === 'number'
        ? inv.balance_due_cents
        : (upperStatus === 'VOID' ? 0 : Math.max(0, totalCents - paidCents));

    let computedStatus = typeof inv.computed_status === 'string' && inv.computed_status.trim()
      ? inv.computed_status
      : upperStatus;
    if (!(typeof inv.computed_status === 'string' && inv.computed_status.trim())) {
      if (upperStatus === 'VOID' || upperStatus === 'DRAFT') {
        computedStatus = upperStatus;
      } else if (totalCents > 0 && paidCents >= totalCents) {
        computedStatus = 'PAID';
      } else if (paidCents > 0) {
        computedStatus = 'PARTIALLY_PAID';
      }
    }

    const nestedItems = Array.isArray(inv.items)
      ? inv.items
      : (invItemsByParent.get(id) ?? []);

    return {
      ...inv,
      client_name: isNonEmptyString(inv.client_name)
        ? inv.client_name
        : (clientNameById.get(clientId) ?? 'Unknown Client'),
      items: nestedItems,
      paid_cents: paidCents,
      balance_due_cents: balanceDueCents,
      computed_status: computedStatus,
      created_at: isNonEmptyString(inv.created_at) ? inv.created_at : fallbackTs,
    };
  });

  // Group active flat Flutter estimate_items by estimate_id
  const estItemsByParent = new Map<string, any[]>();
  if (Array.isArray(record.estimate_items)) {
    for (const rawIt of record.estimate_items as Record<string, unknown>[]) {
      if (rawIt.deleted_at) continue;
      const parentId = String(rawIt.estimate_id ?? '');
      if (!parentId) continue;
      const list = estItemsByParent.get(parentId) ?? [];
      const unitPriceCents = Number(rawIt.unit_price_cents ?? rawIt.unitPriceCents ?? 0) || 0;
      const taxSlab = Number(rawIt.tax_rate_percentage ?? rawIt.taxSlab ?? 0) || 0;
      const sacHsn = String(rawIt.sac_hsn ?? rawIt.sacHsn ?? '');
      list.push({
        id: String(rawIt.id ?? generateUniqueId()),
        description: String(rawIt.description ?? ''),
        sacHsn,
        sac_hsn: sacHsn,
        quantity: Number(rawIt.quantity ?? 1) || 1,
        unitPriceCents,
        unit_price_cents: unitPriceCents,
        taxSlab,
        tax_rate_percentage: taxSlab,
        tax_cents: Number(rawIt.tax_cents ?? 0) || 0,
        total_cents: Number(rawIt.total_cents ?? 0) || 0,
      });
      estItemsByParent.set(parentId, list);
    }
  }

  let estimates: any[] | undefined;
  if (Array.isArray(record.estimates)) {
    estimates = (record.estimates as Record<string, unknown>[])
      .filter((est) => !est.deleted_at)
      .map((est) => {
        const id = String(est.id ?? '');
        const clientId = String(est.client_id ?? '');
        const nestedItems = Array.isArray(est.items)
          ? est.items
          : (estItemsByParent.get(id) ?? []);
        return {
          ...est,
          client_name: isNonEmptyString(est.client_name)
            ? est.client_name
            : (clientNameById.get(clientId) ?? 'Unknown Client'),
          items: nestedItems,
          created_at: isNonEmptyString(est.created_at) ? est.created_at : fallbackTs,
        };
      });
  }

  let expenses: any[] | undefined;
  if (Array.isArray(record.expenses)) {
    expenses = (record.expenses as Record<string, unknown>[])
      .filter((exp) => !exp.deleted_at)
      .map((exp) => {
        const amountCents = Number(exp.amount_cents ?? 0) || 0;
        const taxCents = Number(exp.tax_cents ?? 0) || 0;
        const totalCents =
          typeof exp.total_cents === 'number' ? exp.total_cents : amountCents + taxCents;
        const rawExpCode = String(exp.currency_code ?? exp.currencyCode ?? '').trim().toUpperCase();
        const rawExpDec = exp.currency_decimals ?? exp.currencyDecimals;
        return {
          ...exp,
          tax_cents: taxCents,
          total_cents: totalCents,
          ...(rawExpCode ? { currency_code: rawExpCode } : {}),
          ...(typeof rawExpDec === 'number' ? { currency_decimals: clampDecimals(rawExpDec) } : {}),
          created_at: isNonEmptyString(exp.created_at) ? exp.created_at : fallbackTs,
        };
      });
  }

  let savedItems: any[] | undefined;
  const rawSaved = Array.isArray(record.savedItems)
    ? record.savedItems
    : (Array.isArray(record.saved_items) ? record.saved_items : undefined);
  if (rawSaved) {
    savedItems = (rawSaved as Record<string, unknown>[])
      .filter((item) => !item.deleted_at)
      .map((item) => {
        const sac = String(item.sacHsn ?? item.sac_hsn ?? '');
        const price = Number(item.defaultPriceCents ?? item.default_price_cents ?? 0) || 0;
        const rawItemCode = String(item.currency_code ?? item.currencyCode ?? '').trim().toUpperCase();
        const rawItemDec = item.currency_decimals ?? item.currencyDecimals;
        const itemDec = typeof rawItemDec === 'number' ? clampDecimals(rawItemDec) : undefined;
        return {
          ...item,
          sacHsn: sac,
          sac_hsn: sac,
          defaultPriceCents: price,
          default_price_cents: price,
          ...(rawItemCode ? { currency_code: rawItemCode, currencyCode: rawItemCode } : {}),
          ...(itemDec !== undefined ? { currency_decimals: itemDec, currencyDecimals: itemDec } : {}),
        };
      });
  }

  let businessProfile: any | undefined;
  let rawProf: Record<string, unknown> | undefined;
  if (record.businessProfile && typeof record.businessProfile === 'object' && !Array.isArray(record.businessProfile)) {
    rawProf = record.businessProfile as Record<string, unknown>;
  } else if (Array.isArray(record.business_profile) && record.business_profile.length > 0) {
    const firstProf = record.business_profile[0];
    if (firstProf && typeof firstProf === 'object' && !Array.isArray(firstProf)) {
      rawProf = firstProf as Record<string, unknown>;
    }
  }
  if (rawProf) {
    businessProfile = {
      ...rawProf,
      invoice_prefix: isNonEmptyString(rawProf.invoice_prefix) ? rawProf.invoice_prefix.trim() : 'INV-',
      estimate_prefix: isNonEmptyString(rawProf.estimate_prefix) ? rawProf.estimate_prefix.trim() : 'EST-',
      next_invoice_number:
        isStrictInteger(rawProf.next_invoice_number) && rawProf.next_invoice_number >= 1
          ? rawProf.next_invoice_number
          : 1,
      payment_qr_payload: typeof rawProf.payment_qr_payload === 'string' ? rawProf.payment_qr_payload : '',
    };
  }

  return {
    clients,
    invoices,
    ...(estimates !== undefined ? { estimates } : {}),
    ...(expenses !== undefined ? { expenses } : {}),
    ...(savedItems !== undefined ? { savedItems } : {}),
    ...(businessProfile !== undefined ? { businessProfile } : {}),
  };
}

/**
 * Validates parsed backup JSON snapshot (supporting both React Web JSON and Flutter SQLite JSON),
 * enforcing column NOT NULL requirements and value types before mutating application state.
 */
export function validateBackupPayload(data: unknown): {
  valid: boolean;
  error?: string;
  normalized?: NormalizedBackupPayload;
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
    const err = validateTableRows(key, val, BACKUP_TABLE_RULES[key]);
    if (err) return { valid: false, error: err };
  }

  if (record.saved_items !== undefined) {
    const err = validateTableRows('saved_items', record.saved_items, BACKUP_TABLE_RULES.savedItems);
    if (err) return { valid: false, error: err };
  }

  for (const childKey of ['invoice_items', 'estimate_items', 'payments'] as const) {
    const val = record[childKey];
    if (val === undefined) continue;
    const err = validateTableRows(childKey, val, FLUTTER_CHILD_TABLE_RULES[childKey]);
    if (err) return { valid: false, error: err };
  }

  if (record.businessProfile !== undefined) {
    if (
      !record.businessProfile ||
      typeof record.businessProfile !== 'object' ||
      Array.isArray(record.businessProfile)
    ) {
      return {
        valid: false,
        error: 'Invalid backup file: "businessProfile" must be a JSON object.',
      };
    }
    const profErr = validateProfileRecord(
      record.businessProfile as Record<string, unknown>,
      'businessProfile'
    );
    if (profErr) return { valid: false, error: profErr };
  }

  if (record.business_profile !== undefined) {
    if (!Array.isArray(record.business_profile)) {
      return {
        valid: false,
        error: 'Invalid backup file: "business_profile" must be an array.',
      };
    }
    for (let i = 0; i < record.business_profile.length; i++) {
      const entry = record.business_profile[i];
      if (!entry || typeof entry !== 'object' || Array.isArray(entry)) {
        return {
          valid: false,
          error: 'Invalid backup file: Entries in "business_profile" must be JSON objects.',
        };
      }
      const profErr = validateProfileRecord(
        entry as Record<string, unknown>,
        `business_profile[${i}]`
      );
      if (profErr) return { valid: false, error: profErr };
    }
  }

  return {
    valid: true,
    normalized: normalizeBackupPayloadForWeb(record),
  };
}

/**
 * Checks whether a client has linked invoices or estimates before deletion.
 */
export function hasLinkedClientDocuments(
  clientId: string,
  invoices: Array<{ client_id: string }>,
  estimates: Array<{ client_id: string }>
): boolean {
  return (
    invoices.some((inv) => inv.client_id === clientId) ||
    estimates.some((est) => est.client_id === clientId)
  );
}

/**
 * Detects browser localStorage QuotaExceededError variants reliably across Chrome, Firefox, Safari, and Edge.
 */
export function isQuotaExceededError(err: unknown): boolean {
  if (!err || typeof err !== 'object') return false;
  const anyErr = err as { name?: string; code?: number };
  return (
    anyErr.name === 'QuotaExceededError' ||
    anyErr.name === 'NS_ERROR_DOM_QUOTA_REACHED' ||
    anyErr.code === 22 ||
    anyErr.code === 1014
  );
}

export interface WhatsAppPhoneValidation {
  isValid: boolean;
  normalizedDigits: string;
  warningMessage?: string;
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
 * Validates whether a phone number includes an international country code for wa.me links.
 * Flags empty numbers, leading trunk/IDD zeros (0 / 00), and local <=10-digit numbers without '+'.
 */
export function validateWhatsAppPhone(phone: string): WhatsAppPhoneValidation {
  const trimmed = phone.trim();
  const digits = buildWhatsAppDigits(trimmed);

  if (!digits) {
    return {
      isValid: false,
      normalizedDigits: '',
      warningMessage: 'No phone number on file — WhatsApp will open contact picker instead.',
    };
  }

  if (digits.startsWith('0')) {
    return {
      isValid: false,
      normalizedDigits: digits,
      warningMessage:
        "Number starts with '0'. WhatsApp requires an international country code (e.g. +1 or +91) without leading zeros.",
    };
  }

  if (trimmed.startsWith('+')) {
    if (digits.length < 7) {
      return {
        isValid: false,
        normalizedDigits: digits,
        warningMessage: 'Phone number looks too short for an international WhatsApp link.',
      };
    }
    return {
      isValid: true,
      normalizedDigits: digits,
    };
  }

  if (digits.length <= 10) {
    return {
      isValid: false,
      normalizedDigits: digits,
      warningMessage:
        "Missing '+' country code prefix (e.g. +1 or +91). WhatsApp links may not resolve local-only numbers.",
    };
  }

  return {
    isValid: true,
    normalizedDigits: digits,
  };
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
 * Builds a mailto: URL, pre-filling recipient email when available and omitting empty query parameters.
 */
export function buildMailtoUrl(email: string, subject: string, body: string): string {
  const cleanEmail = email.trim();
  const queryParts: string[] = [];
  if (subject.trim()) queryParts.push(`subject=${encodeURIComponent(subject)}`);
  if (body.trim()) queryParts.push(`body=${encodeURIComponent(body)}`);
  const query = queryParts.length > 0 ? `?${queryParts.join('&')}` : '';
  return `mailto:${cleanEmail}${query}`;
}

/**
 * Builds an sms: URL for a normalized phone number, or null when phone is empty.
 * Applies Apple's '&body=' delimiter quirk when isApple is true (iOS/iPadOS/macOS).
 */
export function buildSmsUrl(phone: string, body = '', isApple = false): string | null {
  const normalized = normalizePhoneForUri(phone);
  if (!normalized) return null;
  if (!body) return `sms:${normalized}`;
  const delimiter = isApple ? '&' : '?';
  return `sms:${normalized}${delimiter}body=${encodeURIComponent(body)}`;
}

/**
 * Builds an smsto: fallback URL for Android OEM ROMs where primary sms: links fail.
 */
export function buildSmsFallbackUrl(phone: string, body = ''): string | null {
  const normalized = normalizePhoneForUri(phone);
  if (!normalized) return null;
  if (!body) return `smsto:${normalized}`;
  return `smsto:${normalized}?body=${encodeURIComponent(body)}`;
}

/**
 * Builds a 1-tap clipboard bundle containing recipient contact, subject, and reminder body
 * suitable for WeChat, Telegram, SMS, or manual email pasting.
 */
export function buildCopyEverythingReminderText(params: {
  subject: string;
  message: string;
  clientName?: string;
  clientEmail?: string;
  phone?: string;
}): string {
  const lines: string[] = [];
  const normalizedPhone = normalizePhoneForUri(params.phone || '');
  const contactParts = [
    params.clientName?.trim() || '',
    params.clientEmail?.trim() || '',
    normalizedPhone,
  ].filter(Boolean);
  if (contactParts.length > 0) {
    lines.push(`To: ${contactParts.join(' • ')}`);
  }
  if (params.subject.trim()) {
    lines.push(`Subject: ${params.subject.trim()}`);
  }
  if (lines.length > 0 && params.message.trim()) {
    lines.push('');
  }
  if (params.message.trim()) {
    lines.push(params.message.trim());
  }
  return lines.join('\n');
}

/**
 * Detects Apple mobile iOS/iPadOS user agents safely in browser environments.
 */
export function isIosDevice(userAgent?: string): boolean {
  const ua = userAgent ?? (typeof navigator !== 'undefined' ? navigator.userAgent || '' : '');
  return /iPad|iPhone|iPod/i.test(ua);
}

/**
 * Detects Apple iOS, iPadOS, and macOS platforms for Apple's '&body=' SMS delimiter.
 */
export function isAppleDevice(userAgent?: string): boolean {
  const ua = userAgent ?? (typeof navigator !== 'undefined' ? navigator.userAgent || '' : '');
  return /iPad|iPhone|iPod|Macintosh|Mac OS X/i.test(ua);
}

/**
 * Returns true if text contains Arabic or Hebrew RTL Unicode characters.
 */
export function containsRtlCharacters(text: string): boolean {
  if (!text) return false;
  for (const ch of text) {
    const cp = ch.codePointAt(0);
    if (cp === undefined) continue;
    if (
      (cp >= 0x0590 && cp <= 0x06ff) ||
      (cp >= 0x0750 && cp <= 0x077f) ||
      (cp >= 0x08a0 && cp <= 0x08ff) ||
      (cp >= 0xfb50 && cp <= 0xfdff) ||
      (cp >= 0xfe70 && cp <= 0xfeff)
    ) {
      return true;
    }
  }
  return false;
}

/**
 * Builds a tel: URL for a normalized phone number, or null when phone is empty.
 */
export function buildTelUrl(phone: string): string | null {
  const normalized = normalizePhoneForUri(phone);
  if (!normalized) return null;
  return `tel:${normalized}`;
}

/**
 * Returns cross-platform desktop/web fallback guidance when native SMS/dialer apps are absent.
 */
export function getDesktopTelephonyFallbackNote(hasPhone: boolean, hasEmail: boolean): string {
  if (!hasPhone && !hasEmail) {
    return 'No client phone or email saved. Copy the reminder message above or open WhatsApp to pick a contact.';
  }
  return 'Desktop systems without a registered SMS/dialer app may ignore external links — use Copy Reminder Message as an instant fallback.';
}

export const MAX_ATTACHMENT_SIZE_BYTES = 5 * 1024 * 1024;
export const MAX_BACKUP_SIZE_BYTES = 50 * 1024 * 1024;

export interface FileUploadValidationResult {
  isValid: boolean;
  mimeType?: string;
  errorMessage?: string;
}

/**
 * Inspects file header magic bytes to determine real image/PDF MIME type.
 */
export function detectMimeFromHeaderBytes(bytes: Uint8Array | number[]): string | null {
  if (
    bytes.length >= 4 &&
    bytes[0] === 0x89 &&
    bytes[1] === 0x50 &&
    bytes[2] === 0x4e &&
    bytes[3] === 0x47
  ) {
    return 'image/png';
  }
  if (bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) {
    return 'image/jpeg';
  }
  if (
    bytes.length >= 12 &&
    bytes[0] === 0x52 &&
    bytes[1] === 0x49 &&
    bytes[2] === 0x46 &&
    bytes[3] === 0x46 &&
    bytes[8] === 0x57 &&
    bytes[9] === 0x45 &&
    bytes[10] === 0x42 &&
    bytes[11] === 0x50
  ) {
    return 'image/webp';
  }
  if (
    bytes.length >= 5 &&
    bytes[0] === 0x25 &&
    bytes[1] === 0x50 &&
    bytes[2] === 0x44 &&
    bytes[3] === 0x46 &&
    bytes[4] === 0x2d
  ) {
    return 'application/pdf';
  }
  return null;
}

/**
 * Validates uploaded image/receipt file bytes by checking empty/size bounds
 * and verifying file magic header signatures before base64 encoding.
 */
export function validateUploadedFileBytes(params: {
  bytes: Uint8Array | number[];
  filename: string;
  allowPdf?: boolean;
  maxBytes?: number;
}): FileUploadValidationResult {
  const { bytes, filename, allowPdf = false, maxBytes = MAX_ATTACHMENT_SIZE_BYTES } = params;
  if (!bytes || bytes.length === 0) {
    return {
      isValid: false,
      errorMessage: 'Selected file is empty (0 bytes).',
    };
  }
  if (bytes.length > maxBytes) {
    const limitMb = Math.floor(maxBytes / (1024 * 1024));
    return {
      isValid: false,
      errorMessage: `File exceeds maximum allowed size of ${limitMb} MB.`,
    };
  }

  const detectedMime = detectMimeFromHeaderBytes(bytes);
  if (
    detectedMime === 'image/png' ||
    detectedMime === 'image/jpeg' ||
    detectedMime === 'image/webp'
  ) {
    return { isValid: true, mimeType: detectedMime };
  }
  if (allowPdf && detectedMime === 'application/pdf') {
    return { isValid: true, mimeType: 'application/pdf' };
  }

  return {
    isValid: false,
    errorMessage: allowPdf
      ? `Unsupported or invalid file "${filename}". Choose a valid PNG, JPG, WEBP, or PDF.`
      : `Unsupported or invalid image "${filename}". Choose a valid PNG, JPG, or WEBP image.`,
  };
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

/**
 * Returns true only when dateStr is strictly formatted as YYYY-MM-DD and represents a real calendar date.
 */
export function isValidIsoCalendarDate(dateStr: string): boolean {
  if (!dateStr || typeof dateStr !== 'string') return false;
  const trimmed = dateStr.trim();
  if (!/^\d{4}-\d{2}-\d{2}$/.test(trimmed)) return false;
  return parseLocalCalendarDate(trimmed) !== null;
}

/**
 * Filters a document's issue date against 'All Time', 'This Month', or 'This Quarter'.
 */
export function matchesDateFilter(
  isoDateStr: string,
  dateFilter: string,
  referenceNow?: Date
): boolean {
  const trimmedFilter = (dateFilter || '').trim();
  if (!trimmedFilter || trimmedFilter === 'All Time') return true;

  const parsed = parseLocalCalendarDate(isoDateStr);
  if (!parsed) return false;

  const now = referenceNow ?? new Date();
  if (trimmedFilter === 'This Month') {
    return parsed.getFullYear() === now.getFullYear() && parsed.getMonth() === now.getMonth();
  }
  if (trimmedFilter === 'This Quarter') {
    const refQuarter = Math.floor(now.getMonth() / 3);
    const itemQuarter = Math.floor(parsed.getMonth() / 3);
    return parsed.getFullYear() === now.getFullYear() && itemQuarter === refQuarter;
  }
  return true;
}

/**
 * Generates a globally unique RFC-4122 UUID v4 string without Date.now() collisions.
 */
export function generateUniqueId(): string {
  if (typeof globalThis.crypto !== 'undefined' && typeof globalThis.crypto.randomUUID === 'function') {
    return globalThis.crypto.randomUUID();
  }
  const bytes = new Uint8Array(16);
  if (typeof globalThis.crypto !== 'undefined' && typeof globalThis.crypto.getRandomValues === 'function') {
    globalThis.crypto.getRandomValues(bytes);
  } else {
    for (let i = 0; i < 16; i++) {
      bytes[i] = Math.floor(Math.random() * 256);
    }
  }
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const hex = Array.from(bytes, (b) => b.toString(16).padStart(2, '0')).join('');
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20, 32)}`;
}

export const ACCENT_PRESET_KEYS = [
  'indigo',
  'emerald',
  'royalBlue',
  'roseRed',
  'amberGold',
  'slateSteel',
] as const;

export type AccentPresetKey = (typeof ACCENT_PRESET_KEYS)[number];

/**
 * Normalizes a persisted accent preset key, falling back to 'indigo'.
 */
export function normalizeAccentColorKey(raw: unknown): AccentPresetKey {
  if (typeof raw !== 'string') return 'indigo';
  const trimmed = raw.trim();
  if ((ACCENT_PRESET_KEYS as readonly string[]).includes(trimmed)) {
    return trimmed as AccentPresetKey;
  }
  return 'indigo';
}

/**
 * Normalizes a persisted theme mode ('light' | 'dark' | 'system'), falling back to 'system'.
 */
export function normalizeThemeMode(raw: unknown): 'light' | 'dark' | 'system' {
  if (typeof raw !== 'string') return 'system';
  const normalized = raw.trim().toLowerCase();
  if (normalized === 'light' || normalized === 'dark') {
    return normalized;
  }
  return 'system';
}

/**
 * Clones an existing invoice with today's local date, a fresh UUID, a sequential
 * document number, PENDING status, zero paid_cents, and full balance due.
 */
export function duplicateInvoiceRecord<T extends Record<string, any>>(
  source: T,
  existingInvoices: Array<Record<string, any>>,
  invoicePrefix = 'INV-',
  minNext = 1,
  referenceNow?: Date
): T {
  const now = referenceNow ?? new Date();
  const todayIso = formatLocalCalendarDate(now);
  const paymentTerms = source.payment_terms || 'Due on Receipt';
  const dueIso = calculateDueDate(todayIso, paymentTerms);
  const nextInvNumber = getNextSequentialDocNumber(
    existingInvoices.map((inv) => String(inv.invoice_number || '')),
    invoicePrefix,
    Math.max(1, minNext)
  );
  const clonedItems = Array.isArray(source.items)
    ? source.items.map((item: any) => ({
        ...item,
        id: generateUniqueId(),
      }))
    : source.items;

  return {
    ...source,
    id: generateUniqueId(),
    invoice_number: nextInvNumber,
    status: 'PENDING',
    computed_status: 'PENDING',
    issue_date: todayIso,
    due_date: dueIso,
    payment_terms: paymentTerms,
    paid_cents: 0,
    balance_due_cents: source.total_cents ?? 0,
    items: clonedItems,
    created_at: now.toISOString(),
  };
}

/**
 * Transitions a finalized invoice into VOID status with zero balance due.
 * Draft invoices remain unchanged (matching Flutter voidInvoice/menu rules).
 */
export function voidInvoiceRecord<T extends Record<string, any>>(source: T): T {
  const currentStatus = String(source.computed_status || source.status || '').toUpperCase();
  if (currentStatus === 'DRAFT') {
    return source;
  }
  return {
    ...source,
    status: 'VOID',
    computed_status: 'VOID',
    balance_due_cents: 0,
  };
}

export interface EditableLineItem {
  id: string;
  description: string;
  sacHsn: string;
  quantity: number;
  unitPriceCents: number;
  taxSlab: number;
}

/**
 * Pure helper to update fields of a single line item by stable ID without
 * shifting sibling row state or mutating integers inconsistently.
 */
export function updateLineItemRecord<T extends EditableLineItem>(
  items: T[],
  id: string,
  patch: Partial<EditableLineItem>
): T[] {
  return items.map((item) => {
    if (item.id !== id) return item;
    const nextQty =
      patch.quantity !== undefined
        ? Math.max(1, Math.trunc(Number(patch.quantity) || 1))
        : item.quantity;
    const nextPrice =
      patch.unitPriceCents !== undefined
        ? Math.max(0, Math.trunc(Number(patch.unitPriceCents) || 0))
        : item.unitPriceCents;
    const nextTax =
      patch.taxSlab !== undefined
        ? Math.max(0, Math.min(100, Math.trunc(Number(patch.taxSlab) || 0)))
        : item.taxSlab;
    return {
      ...item,
      ...patch,
      quantity: nextQty,
      unitPriceCents: nextPrice,
      taxSlab: nextTax,
    };
  });
}

/**
 * Removes a line item by stable ID while preserving the identities and order of all other rows.
 */
export function removeLineItemById<T extends { id: string }>(
  items: T[],
  id: string
): T[] {
  return items.filter((item) => item.id !== id);
}
