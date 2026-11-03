import React, { useState } from 'react';
import { Package, Plus, Trash2, ArrowLeft } from 'lucide-react';

interface ItemsCatalogTabProps {
  savedItems: any[];
  isDarkMode: boolean;
  currencySymbol: string;
  formatMoney: (cents: number) => string;
  parsePriceToCents: (val: string) => number;
  onBack: () => void;
  onAddItem: (itemData: any) => void;
  onDeleteItem: (item: any) => void;
}

export const ItemsCatalogTab: React.FC<ItemsCatalogTabProps> = ({
  savedItems,
  isDarkMode,
  currencySymbol,
  formatMoney,
  parsePriceToCents,
  onBack,
  onAddItem,
  onDeleteItem,
}) => {
  const [title, setTitle] = useState<string>('');
  const [priceStr, setPriceStr] = useState<string>('');
  const [sacHsn, setSacHsn] = useState<string>('');

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!title.trim()) return;
    const cents = parsePriceToCents(priceStr);
    onAddItem({ title: title.trim(), default_price_cents: cents, sac_hsn: sacHsn.trim() });
    setTitle('');
    setPriceStr('');
    setSacHsn('');
  };

  return (
    <div className="space-y-6">
      <div className={`p-4 rounded-xl border flex items-center justify-between gap-4 ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}>
        <button onClick={onBack} className="flex items-center gap-2 text-xs font-bold text-slate-500 hover:text-slate-800 dark:hover:text-slate-200 cursor-pointer">
          <ArrowLeft className="w-4 h-4" />
          <span>Back to Hub</span>
        </button>
        <h3 className="font-bold text-sm">Preset Services & Catalog Library</h3>
      </div>

      {/* Add Item Form */}
      <form onSubmit={handleSubmit} className={`p-5 rounded-xl border space-y-4 ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}>
        <h4 className="font-bold text-xs uppercase tracking-wider text-slate-400">Add Preset Service or Product</h4>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
          <input
            type="text"
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            placeholder="Service Title / Item Name *"
            className={`p-2.5 rounded-xl text-xs border ${isDarkMode ? 'bg-slate-900 border-slate-800' : 'bg-slate-50 border-slate-200'}`}
            required
          />
          <input
            type="text"
            value={priceStr}
            onChange={(e) => setPriceStr(e.target.value)}
            placeholder={`Default Rate / Unit Price (${currencySymbol})`}
            className={`p-2.5 rounded-xl text-xs border ${isDarkMode ? 'bg-slate-900 border-slate-800' : 'bg-slate-50 border-slate-200'}`}
          />
          <input
            type="text"
            value={sacHsn}
            onChange={(e) => setSacHsn(e.target.value)}
            placeholder="SAC / HSN Code (Optional)"
            className={`p-2.5 rounded-xl text-xs border ${isDarkMode ? 'bg-slate-900 border-slate-800' : 'bg-slate-50 border-slate-200'}`}
          />
        </div>
        <button
          type="submit"
          className="px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white font-bold text-xs rounded-xl flex items-center gap-2 cursor-pointer transition shadow-sm"
        >
          <Plus className="w-4 h-4" />
          <span>Save Service Preset</span>
        </button>
      </form>

      {/* Items List */}
      <div className={`rounded-xl border overflow-hidden ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}>
        <div className="p-4 border-b font-bold text-xs uppercase tracking-wider text-slate-400">
          Preset Library ({savedItems.length})
        </div>
        <div className="divide-y divide-slate-100 dark:divide-slate-800">
          {savedItems.map((item) => (
            <div key={item.id} className="p-4 flex items-center justify-between gap-3 text-xs">
              <div>
                <div className="font-bold text-sm">{item.title}</div>
                {item.sac_hsn && <span className="text-slate-400 text-[11px]">SAC/HSN: {item.sac_hsn}</span>}
              </div>
              <div className="flex items-center gap-4">
                <span className="font-mono font-bold text-indigo-500">{formatMoney(item.default_price_cents || item.defaultPriceCents || 0)}</span>
                <button
                  onClick={() => onDeleteItem(item)}
                  className="p-1.5 rounded-lg bg-rose-50 hover:bg-rose-100 text-rose-700 dark:bg-rose-950 dark:text-rose-300 transition cursor-pointer"
                  title="Delete Item"
                >
                  <Trash2 className="w-3.5 h-3.5" />
                </button>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};
