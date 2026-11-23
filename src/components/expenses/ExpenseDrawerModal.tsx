import React, { useState, useEffect, useRef } from 'react';
import { Wallet, X, Save, Sparkles, AlertCircle, Paperclip, FileText } from 'lucide-react';
import {
  calculateTaxCents,
  formatDecimalUnits,
  formatLocalCalendarDate,
  formatMoney,
  getCurrencyDecimals,
  parsePriceToUnits,
  resolveEffectiveCurrency,
  validateUploadedFileBytes,
} from '../../billingRules';

interface ExpenseDrawerModalProps {
  isOpen: boolean;
  isDarkMode: boolean;
  currencyCode?: string;
  currencySymbol: string;
  currencyDecimals: number;
  initialExpense?: any | null;
  onClose: () => void;
  onSave: (expenseData: {
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
    currency_code: string;
    currency_decimals: number;
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
  currencyCode = 'USD',
  currencySymbol,
  currencyDecimals,
  initialExpense,
  onClose,
  onSave,
}) => {
  const defaultDecimals =
    currencyDecimals ?? getCurrencyDecimals(currencyCode || currencySymbol);
  const resolvedCur = resolveEffectiveCurrency({
    recordCode: initialExpense?.currency_code ?? initialExpense?.currencyCode ?? '',
    recordDecimals: String(initialExpense?.currency_code ?? initialExpense?.currencyCode ?? '').trim()
      ? (initialExpense?.currency_decimals ?? initialExpense?.currencyDecimals)
      : undefined,
    defaultCode: currencyCode,
    defaultSymbol: currencySymbol,
    defaultDecimals,
  });
  const activeCode = resolvedCur.code;
  const activeSymbol = resolvedCur.symbol;
  const activeDecimals = resolvedCur.decimals;

  const [vendor, setVendor] = useState<string>('');
  const [category, setCategory] = useState<string>('Software & SaaS');
  const [amountStr, setAmountStr] = useState<string>('');
  const [taxStr, setTaxStr] = useState<string>(formatDecimalUnits(0, activeDecimals));
  const [expenseDate, setExpenseDate] = useState<string>(formatLocalCalendarDate());
  const [notes, setNotes] = useState<string>('');
  const [receiptBase64, setReceiptBase64] = useState<string>('');
  const [receiptName, setReceiptName] = useState<string>('');
  const [errorMsg, setErrorMsg] = useState<string>('');
  const receiptInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (!isOpen) return;
    if (initialExpense) {
      setVendor(initialExpense.vendor || '');
      setCategory(initialExpense.category || 'Software & SaaS');
      setAmountStr(formatDecimalUnits(initialExpense.amount_cents || 0, activeDecimals));
      setTaxStr(formatDecimalUnits(initialExpense.tax_cents || 0, activeDecimals));
      setExpenseDate(initialExpense.expense_date || formatLocalCalendarDate());
      setNotes(initialExpense.notes || '');
      setReceiptBase64(initialExpense.receipt_base64 || '');
      setReceiptName(initialExpense.receipt_name || '');
    } else {
      setVendor('');
      setCategory('Software & SaaS');
      setAmountStr('');
      setTaxStr(formatDecimalUnits(0, activeDecimals));
      setExpenseDate(formatLocalCalendarDate());
      setNotes('');
      setReceiptBase64('');
      setReceiptName('');
    }
    setErrorMsg('');
  }, [isOpen, initialExpense, activeDecimals]);

  useEffect(() => {
    if (!isOpen) return;
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
    };
    document.addEventListener('keydown', handleKeyDown);
    return () => document.removeEventListener('keydown', handleKeyDown);
  }, [isOpen, onClose]);

  if (!isOpen) return null;

  const isEditing = !!initialExpense?.id;
  const baseUnits = parsePriceToUnits(amountStr, activeDecimals);
  const taxUnits = parsePriceToUnits(taxStr, activeDecimals);
  const totalUnits = baseUnits + taxUnits;
  const categoryOptions = EXPENSE_CATEGORIES.includes(category)
    ? EXPENSE_CATEGORIES
    : [...EXPENSE_CATEGORIES, category];

  const handleApplyTenPercentTax = () => {
    if (baseUnits <= 0) {
      setErrorMsg('Enter a positive base amount before calculating 10% tax.');
      return;
    }
    setErrorMsg('');
    const computed = calculateTaxCents(baseUnits, 10);
    setTaxStr(formatDecimalUnits(computed, activeDecimals));
  };

  const handleReceiptUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    e.target.value = '';
    if (!file) return;

    try {
      const buffer = await file.arrayBuffer();
      const bytes = new Uint8Array(buffer);
      const validation = validateUploadedFileBytes({
        bytes,
        filename: file.name,
        allowPdf: true,
      });
      if (!validation.isValid || !validation.mimeType) {
        setErrorMsg(validation.errorMessage || 'Invalid receipt file selected.');
        return;
      }

      const reader = new FileReader();
      reader.onload = (ev) => {
        const result = ev.target?.result;
        if (typeof result === 'string') {
          const commaIdx = result.indexOf(',');
          const b64Payload = commaIdx >= 0 ? result.slice(commaIdx + 1) : result;
          setReceiptBase64(`data:${validation.mimeType};base64,${b64Payload}`);
          setReceiptName(file.name);
          setErrorMsg('');
        }
      };
      reader.readAsDataURL(file);
    } catch {
      setErrorMsg('Unable to read the selected receipt file.');
    }
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
      ...(isEditing ? { id: initialExpense.id } : {}),
      vendor: vendor.trim(),
      category,
      amount_cents: baseUnits,
      tax_cents: taxUnits,
      total_cents: totalUnits,
      expense_date: expenseDate || formatLocalCalendarDate(),
      notes: notes.trim(),
      receipt_base64: receiptBase64,
      receipt_name: receiptName,
      currency_code: activeCode,
      currency_decimals: activeDecimals,
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
            <Wallet className="w-5 h-5 accent-text" />
            <h3 id="expense-drawer-title" className="font-bold text-sm">
              {isEditing ? `Edit Business Expense (${activeCode})` : `Record Business Expense (${activeCode})`}
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
              className={`w-full p-2.5 rounded-xl border accent-focus ${
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
                {categoryOptions.map((cat) => (
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
                Base Amount ({activeSymbol}) *
              </label>
              <input
                type="text"
                inputMode={activeDecimals > 0 ? 'decimal' : 'numeric'}
                value={amountStr}
                onChange={(e) => {
                  setAmountStr(e.target.value);
                  if (errorMsg) setErrorMsg('');
                }}
                placeholder={activeDecimals === 0 ? '5000' : activeDecimals === 3 ? '50.000' : '50.00'}
                className={`w-full p-2.5 rounded-xl border font-mono tabular-nums accent-focus ${
                  isDarkMode
                    ? 'bg-slate-900 border-slate-800 text-slate-100'
                    : 'bg-slate-50 border-slate-200 text-slate-900'
                }`}
              />
            </div>

            <div>
              <div className="flex items-center justify-between mb-1">
                <label className="block font-bold text-slate-500">
                  Input Tax ({activeSymbol})
                </label>
                <button
                  type="button"
                  onClick={handleApplyTenPercentTax}
                  className="text-[11px] font-bold accent-text hover:underline flex items-center gap-1 cursor-pointer"
                >
                  <Sparkles className="w-3 h-3" />
                  <span>10% Tax</span>
                </button>
              </div>
              <input
                type="text"
                inputMode={activeDecimals > 0 ? 'decimal' : 'numeric'}
                value={taxStr}
                onChange={(e) => setTaxStr(e.target.value)}
                placeholder={formatDecimalUnits(0, activeDecimals)}
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

          {/* Receipt Upload & Preview */}
          <div className="space-y-2">
            <label className="block font-bold text-slate-500">
              Attach Receipt (PNG, JPG, WEBP, PDF &bull; max 5 MB)
            </label>
            <input
              ref={receiptInputRef}
              type="file"
              accept="image/png,image/jpeg,image/webp,application/pdf,.png,.jpg,.jpeg,.webp,.pdf"
              onChange={handleReceiptUpload}
              className="hidden"
            />
            <div className="flex flex-wrap items-center gap-2">
              <button
                type="button"
                onClick={() => receiptInputRef.current?.click()}
                className={`px-3 py-2 rounded-xl border font-bold flex items-center gap-2 transition cursor-pointer ${
                  isDarkMode
                    ? 'bg-slate-900 border-slate-700 hover:bg-slate-800 text-slate-200'
                    : 'bg-slate-50 border-slate-200 hover:bg-slate-100 text-slate-700'
                }`}
              >
                <Paperclip className="w-3.5 h-3.5 accent-text" />
                <span className="truncate max-w-[220px]">
                  {receiptName ? `Receipt: ${receiptName}` : 'Attach Receipt (Image/PDF)'}
                </span>
              </button>
              {receiptBase64 && (
                <button
                  type="button"
                  onClick={() => {
                    setReceiptBase64('');
                    setReceiptName('');
                  }}
                  className="px-2.5 py-2 rounded-xl text-rose-600 hover:bg-rose-50 dark:hover:bg-rose-950 font-bold flex items-center gap-1 cursor-pointer"
                >
                  <X className="w-3.5 h-3.5" />
                  <span>Remove</span>
                </button>
              )}
            </div>

            {receiptBase64 && (
              <div
                className={`p-2.5 rounded-xl border flex items-center gap-3 ${
                  isDarkMode ? 'bg-slate-900/70 border-slate-800' : 'bg-slate-50 border-slate-200'
                }`}
              >
                {receiptBase64.startsWith('data:image') ? (
                  <img
                    src={receiptBase64}
                    alt={receiptName || 'Receipt preview'}
                    className="h-12 w-12 object-cover rounded-lg border border-slate-200 dark:border-slate-700 shrink-0"
                  />
                ) : (
                  <div className="h-12 w-12 rounded-lg bg-rose-50 dark:bg-rose-950 border border-rose-200 dark:border-rose-800 flex items-center justify-center shrink-0">
                    <FileText className="w-6 h-6 text-rose-500" />
                  </div>
                )}
                <div className="min-w-0 flex-1">
                  <div className="font-bold truncate">{receiptName || 'Attached Receipt'}</div>
                  <div className="text-[11px] text-slate-400">
                    {receiptBase64.startsWith('data:application/pdf') ? 'PDF document ready' : 'Image preview ready'}
                  </div>
                </div>
              </div>
            )}
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
              {formatMoney(totalUnits, activeSymbol, activeDecimals, activeCode)}
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
              className="px-4 py-2 accent-btn font-bold text-xs rounded-xl flex items-center gap-1.5 transition cursor-pointer shadow-xs"
            >
              <Save className="w-4 h-4" />
              <span>{isEditing ? 'Update Expense' : 'Save Expense'}</span>
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

export default ExpenseDrawerModal;
