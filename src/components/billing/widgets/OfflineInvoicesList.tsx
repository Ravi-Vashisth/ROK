import React from 'react';
import { Search, FileText, CheckCircle2, Clock, AlertCircle, Eye, Trash2, DollarSign } from 'lucide-react';

interface OfflineInvoicesListProps {
  invoices: any[];
  isDarkMode: boolean;
  searchQuery: string;
  statusFilter: string;
  dateFilter: string;
  formatMoney: (cents: number) => string;
  onRecordPayment: (invoice: any) => void;
  onDeleteInvoice: (invoice: any) => void;
  onEditDraft?: (invoice: any) => void;
  onFinalizeInvoice?: (invoice: any) => void;
  onDuplicateInvoice?: (invoice: any) => void;
}

export const OfflineInvoicesList: React.FC<OfflineInvoicesListProps> = ({
  invoices,
  isDarkMode,
  searchQuery,
  statusFilter,
  dateFilter,
  formatMoney,
  onRecordPayment,
  onDeleteInvoice,
  onEditDraft,
  onFinalizeInvoice,
  onDuplicateInvoice,
}) => {
  const filteredInvoices = invoices.filter((inv) => {
    // Status filter
    const status = (inv.computed_status || inv.status || '').toUpperCase();
    if (statusFilter !== 'All') {
      if (statusFilter === 'Draft' && status !== 'DRAFT') return false;
      if (statusFilter === 'Pending' && status !== 'PENDING') return false;
      if (statusFilter === 'Partially Paid' && status !== 'PARTIALLY_PAID') return false;
      if (statusFilter === 'Paid' && status !== 'PAID') return false;
      if (statusFilter === 'Overdue' && status !== 'OVERDUE') return false;
      if (statusFilter === 'Void' && status !== 'VOID') return false;
    }

    // Search query
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase().trim();
      const matchNum = inv.invoice_number?.toLowerCase().includes(q);
      const matchClient = inv.client_name?.toLowerCase().includes(q);
      if (!matchNum && !matchClient) return false;
    }

    return true;
  });

  if (filteredInvoices.length === 0) {
    return (
      <div className={`p-12 text-center rounded-xl border ${isDarkMode ? 'bg-[#0F172A] border-slate-800 text-slate-400' : 'bg-white border-slate-200 text-slate-500'}`}>
        <FileText className="w-10 h-10 mx-auto text-slate-400 mb-3" />
        <h4 className="font-bold text-sm">No Invoices Found</h4>
        <p className="text-xs mt-1">Try adjusting your search query or filter chips.</p>
      </div>
    );
  }

  return (
    <div className={`rounded-xl border overflow-hidden ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}>
      <div className="overflow-x-auto">
        <table className="w-full text-left text-xs">
          <thead className={`border-b font-bold uppercase tracking-wider text-[11px] ${isDarkMode ? 'border-slate-800 bg-slate-900/50 text-slate-400' : 'border-slate-100 bg-slate-50 text-slate-500'}`}>
            <tr>
              <th className="p-3.5">Invoice #</th>
              <th className="p-3.5">Client</th>
              <th className="p-3.5">Issue Date</th>
              <th className="p-3.5">Due Date</th>
              <th className="p-3.5 text-right">Total Amount</th>
              <th className="p-3.5 text-right">Balance Due</th>
              <th className="p-3.5 text-center">Status</th>
              <th className="p-3.5 text-right">Actions</th>
            </tr>
          </thead>
          <tbody className={`divide-y ${isDarkMode ? 'divide-slate-800' : 'divide-slate-100'}`}>
            {filteredInvoices.map((inv) => {
              const status = inv.computed_status || inv.status;
              const isDraft = status === 'DRAFT';
              const isPaid = status === 'PAID';
              const isOverdue = status === 'OVERDUE';

              return (
                <tr key={inv.id} className={`hover:bg-indigo-50/20 transition ${isDarkMode ? 'hover:bg-slate-800/40' : ''}`}>
                  <td className="p-3.5 font-bold font-mono text-indigo-500">{inv.invoice_number}</td>
                  <td className="p-3.5 font-semibold">{inv.client_name || 'Client'}</td>
                  <td className="p-3.5 text-slate-500">{inv.issue_date}</td>
                  <td className="p-3.5 text-slate-500">{inv.due_date}</td>
                  <td className="p-3.5 text-right font-bold font-mono">{formatMoney(inv.total_cents)}</td>
                  <td className="p-3.5 text-right font-bold font-mono text-amber-600">{formatMoney(inv.balance_due_cents ?? inv.total_cents)}</td>
                  <td className="p-3.5 text-center">
                    <span className={`inline-block px-2.5 py-1 rounded-md text-[10px] font-bold uppercase ${
                      isDraft ? 'bg-slate-100 text-slate-800 dark:bg-slate-800 dark:text-slate-200 border border-slate-300 dark:border-slate-700' :
                      isPaid ? 'bg-emerald-100 text-emerald-800 dark:bg-emerald-950 dark:text-emerald-300' :
                      isOverdue ? 'bg-rose-100 text-rose-800 dark:bg-rose-950 dark:text-rose-300' :
                      'bg-indigo-50 text-indigo-700 dark:bg-indigo-950 dark:text-indigo-300'
                    }`}>
                      {status}
                    </span>
                  </td>
                  <td className="p-3.5 text-right space-x-1">
                    {isDraft && onEditDraft && (
                      <button
                        onClick={() => onEditDraft(inv)}
                        className="px-2.5 py-1 rounded-lg border border-slate-300 dark:border-slate-700 hover:bg-slate-100 dark:hover:bg-slate-800 text-slate-700 dark:text-slate-300 font-bold text-[11px] transition cursor-pointer inline-flex items-center gap-1 shadow-xs"
                        title="Edit Draft Invoice"
                      >
                        <span>Edit Draft</span>
                      </button>
                    )}
                    {isDraft && onFinalizeInvoice && (
                      <button
                        onClick={() => onFinalizeInvoice(inv)}
                        className="px-2.5 py-1 rounded-lg bg-indigo-600 hover:bg-indigo-700 text-white font-bold text-[11px] transition cursor-pointer inline-flex items-center gap-1 shadow-xs"
                        title="Finalize & Issue Invoice"
                      >
                        <CheckCircle2 className="w-3.5 h-3.5" />
                        <span>Finalize</span>
                      </button>
                    )}
                    {!isPaid && !isDraft && (
                      <button
                        onClick={() => onRecordPayment(inv)}
                        className="p-1.5 rounded-lg bg-emerald-50 hover:bg-emerald-100 text-emerald-700 dark:bg-emerald-950 dark:text-emerald-300 transition cursor-pointer"
                        title="Record Payment"
                      >
                        <DollarSign className="w-3.5 h-3.5" />
                      </button>
                    )}
                    <button
                      onClick={() => onDeleteInvoice(inv)}
                      className="p-1.5 rounded-lg bg-rose-50 hover:bg-rose-100 text-rose-700 dark:bg-rose-950 dark:text-rose-300 transition cursor-pointer"
                      title="Delete Invoice"
                    >
                      <Trash2 className="w-3.5 h-3.5" />
                    </button>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </div>
  );
};

