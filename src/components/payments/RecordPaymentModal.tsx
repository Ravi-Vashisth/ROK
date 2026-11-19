import React, { useState, useEffect } from 'react';
import { X, DollarSign, CheckCircle2, AlertCircle } from 'lucide-react';
import {
  formatDecimalUnits,
  formatLocalCalendarDate,
  formatMoney as formatMoneyUnits,
  getCurrencyDecimals,
  parsePriceToUnits,
} from '../../billingRules';

interface RecordPaymentModalProps {
  invoice: any;
  isOpen: boolean;
  isDarkMode: boolean;
  currencySymbol: string;
  formatMoney: (cents: number) => string;
  parsePriceToCents: (val: string) => number;
  onClose: () => void;
  onSubmit: (paymentData: {
    invoiceId: string;
    amountReceivedCents: number;
    tdsCents: number;
    totalCreditCents: number;
    paymentMethod: string;
    paymentDate: string;
    referenceNumber: string;
    notes: string;
  }) => void;
}

export const RecordPaymentModal: React.FC<RecordPaymentModalProps> = ({
  invoice,
  isOpen,
  isDarkMode,
  currencySymbol,
  onClose,
  onSubmit,
}) => {
  const invSym = invoice?.currency_symbol || currencySymbol || '$';
  const invDec = invoice?.currency_decimals ?? getCurrencyDecimals(invoice?.currency_code || invSym);
  const balanceDueCents = invoice
    ? invoice.balance_due_cents ?? Math.max(0, (invoice.total_cents || 0) - (invoice.paid_cents || 0))
    : 0;

  const [amountReceivedStr, setAmountReceivedStr] = useState<string>(
    formatDecimalUnits(balanceDueCents, invDec)
  );
  const [tdsStr, setTdsStr] = useState<string>(formatDecimalUnits(0, invDec));
  const [paymentMethod, setPaymentMethod] = useState<string>('Bank Wire');
  const [paymentDate, setPaymentDate] = useState<string>(formatLocalCalendarDate());
  const [referenceNumber, setReferenceNumber] = useState<string>('');
  const [notes, setNotes] = useState<string>('');
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  useEffect(() => {
    if (!isOpen || !invoice) return;
    setAmountReceivedStr(formatDecimalUnits(balanceDueCents, invDec));
    setTdsStr(formatDecimalUnits(0, invDec));
    setPaymentMethod('Bank Wire');
    setPaymentDate(formatLocalCalendarDate());
    setReferenceNumber('');
    setNotes('');
    setErrorMessage(null);
  }, [isOpen, invoice?.id, balanceDueCents, invDec]);

  useEffect(() => {
    if (!isOpen) return;
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        onClose();
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [isOpen, onClose]);

  if (!isOpen || !invoice) return null;

  const fmtInvMoney = (units: number) => formatMoneyUnits(units, invSym, invDec);
  const amountReceivedCents = parsePriceToUnits(amountReceivedStr, invDec);
  const tdsCents = parsePriceToUnits(tdsStr, invDec);
  const totalCreditCents = amountReceivedCents + tdsCents;
  const remainingBalanceCents = Math.max(0, balanceDueCents - totalCreditCents);

  const handleApplyPreset = (presetUnits: number) => {
    setAmountReceivedStr(formatDecimalUnits(presetUnits, invDec));
    setTdsStr(formatDecimalUnits(0, invDec));
    setErrorMessage(null);
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();

    if (totalCreditCents <= 0) {
      setErrorMessage('Total payment credit (Amount Received + TDS) must be greater than zero.');
      return;
    }

    if (totalCreditCents > balanceDueCents) {
      setErrorMessage(
        `Total credit (${fmtInvMoney(totalCreditCents)}) cannot exceed remaining balance due (${fmtInvMoney(balanceDueCents)}).`
      );
      return;
    }

    onSubmit({
      invoiceId: invoice.id,
      amountReceivedCents,
      tdsCents,
      totalCreditCents,
      paymentMethod,
      paymentDate,
      referenceNumber: referenceNumber.trim(),
      notes: notes.trim(),
    });
    onClose();
  };

  const stepVal = invDec === 0 ? '1' : invDec === 3 ? '0.001' : '0.01';

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-xs animate-in fade-in duration-150"
      onClick={(e) => {
        if (e.target === e.currentTarget) {
          onClose();
        }
      }}
    >
      <div
        role="dialog"
        aria-modal="true"
        className={`w-full max-w-lg max-h-[90vh] overflow-y-auto rounded-xl border shadow-2xl p-6 ${
          isDarkMode ? 'bg-[#0F172A] border-slate-800 text-slate-100' : 'bg-white border-slate-200 text-slate-900'
        }`}
      >
        {/* Header */}
        <div className="flex items-center justify-between gap-2 pb-4 border-b border-slate-200 dark:border-slate-800">
          <div className="min-w-0">
            <h3 className="text-base font-bold flex items-center gap-2">
              <DollarSign className="w-5 h-5 text-emerald-500 shrink-0" />
              <span>Record Payment Received</span>
            </h3>
            <p className="text-xs text-slate-500 mt-0.5 truncate">
              Invoice <span className="font-mono font-bold">{invoice.invoice_number}</span> &bull; {invoice.client_name}
            </p>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="p-1 rounded-lg text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 transition cursor-pointer shrink-0"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Quick Balance Summary */}
        <div className="my-4 p-3.5 rounded-xl bg-slate-50 dark:bg-slate-900/60 border border-slate-200 dark:border-slate-800 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3">
          <div>
            <div className="text-[11px] font-semibold text-slate-500 uppercase tracking-wider">Current Balance Due</div>
            <div className="text-lg font-bold font-mono tabular-nums accent-text">
              {fmtInvMoney(balanceDueCents)}
            </div>
          </div>
          <div className="flex flex-wrap gap-1.5">
            <button
              type="button"
              onClick={() => handleApplyPreset(balanceDueCents)}
              className="px-2.5 py-1 text-xs font-bold rounded-lg accent-soft-btn border cursor-pointer transition"
            >
              100% Full
            </button>
            <button
              type="button"
              onClick={() => handleApplyPreset(Math.floor((balanceDueCents + 1) / 2))}
              className="px-2.5 py-1 text-xs font-bold rounded-lg bg-slate-100 dark:bg-slate-800 text-slate-700 dark:text-slate-300 hover:bg-slate-200 dark:hover:bg-slate-700 cursor-pointer transition"
            >
              50% Deposit
            </button>
            <button
              type="button"
              onClick={() => handleApplyPreset(Math.floor((balanceDueCents + 2) / 4))}
              className="px-2.5 py-1 text-xs font-bold rounded-lg bg-slate-100 dark:bg-slate-800 text-slate-700 dark:text-slate-300 hover:bg-slate-200 dark:hover:bg-slate-700 cursor-pointer transition"
            >
              25% Retainer
            </button>
          </div>
        </div>

        {errorMessage && (
          <div className="mb-4 p-3 rounded-xl bg-rose-50 dark:bg-rose-950/60 border border-rose-200 dark:border-rose-800 text-rose-700 dark:text-rose-300 text-xs flex items-center gap-2">
            <AlertCircle className="w-4 h-4 shrink-0" />
            <span>{errorMessage}</span>
          </div>
        )}

        <form onSubmit={handleSubmit} className="space-y-4">
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <label className="block text-xs font-bold mb-1">Amount Received ({invSym}) *</label>
              <input
                type="number"
                inputMode={invDec > 0 ? 'decimal' : 'numeric'}
                step={stepVal}
                min="0"
                value={amountReceivedStr}
                onChange={(e) => {
                  setAmountReceivedStr(e.target.value);
                  setErrorMessage(null);
                }}
                className="w-full px-3 py-2 text-xs font-mono font-bold rounded-xl border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-900 accent-focus"
                required
              />
            </div>
            <div>
              <label className="block text-xs font-bold mb-1">TDS Withholding Tax ({invSym})</label>
              <input
                type="number"
                inputMode={invDec > 0 ? 'decimal' : 'numeric'}
                step={stepVal}
                min="0"
                value={tdsStr}
                onChange={(e) => {
                  setTdsStr(e.target.value);
                  setErrorMessage(null);
                }}
                className="w-full px-3 py-2 text-xs font-mono font-bold rounded-xl border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-900 accent-focus"
                placeholder={formatDecimalUnits(0, invDec)}
              />
            </div>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <label className="block text-xs font-bold mb-1">Payment Method</label>
              <select
                value={paymentMethod}
                onChange={(e) => setPaymentMethod(e.target.value)}
                className="w-full px-3 py-2 text-xs rounded-xl border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-900 accent-focus cursor-pointer"
              >
                <option value="Bank Wire">Bank Wire (ACH / NEFT / IMPS)</option>
                <option value="UPI / PayPal">UPI / PayPal</option>
                <option value="Credit Card">Credit Card</option>
                <option value="Cash">Cash</option>
                <option value="Check">Check</option>
              </select>
            </div>
            <div>
              <label className="block text-xs font-bold mb-1">Payment Date</label>
              <input
                type="date"
                value={paymentDate}
                onChange={(e) => setPaymentDate(e.target.value)}
                className="w-full px-3 py-2 text-xs rounded-xl border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-900 accent-focus"
                required
              />
            </div>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <label className="block text-xs font-bold mb-1">Reference / UTR #</label>
              <input
                type="text"
                value={referenceNumber}
                onChange={(e) => setReferenceNumber(e.target.value)}
                placeholder="e.g. UTR-9823412 or Cheque 0012"
                className="w-full px-3 py-2 text-xs rounded-xl border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-900 accent-focus"
              />
            </div>
            <div>
              <label className="block text-xs font-bold mb-1">Payment Notes / Memo</label>
              <input
                type="text"
                value={notes}
                onChange={(e) => setNotes(e.target.value)}
                placeholder="e.g. Milestone 1 settlement"
                className="w-full px-3 py-2 text-xs rounded-xl border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-900 accent-focus"
              />
            </div>
          </div>

          {/* Computed Settlement Preview */}
          <div className="p-3 rounded-xl bg-slate-100 dark:bg-slate-800/60 border border-slate-200 dark:border-slate-700 text-xs space-y-1">
            <div className="flex flex-wrap justify-between gap-2">
              <span className="text-slate-500">Total Credit Recorded:</span>
              <span className="font-mono tabular-nums font-bold text-slate-800 dark:text-slate-200">
                {fmtInvMoney(totalCreditCents)}
                {tdsCents > 0 && ` (Net: ${fmtInvMoney(amountReceivedCents)} + TDS: ${fmtInvMoney(tdsCents)})`}
              </span>
            </div>
            <div className="flex flex-wrap justify-between gap-2">
              <span className="text-slate-500">Remaining Balance:</span>
              <span className={`font-mono tabular-nums font-bold ${remainingBalanceCents === 0 ? 'text-emerald-600' : 'text-slate-700 dark:text-slate-300'}`}>
                {remainingBalanceCents === 0 ? '✓ Paid in Full' : fmtInvMoney(remainingBalanceCents)}
              </span>
            </div>
          </div>

          {/* Modal Actions */}
          <div className="pt-2 flex justify-end gap-2 border-t border-slate-200 dark:border-slate-800">
            <button
              type="button"
              onClick={onClose}
              className="px-4 py-2 text-xs font-bold rounded-xl border border-slate-300 dark:border-slate-700 hover:bg-slate-100 dark:hover:bg-slate-800 transition cursor-pointer"
            >
              Cancel
            </button>
            <button
              type="submit"
              className="px-4 py-2 text-xs font-bold rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white flex items-center gap-1.5 transition cursor-pointer shadow-sm"
            >
              <CheckCircle2 className="w-4 h-4" />
              <span>Confirm & Record Payment</span>
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
