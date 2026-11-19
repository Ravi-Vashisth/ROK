import React, { useState, useEffect } from 'react';
import { Wallet, Plus, Search, Trash2, Edit2, Paperclip, X, FileText } from 'lucide-react';

interface ExpensesTabProps {
  expenses: any[];
  isDarkMode: boolean;
  formatMoney: (cents: number) => string;
  onAddExpense: () => void;
  onEditExpense: (expense: any) => void;
  onDeleteExpense: (expense: any) => void;
}

export const ExpensesTab: React.FC<ExpensesTabProps> = ({
  expenses,
  isDarkMode,
  formatMoney,
  onAddExpense,
  onEditExpense,
  onDeleteExpense,
}) => {
  const [searchQuery, setSearchQuery] = useState<string>('');
  const [categoryFilter, setCategoryFilter] = useState<string>('All');
  const [previewExpense, setPreviewExpense] = useState<any | null>(null);

  useEffect(() => {
    if (!previewExpense) return;
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        setPreviewExpense(null);
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [previewExpense]);

  const categories = [
    'All',
    'Software & SaaS',
    'Software',
    'Office Supplies',
    'Hardware',
    'Travel',
    'Marketing',
    'Utilities',
    'Subcontracting',
    'Other',
  ];

  const filteredExpenses = expenses.filter((exp) => {
    if (categoryFilter !== 'All' && exp.category !== categoryFilter) return false;
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase().trim();
      const matchVendor = exp.vendor?.toLowerCase().includes(q);
      const matchCat = exp.category?.toLowerCase().includes(q);
      const matchNotes = exp.notes?.toLowerCase().includes(q);
      if (!matchVendor && !matchCat && !matchNotes) return false;
    }
    return true;
  });

  const totalExpenseCents = filteredExpenses.reduce((sum, exp) => sum + (exp.total_cents || 0), 0);

  return (
    <div className="space-y-6">
      {/* Top Header */}
      <div className={`p-6 rounded-xl border flex flex-col min-[900px]:flex-row items-start min-[900px]:items-center justify-between gap-4 ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}>
        <div>
          <h2 className="text-xl font-bold tracking-tight">Expense Tracker & Receipts</h2>
          <p className="text-xs text-slate-500 mt-1">Track business expenses, vendor receipts, and deductibles</p>
        </div>

        <button
          onClick={onAddExpense}
          className="px-4 py-2 accent-btn font-bold text-xs rounded-xl flex items-center gap-2 cursor-pointer shadow-sm transition shrink-0"
        >
          <Plus className="w-4 h-4" />
          <span>Record Expense</span>
        </button>
      </div>

      {/* Filter & Summary Card */}
      <div className={`p-4 rounded-xl border space-y-3 ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}>
        <div className="flex flex-col min-[900px]:flex-row items-stretch min-[900px]:items-center gap-3">
          <div className="relative flex-1 w-full">
            <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder="Search expenses by vendor or category"
              className={`w-full pl-9 pr-3 py-2 rounded-xl text-xs border focus:outline-none ${isDarkMode ? 'bg-slate-900 border-slate-800 text-slate-100' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
            />
          </div>
          <div className="text-xs font-bold font-mono tabular-nums px-3 py-2 rounded-xl border border-rose-200 bg-rose-50 text-rose-800 dark:border-rose-900 dark:bg-rose-950 dark:text-rose-300 shrink-0 text-center min-[900px]:text-left">
            Total: {formatMoney(totalExpenseCents)}
          </div>
        </div>

        {/* Categories */}
        <div className="flex items-center gap-2 overflow-x-auto pb-1">
          {categories.map((cat) => {
            const isSelected = categoryFilter === cat;
            return (
              <button
                key={cat}
                onClick={() => setCategoryFilter(cat)}
                className={`px-3 py-1 rounded-lg text-xs font-semibold whitespace-nowrap transition cursor-pointer ${
                  isSelected
                    ? 'accent-tab-active'
                    : isDarkMode ? 'bg-slate-800 text-slate-300 hover:bg-slate-700' : 'bg-slate-100 text-slate-600 hover:bg-slate-200'
                }`}
              >
                {cat}
              </button>
            );
          })}
        </div>
      </div>

      {/* Expense List Table */}
      {filteredExpenses.length === 0 ? (
        <div className={`p-12 text-center rounded-xl border ${isDarkMode ? 'bg-[#0F172A] border-slate-800 text-slate-400' : 'bg-white border-slate-200 text-slate-500'}`}>
          <Wallet className="w-10 h-10 mx-auto text-slate-400 mb-3" />
          <h4 className="font-bold text-sm">No Expenses Recorded</h4>
          <p className="text-xs mt-1">Click "Record Expense" to track your business costs.</p>
        </div>
      ) : (
        <div className={`rounded-xl border overflow-hidden ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}>
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead className={`border-b font-bold uppercase tracking-wider text-[11px] ${isDarkMode ? 'border-slate-800 bg-slate-900/50 text-slate-400' : 'border-slate-100 bg-slate-50 text-slate-500'}`}>
                <tr>
                  <th className="p-3.5">Vendor</th>
                  <th className="p-3.5">Category</th>
                  <th className="p-3.5">Date</th>
                  <th className="p-3.5 text-right">Amount</th>
                  <th className="p-3.5 text-right">Tax</th>
                  <th className="p-3.5 text-right">Total</th>
                  <th className="p-3.5 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className={`divide-y ${isDarkMode ? 'divide-slate-800' : 'divide-slate-100'}`}>
                {filteredExpenses.map((exp) => (
                  <tr key={exp.id} className="accent-hover-row transition">
                    <td className="p-3.5 font-bold">
                      <div className="flex flex-wrap items-center gap-2">
                        <span>{exp.vendor}</span>
                        {exp.receipt_base64 && (
                          <button
                            type="button"
                            onClick={() => setPreviewExpense(exp)}
                            className="px-2 py-0.5 rounded-lg border accent-soft-btn text-[10px] font-bold inline-flex items-center gap-1 cursor-pointer transition"
                            title={exp.receipt_name || 'Preview Receipt'}
                          >
                            <Paperclip className="w-3 h-3" />
                            <span>Receipt</span>
                          </button>
                        )}
                      </div>
                      {exp.notes && (
                        <div className="text-[11px] font-normal text-slate-400 truncate max-w-xs mt-0.5">
                          {exp.notes}
                        </div>
                      )}
                    </td>
                    <td className="p-3.5 text-slate-500">{exp.category}</td>
                    <td className="p-3.5 text-slate-500">{exp.expense_date}</td>
                    <td className="p-3.5 text-right font-mono tabular-nums whitespace-nowrap">{formatMoney(exp.amount_cents)}</td>
                    <td className="p-3.5 text-right font-mono tabular-nums text-slate-400 whitespace-nowrap">{formatMoney(exp.tax_cents || 0)}</td>
                    <td className="p-3.5 text-right font-mono tabular-nums font-bold text-rose-600 whitespace-nowrap">-{formatMoney(exp.total_cents)}</td>
                    <td className="p-3.5 text-right whitespace-nowrap">
                      <div className="inline-flex items-center gap-1.5">
                        <button
                          type="button"
                          onClick={() => onEditExpense(exp)}
                          className={`p-1.5 rounded-xl border transition cursor-pointer inline-flex ${
                            isDarkMode
                              ? 'border-slate-700 hover:bg-slate-800 text-slate-300'
                              : 'border-slate-200 hover:bg-slate-100 text-slate-700'
                          }`}
                          title="Edit Expense"
                        >
                          <Edit2 className="w-3.5 h-3.5" />
                        </button>
                        <button
                          type="button"
                          onClick={() => onDeleteExpense(exp)}
                          className="p-1.5 rounded-xl bg-rose-50 hover:bg-rose-100 text-rose-700 dark:bg-rose-950 dark:text-rose-300 transition cursor-pointer inline-flex"
                          title="Delete Expense"
                        >
                          <Trash2 className="w-3.5 h-3.5" />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Receipt Preview Modal */}
      {previewExpense && (
        <div
          className="fixed inset-0 bg-black/50 backdrop-blur-xs flex items-center justify-center p-4 z-50"
          onClick={(e) => {
            if (e.target === e.currentTarget) {
              setPreviewExpense(null);
            }
          }}
        >
          <div
            role="dialog"
            aria-modal="true"
            className={`w-full max-w-md max-h-[90vh] overflow-y-auto rounded-xl border p-6 space-y-4 shadow-xl ${
              isDarkMode ? 'bg-[#0F172A] border-slate-800 text-slate-100' : 'bg-white border-slate-200 text-slate-900'
            }`}
          >
            <div className="flex items-center justify-between gap-2">
              <div className="min-w-0">
                <h3 className="font-bold text-sm truncate">Receipt: {previewExpense.vendor}</h3>
                {previewExpense.receipt_name && (
                  <p className="text-[11px] text-slate-400 truncate mt-0.5">
                    File: {previewExpense.receipt_name}
                  </p>
                )}
              </div>
              <button
                type="button"
                onClick={() => setPreviewExpense(null)}
                className="text-slate-400 hover:text-slate-600 cursor-pointer shrink-0"
                aria-label="Close receipt preview"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            {previewExpense.receipt_base64?.startsWith('data:image') ? (
              <div className="rounded-xl border border-slate-200 dark:border-slate-800 overflow-hidden bg-slate-50 dark:bg-slate-900 flex items-center justify-center p-2">
                <img
                  src={previewExpense.receipt_base64}
                  alt={previewExpense.receipt_name || 'Expense receipt'}
                  className="max-h-72 object-contain rounded-lg"
                />
              </div>
            ) : previewExpense.receipt_base64?.startsWith('data:application/pdf') ? (
              <div className={`p-6 rounded-xl border text-center space-y-2 ${isDarkMode ? 'bg-slate-900 border-slate-800' : 'bg-slate-50 border-slate-200'}`}>
                <FileText className="w-10 h-10 text-rose-500 mx-auto" />
                <p className="text-xs font-bold">PDF Receipt Document Attached</p>
                <a
                  href={previewExpense.receipt_base64}
                  download={previewExpense.receipt_name || 'receipt.pdf'}
                  className="inline-flex px-3 py-1.5 rounded-xl accent-btn text-xs font-bold transition"
                >
                  Download PDF Receipt
                </a>
              </div>
            ) : (
              <p className="text-xs text-slate-400">No receipt preview available.</p>
            )}

            <div className="flex justify-end">
              <button
                type="button"
                onClick={() => setPreviewExpense(null)}
                className="px-4 py-1.5 text-xs font-bold rounded-xl border border-slate-300 dark:border-slate-700 hover:bg-slate-100 dark:hover:bg-slate-800 cursor-pointer"
              >
                Close
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
