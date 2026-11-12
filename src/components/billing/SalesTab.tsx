import React, { useState } from 'react';
import { ReceiptText, FileText, Plus, Search } from 'lucide-react';
import { OfflineInvoicesList } from './widgets/OfflineInvoicesList';
import { OfflineEstimatesList } from '../estimates/OfflineEstimatesList';

interface SalesTabProps {
  invoices: any[];
  estimates: any[];
  isDarkMode: boolean;
  formatMoney: (cents: number) => string;
  onCreateInvoice: () => void;
  onCreateQuote: () => void;
  onRecordPayment: (invoice: any) => void;
  onDeleteInvoice: (invoice: any) => void;
  onConvertEstimate: (estimate: any) => void;
  onDeleteEstimate: (estimate: any) => void;
  onEditInvoiceDraft?: (invoice: any) => void;
  onEditEstimateDraft?: (estimate: any) => void;
  onFinalizeInvoice?: (invoice: any) => void;
  onFinalizeEstimate?: (estimate: any) => void;
}

export const SalesTab: React.FC<SalesTabProps> = ({
  invoices,
  estimates,
  isDarkMode,
  formatMoney,
  onCreateInvoice,
  onCreateQuote,
  onRecordPayment,
  onDeleteInvoice,
  onConvertEstimate,
  onDeleteEstimate,
  onEditInvoiceDraft,
  onEditEstimateDraft,
  onFinalizeInvoice,
  onFinalizeEstimate,
}) => {
  const [subTab, setSubTab] = useState<number>(0); // 0 = Invoices, 1 = Estimates
  const [searchQuery, setSearchQuery] = useState<string>('');
  const [statusFilter, setStatusFilter] = useState<string>('All');
  const [dateFilter, setDateFilter] = useState<string>('All Time');

  return (
    <div className="space-y-6">
      {/* Sales Header & Action Bar */}
      <div className={`p-6 rounded-xl border flex flex-col md:flex-row items-start md:items-center justify-between gap-4 ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}>
        <div>
          <h2 className="text-xl font-bold tracking-tight">Sales & Proposals Overview</h2>
          <p className="text-xs text-slate-500 mt-1">Manage client invoices, proposals, and track receivables</p>
        </div>

        <div className="flex flex-wrap items-center gap-3">
          {/* SubTab Toggles */}
          <div className={`p-1 rounded-xl border flex items-center gap-1 ${isDarkMode ? 'bg-slate-900 border-slate-800' : 'bg-slate-100 border-slate-200'}`}>
            <button
              onClick={() => { setSubTab(0); setStatusFilter('All'); }}
              className={`px-3 py-1.5 rounded-lg text-xs font-bold flex items-center gap-1.5 transition cursor-pointer ${
                subTab === 0
                  ? isDarkMode ? 'bg-indigo-600 text-white' : 'bg-white text-slate-900 shadow-sm'
                  : 'text-slate-500 hover:text-slate-800'
              }`}
            >
              <ReceiptText className="w-3.5 h-3.5" />
              <span>Invoices ({invoices.length})</span>
            </button>
            <button
              onClick={() => { setSubTab(1); setStatusFilter('All'); }}
              className={`px-3 py-1.5 rounded-lg text-xs font-bold flex items-center gap-1.5 transition cursor-pointer ${
                subTab === 1
                  ? isDarkMode ? 'bg-indigo-600 text-white' : 'bg-white text-slate-900 shadow-sm'
                  : 'text-slate-500 hover:text-slate-800'
              }`}
            >
              <FileText className="w-3.5 h-3.5" />
              <span>Quotes / Estimates ({estimates.length})</span>
            </button>
          </div>

          {/* Create Button */}
          {subTab === 0 ? (
            <button
              onClick={onCreateInvoice}
              className="px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white font-bold text-xs rounded-xl flex items-center gap-2 cursor-pointer shadow-sm transition"
            >
              <Plus className="w-4 h-4" />
              <span>Create Invoice</span>
            </button>
          ) : (
            <button
              onClick={onCreateQuote}
              className="px-4 py-2 bg-amber-600 hover:bg-amber-700 text-white font-bold text-xs rounded-xl flex items-center gap-2 cursor-pointer shadow-sm transition"
            >
              <Plus className="w-4 h-4" />
              <span>New Quote</span>
            </button>
          )}
        </div>
      </div>

      {/* Filter & Search Card */}
      <div className={`p-4 rounded-xl border space-y-3 ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}>
        <div className="flex flex-col md:flex-row items-center gap-3">
          <div className="relative flex-1 w-full">
            <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder="Search by client name or invoice / quote #"
              className={`w-full pl-9 pr-3 py-2 rounded-xl text-xs border focus:outline-none focus:ring-2 focus:ring-indigo-500 ${isDarkMode ? 'bg-slate-900 border-slate-800 text-slate-100' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
            />
          </div>
          <select
            value={dateFilter}
            onChange={(e) => setDateFilter(e.target.value)}
            className={`px-3 py-2 rounded-xl text-xs border focus:outline-none ${isDarkMode ? 'bg-slate-900 border-slate-800 text-slate-200' : 'bg-slate-50 border-slate-200 text-slate-700'}`}
          >
            <option value="All Time">All Time</option>
            <option value="This Month">This Month</option>
            <option value="This Quarter">This Quarter</option>
          </select>
        </div>

        {/* Filter Chips */}
        <div className="flex items-center gap-2 overflow-x-auto pb-1">
          {(subTab === 0
            ? ['All', 'Draft', 'Pending', 'Partially Paid', 'Paid', 'Overdue', 'Void']
            : ['All', 'Draft', 'Pending', 'Accepted', 'Declined', 'Converted']
          ).map((st) => {
            const isSelected = statusFilter === st;
            return (
              <button
                key={st}
                onClick={() => setStatusFilter(st)}
                className={`px-3 py-1 rounded-lg text-xs font-semibold whitespace-nowrap transition cursor-pointer ${
                  isSelected
                    ? 'bg-indigo-600 text-white'
                    : isDarkMode ? 'bg-slate-800 text-slate-300 hover:bg-slate-700' : 'bg-slate-100 text-slate-600 hover:bg-slate-200'
                }`}
              >
                {st}
              </button>
            );
          })}
        </div>
      </div>

      {/* Main List */}
      {subTab === 0 ? (
        <OfflineInvoicesList
          invoices={invoices}
          isDarkMode={isDarkMode}
          searchQuery={searchQuery}
          statusFilter={statusFilter}
          dateFilter={dateFilter}
          formatMoney={formatMoney}
          onRecordPayment={onRecordPayment}
          onDeleteInvoice={onDeleteInvoice}
          onEditDraft={onEditInvoiceDraft}
          onFinalizeInvoice={onFinalizeInvoice}
        />
      ) : (
        <OfflineEstimatesList
          estimates={estimates}
          isDarkMode={isDarkMode}
          searchQuery={searchQuery}
          statusFilter={statusFilter}
          dateFilter={dateFilter}
          formatMoney={formatMoney}
          onConvertEstimate={onConvertEstimate}
          onDeleteEstimate={onDeleteEstimate}
          onEditDraft={onEditEstimateDraft}
          onFinalizeEstimate={onFinalizeEstimate}
        />
      )}
    </div>
  );
};

