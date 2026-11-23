import React, { useState, useEffect } from 'react';
import { Package, Plus, Trash2, Edit2, ArrowLeft, Check } from 'lucide-react';
import {
  formatDecimalUnits,
  formatMoney as formatMoneyUnits,
  getCurrencyDecimals,
  parsePriceToUnits,
  resolveEffectiveCurrency,
} from '../../billingRules';

interface ItemsCatalogTabProps {
  savedItems: any[];
  isDarkMode: boolean;
  currencyCode?: string;
  currencySymbol: string;
  currencyDecimals?: number;
  formatMoney: (cents: number) => string;
  parsePriceToCents: (val: string) => number;
  onBack: () => void;
  onAddItem: (itemData: any) => void;
  onUpdateItem?: (id: string, itemData: any) => void;
  onDeleteItem: (item: any) => void;
}

export const ItemsCatalogTab: React.FC<ItemsCatalogTabProps> = ({
  savedItems,
  isDarkMode,
  currencyCode,
  currencySymbol,
  currencyDecimals,
  formatMoney: _formatMoney,
  parsePriceToCents: _parsePriceToCents,
  onBack,
  onAddItem,
  onUpdateItem,
  onDeleteItem,
}) => {
  const [title, setTitle] = useState<string>('');
  const [priceStr, setPriceStr] = useState<string>('');
  const [sacHsn, setSacHsn] = useState<string>('');
  const [description, setDescription] = useState<string>('');

  // Edit item state
  const [editingItem, setEditingItem] = useState<any | null>(null);
  const [editTitle, setEditTitle] = useState<string>('');
  const [editPriceStr, setEditPriceStr] = useState<string>('');
  const [editSacHsn, setEditSacHsn] = useState<string>('');
  const [editDescription, setEditDescription] = useState<string>('');

  const effectiveDefaultCode =
    (currencyCode || '').trim().toUpperCase() ||
    (currencySymbol.trim() === '₹' ? 'INR' : 'USD');
  const curDec = currencyDecimals ?? getCurrencyDecimals(effectiveDefaultCode);

  useEffect(() => {
    if (!editingItem) return;
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        setEditingItem(null);
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [editingItem]);

  const resolveItemCurrency = (item: any) => {
    const recCode = item?.currency_code ?? item?.currencyCode ?? '';
    const recDec = item?.currency_decimals ?? item?.currencyDecimals;
    return resolveEffectiveCurrency({
      recordCode: recCode,
      recordDecimals: String(recCode).trim() ? recDec : undefined,
      defaultCode: effectiveDefaultCode,
      defaultSymbol: currencySymbol,
      defaultDecimals: curDec,
    });
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!title.trim()) return;
    const cents = parsePriceToUnits(priceStr, curDec);
    onAddItem({
      title: title.trim(),
      default_price_cents: cents,
      sac_hsn: sacHsn.trim(),
      description: description.trim(),
      currency_code: effectiveDefaultCode,
      currency_decimals: curDec,
    });
    setTitle('');
    setPriceStr('');
    setSacHsn('');
    setDescription('');
  };

  const handleOpenEdit = (item: any) => {
    const itemCur = resolveItemCurrency(item);
    setEditingItem(item);
    setEditTitle(item.title || '');
    setEditSacHsn(item.sac_hsn || item.sacHsn || '');
    const priceCents = item.default_price_cents ?? item.defaultPriceCents ?? 0;
    setEditPriceStr(formatDecimalUnits(priceCents, itemCur.decimals));
    setEditDescription(item.description || '');
  };

  const handleSaveEdit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!editingItem || !editTitle.trim()) return;
    const itemCur = resolveItemCurrency(editingItem);
    const cents = parsePriceToUnits(editPriceStr, itemCur.decimals);
    if (onUpdateItem) {
      onUpdateItem(editingItem.id, {
        title: editTitle.trim(),
        default_price_cents: cents,
        sac_hsn: editSacHsn.trim(),
        description: editDescription.trim(),
        currency_code: itemCur.code,
        currency_decimals: itemCur.decimals,
      });
    }
    setEditingItem(null);
  };

  const handleDeletePrompt = (item: any) => {
    onDeleteItem(item);
  };

  return (
    <div className="space-y-6">
      <div className={`p-4 rounded-xl border flex flex-wrap items-center justify-between gap-4 ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}>
        <button onClick={onBack} className="flex items-center gap-2 text-xs font-bold text-slate-500 hover:text-slate-800 dark:hover:text-slate-200 cursor-pointer">
          <ArrowLeft className="w-4 h-4" />
          <span>Back to Settings</span>
        </button>
        <h3 className="font-bold text-sm">Preset Services & Catalog Library</h3>
      </div>

      {/* Add Item Form */}
      <form onSubmit={handleSubmit} className={`p-5 rounded-xl border space-y-4 ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}>
        <h4 className="font-bold text-xs uppercase tracking-wider text-slate-400">Add Preset Service or Product</h4>
        <div className="grid grid-cols-1 min-[900px]:grid-cols-3 gap-3">
          <input
            type="text"
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            placeholder="Service Title / Item Name *"
            className={`p-2.5 rounded-xl text-xs border ${isDarkMode ? 'bg-slate-900 border-slate-800 text-slate-100' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
            required
          />
          <input
            type="text"
            value={priceStr}
            onChange={(e) => setPriceStr(e.target.value)}
            placeholder={`Default Rate / Unit Price (${currencySymbol})`}
            className={`p-2.5 rounded-xl text-xs border ${isDarkMode ? 'bg-slate-900 border-slate-800 text-slate-100' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
          />
          <input
            type="text"
            value={sacHsn}
            onChange={(e) => setSacHsn(e.target.value)}
            placeholder="SAC / HSN Code (Optional)"
            className={`p-2.5 rounded-xl text-xs border ${isDarkMode ? 'bg-slate-900 border-slate-800 text-slate-100' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
          />
        </div>
        <div className="flex flex-col sm:flex-row items-stretch sm:items-center gap-3">
          <input
            type="text"
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            placeholder="Deliverable description / scope (Optional)"
            className={`flex-1 p-2.5 rounded-xl text-xs border ${isDarkMode ? 'bg-slate-900 border-slate-800 text-slate-100' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
          />
          <button
            type="submit"
            className="px-4 py-2.5 accent-btn font-bold text-xs rounded-xl flex items-center justify-center gap-2 cursor-pointer transition shadow-xs shrink-0"
          >
            <Plus className="w-4 h-4" />
            <span>Save Service Preset</span>
          </button>
        </div>
      </form>

      {/* Items Table with Actions header */}
      <div className={`rounded-xl border overflow-hidden ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}>
        <div className="p-4 border-b font-bold text-xs uppercase tracking-wider text-slate-400">
          Preset Library ({savedItems.length})
        </div>
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead className={`border-b font-bold ${isDarkMode ? 'bg-slate-900 border-slate-800 text-slate-400' : 'bg-slate-50 border-slate-200 text-slate-600'}`}>
              <tr>
                <th className="p-3">Item / Service Title</th>
                <th className="p-3">Description</th>
                <th className="p-3">SAC / HSN</th>
                <th className="p-3 text-right">Default Unit Price</th>
                <th className="p-3 text-center">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100 dark:divide-slate-800">
              {savedItems.length === 0 ? (
                <tr>
                  <td colSpan={5} className="p-8 text-center text-slate-400">
                    No items found in catalog. Create one above.
                  </td>
                </tr>
              ) : (
                savedItems.map((item) => {
                  const itemCur = resolveItemCurrency(item);
                  const isForeign = itemCur.code !== effectiveDefaultCode;
                  const formattedPrice = formatMoneyUnits(
                    item.default_price_cents ?? item.defaultPriceCents ?? 0,
                    itemCur.symbol,
                    itemCur.decimals,
                    itemCur.code
                  );
                  return (
                  <tr key={item.id} className="hover:bg-slate-50/50 dark:hover:bg-slate-800/30 transition">
                    <td className="p-3 font-bold text-slate-800 dark:text-slate-100">
                      <div className="flex items-center gap-2">
                        <div className="w-6 h-6 rounded-full bg-blue-100 dark:bg-blue-950 flex items-center justify-center text-blue-600 dark:text-blue-400 shrink-0">
                          <Package className="w-3.5 h-3.5" />
                        </div>
                        <span>{item.title}</span>
                      </div>
                    </td>
                    <td className="p-3 text-slate-500 max-w-xs truncate">
                      {item.description || 'Standard preset deliverable'}
                    </td>
                    <td className="p-3 text-slate-400 font-mono">
                      {item.sac_hsn || item.sacHsn || '—'}
                    </td>
                    <td className="p-3 text-right font-mono tabular-nums font-bold accent-text whitespace-nowrap">
                      <span>{formattedPrice}</span>
                      {isForeign && (
                        <span className="ml-1.5 text-[10px] font-bold text-slate-400">
                          {itemCur.code}
                        </span>
                      )}
                    </td>
                    <td className="p-3 text-center">
                      <div className="flex items-center justify-center gap-1.5">
                        <button
                          onClick={() => handleOpenEdit(item)}
                          className="p-1.5 rounded-lg border border-slate-300 dark:border-slate-700 hover:bg-slate-100 dark:hover:bg-slate-800 text-slate-600 dark:text-slate-300 transition cursor-pointer"
                          title="Edit Item"
                        >
                          <Edit2 className="w-3.5 h-3.5" />
                        </button>
                        <button
                          onClick={() => handleDeletePrompt(item)}
                          className="p-1.5 rounded-lg bg-rose-50 hover:bg-rose-100 text-rose-700 dark:bg-rose-950 dark:text-rose-300 transition cursor-pointer"
                          title="Delete Item"
                        >
                          <Trash2 className="w-3.5 h-3.5" />
                        </button>
                      </div>
                    </td>
                  </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Edit Item Modal */}
      {editingItem && (() => {
        const editingCur = resolveItemCurrency(editingItem);
        return (
        <div
          className="fixed inset-0 bg-black/50 backdrop-blur-xs flex items-center justify-center p-4 z-50"
          onClick={(e) => {
            if (e.target === e.currentTarget) {
              setEditingItem(null);
            }
          }}
        >
          <div
            role="dialog"
            aria-modal="true"
            className={`w-full max-w-md max-h-[90vh] overflow-y-auto rounded-xl border p-6 space-y-4 ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}
          >
            <h3 className="font-bold text-sm">Edit Catalog Item ({editingCur.code})</h3>
            <form onSubmit={handleSaveEdit} className="space-y-3 text-xs">
              <div>
                <label className="block font-bold text-slate-500 mb-1">Item / Service Title *</label>
                <input
                  type="text"
                  value={editTitle}
                  onChange={(e) => setEditTitle(e.target.value)}
                  className={`w-full p-2.5 rounded-xl border ${isDarkMode ? 'bg-slate-900 border-slate-800 text-slate-100' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
                  required
                />
              </div>
              <div>
                <label className="block font-bold text-slate-500 mb-1">SAC / HSN Code</label>
                <input
                  type="text"
                  value={editSacHsn}
                  onChange={(e) => setEditSacHsn(e.target.value)}
                  placeholder="e.g. 998311"
                  className={`w-full p-2.5 rounded-xl border ${isDarkMode ? 'bg-slate-900 border-slate-800 text-slate-100' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
                />
              </div>
              <div>
                <label className="block font-bold text-slate-500 mb-1">Default Unit Price ({editingCur.symbol}) *</label>
                <input
                  type="text"
                  value={editPriceStr}
                  onChange={(e) => setEditPriceStr(e.target.value)}
                  className={`w-full p-2.5 rounded-xl border ${isDarkMode ? 'bg-slate-900 border-slate-800 text-slate-100' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
                  required
                />
              </div>
              <div>
                <label className="block font-bold text-slate-500 mb-1">Description</label>
                <textarea
                  value={editDescription}
                  onChange={(e) => setEditDescription(e.target.value)}
                  rows={2}
                  className={`w-full p-2.5 rounded-xl border ${isDarkMode ? 'bg-slate-900 border-slate-800 text-slate-100' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
                />
              </div>
              <div className="flex items-center justify-end gap-2 pt-2">
                <button
                  type="button"
                  onClick={() => setEditingItem(null)}
                  className="px-3 py-1.5 border rounded-xl text-xs font-bold cursor-pointer"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-4 py-1.5 accent-btn rounded-xl text-xs font-bold cursor-pointer flex items-center gap-1.5"
                >
                  <Check className="w-3.5 h-3.5" />
                  <span>Save Item</span>
                </button>
              </div>
            </form>
          </div>
        </div>
        );
      })()}
    </div>
  );
};

export default ItemsCatalogTab;
