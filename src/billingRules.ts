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
 * Formula:
 *  - Subtotal = sum of items' total_cents
 *  - Tax = (subtotal * tax_percentage + 50) ~/ 100 (integer round-half-up)
 *  - Total = subtotal + tax
 */
export function calculateCartTotals(
  subtotalCents: number,
  taxPercentage: number
): InvoiceCalculation {
  const safeTax = Math.max(0, Math.floor(taxPercentage));
  // Integer round-half-up: (subtotal * taxPercentage + 50) ~/ 100
  const taxCents = Math.floor((subtotalCents * safeTax + 50) / 100);
  const totalCents = subtotalCents + taxCents;

  return {
    subtotalCents,
    taxCents,
    totalCents,
  };
}

/**
 * Generates sequential invoice number starting at INV-0001.
 */
export function formatNextInvoiceNumber(existingCount: number): string {
  const nextNum = existingCount + 1;
  return `INV-${String(nextNum).padStart(4, '0')}`;
}

/**
 * UI display formatting: formats integer cents as USD.
 */
export function formatCents(cents: number): string {
  const dollars = cents / 100;
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
  }).format(dollars);
}
