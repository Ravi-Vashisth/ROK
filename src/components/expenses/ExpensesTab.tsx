import React, { useState } from 'react';
import { Wallet, Plus, Search, Trash2, Tag, Calendar } from 'lucide-react';

interface ExpensesTabProps {
  expenses: any[];
  isDarkMode: boolean;
  formatMoney: (cents: number) => string;
  onAddExpense: () => void;
  onDeleteExpense: (expense: any) => void;
}

export const ExpensesTab: React.FC<ExpensesTabProps> = ({
  expenses,
  isDarkMode,
  formatMoney,
  onAddExpense,
  onDeleteExpense,
}) => {
  const [searchQuery, setSearchQuery] = useState<string>('');
  const [categoryFilter, setCategoryFilter] = useState<string>('All');

  const categories = ['All', 'Software & SaaS', 'Office Supplies', 'Hardware', 'Travel', 'Marketing', 'Utilities'];

  const filteredExpenses = expenses.filter((exp) => {
    if (categoryFilter !== 'All' && exp.category !== categoryFilter) return false;
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase().trim();
      const matchVendor = exp.vendor?.toLowerCase().includes(q);
      const matchCat = exp.category?.toLowerCase().includes(q);
      if (!matchVendor && !matchCat) return false;
    }
    return true;
  });

  const totalExpenseCents = filteredExpenses.reduce((sum, exp) => sum + (exp.total_cents || 0), 0);

  return (
    <div className="space-y-6">
      {/* Top Header */}
      <div className={`p-6 rounded-xl border flex flex-col md:flex-row items-start md:items-center justify-between gap-4 ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}>
        <div>
          <h2 className="text-xl font-bold tracking-tight">Expense Tracker & Receipts</h2>
          <p className="text-xs text-slate-500 mt-1">Track business expenses, vendor receipts, and deductibles</p>
        </div>

        <button
          onClick={onAddExpense}
          className="px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white font-bold text-xs rounded-xl flex items-center gap-2 cursor-pointer shadow-sm transition"
        >
          <Plus className="w-4 h-4" />
          <span>Record Expense</span>
        </button>
      </div>

      {/* Filter & Summary Card */}
      <div className={`p-4 rounded-xl border space-y-3 ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}>
        <div className="flex flex-col md:flex-row items-center gap-3">
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
          <div className="text-xs font-bold font-mono px-3 py-2 rounded-xl border border-rose-200 bg-rose-50 text-rose-800 dark:border-rose-900 dark:bg-rose-950 dark:text-rose-300">
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
                    ? 'bg-indigo-600 text-white'
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
                  <tr key={exp.id} className={`hover:bg-indigo-50/20 transition ${isDarkMode ? 'hover:bg-slate-800/40' : ''}`}>
                    <td className="p-3.5 font-bold">{exp.vendor}</td>
                    <td className="p-3.5 text-slate-500">{exp.category}</td>
                    <td className="p-3.5 text-slate-500">{exp.expense_date}</td>
                    <td className="p-3.5 text-right font-mono">{formatMoney(exp.amount_cents)}</td>
                    <td className="p-3.5 text-right font-mono text-slate-400">{formatMoney(exp.tax_cents || 0)}</td>
                    <td className="p-3.5 text-right font-mono font-bold text-rose-600">-{formatMoney(exp.total_cents)}</td>
                    <td className="p-3.5 text-right">
                      <button
                        onClick={() => onDeleteExpense(exp)}
                        className="p-1.5 rounded-lg bg-rose-50 hover:bg-rose-100 text-rose-700 dark:bg-rose-950 dark:text-rose-300 transition cursor-pointer inline-flex"
                        title="Delete Expense"
                      >
                        <Trash2 className="w-3.5 h-3.5" />
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
};
