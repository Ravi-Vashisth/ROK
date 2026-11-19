import React, { useState } from 'react';
import { ReceiptText, FileText, Users, Plus, Search } from 'lucide-react';
import { OfflineInvoicesList } from './widgets/OfflineInvoicesList';
import { OfflineEstimatesList } from '../estimates/OfflineEstimatesList';
import { ClientsTab } from '../clients/ClientsTab';

interface SalesTabProps {
  invoices: any[];
  estimates: any[];
  clients: any[];
  isDarkMode: boolean;
  currencyCode?: string;
  currencySymbol?: string;
  currencyDecimals?: number;
  formatMoney: (cents: number) => string;
  onCreateInvoice: () => void;
  onCreateQuote: () => void;
  onRecordPayment: (invoice: any) => void;
  onSendReminder?: (invoice: any) => void;
  onDeleteInvoice: (invoice: any) => void;
  onConvertEstimate: (estimate: any) => void;
  onDeleteEstimate: (estimate: any) => void;
  onEditInvoiceDraft?: (invoice: any) => void;
  onEditEstimateDraft?: (estimate: any) => void;
  onFinalizeInvoice?: (invoice: any) => void;
  onFinalizeEstimate?: (estimate: any) => void;
  onDuplicateInvoice?: (invoice: any) => void;
  onVoidInvoice?: (invoice: any) => void;
  onPrintInvoice?: (invoice: any) => void;
  onPrintEstimate?: (estimate: any) => void;
  onPrintStatement?: (client: any) => void;
  onAddClient?: (clientData: any) => void;
  onUpdateClient?: (id: string, updatedData: any) => void;
  onDeleteClient?: (client: any) => void;
  onNotify?: (msg: string) => void;
  initialSubTab?: number;
}

export const SalesTab: React.FC<SalesTabProps> = ({
  invoices,
  estimates,
  clients,
  isDarkMode,
  currencyCode,
  currencySymbol,
  currencyDecimals,
  formatMoney,
  onCreateInvoice,
  onCreateQuote,
  onRecordPayment,
  onSendReminder,
  onDeleteInvoice,
  onConvertEstimate,
  onDeleteEstimate,
  onEditInvoiceDraft,
  onEditEstimateDraft,
  onFinalizeInvoice,
  onFinalizeEstimate,
  onDuplicateInvoice,
  onVoidInvoice,
  onPrintInvoice,
  onPrintEstimate,
  onPrintStatement,
  onAddClient,
  onUpdateClient,
  onDeleteClient,
  onNotify,
  initialSubTab = 0,
}) => {
  const [subTab, setSubTab] = useState<number>(initialSubTab); // 0 = Invoices, 1 = Estimates, 2 = Clients CRM
  const [searchQuery, setSearchQuery] = useState<string>('');
  const [statusFilter, setStatusFilter] = useState<string>('All');
  const [dateFilter, setDateFilter] = useState<string>('All Time');

  return (
    <div className="space-y-6">
      {/* Sales Header & Action Bar */}
      <div className={`p-6 rounded-xl border flex flex-col min-[900px]:flex-row items-start min-[900px]:items-center justify-between gap-4 ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}>
        <div>
          <h2 className="text-xl font-bold tracking-tight">Sales & Clients CRM</h2>
          <p className="text-xs text-slate-500 mt-1">Manage client invoices, proposals, and customer dossiers in one place</p>
        </div>

        <div className="flex flex-wrap items-center gap-3 max-w-full">
          {/* 3-View SubTab Toggles */}
          <div className={`p-1 rounded-xl border flex items-center gap-1 max-w-full overflow-x-auto ${isDarkMode ? 'bg-slate-900 border-slate-800' : 'bg-slate-100 border-slate-200'}`}>
            <button
              onClick={() => { setSubTab(0); setStatusFilter('All'); }}
              className={`px-3 py-1.5 rounded-lg text-xs font-bold flex items-center gap-1.5 transition cursor-pointer whitespace-nowrap shrink-0 ${
                subTab === 0
                  ? isDarkMode ? 'accent-tab-active' : 'bg-white text-slate-900 shadow-sm'
                  : 'text-slate-500 hover:text-slate-800 dark:hover:text-slate-200'
              }`}
            >
              <ReceiptText className="w-3.5 h-3.5" />
              <span>Invoices ({invoices.length})</span>
            </button>
            <button
              onClick={() => { setSubTab(1); setStatusFilter('All'); }}
              className={`px-3 py-1.5 rounded-lg text-xs font-bold flex items-center gap-1.5 transition cursor-pointer whitespace-nowrap shrink-0 ${
                subTab === 1
                  ? isDarkMode ? 'accent-tab-active' : 'bg-white text-slate-900 shadow-sm'
                  : 'text-slate-500 hover:text-slate-800 dark:hover:text-slate-200'
              }`}
            >
              <FileText className="w-3.5 h-3.5" />
              <span>Quotes ({estimates.length})</span>
            </button>
            <button
              onClick={() => { setSubTab(2); setStatusFilter('All'); }}
              className={`px-3 py-1.5 rounded-lg text-xs font-bold flex items-center gap-1.5 transition cursor-pointer whitespace-nowrap shrink-0 ${
                subTab === 2
                  ? isDarkMode ? 'accent-tab-active' : 'bg-white text-slate-900 shadow-sm'
                  : 'text-slate-500 hover:text-slate-800 dark:hover:text-slate-200'
              }`}
            >
              <Users className="w-3.5 h-3.5" />
              <span>Clients ({clients.length})</span>
            </button>
          </div>

          {/* Action Button */}
          {subTab === 0 ? (
            <button
              onClick={onCreateInvoice}
              className="px-4 py-2 accent-btn font-bold text-xs rounded-xl flex items-center gap-2 cursor-pointer shadow-sm transition"
            >
              <Plus className="w-4 h-4" />
              <span>Create Invoice</span>
            </button>
          ) : subTab === 1 ? (
            <button
              onClick={onCreateQuote}
              className="px-4 py-2 bg-amber-600 hover:bg-amber-700 text-white font-bold text-xs rounded-xl flex items-center gap-2 cursor-pointer shadow-sm transition"
            >
              <Plus className="w-4 h-4" />
              <span>New Quote</span>
            </button>
          ) : null}
        </div>
      </div>

      {/* SubTab Views */}
      {subTab === 2 ? (
        <ClientsTab
          clients={clients}
          invoices={invoices}
          isDarkMode={isDarkMode}
          currencyCode={currencyCode}
          currencySymbol={currencySymbol}
          currencyDecimals={currencyDecimals}
          formatMoney={formatMoney}
          onBack={() => setSubTab(0)}
          onAddClient={onAddClient || (() => {})}
          onUpdateClient={onUpdateClient || (() => {})}
          onDeleteClient={onDeleteClient || (() => {})}
          onPrintStatement={onPrintStatement}
          onNotify={onNotify}
        />
      ) : (
        <>
          {/* Filter & Search Card */}
          <div className={`p-4 rounded-xl border space-y-3 ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}>
            <div className="flex flex-col min-[900px]:flex-row items-stretch min-[900px]:items-center gap-3">
              <div className="relative flex-1 w-full">
                <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
                <input
                  type="text"
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  placeholder="Search by client name or invoice / quote #"
                  className={`w-full pl-9 pr-3 py-2 rounded-xl text-xs border accent-focus ${isDarkMode ? 'bg-slate-900 border-slate-800 text-slate-100' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
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
                        ? 'accent-tab-active'
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
              onSendReminder={onSendReminder}
              onDeleteInvoice={onDeleteInvoice}
              onEditDraft={onEditInvoiceDraft}
              onFinalizeInvoice={onFinalizeInvoice}
              onDuplicateInvoice={onDuplicateInvoice}
              onVoidInvoice={onVoidInvoice}
              onPrintInvoice={onPrintInvoice}
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
              onPrintEstimate={onPrintEstimate}
            />
          )}
        </>
      )}
    </div>
  );
};
