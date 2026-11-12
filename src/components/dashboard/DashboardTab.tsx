import React from 'react';
import { LayoutDashboard, TrendingUp, CheckCircle, Clock, AlertTriangle, ArrowUpRight, ArrowDownRight, Plus } from 'lucide-react';

interface DashboardTabProps {
  invoices: any[];
  expenses: any[];
  clients: any[];
  isDarkMode: boolean;
  currencySymbol: string;
  formatMoney: (cents: number) => string;
  onNavigateToSales: () => void;
  onNavigateToExpenses: () => void;
  onCreateInvoice: () => void;
}

export const DashboardTab: React.FC<DashboardTabProps> = ({
  invoices,
  expenses,
  clients,
  isDarkMode,
  currencySymbol,
  formatMoney,
  onNavigateToSales,
  onNavigateToExpenses,
  onCreateInvoice,
}) => {
  // Cash flow metrics (exclude DRAFT and VOID invoices)
  const activeInvoices = invoices.filter(
    (inv) => inv.status !== 'DRAFT' && inv.status !== 'VOID'
  );
  const totalInvoicedCents = activeInvoices.reduce((sum, inv) => sum + (inv.total_cents || 0), 0);
  const totalCollectedCents = activeInvoices.reduce((sum, inv) => sum + (inv.paid_cents || 0), 0);
  const pendingBalanceCents = activeInvoices.reduce((sum, inv) => sum + (inv.balance_due_cents || 0), 0);
  
  const todayDate = new Date();
  todayDate.setHours(0, 0, 0, 0);

  const overdueInvoices = activeInvoices.filter((inv) => {
    if (!inv.due_date || (inv.balance_due_cents || 0) <= 0) return false;
    const due = new Date(inv.due_date);
    due.setHours(0, 0, 0, 0);
    return todayDate > due;
  });

  const overdueAmountCents = overdueInvoices.reduce(
    (sum, inv) => sum + (inv.balance_due_cents || 0),
    0
  );

  const totalExpenseCents = expenses.reduce((sum, exp) => sum + (exp.total_cents || 0), 0);
  const netProfitCents = totalCollectedCents - totalExpenseCents;

  const recentInvoices = invoices.filter((i) => i.status !== 'DRAFT').slice(0, 5);
  const recentExpenses = expenses.slice(0, 5);

  return (
    <div className="space-y-6">
      {/* Top Banner */}
      <div className={`p-6 rounded-xl border flex flex-col md:flex-row items-start md:items-center justify-between gap-4 ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}>
        <div>
          <h2 className="text-xl font-bold tracking-tight">Executive Financial Dashboard</h2>
          <p className="text-xs text-slate-500 mt-1">Real-time local ledger overview & cash flow metrics</p>
        </div>
        <button
          onClick={onCreateInvoice}
          className="px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white font-bold text-xs rounded-xl flex items-center gap-2 cursor-pointer shadow-sm transition"
        >
          <Plus className="w-4 h-4" />
          <span>Create New Invoice</span>
        </button>
      </div>

      {/* Cash Flow Metrics Bar */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className={`p-4 rounded-xl border ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}>
          <div className="flex items-center gap-2 text-xs font-semibold text-slate-500 mb-2">
            <TrendingUp className="w-4 h-4 text-indigo-500" />
            <span>Total Invoiced</span>
          </div>
          <div className="text-xl font-extrabold font-mono">{formatMoney(totalInvoicedCents)}</div>
          <p className="text-[11px] text-slate-400 mt-1">{invoices.length} invoices issued</p>
        </div>

        <div className={`p-4 rounded-xl border ${isDarkMode ? 'bg-emerald-950/30 border-emerald-900/50 text-emerald-300' : 'bg-emerald-50/60 border-emerald-200 text-emerald-900'}`}>
          <div className="flex items-center gap-2 text-xs font-semibold mb-2">
            <CheckCircle className="w-4 h-4 text-emerald-600" />
            <span>Total Collected</span>
          </div>
          <div className="text-xl font-extrabold font-mono">{formatMoney(totalCollectedCents)}</div>
          <p className="text-[11px] opacity-80 mt-1">Settled payments</p>
        </div>

        <div className={`p-4 rounded-xl border ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}>
          <div className="flex items-center gap-2 text-xs font-semibold text-slate-500 mb-2">
            <Clock className="w-4 h-4 text-amber-500" />
            <span>Pending Balance</span>
          </div>
          <div className="text-xl font-extrabold font-mono">{formatMoney(pendingBalanceCents)}</div>
          <p className="text-[11px] text-slate-400 mt-1">Awaiting client payment</p>
        </div>

        <div className={`p-4 rounded-xl border ${isDarkMode ? 'bg-rose-950/30 border-rose-900/50 text-rose-300' : 'bg-rose-50/60 border-rose-200 text-rose-900'}`}>
          <div className="flex items-center gap-2 text-xs font-semibold mb-2">
            <AlertTriangle className="w-4 h-4 text-rose-600" />
            <span>Overdue Amount</span>
          </div>
          <div className="text-xl font-extrabold font-mono">{formatMoney(overdueAmountCents)}</div>
          <p className="text-[11px] opacity-80 mt-1">Passed payment terms</p>
        </div>
      </div>

      {/* Net Profit Summary */}
      <div className={`p-5 rounded-xl border flex flex-wrap items-center justify-between gap-4 ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}>
        <div className="flex items-center gap-4">
          <div className={`p-3 rounded-xl ${netProfitCents >= 0 ? 'bg-emerald-500/10 text-emerald-500' : 'bg-rose-500/10 text-rose-500'}`}>
            {netProfitCents >= 0 ? <ArrowUpRight className="w-6 h-6" /> : <ArrowDownRight className="w-6 h-6" />}
          </div>
          <div>
            <span className="text-xs text-slate-500 font-semibold uppercase tracking-wider">Net Operating Profit</span>
            <div className="text-2xl font-black font-mono mt-0.5">{formatMoney(netProfitCents)}</div>
            <p className="text-xs text-slate-400 mt-0.5">Collected ({formatMoney(totalCollectedCents)}) − Expenses ({formatMoney(totalExpenseCents)})</p>
          </div>
        </div>
        <div className="flex gap-2">
          <button
            onClick={onNavigateToSales}
            className="px-3 py-1.5 bg-slate-100 hover:bg-slate-200 dark:bg-slate-800 dark:hover:bg-slate-700 text-xs font-bold rounded-xl transition cursor-pointer"
          >
            View Sales & Invoices
          </button>
          <button
            onClick={onNavigateToExpenses}
            className="px-3 py-1.5 bg-slate-100 hover:bg-slate-200 dark:bg-slate-800 dark:hover:bg-slate-700 text-xs font-bold rounded-xl transition cursor-pointer"
          >
            View Expenses
          </button>
        </div>
      </div>

      {/* Action Required Triage Inbox */}
      <div className={`p-4 rounded-xl border space-y-3 ${isDarkMode ? 'bg-amber-950/20 border-amber-900/50' : 'bg-amber-50/50 border-amber-300'}`}>
        <div className="flex items-center gap-2 text-xs font-bold text-amber-600 dark:text-amber-400">
          <AlertTriangle className="w-4 h-4" />
          <span>Action Required Triage ({overdueInvoices.length} Pending)</span>
        </div>
        {overdueInvoices.length === 0 ? (
          <p className="text-xs text-emerald-600 font-semibold">All client balances are up to date. No urgent action required.</p>
        ) : (
          <div className="space-y-2">
            {overdueInvoices.map((inv) => {
              const due = new Date(inv.due_date);
              const diffMs = todayDate.getTime() - due.getTime();
              const days = Math.max(1, Math.floor(diffMs / (1000 * 60 * 60 * 24)));
              return (
                <div key={inv.id} className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-2 text-xs">
                  <span className="text-slate-700 dark:text-slate-300">
                    Invoice <strong className="text-indigo-600">{inv.invoice_number}</strong> for {inv.client_name || 'Client'} is {days} {days === 1 ? 'day' : 'days'} overdue ({formatMoney(inv.balance_due_cents || 0)} balance due).
                  </span>
                  <button
                    onClick={onNavigateToSales}
                    className="px-2.5 py-1 bg-white dark:bg-slate-800 border border-slate-300 dark:border-slate-700 rounded-lg font-bold text-[11px] text-indigo-600 cursor-pointer hover:bg-slate-50 shrink-0"
                  >
                    View in Sales
                  </button>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* Two Column Grid: Recent Invoices & Recent Expenses */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Recent Invoices */}
        <div className={`p-5 rounded-xl border space-y-4 ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}>
          <div className="flex items-center justify-between">
            <h3 className="font-bold text-sm">Recent Invoices</h3>
            <button onClick={onNavigateToSales} className="text-xs font-bold text-indigo-500 hover:underline cursor-pointer">
              View All ({invoices.length})
            </button>
          </div>
          {recentInvoices.length === 0 ? (
            <p className="text-xs text-slate-400 py-6 text-center">No invoices created yet.</p>
          ) : (
            <div className="space-y-2">
              {recentInvoices.map((inv) => (
                <div key={inv.id} className={`p-3 rounded-xl border flex items-center justify-between text-xs ${isDarkMode ? 'border-slate-800 bg-slate-900/50' : 'border-slate-100 bg-slate-50'}`}>
                  <div>
                    <div className="font-bold font-mono text-indigo-500">{inv.invoice_number}</div>
                    <div className="text-slate-500 text-[11px] mt-0.5">{inv.client_name || 'Client'}</div>
                  </div>
                  <div className="text-right">
                    <div className="font-bold font-mono">{formatMoney(inv.total_cents)}</div>
                    <span className="text-[10px] font-bold uppercase px-2 py-0.5 rounded-md bg-indigo-50 text-indigo-700 dark:bg-indigo-950 dark:text-indigo-300">
                      {inv.computed_status || inv.status}
                    </span>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Recent Expenses */}
        <div className={`p-5 rounded-xl border space-y-4 ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}>
          <div className="flex items-center justify-between">
            <h3 className="font-bold text-sm">Recent Expenses</h3>
            <button onClick={onNavigateToExpenses} className="text-xs font-bold text-indigo-500 hover:underline cursor-pointer">
              View All ({expenses.length})
            </button>
          </div>
          {recentExpenses.length === 0 ? (
            <p className="text-xs text-slate-400 py-6 text-center">No expenses recorded yet.</p>
          ) : (
            <div className="space-y-2">
              {recentExpenses.map((exp) => (
                <div key={exp.id} className={`p-3 rounded-xl border flex items-center justify-between text-xs ${isDarkMode ? 'border-slate-800 bg-slate-900/50' : 'border-slate-100 bg-slate-50'}`}>
                  <div>
                    <div className="font-bold">{exp.vendor}</div>
                    <div className="text-slate-500 text-[11px] mt-0.5">{exp.category} • {exp.expense_date}</div>
                  </div>
                  <div className="text-right font-bold font-mono text-rose-500">
                    -{formatMoney(exp.total_cents)}
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
};
