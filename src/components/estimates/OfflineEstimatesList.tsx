import React from 'react';
import { FileText, ArrowRightLeft, Trash2 } from 'lucide-react';

interface OfflineEstimatesListProps {
  estimates: any[];
  isDarkMode: boolean;
  searchQuery: string;
  statusFilter: string;
  dateFilter: string;
  formatMoney: (cents: number) => string;
  onConvertEstimate: (estimate: any) => void;
  onDeleteEstimate: (estimate: any) => void;
}

export const OfflineEstimatesList: React.FC<OfflineEstimatesListProps> = ({
  estimates,
  isDarkMode,
  searchQuery,
  statusFilter,
  dateFilter,
  formatMoney,
  onConvertEstimate,
  onDeleteEstimate,
}) => {
  const filteredEstimates = estimates.filter((est) => {
    // Search query
    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase().trim();
      const matchNum = est.estimate_number?.toLowerCase().includes(q);
      const matchClient = est.client_name?.toLowerCase().includes(q);
      if (!matchNum && !matchClient) return false;
    }
    return true;
  });

  if (filteredEstimates.length === 0) {
    return (
      <div className={`p-12 text-center rounded-xl border ${isDarkMode ? 'bg-[#0F172A] border-slate-800 text-slate-400' : 'bg-white border-slate-200 text-slate-500'}`}>
        <FileText className="w-10 h-10 mx-auto text-slate-400 mb-3" />
        <h4 className="font-bold text-sm">No Quotes Recorded</h4>
        <p className="text-xs mt-1">Click "+ New Quote" to create your first estimate or proposal.</p>
      </div>
    );
  }

  return (
    <div className={`rounded-xl border overflow-hidden ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}>
      <div className="overflow-x-auto">
        <table className="w-full text-left text-xs">
          <thead className={`border-b font-bold uppercase tracking-wider text-[11px] ${isDarkMode ? 'border-slate-800 bg-slate-900/50 text-slate-400' : 'border-slate-100 bg-slate-50 text-slate-500'}`}>
            <tr>
              <th className="p-3.5">Quote #</th>
              <th className="p-3.5">Client</th>
              <th className="p-3.5">Issue Date</th>
              <th className="p-3.5">Expiry Date</th>
              <th className="p-3.5 text-right">Total Amount</th>
              <th className="p-3.5 text-center">Status</th>
              <th className="p-3.5 text-right">Actions</th>
            </tr>
          </thead>
          <tbody className={`divide-y ${isDarkMode ? 'divide-slate-800' : 'divide-slate-100'}`}>
            {filteredEstimates.map((est) => {
              const isConverted = est.status === 'CONVERTED';

              return (
                <tr key={est.id} className={`hover:bg-indigo-50/20 transition ${isDarkMode ? 'hover:bg-slate-800/40' : ''}`}>
                  <td className="p-3.5 font-bold font-mono text-amber-600">{est.estimate_number}</td>
                  <td className="p-3.5 font-semibold">{est.client_name || 'Client'}</td>
                  <td className="p-3.5 text-slate-500">{est.issue_date}</td>
                  <td className="p-3.5 text-slate-500">{est.expiry_date}</td>
                  <td className="p-3.5 text-right font-bold font-mono">{formatMoney(est.total_cents)}</td>
                  <td className="p-3.5 text-center">
                    <span className={`inline-block px-2.5 py-1 rounded-md text-[10px] font-bold uppercase ${
                      isConverted ? 'bg-emerald-100 text-emerald-800 dark:bg-emerald-950 dark:text-emerald-300' :
                      'bg-amber-100 text-amber-800 dark:bg-amber-950 dark:text-amber-300'
                    }`}>
                      {est.status || 'PENDING'}
                    </span>
                  </td>
                  <td className="p-3.5 text-right space-x-1">
                    {!isConverted && (
                      <button
                        onClick={() => onConvertEstimate(est)}
                        className="px-2 py-1 bg-emerald-50 hover:bg-emerald-100 text-emerald-700 dark:bg-emerald-950 dark:text-emerald-300 text-[11px] font-bold rounded-lg flex items-center gap-1 inline-flex cursor-pointer transition"
                        title="Convert to Live Invoice"
                      >
                        <ArrowRightLeft className="w-3 h-3" />
                        <span>Convert</span>
                      </button>
                    )}
                    <button
                      onClick={() => onDeleteEstimate(est)}
                      className="p-1.5 rounded-lg bg-rose-50 hover:bg-rose-100 text-rose-700 dark:bg-rose-950 dark:text-rose-300 transition cursor-pointer inline-flex"
                      title="Delete Quote"
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
