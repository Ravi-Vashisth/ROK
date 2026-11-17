import React, { useState, useEffect } from 'react';
import { Wallet, X, Save, Sparkles, AlertCircle } from 'lucide-react';
import {
  calculateTaxCents,
  formatDecimalUnits,
  formatMoney,
  parsePriceToUnits,
} from '../../billingRules';

interface ExpenseDrawerModalProps {
  isOpen: boolean;
  isDarkMode: boolean;
  currencySymbol: string;
  currencyDecimals: number;
  onClose: () => void;
  onSave: (expenseData: {
    vendor: string;
    category: string;
    amount_cents: number;
    tax_cents: number;
    total_cents: number;
    expense_date: string;
    notes: string;
  }) => void;
}

const EXPENSE_CATEGORIES = [
  'Software & SaaS',
  'Hardware',
  'Office Supplies',
  'Travel',
  'Marketing',
  'Utilities',
  'Subcontracting',
  'Other',
];

export const ExpenseDrawerModal: React.FC<ExpenseDrawerModalProps> = ({
  isOpen,
  isDarkMode,
  currencySymbol,
  currencyDecimals,
  onClose,
  onSave,
}) => {
  const [vendor, setVendor] = useState<string>('');
  const [category, setCategory] = useState<string>('Software & SaaS');
  const [amountStr, setAmountStr] = useState<string>('');
  const [taxStr, setTaxStr] = useState<string>(currencyDecimals === 0 ? '0' : '0.00');
  const [expenseDate, setExpenseDate] = useState<string>(
    new Date().toISOString().split('T')[0]
  );
  const [notes, setNotes] = useState<string>('');
  const [errorMsg, setErrorMsg] = useState<string>('');

  useEffect(() => {
    if (!isOpen) return;
    setVendor('');
    setCategory('Software & SaaS');
    setAmountStr('');
    setTaxStr(currencyDecimals === 0 ? '0' : '0.00');
    setExpenseDate(new Date().toISOString().split('T')[0]);
    setNotes('');
    setErrorMsg('');
  }, [isOpen, currencyDecimals]);

  useEffect(() => {
    if (!isOpen) return;
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
    };
    document.addEventListener('keydown', handleKeyDown);
    return () => document.removeEventListener('keydown', handleKeyDown);
  }, [isOpen, onClose]);

  if (!isOpen) return null;

  const baseUnits = parsePriceToUnits(amountStr, currencyDecimals);
  const taxUnits = parsePriceToUnits(taxStr, currencyDecimals);
  const totalUnits = baseUnits + taxUnits;

  const handleApplyTenPercentTax = () => {
    if (baseUnits <= 0) {
      setErrorMsg('Enter a positive base amount before calculating 10% tax.');
      return;
    }
    setErrorMsg('');
    const computed = calculateTaxCents(baseUnits, 10);
    setTaxStr(formatDecimalUnits(computed, currencyDecimals));
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!vendor.trim()) {
      setErrorMsg('Please enter a vendor or merchant name.');
      return;
    }
    if (baseUnits <= 0) {
      setErrorMsg('Please enter a valid positive base expense amount.');
      return;
    }
    onSave({
      vendor: vendor.trim(),
      category,
      amount_cents: baseUnits,
      tax_cents: taxUnits,
      total_cents: totalUnits,
      expense_date: expenseDate || new Date().toISOString().split('T')[0],
      notes: notes.trim(),
    });
    onClose();
  };

  return (
    <div
      className="fixed inset-0 bg-black/50 backdrop-blur-xs flex items-center justify-center p-4 z-50"
      onClick={onClose}
      role="dialog"
      aria-modal="true"
      aria-labelledby="expense-drawer-title"
    >
      <div
        className={`w-full max-w-lg max-h-[90vh] flex flex-col rounded-xl border shadow-xl overflow-hidden ${
          isDarkMode
            ? 'bg-[#0F172A] border-slate-800 text-slate-100'
            : 'bg-white border-slate-200 text-slate-900'
        }`}
        onClick={(e) => e.stopPropagation()}
      >
        <div className="p-4 border-b dark:border-slate-800 flex items-center justify-between shrink-0">
          <div className="flex items-center gap-2">
            <Wallet className="w-5 h-5 text-indigo-500" />
            <h3 id="expense-drawer-title" className="font-bold text-sm">
              Record Business Expense
            </h3>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="p-1 rounded-xl hover:bg-slate-100 dark:hover:bg-slate-800 transition cursor-pointer"
            aria-label="Close modal"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="p-5 space-y-4 overflow-y-auto text-xs flex-1">
          {errorMsg && (
            <div className="p-3 rounded-xl border border-rose-300 dark:border-rose-800 bg-rose-50 dark:bg-rose-950/60 text-rose-700 dark:text-rose-300 flex items-center gap-2 font-semibold">
              <AlertCircle className="w-4 h-4 shrink-0" />
              <span>{errorMsg}</span>
            </div>
          )}

          <div>
            <label className="block font-bold text-slate-500 mb-1">
              Vendor / Merchant *
            </label>
            <input
              type="text"
              value={vendor}
              onChange={(e) => {
                setVendor(e.target.value);
                if (errorMsg) setErrorMsg('');
              }}
              placeholder="e.g. Amazon Web Services, Apple Store"
              className={`w-full p-2.5 rounded-xl border focus:outline-none focus:ring-2 focus:ring-indigo-500 ${
                isDarkMode
                  ? 'bg-slate-900 border-slate-800 text-slate-100'
                  : 'bg-slate-50 border-slate-200 text-slate-900'
              }`}
              autoFocus
            />
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <label className="block font-bold text-slate-500 mb-1">Category</label>
              <select
                value={category}
                onChange={(e) => setCategory(e.target.value)}
                className={`w-full p-2.5 rounded-xl border focus:outline-none ${
                  isDarkMode
                    ? 'bg-slate-900 border-slate-800 text-slate-100'
                    : 'bg-slate-50 border-slate-200 text-slate-900'
                }`}
              >
                {EXPENSE_CATEGORIES.map((cat) => (
                  <option key={cat} value={cat}>
                    {cat}
                  </option>
                ))}
              </select>
            </div>
            <div>
              <label className="block font-bold text-slate-500 mb-1">Expense Date</label>
              <input
                type="date"
                value={expenseDate}
                onChange={(e) => setExpenseDate(e.target.value)}
                className={`w-full p-2.5 rounded-xl border focus:outline-none ${
                  isDarkMode
                    ? 'bg-slate-900 border-slate-800 text-slate-100'
                    : 'bg-slate-50 border-slate-200 text-slate-900'
                }`}
              />
            </div>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <label className="block font-bold text-slate-500 mb-1">
                Base Amount ({currencySymbol}) *
              </label>
              <input
                type="text"
                inputMode="decimal"
                value={amountStr}
                onChange={(e) => {
                  setAmountStr(e.target.value);
                  if (errorMsg) setErrorMsg('');
                }}
                placeholder={currencyDecimals === 0 ? '5000' : '50.00'}
                className={`w-full p-2.5 rounded-xl border font-mono tabular-nums focus:outline-none focus:ring-2 focus:ring-indigo-500 ${
                  isDarkMode
                    ? 'bg-slate-900 border-slate-800 text-slate-100'
                    : 'bg-slate-50 border-slate-200 text-slate-900'
                }`}
              />
            </div>

            <div>
              <div className="flex items-center justify-between mb-1">
                <label className="block font-bold text-slate-500">
                  Input Tax ({currencySymbol})
                </label>
                <button
                  type="button"
                  onClick={handleApplyTenPercentTax}
                  className="text-[11px] font-bold text-indigo-600 dark:text-indigo-400 hover:underline flex items-center gap-1 cursor-pointer"
                >
                  <Sparkles className="w-3 h-3" />
                  <span>10% Tax</span>
                </button>
              </div>
              <input
                type="text"
                inputMode="decimal"
                value={taxStr}
                onChange={(e) => setTaxStr(e.target.value)}
                placeholder={currencyDecimals === 0 ? '0' : '0.00'}
                className={`w-full p-2.5 rounded-xl border font-mono tabular-nums focus:outline-none ${
                  isDarkMode
                    ? 'bg-slate-900 border-slate-800 text-slate-100'
                    : 'bg-slate-50 border-slate-200 text-slate-900'
                }`}
              />
            </div>
          </div>

          <div>
            <label className="block font-bold text-slate-500 mb-1">
              Notes / Receipt Reference (Optional)
            </label>
            <textarea
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              rows={2}
              placeholder="e.g. Annual domain renewal or AWS production bill"
              className={`w-full p-2.5 rounded-xl border focus:outline-none ${
                isDarkMode
                  ? 'bg-slate-900 border-slate-800 text-slate-100'
                  : 'bg-slate-50 border-slate-200 text-slate-900'
              }`}
            />
          </div>

          <div
            className={`p-3 rounded-xl border flex items-center justify-between font-mono tabular-nums ${
              isDarkMode
                ? 'bg-slate-900/70 border-slate-800'
                : 'bg-slate-50 border-slate-200'
            }`}
          >
            <span className="font-sans font-bold text-slate-500">Total Deductible:</span>
            <span className="text-sm font-bold text-rose-600 dark:text-rose-400">
              {formatMoney(totalUnits, currencySymbol, currencyDecimals)}
            </span>
          </div>

          <div className="pt-2 flex justify-end gap-2 border-t dark:border-slate-800">
            <button
              type="button"
              onClick={onClose}
              className="px-4 py-2 border border-slate-300 dark:border-slate-700 rounded-xl text-xs font-bold hover:bg-slate-100 dark:hover:bg-slate-800 transition cursor-pointer"
            >
              Cancel
            </button>
            <button
              type="submit"
              className="px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white font-bold text-xs rounded-xl flex items-center gap-1.5 transition cursor-pointer shadow-xs"
            >
              <Save className="w-4 h-4" />
              <span>Save Expense</span>
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

export default ExpenseDrawerModal;
