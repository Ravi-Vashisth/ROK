import React from 'react';
import { Users, Package, Settings, Database, FileSpreadsheet, ShieldCheck } from 'lucide-react';

interface HubSettingsTabProps {
  isDarkMode: boolean;
  onOpenClients: () => void;
  onOpenItems: () => void;
  onOpenProfile: () => void;
  onOpenCsvModal: () => void;
  onRestoreDatabase: (file: File) => void;
}

export const HubSettingsTab: React.FC<HubSettingsTabProps> = ({
  isDarkMode,
  onOpenClients,
  onOpenItems,
  onOpenProfile,
  onOpenCsvModal,
  onRestoreDatabase,
}) => {
  const fileInputRef = React.useRef<HTMLInputElement>(null);

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      onRestoreDatabase(file);
      e.target.value = '';
    }
  };

  return (
    <div className="space-y-6">
      <div className={`p-6 rounded-xl border ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}>
        <h2 className="text-xl font-bold tracking-tight">Hub & System Administration</h2>
        <p className="text-xs text-slate-500 mt-1">Manage client records, product libraries, branding, and local backups</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {/* Clients Directory */}
        <div
          onClick={onOpenClients}
          className={`p-6 rounded-xl border hover:border-indigo-500 transition cursor-pointer space-y-3 ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}
        >
          <div className="w-10 h-10 rounded-xl bg-indigo-50 dark:bg-indigo-950/50 text-indigo-600 flex items-center justify-center">
            <Users className="w-5 h-5" />
          </div>
          <h3 className="font-bold text-sm">Client Directory & Statements</h3>
          <p className="text-xs text-slate-500">Manage client contacts, tax IDs, and generate client billing statements.</p>
        </div>

        {/* Preset Items */}
        <div
          onClick={onOpenItems}
          className={`p-6 rounded-xl border hover:border-indigo-500 transition cursor-pointer space-y-3 ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}
        >
          <div className="w-10 h-10 rounded-xl bg-indigo-50 dark:bg-indigo-950/50 text-indigo-600 flex items-center justify-center">
            <Package className="w-5 h-5" />
          </div>
          <h3 className="font-bold text-sm">Saved Services & Item Library</h3>
          <p className="text-xs text-slate-500">Create preset rates and service packages for 1-click invoice line item auto-fill.</p>
        </div>

        {/* Business Profile */}
        <div
          onClick={onOpenProfile}
          className={`p-6 rounded-xl border hover:border-indigo-500 transition cursor-pointer space-y-3 ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}
        >
          <div className="w-10 h-10 rounded-xl bg-indigo-50 dark:bg-indigo-950/50 text-indigo-600 flex items-center justify-center">
            <Settings className="w-5 h-5" />
          </div>
          <h3 className="font-bold text-sm">Business Settings & Branding</h3>
          <p className="text-xs text-slate-500">Set currency symbol, default payment terms, tax numbers, and invoice headers.</p>
        </div>

        {/* CSV Export */}
        <div
          onClick={onOpenCsvModal}
          className={`p-6 rounded-xl border hover:border-indigo-500 transition cursor-pointer space-y-3 ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}
        >
          <div className="w-10 h-10 rounded-xl bg-emerald-50 dark:bg-emerald-950/50 text-emerald-600 flex items-center justify-center">
            <FileSpreadsheet className="w-5 h-5" />
          </div>
          <h3 className="font-bold text-sm">Export Accountant CSV</h3>
          <p className="text-xs text-slate-500">Export full financial breakdown CSV files for accounting and tax reporting.</p>
        </div>

        {/* Database Restore */}
        <div
          onClick={() => fileInputRef.current?.click()}
          className={`p-6 rounded-xl border hover:border-indigo-500 transition cursor-pointer space-y-3 ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}
        >
          <input
            type="file"
            ref={fileInputRef}
            onChange={handleFileChange}
            accept=".json"
            className="hidden"
          />
          <div className="w-10 h-10 rounded-xl bg-indigo-50 dark:bg-indigo-950/50 text-indigo-600 flex items-center justify-center">
            <Database className="w-5 h-5" />
          </div>
          <h3 className="font-bold text-sm">Restore JSON Backup</h3>
          <p className="text-xs text-slate-500">Restore or import local SQLite database snapshots from a backup JSON file.</p>
        </div>
      </div>
    </div>
  );
};
