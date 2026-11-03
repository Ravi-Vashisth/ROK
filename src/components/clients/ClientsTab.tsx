import React, { useState } from 'react';
import { Users, Plus, Trash2, Mail, Phone, MapPin, Hash, ArrowLeft } from 'lucide-react';

interface ClientsTabProps {
  clients: any[];
  isDarkMode: boolean;
  onBack: () => void;
  onAddClient: (clientData: any) => void;
  onDeleteClient: (client: any) => void;
}

export const ClientsTab: React.FC<ClientsTabProps> = ({
  clients,
  isDarkMode,
  onBack,
  onAddClient,
  onDeleteClient,
}) => {
  const [name, setName] = useState<string>('');
  const [email, setEmail] = useState<string>('');
  const [phone, setPhone] = useState<string>('');
  const [address, setAddress] = useState<string>('');
  const [taxId, setTaxId] = useState<string>('');

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!name.trim()) return;
    onAddClient({ name: name.trim(), email, phone, address, taxId });
    setName('');
    setEmail('');
    setPhone('');
    setAddress('');
    setTaxId('');
  };

  return (
    <div className="space-y-6">
      <div className={`p-4 rounded-xl border flex items-center justify-between gap-4 ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}>
        <button onClick={onBack} className="flex items-center gap-2 text-xs font-bold text-slate-500 hover:text-slate-800 dark:hover:text-slate-200 cursor-pointer">
          <ArrowLeft className="w-4 h-4" />
          <span>Back to Hub</span>
        </button>
        <h3 className="font-bold text-sm">Client Directory & Contact Records</h3>
      </div>

      {/* Add Client Form */}
      <form onSubmit={handleSubmit} className={`p-5 rounded-xl border space-y-4 ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}>
        <h4 className="font-bold text-xs uppercase tracking-wider text-slate-400">Add New Client</h4>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
          <input
            type="text"
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="Client Name *"
            className={`p-2.5 rounded-xl text-xs border ${isDarkMode ? 'bg-slate-900 border-slate-800' : 'bg-slate-50 border-slate-200'}`}
            required
          />
          <input
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            placeholder="Email Address"
            className={`p-2.5 rounded-xl text-xs border ${isDarkMode ? 'bg-slate-900 border-slate-800' : 'bg-slate-50 border-slate-200'}`}
          />
          <input
            type="text"
            value={phone}
            onChange={(e) => setPhone(e.target.value)}
            placeholder="Phone Number"
            className={`p-2.5 rounded-xl text-xs border ${isDarkMode ? 'bg-slate-900 border-slate-800' : 'bg-slate-50 border-slate-200'}`}
          />
        </div>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
          <input
            type="text"
            value={taxId}
            onChange={(e) => setTaxId(e.target.value)}
            placeholder="Tax ID / GSTIN / VAT Number"
            className={`p-2.5 rounded-xl text-xs border ${isDarkMode ? 'bg-slate-900 border-slate-800' : 'bg-slate-50 border-slate-200'}`}
          />
          <input
            type="text"
            value={address}
            onChange={(e) => setAddress(e.target.value)}
            placeholder="Full Billing Address"
            className={`p-2.5 rounded-xl text-xs border ${isDarkMode ? 'bg-slate-900 border-slate-800' : 'bg-slate-50 border-slate-200'}`}
          />
        </div>
        <button
          type="submit"
          className="px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white font-bold text-xs rounded-xl flex items-center gap-2 cursor-pointer transition shadow-sm"
        >
          <Plus className="w-4 h-4" />
          <span>Save Client</span>
        </button>
      </form>

      {/* Client List */}
      <div className={`rounded-xl border overflow-hidden ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}>
        <div className="p-4 border-b font-bold text-xs uppercase tracking-wider text-slate-400">
          Saved Clients ({clients.length})
        </div>
        <div className="divide-y divide-slate-100 dark:divide-slate-800">
          {clients.map((c) => (
            <div key={c.id} className="p-4 flex flex-col md:flex-row items-start md:items-center justify-between gap-3 text-xs">
              <div className="space-y-1">
                <div className="font-bold text-sm text-indigo-500">{c.name}</div>
                <div className="flex flex-wrap items-center gap-4 text-slate-500">
                  {c.email && <span className="flex items-center gap-1"><Mail className="w-3 h-3" />{c.email}</span>}
                  {c.phone && <span className="flex items-center gap-1"><Phone className="w-3 h-3" />{c.phone}</span>}
                  {c.tax_id && <span className="flex items-center gap-1"><Hash className="w-3 h-3" />Tax ID: {c.tax_id}</span>}
                </div>
                {c.address && <p className="text-slate-400 text-[11px] flex items-center gap-1"><MapPin className="w-3 h-3" />{c.address}</p>}
              </div>
              <button
                onClick={() => onDeleteClient(c)}
                className="p-1.5 rounded-lg bg-rose-50 hover:bg-rose-100 text-rose-700 dark:bg-rose-950 dark:text-rose-300 transition cursor-pointer"
                title="Delete Client"
              >
                <Trash2 className="w-3.5 h-3.5" />
              </button>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};
