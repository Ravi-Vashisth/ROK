import React, { useEffect } from 'react';
import { Printer, X } from 'lucide-react';
import {
  computeClientRollup,
  formatLocalCalendarDate,
  formatMoney,
  getCurrencyDecimals,
  getRegionalTaxIdLabel,
  resolveEffectiveCurrency,
  resolveRegionalTaxBreakdown,
} from '../../billingRules';

export type PrintTarget =
  | { type: 'invoice'; data: any }
  | { type: 'estimate'; data: any }
  | { type: 'statement'; client: any };

interface PrintPreviewModalProps {
  target: PrintTarget | null;
  clients: any[];
  invoices: any[];
  businessProfile: any;
  isDarkMode: boolean;
  onClose: () => void;
}

const toImageDataSrc = (raw?: string): string | null => {
  if (!raw || !raw.trim()) return null;
  const trimmed = raw.trim();
  return trimmed.startsWith('data:') ? trimmed : `data:image/png;base64,${trimmed}`;
};

const cleanMultiline = (raw?: string): string =>
  (raw || '').replace(/\\n/g, '\n').trim();

export const PrintPreviewModal: React.FC<PrintPreviewModalProps> = ({
  target,
  clients,
  invoices,
  businessProfile,
  isDarkMode,
  onClose,
}) => {
  useEffect(() => {
    if (!target) return;
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        onClose();
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [target, onClose]);

  if (!target) return null;

  const defaultCode = (businessProfile.currency_code || 'USD').trim() || 'USD';
  const defaultSym = (businessProfile.currency_symbol || '$').trim() || '$';
  const defaultDec =
    businessProfile.currency_decimals ?? getCurrencyDecimals(defaultCode || defaultSym);

  const logoSrc = toImageDataSrc(businessProfile.logo_base64);
  const signatureSrc = toImageDataSrc(businessProfile.signature_base64);

  const headerTitle =
    target.type === 'invoice'
      ? `Print Preview — ${target.data.invoice_number}`
      : target.type === 'estimate'
        ? `Print Preview — ${target.data.estimate_number}`
        : `Statement of Account — ${target.client.name}`;

  const renderInvoiceOrQuote = (doc: any, isQuote: boolean) => {
    const client =
      clients.find((c) => c.id === doc.client_id) || {
        id: doc.client_id,
        name: doc.client_name || 'Client',
        email: '',
        phone: '',
        address: '',
        tax_id: '',
      };

    const cur = resolveEffectiveCurrency({
      recordCode: doc.currency_code,
      recordSymbol: doc.currency_symbol,
      recordDecimals: String(doc.currency_code || '').trim() ? doc.currency_decimals : undefined,
      defaultCode,
      defaultSymbol: defaultSym,
      defaultDecimals: defaultDec,
    });
    const fmt = (units: number) => formatMoney(units, cur.symbol, cur.decimals);

    const status = String(doc.computed_status || doc.status || 'PENDING').toUpperCase();
    const isVoid = !isQuote && status === 'VOID';
    const isDraft = status === 'DRAFT';
    const isPaid = !isQuote && !isVoid && status === 'PAID';
    const isPartial = !isQuote && !isVoid && status === 'PARTIALLY_PAID';
    const isOverdue = !isQuote && !isVoid && status === 'OVERDUE';
    const isConverted = isQuote && status === 'CONVERTED';

    const subtotalCents = Number(doc.subtotal_cents) || 0;
    const discountCents = Number(doc.discount_cents) || 0;
    const netSubtotalCents = Math.max(0, subtotalCents - discountCents);
    const taxCents = Number(doc.tax_cents) || 0;
    const totalCents = Number(doc.total_cents) || 0;
    const paidCents = Number(doc.paid_cents) || 0;
    const balanceDueCents = isVoid
      ? 0
      : Math.max(0, doc.balance_due_cents ?? totalCents - paidCents);

    const breakdown = resolveRegionalTaxBreakdown({
      taxMode: doc.tax_mode,
      netSubtotalCents,
      taxCents,
      pstRatePercentage: doc.pst_rate_percentage,
      taxExemptionId: doc.tax_exemption_id,
      businessTaxId: businessProfile.tax_id,
      clientTaxId: client.tax_id,
      fallbackAutoDetect: true,
      clientAddress: client.address,
      notes: doc.notes,
      terms: doc.terms,
    });

    const supplierTaxLabel = getRegionalTaxIdLabel(breakdown.effectiveMode, false);
    const clientTaxLabel = getRegionalTaxIdLabel(breakdown.effectiveMode, true);

    const rawItems = Array.isArray(doc.items)
      ? doc.items.filter(
          (it: any) => !(!(it.description || '').trim() && (it.unitPriceCents ?? it.unit_price_cents ?? 0) === 0)
        )
      : [];

    const effectiveItems =
      rawItems.length > 0
        ? rawItems
        : [
            {
              id: 'summary-fallback',
              description: isQuote ? 'Proposal / Consulting Services' : 'Consulting / Billing Services',
              sacHsn: '',
              quantity: 1,
              unitPriceCents: subtotalCents,
              totalCents: subtotalCents,
            },
          ];

    const effectiveTerms = cleanMultiline(doc.terms || businessProfile.default_terms);
    const effectiveNotes = cleanMultiline(doc.notes || businessProfile.default_notes);
    const paymentDetails = cleanMultiline(businessProfile.payment_details);

    const statusBadgeClasses = isVoid || isDraft
      ? 'bg-slate-100 text-slate-700 border-slate-300'
      : isPaid || isConverted
        ? 'bg-emerald-50 text-emerald-700 border-emerald-400'
        : isOverdue
          ? 'bg-rose-50 text-rose-700 border-rose-400'
          : isPartial
            ? 'bg-amber-50 text-amber-700 border-amber-400'
            : 'accent-badge border';

    const statusLabel = isQuote
      ? status
      : isPaid
        ? 'PAID IN FULL'
        : status.replace('_', ' ');

    return (
      <div className="space-y-6 text-xs leading-relaxed text-slate-800">
        {/* Document Header */}
        <div className="flex flex-wrap items-start justify-between gap-4 border-b border-slate-200 pb-5">
          <div className="flex items-center gap-3.5">
            {logoSrc && (
              <img
                src={logoSrc}
                alt="Studio Logo"
                className="w-12 h-12 object-contain rounded-lg border border-slate-200 p-1 bg-white shrink-0"
              />
            )}
            <div>
              <h1 className="text-2xl font-extrabold tracking-tight text-slate-900">
                {isQuote ? 'ESTIMATE / QUOTE' : 'TAX INVOICE'}
              </h1>
              <div className="text-sm font-bold font-mono accent-text mt-0.5">
                {isQuote ? doc.estimate_number : doc.invoice_number}
              </div>
            </div>
          </div>

          <div className="text-right space-y-1">
            <span className={`inline-block px-2.5 py-1 rounded-md border text-[10px] font-bold uppercase ${statusBadgeClasses}`}>
              {statusLabel}
            </span>
            <div className="text-[11px] text-slate-500 pt-1">
              Issue Date: <span className="font-semibold text-slate-800">{doc.issue_date}</span>
            </div>
            <div className={`text-[11px] font-semibold ${isOverdue ? 'text-rose-700' : 'text-slate-800'}`}>
              {isQuote ? `Valid Until: ${doc.expiry_date}` : `Due Date: ${doc.due_date} (${doc.payment_terms || 'Due on Receipt'})`}
            </div>
            {doc.po_number && String(doc.po_number).trim() && (
              <div className="text-[11px] font-semibold text-slate-600">
                {isQuote ? 'PO / Ref' : 'PO Number'}: {doc.po_number}
              </div>
            )}
          </div>
        </div>

        {/* Party Columns */}
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-6">
          <div className="space-y-0.5">
            <div className="text-[10px] font-bold uppercase tracking-wider text-slate-400">
              {isQuote ? 'Prepared By' : 'Billed From'}
            </div>
            <div className="text-sm font-bold text-slate-900">
              {businessProfile.business_name || 'My Freelance Studio'}
            </div>
            {businessProfile.email && <div className="text-slate-600">{businessProfile.email}</div>}
            {businessProfile.phone && <div className="text-slate-600">{businessProfile.phone}</div>}
            {businessProfile.address && (
              <div className="text-slate-500 whitespace-pre-line">{businessProfile.address}</div>
            )}
            {businessProfile.tax_id && (
              <div className="font-semibold text-slate-700 pt-0.5">
                {supplierTaxLabel}: {businessProfile.tax_id}
              </div>
            )}
          </div>

          <div className="space-y-0.5">
            <div className="text-[10px] font-bold uppercase tracking-wider text-slate-400">
              {isQuote ? 'Prepared For' : 'Billed To'}
            </div>
            <div className="text-sm font-bold text-slate-900">{client.name}</div>
            {client.email && <div className="text-slate-600">{client.email}</div>}
            {client.phone && <div className="text-slate-600">{client.phone}</div>}
            {client.address && (
              <div className="text-slate-500 whitespace-pre-line">{client.address}</div>
            )}
            {client.tax_id && (
              <div className="font-semibold text-slate-700 pt-0.5">
                {clientTaxLabel}: {client.tax_id}
              </div>
            )}
          </div>
        </div>

        {/* Regional Tax Notice Banner */}
        {breakdown.noticeText && (
          <div className="p-2.5 rounded-lg border border-indigo-200 bg-indigo-50/70 text-center space-y-0.5">
            {breakdown.noticeTitle && (
              <div className="text-[10px] font-bold uppercase tracking-wider text-indigo-900">
                {breakdown.noticeTitle}
              </div>
            )}
            <div className="text-[11px] font-semibold text-indigo-950">{breakdown.noticeText}</div>
          </div>
        )}

        {/* Line Items Table */}
        <div>
          <div className="text-[10px] font-bold uppercase tracking-wider text-slate-400 mb-1.5">
            {isQuote ? 'Proposed Items & Services' : 'Line Items'}
          </div>
          <table className="w-full text-left border border-slate-200 rounded-lg overflow-hidden">
            <thead className="bg-slate-50 border-b border-slate-200 text-[10px] font-bold uppercase tracking-wider text-slate-600">
              <tr>
                <th className="py-2 px-3">Description</th>
                {!isQuote && <th className="py-2 px-2">SAC / HSN</th>}
                <th className="py-2 px-2 text-center">Qty</th>
                <th className="py-2 px-3 text-right">Unit Price</th>
                <th className="py-2 px-3 text-right">Total</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {effectiveItems.map((it: any, idx: number) => {
                const qty = Number(it.quantity) || 1;
                const unitPrice = Number(it.unitPriceCents ?? it.unit_price_cents) || 0;
                const rowTotal = Number(it.totalCents ?? it.total_cents ?? qty * unitPrice);
                const sac = it.sacHsn ?? it.sac_hsn ?? '';
                return (
                  <tr key={it.id || idx} className={idx % 2 === 1 ? 'bg-slate-50/50' : 'bg-white'}>
                    <td className="py-2 px-3 font-medium text-slate-900 whitespace-pre-line">
                      {cleanMultiline(it.description) || 'Service Item'}
                    </td>
                    {!isQuote && <td className="py-2 px-2 font-mono text-slate-500">{sac || '—'}</td>}
                    <td className="py-2 px-2 text-center tabular-nums">{qty}</td>
                    <td className="py-2 px-3 text-right font-mono tabular-nums">{fmt(unitPrice)}</td>
                    <td className="py-2 px-3 text-right font-mono tabular-nums font-bold text-slate-900">
                      {fmt(rowTotal)}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>

        {/* Totals Block */}
        <div className="flex justify-end print-avoid-break">
          <div className="w-full max-w-xs space-y-1.5 text-xs">
            <div className="flex justify-between text-slate-600">
              <span>Subtotal</span>
              <span className="font-mono tabular-nums font-semibold text-slate-800">{fmt(subtotalCents)}</span>
            </div>
            {discountCents > 0 && (
              <div className="flex justify-between text-amber-700 font-semibold">
                <span>
                  Discount ({doc.discount_type === 'percent' ? `${doc.discount_value}%` : 'Flat'})
                </span>
                <span className="font-mono tabular-nums">-{fmt(discountCents)}</span>
              </div>
            )}
            {breakdown.lines.map((line, i) => (
              <div key={i} className="flex justify-between text-slate-600">
                <span>{line.label}</span>
                <span className="font-mono tabular-nums">{fmt(line.cents)}</span>
              </div>
            ))}
            <div className="border-t border-slate-200 pt-1.5 flex justify-between font-bold text-sm text-slate-900">
              <span>{isQuote ? 'Estimated Total' : 'Total Invoice Amount'}</span>
              <span className="font-mono tabular-nums">{fmt(totalCents)}</span>
            </div>
            {!isQuote && paidCents > 0 && (
              <div className="flex justify-between text-emerald-700 font-semibold">
                <span>Less Payments Received</span>
                <span className="font-mono tabular-nums">-{fmt(paidCents)}</span>
              </div>
            )}
            {!isQuote && (
              <div
                className={`mt-2 p-2.5 rounded-lg border flex justify-between items-center font-bold text-sm ${
                  isVoid
                    ? 'bg-slate-100 border-slate-300 text-slate-700'
                    : isPaid
                      ? 'bg-emerald-50 border-emerald-300 text-emerald-800'
                      : isOverdue
                        ? 'bg-rose-50 border-rose-300 text-rose-800'
                        : 'accent-badge border'
                }`}
              >
                <span>{isVoid ? 'Balance Due (Voided)' : 'Balance Due'}</span>
                <span className="font-mono tabular-nums">{fmt(balanceDueCents)}</span>
              </div>
            )}
          </div>
        </div>

        {/* Terms & Notes */}
        {(effectiveTerms || effectiveNotes) && (
          <div className="p-3 rounded-lg bg-slate-50 border border-slate-200 space-y-1.5 text-[11px] text-slate-600 print-avoid-break">
            {effectiveTerms && (
              <div>
                <span className="font-bold text-slate-700 block">
                  {isQuote ? 'Proposal Terms:' : 'Terms & Conditions:'}
                </span>
                <p className="whitespace-pre-line">{effectiveTerms}</p>
              </div>
            )}
            {effectiveNotes && (
              <div>
                <span className="font-bold text-slate-700 block">
                  {isQuote ? 'Proposal Notes:' : 'Notes:'}
                </span>
                <p className="whitespace-pre-line">{effectiveNotes}</p>
              </div>
            )}
          </div>
        )}

        {/* Signature & Footer Block */}
        {isQuote ? (
          <div className="flex flex-wrap items-end justify-between gap-6 pt-3 print-avoid-break">
            <div className="space-y-3">
              <div>
                <div className="font-bold text-slate-700">
                  This estimate is valid until {doc.expiry_date}.
                </div>
                <div className="text-[10px] text-slate-500">
                  Upon acceptance, this estimate can be converted directly into a formal invoice.
                </div>
              </div>
              <div className="pt-4">
                <div className="w-44 border-t border-slate-400 pt-1 text-[10px] font-bold text-slate-500">
                  Client Acceptance Signature
                </div>
                <div className="text-[10px] text-slate-400 mt-1">Date: ____________________</div>
              </div>
            </div>
            {(signatureSrc || businessProfile.signature_label) && (
              <div className="text-center">
                {signatureSrc ? (
                  <img src={signatureSrc} alt="Authorized Signature" className="h-10 mx-auto object-contain mb-1" />
                ) : (
                  <div className="h-8" />
                )}
                <div className="w-36 border-t border-slate-400 pt-1 text-[10px] font-bold text-slate-500">
                  {businessProfile.signature_label || 'Authorized Signatory'}
                </div>
              </div>
            )}
          </div>
        ) : (
          <div className="space-y-3 print-avoid-break">
            {(signatureSrc || businessProfile.signature_label) && (
              <div className="flex justify-end">
                <div className="text-center">
                  {signatureSrc ? (
                    <img src={signatureSrc} alt="Authorized Signature" className="h-10 mx-auto object-contain mb-1" />
                  ) : (
                    <div className="h-8" />
                  )}
                  <div className="w-36 border-t border-slate-400 pt-1 text-[10px] font-bold text-slate-500">
                    {businessProfile.signature_label || 'Authorized Signatory'}
                  </div>
                </div>
              </div>
            )}

            {isVoid ? (
              <div className="p-2.5 rounded-lg bg-slate-100 border border-slate-300 text-center font-bold text-slate-700">
                THIS INVOICE HAS BEEN VOIDED — NO PAYMENT DUE
              </div>
            ) : isPaid ? (
              <div className="p-2.5 rounded-lg bg-emerald-50 border border-emerald-400 text-center font-bold text-emerald-800 tracking-wide">
                PAID IN FULL — THANK YOU FOR YOUR BUSINESS!
              </div>
            ) : (
              paymentDetails && (
                <div className="p-3 rounded-lg bg-slate-50 border border-slate-200 space-y-1">
                  <div className="text-[10px] font-bold uppercase tracking-wider text-slate-500">
                    Payment Instructions
                  </div>
                  <div className="text-[11px] text-slate-700 whitespace-pre-line">{paymentDetails}</div>
                  <div className={`text-[11px] font-bold pt-1 ${isOverdue ? 'text-rose-700' : 'text-slate-600'}`}>
                    Please remit payment within {doc.payment_terms || 'Due on Receipt'} (Due: {doc.due_date}).
                  </div>
                </div>
              )
            )}
          </div>
        )}
      </div>
    );
  };

  const renderStatement = (client: any) => {
    const activeInvoices = invoices
      .filter((inv) => {
        if (inv.client_id !== client.id) return false;
        const s = String(inv.computed_status || inv.status || '').toUpperCase();
        return s !== 'VOID' && s !== 'DRAFT';
      })
      .sort((a, b) => (a.issue_date || '').localeCompare(b.issue_date || ''));

    const rollup = computeClientRollup(activeInvoices, {
      code: defaultCode,
      symbol: defaultSym,
      decimals: defaultDec,
    });
    const todayStr = formatLocalCalendarDate();

    return (
      <div className="space-y-6 text-xs leading-relaxed text-slate-800">
        {/* Statement Header */}
        <div className="flex flex-wrap items-start justify-between gap-4 border-b border-slate-200 pb-5">
          <div className="flex items-center gap-3.5">
            {logoSrc && (
              <img
                src={logoSrc}
                alt="Studio Logo"
                className="w-11 h-11 object-contain rounded-lg border border-slate-200 p-1 bg-white shrink-0"
              />
            )}
            <div>
              <div className="text-lg font-extrabold text-slate-900">
                {businessProfile.business_name || 'My Freelance Studio'}
              </div>
              {businessProfile.email && <div className="text-slate-500">{businessProfile.email}</div>}
              {businessProfile.tax_id && <div className="text-slate-500">Tax ID: {businessProfile.tax_id}</div>}
            </div>
          </div>

          <div className="text-right">
            <h1 className="text-lg font-extrabold tracking-tight accent-text">STATEMENT OF ACCOUNT</h1>
            <div className="text-[11px] text-slate-500 mt-1">Date Generated: {todayStr}</div>
          </div>
        </div>

        {/* Account & Summary */}
        <div className="flex flex-wrap items-start justify-between gap-6">
          <div className="space-y-0.5">
            <div className="text-[10px] font-bold uppercase tracking-wider text-slate-400">Account For:</div>
            <div className="text-sm font-bold text-slate-900">{client.name}</div>
            {client.email && <div className="text-slate-600">{client.email}</div>}
            {client.phone && <div className="text-slate-600">{client.phone}</div>}
            {client.address && <div className="text-slate-500 whitespace-pre-line">{client.address}</div>}
            {client.tax_id && <div className="text-slate-600 font-semibold">Tax ID: {client.tax_id}</div>}
          </div>

          <div className="p-3.5 rounded-lg border border-slate-200 bg-slate-50 min-w-[230px] text-right space-y-1">
            <div className="font-bold text-slate-800 font-mono tabular-nums">
              Total Invoiced: {rollup.formattedTotalBilled}
            </div>
            <div className="font-bold text-emerald-700 font-mono tabular-nums">
              Total Paid: {rollup.formattedTotalPaid}
            </div>
            <div className="border-t border-slate-300 my-1" />
            <div
              className={`text-sm font-extrabold font-mono tabular-nums ${
                rollup.hasOutstandingBalance ? 'text-rose-700' : 'text-emerald-700'
              }`}
            >
              Balance Due: {rollup.formattedOutstandingBalance}
            </div>
          </div>
        </div>

        {/* Chronological Invoices Table */}
        <div>
          <div className="text-[10px] font-bold uppercase tracking-wider text-slate-500 mb-2">
            Chronological Invoices & Billing History
          </div>
          <table className="w-full text-left border border-slate-200 rounded-lg overflow-hidden">
            <thead className="bg-slate-100 border-b border-slate-200 text-[10px] font-bold uppercase tracking-wider text-slate-600">
              <tr>
                <th className="py-2 px-3">Invoice #</th>
                <th className="py-2 px-2 text-center">Issue Date</th>
                <th className="py-2 px-2 text-center">Due Date</th>
                <th className="py-2 px-2 text-center">Status</th>
                <th className="py-2 px-3 text-right">Billed</th>
                <th className="py-2 px-3 text-right">Paid</th>
                <th className="py-2 px-3 text-right">Balance Due</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {activeInvoices.length === 0 ? (
                <tr>
                  <td colSpan={7} className="py-6 text-center text-slate-400">
                    No finalized invoices recorded for this client.
                  </td>
                </tr>
              ) : (
                activeInvoices.map((inv) => {
                  const cur = resolveEffectiveCurrency({
                    recordCode: inv.currency_code,
                    recordSymbol: inv.currency_symbol,
                    recordDecimals: String(inv.currency_code || '').trim()
                      ? inv.currency_decimals
                      : undefined,
                    defaultCode,
                    defaultSymbol: defaultSym,
                    defaultDecimals: defaultDec,
                  });
                  const status = String(inv.computed_status || inv.status || 'PENDING').toUpperCase();
                  return (
                    <tr key={inv.id}>
                      <td className="py-2 px-3 font-mono font-bold text-slate-900">{inv.invoice_number}</td>
                      <td className="py-2 px-2 text-center text-slate-600">{inv.issue_date}</td>
                      <td className="py-2 px-2 text-center text-slate-600">{inv.due_date}</td>
                      <td className="py-2 px-2 text-center font-semibold text-slate-700">{status}</td>
                      <td className="py-2 px-3 text-right font-mono tabular-nums">
                        {formatMoney(inv.total_cents || 0, cur.symbol, cur.decimals)}
                      </td>
                      <td className="py-2 px-3 text-right font-mono tabular-nums text-emerald-700">
                        {formatMoney(inv.paid_cents || 0, cur.symbol, cur.decimals)}
                      </td>
                      <td className="py-2 px-3 text-right font-mono tabular-nums font-bold text-slate-900">
                        {formatMoney(inv.balance_due_cents ?? Math.max(0, (inv.total_cents || 0) - (inv.paid_cents || 0)), cur.symbol, cur.decimals)}
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </div>
    );
  };

  return (
    <div
      className="print-portal-backdrop fixed inset-0 bg-black/60 backdrop-blur-xs flex items-center justify-center p-4 z-50"
      onClick={(e) => {
        if (e.target === e.currentTarget) onClose();
      }}
    >
      <div
        role="dialog"
        aria-modal="true"
        className={`print-dialog-shell w-full max-w-4xl max-h-[92vh] flex flex-col rounded-xl border shadow-2xl overflow-hidden ${
          isDarkMode ? 'bg-[#0F172A] border-slate-800 text-slate-100' : 'bg-slate-100 border-slate-200 text-slate-900'
        }`}
      >
        {/* Preview Action Toolbar (hidden in actual print output) */}
        <div className={`no-print px-5 py-3.5 border-b flex items-center justify-between gap-3 shrink-0 ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}>
          <div className="min-w-0">
            <h3 className="font-bold text-sm truncate">{headerTitle}</h3>
            <p className="text-[11px] text-slate-400">
              A4 print-ready sheet — click Print / Save PDF to print or export as PDF
            </p>
          </div>
          <div className="flex items-center gap-2 shrink-0">
            <button
              type="button"
              onClick={() => window.print()}
              className="px-3.5 py-2 accent-btn rounded-xl text-xs font-bold flex items-center gap-1.5 cursor-pointer shadow-xs transition"
            >
              <Printer className="w-3.5 h-3.5" />
              <span>Print / Save PDF</span>
            </button>
            <button
              type="button"
              onClick={onClose}
              aria-label="Close print preview"
              className={`p-2 rounded-xl border cursor-pointer transition ${
                isDarkMode ? 'border-slate-700 hover:bg-slate-800 text-slate-300' : 'border-slate-200 hover:bg-slate-100 text-slate-600'
              }`}
            >
              <X className="w-4 h-4" />
            </button>
          </div>
        </div>

        {/* Scrollable A4 Paper Container */}
        <div className="flex-1 overflow-y-auto p-4 sm:p-8 print-portal-backdrop">
          <div
            id="print-sheet-root"
            className="a4-paper mx-auto max-w-[794px] bg-white text-slate-900 rounded-xl shadow-lg border border-slate-200 p-6 sm:p-10"
          >
            {target.type === 'invoice' && renderInvoiceOrQuote(target.data, false)}
            {target.type === 'estimate' && renderInvoiceOrQuote(target.data, true)}
            {target.type === 'statement' && renderStatement(target.client)}
          </div>
        </div>
      </div>
    </div>
  );
};

export default PrintPreviewModal;
