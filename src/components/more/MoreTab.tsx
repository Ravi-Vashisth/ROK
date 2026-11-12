import React from 'react';
import { Users, Package, FileSpreadsheet, Settings, Database, ChevronRight } from 'lucide-react';

interface MoreTabProps {
  isDarkMode: boolean;
  onNavigateToClients: () => void;
  onNavigateToCatalog: () => void;
  onOpenCsvModal: () => void;
  onNavigateToSettings: () => void;
  onNavigateToBackup: () => void;
}

export const MoreTab: React.FC<MoreTabProps> = ({
  isDarkMode,
  onNavigateToClients,
  onNavigateToCatalog,
  onOpenCsvModal,
  onNavigateToSettings,
  onNavigateToBackup,
}) => {
  return (
    <div className="space-y-4">
      <div className={`p-4 rounded-xl border ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}>
        <h2 className="text-base font-bold tracking-tight">More Application Destinations</h2>
        <p className="text-xs text-slate-500 mt-0.5">Quick access to client records, item catalog, reports, settings, and backups</p>
      </div>

      <div className="space-y-2">
        {/* Clients Directory */}
        <button
          onClick={onNavigateToClients}
          className={`w-full p-4 rounded-xl border text-left flex items-center justify-between transition cursor-pointer ${
            isDarkMode ? 'bg-[#0F172A] border-slate-800 hover:bg-slate-800/50' : 'bg-white border-slate-200 hover:bg-slate-50'
          }`}
        >
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-indigo-50 dark:bg-indigo-950/50 text-indigo-600 flex items-center justify-center shrink-0">
              <Users className="w-5 h-5" />
            </div>
            <div>
              <h3 className="font-bold text-xs text-slate-800 dark:text-slate-100">Clients & Account Dossiers</h3>
              <p className="text-[11px] text-slate-400">CRM directory, billing history, and statements of account</p>
            </div>
          </div>
          <ChevronRight className="w-4 h-4 text-slate-400 shrink-0" />
        </button>

        {/* Catalog & Services */}
        <button
          onClick={onNavigateToCatalog}
          className={`w-full p-4 rounded-xl border text-left flex items-center justify-between transition cursor-pointer ${
            isDarkMode ? 'bg-[#0F172A] border-slate-800 hover:bg-slate-800/50' : 'bg-white border-slate-200 hover:bg-slate-50'
          }`}
        >
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-blue-50 dark:bg-blue-950/50 text-blue-600 flex items-center justify-center shrink-0">
              <Package className="w-5 h-5" />
            </div>
            <div>
              <h3 className="font-bold text-xs text-slate-800 dark:text-slate-100">Items & Services Catalog</h3>
              <p className="text-[11px] text-slate-400">Preset rates, SAC/HSN codes, and line item auto-fill</p>
            </div>
          </div>
          <ChevronRight className="w-4 h-4 text-slate-400 shrink-0" />
        </button>

        {/* CSV Reports */}
        <button
          onClick={onOpenCsvModal}
          className={`w-full p-4 rounded-xl border text-left flex items-center justify-between transition cursor-pointer ${
            isDarkMode ? 'bg-[#0F172A] border-slate-800 hover:bg-slate-800/50' : 'bg-white border-slate-200 hover:bg-slate-50'
          }`}
        >
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-emerald-50 dark:bg-emerald-950/50 text-emerald-600 flex items-center justify-center shrink-0">
              <FileSpreadsheet className="w-5 h-5" />
            </div>
            <div>
              <h3 className="font-bold text-xs text-slate-800 dark:text-slate-100">Reports & Export CSV</h3>
              <p className="text-[11px] text-slate-400">Single-table accountant CSV export for Invoices and Expenses</p>
            </div>
          </div>
          <ChevronRight className="w-4 h-4 text-slate-400 shrink-0" />
        </button>

        {/* Business Settings */}
        <button
          onClick={onNavigateToSettings}
          className={`w-full p-4 rounded-xl border text-left flex items-center justify-between transition cursor-pointer ${
            isDarkMode ? 'bg-[#0F172A] border-slate-800 hover:bg-slate-800/50' : 'bg-white border-slate-200 hover:bg-slate-50'
          }`}
        >
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-purple-50 dark:bg-purple-950/50 text-purple-600 flex items-center justify-center shrink-0">
              <Settings className="w-5 h-5" />
            </div>
            <div>
              <h3 className="font-bold text-xs text-slate-800 dark:text-slate-100">Business Settings & Branding</h3>
              <p className="text-[11px] text-slate-400">Legal business name, tax numbers, logo, and digital signature</p>
            </div>
          </div>
          <ChevronRight className="w-4 h-4 text-slate-400 shrink-0" />
        </button>

        {/* Data Backup */}
        <button
          onClick={onNavigateToBackup}
          className={`w-full p-4 rounded-xl border text-left flex items-center justify-between transition cursor-pointer ${
            isDarkMode ? 'bg-[#0F172A] border-slate-800 hover:bg-slate-800/50' : 'bg-white border-slate-200 hover:bg-slate-50'
          }`}
        >
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-amber-50 dark:bg-amber-950/50 text-amber-600 flex items-center justify-center shrink-0">
              <Database className="w-5 h-5" />
            </div>
            <div>
              <h3 className="font-bold text-xs text-slate-800 dark:text-slate-100">Data Backup & Recovery</h3>
              <p className="text-[11px] text-slate-400">Export or restore database JSON snapshots</p>
            </div>
          </div>
          <ChevronRight className="w-4 h-4 text-slate-400 shrink-0" />
        </button>
      </div>
    </div>
  );
};

export default MoreTab;
