import React, { useState, useRef } from 'react';
import {
  Settings,
  Building,
  Package,
  CreditCard,
  Database,
  Save,
  Image,
  PenTool,
  CheckCircle2,
  Trash2,
  Download,
  Upload,
} from 'lucide-react';
import { ItemsCatalogTab } from '../items/ItemsCatalogTab';

interface SettingsTabProps {
  isDarkMode: boolean;
  businessProfile: any;
  savedItems: any[];
  currencySymbol: string;
  formatMoney: (cents: number) => string;
  parsePriceToCents: (val: string) => number;
  initialSubTab?: number;
  onSaveProfile: (profileData: any) => void;
  onAddItem: (itemData: any) => void;
  onUpdateItem?: (id: string, itemData: any) => void;
  onDeleteItem: (item: any) => void;
  onExportDatabase?: () => void;
  onRestoreDatabase: (file: File) => void;
}

export const SettingsTab: React.FC<SettingsTabProps> = ({
  isDarkMode,
  businessProfile,
  savedItems,
  currencySymbol,
  formatMoney,
  parsePriceToCents,
  initialSubTab = 0,
  onSaveProfile,
  onAddItem,
  onUpdateItem,
  onDeleteItem,
  onExportDatabase,
  onRestoreDatabase,
}) => {
  const [activeSubTab, setActiveSubTab] = useState<number>(initialSubTab);

  // Business Profile Form State
  const [businessName, setBusinessName] = useState<string>(businessProfile.business_name || '');
  const [email, setEmail] = useState<string>(businessProfile.email || '');
  const [phone, setPhone] = useState<string>(businessProfile.phone || '');
  const [address, setAddress] = useState<string>(businessProfile.address || '');
  const [taxId, setTaxId] = useState<string>(businessProfile.tax_id || '');
  const [currencyCode, setCurrencyCode] = useState<string>(businessProfile.currency_code || 'USD');
  const [paymentDetails, setPaymentDetails] = useState<string>(businessProfile.payment_details || '');
  const [defaultTerms, setDefaultTerms] = useState<string>(businessProfile.default_terms || '');
  const [defaultNotes, setDefaultNotes] = useState<string>(businessProfile.default_notes || '');
  const [logoBase64, setLogoBase64] = useState<string>(businessProfile.logo_base64 || '');
  const [signatureBase64, setSignatureBase64] = useState<string>(businessProfile.signature_base64 || '');

  const logoInputRef = useRef<HTMLInputElement>(null);
  const signatureInputRef = useRef<HTMLInputElement>(null);
  const backupInputRef = useRef<HTMLInputElement>(null);

  const handleFileUpload = (e: React.ChangeEvent<HTMLInputElement>, type: 'logo' | 'signature') => {
    const file = e.target.files?.[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = (uploadEvent) => {
      const base64 = uploadEvent.target?.result as string;
      if (type === 'logo') setLogoBase64(base64);
      else setSignatureBase64(base64);
    };
    reader.readAsDataURL(file);
    e.target.value = '';
  };

  const handleSaveProfileSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    let sym = '$';
    if (currencyCode === 'INR') sym = '₹';
    if (currencyCode === 'EUR') sym = '€';
    if (currencyCode === 'GBP') sym = '£';
    if (currencyCode === 'JPY') sym = '¥';

    onSaveProfile({
      ...businessProfile,
      business_name: businessName,
      email,
      phone,
      address,
      tax_id: taxId,
      currency_code: currencyCode,
      currency_symbol: sym,
      payment_details: paymentDetails,
      default_terms: defaultTerms,
      default_notes: defaultNotes,
      logo_base64: logoBase64,
      signature_base64: signatureBase64,
    });
    alert('Business settings and branding updated successfully!');
  };

  const handleRestoreFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      onRestoreDatabase(file);
      e.target.value = '';
    }
  };

  return (
    <div className="space-y-6">
      {/* Header & 4-SubTab Segmented Control */}
      <div className={`p-6 rounded-xl border flex flex-col md:flex-row md:items-center justify-between gap-4 ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}>
        <div>
          <h2 className="text-xl font-bold tracking-tight">Application Settings & System Preferences</h2>
          <p className="text-xs text-slate-500 mt-0.5">Manage business profile, item catalog, payment methods, and local database backups</p>
        </div>

        <div className={`inline-flex p-1 rounded-xl border self-start md:self-auto overflow-x-auto ${isDarkMode ? 'bg-slate-900 border-slate-800' : 'bg-slate-100 border-slate-200'}`}>
          <button
            onClick={() => setActiveSubTab(0)}
            className={`px-3 py-1.5 rounded-lg text-xs font-bold transition flex items-center gap-1.5 cursor-pointer whitespace-nowrap ${
              activeSubTab === 0
                ? 'bg-indigo-600 text-white shadow-xs'
                : 'text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-100'
            }`}
          >
            <Building className="w-3.5 h-3.5" />
            <span>Profile & Branding</span>
          </button>
          <button
            onClick={() => setActiveSubTab(1)}
            className={`px-3 py-1.5 rounded-lg text-xs font-bold transition flex items-center gap-1.5 cursor-pointer whitespace-nowrap ${
              activeSubTab === 1
                ? 'bg-indigo-600 text-white shadow-xs'
                : 'text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-100'
            }`}
          >
            <Package className="w-3.5 h-3.5" />
            <span>Catalog & Services</span>
          </button>
          <button
            onClick={() => setActiveSubTab(2)}
            className={`px-3 py-1.5 rounded-lg text-xs font-bold transition flex items-center gap-1.5 cursor-pointer whitespace-nowrap ${
              activeSubTab === 2
                ? 'bg-indigo-600 text-white shadow-xs'
                : 'text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-100'
            }`}
          >
            <CreditCard className="w-3.5 h-3.5" />
            <span>Payment & Banking</span>
          </button>
          <button
            onClick={() => setActiveSubTab(3)}
            className={`px-3 py-1.5 rounded-lg text-xs font-bold transition flex items-center gap-1.5 cursor-pointer whitespace-nowrap ${
              activeSubTab === 3
                ? 'bg-indigo-600 text-white shadow-xs'
                : 'text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-slate-100'
            }`}
          >
            <Database className="w-3.5 h-3.5" />
            <span>Data Management</span>
          </button>
        </div>
      </div>

      {/* Sub-Tab 0: Business Profile & Branding */}
      {activeSubTab === 0 && (
        <form onSubmit={handleSaveProfileSubmit} className={`p-6 rounded-xl border space-y-4 ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}>
          <h3 className="font-bold text-sm text-slate-800 dark:text-slate-100 uppercase tracking-wider">Business Identity & Legal Branding</h3>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-xs">
            <div>
              <label className="block font-bold text-slate-500 mb-1">Legal Business Name *</label>
              <input
                type="text"
                value={businessName}
                onChange={(e) => setBusinessName(e.target.value)}
                className={`w-full p-2.5 rounded-xl border ${isDarkMode ? 'bg-slate-900 border-slate-800 text-slate-100' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
                required
              />
            </div>
            <div>
              <label className="block font-bold text-slate-500 mb-1">Billing Email</label>
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                className={`w-full p-2.5 rounded-xl border ${isDarkMode ? 'bg-slate-900 border-slate-800 text-slate-100' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
              />
            </div>
            <div>
              <label className="block font-bold text-slate-500 mb-1">Phone Number</label>
              <input
                type="text"
                value={phone}
                onChange={(e) => setPhone(e.target.value)}
                className={`w-full p-2.5 rounded-xl border ${isDarkMode ? 'bg-slate-900 border-slate-800 text-slate-100' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
              />
            </div>
            <div>
              <label className="block font-bold text-slate-500 mb-1">Tax ID / GSTIN / VAT</label>
              <input
                type="text"
                value={taxId}
                onChange={(e) => setTaxId(e.target.value)}
                className={`w-full p-2.5 rounded-xl border ${isDarkMode ? 'bg-slate-900 border-slate-800 text-slate-100' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
              />
            </div>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-xs">
            <div>
              <label className="block font-bold text-slate-500 mb-1">Default Currency Code</label>
              <select
                value={currencyCode}
                onChange={(e) => setCurrencyCode(e.target.value)}
                className={`w-full p-2.5 rounded-xl border ${isDarkMode ? 'bg-slate-900 border-slate-800 text-slate-100' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
              >
                <option value="USD">USD ($)</option>
                <option value="INR">INR (₹)</option>
                <option value="EUR">EUR (€)</option>
                <option value="GBP">GBP (£)</option>
                <option value="JPY">JPY (¥)</option>
              </select>
            </div>
            <div>
              <label className="block font-bold text-slate-500 mb-1">Business Address</label>
              <input
                type="text"
                value={address}
                onChange={(e) => setAddress(e.target.value)}
                className={`w-full p-2.5 rounded-xl border ${isDarkMode ? 'bg-slate-900 border-slate-800 text-slate-100' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
              />
            </div>
          </div>

          {/* Logo & Signature Branding Controls */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-xs pt-2">
            <div className={`p-4 rounded-xl border ${isDarkMode ? 'bg-slate-900/60 border-slate-800' : 'bg-slate-50 border-slate-200'}`}>
              <label className="block font-bold text-slate-500 mb-2 flex items-center gap-1.5">
                <Image className="w-3.5 h-3.5" />
                <span>Company Logo</span>
              </label>
              <input type="file" ref={logoInputRef} onChange={(e) => handleFileUpload(e, 'logo')} accept="image/*" className="hidden" />
              {logoBase64 ? (
                <div className="flex items-center justify-between gap-2">
                  <div className="flex items-center gap-2">
                    <img src={logoBase64} alt="Logo Preview" className="w-10 h-10 object-contain rounded-lg border border-slate-200 dark:border-slate-700 bg-white" />
                    <span className="text-[11px] font-bold text-emerald-600 flex items-center gap-1">
                      <CheckCircle2 className="w-3.5 h-3.5" /> Logo Configured
                    </span>
                  </div>
                  <button type="button" onClick={() => setLogoBase64('')} className="p-1.5 text-rose-500 hover:bg-rose-50 rounded-lg cursor-pointer">
                    <Trash2 className="w-3.5 h-3.5" />
                  </button>
                </div>
              ) : (
                <button type="button" onClick={() => logoInputRef.current?.click()} className="w-full py-2 px-3 border border-dashed rounded-lg text-slate-500 hover:border-indigo-500 hover:text-indigo-600 transition text-center cursor-pointer">
                  + Upload Logo Image
                </button>
              )}
            </div>

            <div className={`p-4 rounded-xl border ${isDarkMode ? 'bg-slate-900/60 border-slate-800' : 'bg-slate-50 border-slate-200'}`}>
              <label className="block font-bold text-slate-500 mb-2 flex items-center gap-1.5">
                <PenTool className="w-3.5 h-3.5" />
                <span>Digital Signature</span>
              </label>
              <input type="file" ref={signatureInputRef} onChange={(e) => handleFileUpload(e, 'signature')} accept="image/*" className="hidden" />
              {signatureBase64 ? (
                <div className="flex items-center justify-between gap-2">
                  <div className="flex items-center gap-2">
                    <img src={signatureBase64} alt="Signature Preview" className="w-10 h-10 object-contain rounded-lg border border-slate-200 dark:border-slate-700 bg-white" />
                    <span className="text-[11px] font-bold text-emerald-600 flex items-center gap-1">
                      <CheckCircle2 className="w-3.5 h-3.5" /> ✔ Digital Signature Configured
                    </span>
                  </div>
                  <button type="button" onClick={() => setSignatureBase64('')} className="p-1.5 text-rose-500 hover:bg-rose-50 rounded-lg cursor-pointer">
                    <Trash2 className="w-3.5 h-3.5" />
                  </button>
                </div>
              ) : (
                <button type="button" onClick={() => signatureInputRef.current?.click()} className="w-full py-2 px-3 border border-dashed rounded-lg text-slate-500 hover:border-indigo-500 hover:text-indigo-600 transition text-center cursor-pointer">
                  + Upload Signature Image
                </button>
              )}
            </div>
          </div>

          <div className="flex justify-end pt-3 border-t dark:border-slate-800">
            <button
              type="submit"
              className="px-5 py-2 bg-indigo-600 hover:bg-indigo-700 text-white font-bold text-xs rounded-xl flex items-center gap-1.5 cursor-pointer transition shadow-xs"
            >
              <Save className="w-4 h-4" />
              <span>Save Business Settings</span>
            </button>
          </div>
        </form>
      )}

      {/* Sub-Tab 1: Catalog & Services */}
      {activeSubTab === 1 && (
        <ItemsCatalogTab
          savedItems={savedItems}
          isDarkMode={isDarkMode}
          currencySymbol={currencySymbol}
          formatMoney={formatMoney}
          parsePriceToCents={parsePriceToCents}
          onBack={() => setActiveSubTab(0)}
          onAddItem={onAddItem}
          onUpdateItem={onUpdateItem}
          onDeleteItem={onDeleteItem}
        />
      )}

      {/* Sub-Tab 2: Payment & Banking */}
      {activeSubTab === 2 && (
        <div className={`p-6 rounded-xl border space-y-4 ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}>
          <h3 className="font-bold text-sm text-slate-800 dark:text-slate-100 uppercase tracking-wider">Payment Methods & Remittance Instructions</h3>
          <p className="text-xs text-slate-500">Configure default remittance notes, bank routing numbers, UPI VPAs, and invoice payment terms.</p>

          <div className="space-y-4 text-xs">
            <div>
              <label className="block font-bold text-slate-500 mb-1">Bank Wire / UPI / Online Payment Instructions</label>
              <textarea
                value={paymentDetails}
                onChange={(e) => setPaymentDetails(e.target.value)}
                rows={3}
                placeholder="e.g. Bank: Chase, Account: 12345678, Routing: 987654321, UPI: business@upi"
                className={`w-full p-3 rounded-xl border ${isDarkMode ? 'bg-slate-900 border-slate-800 text-slate-100' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
              />
            </div>

            <div>
              <label className="block font-bold text-slate-500 mb-1">Default Invoice Terms & Legal Notice</label>
              <textarea
                value={defaultTerms}
                onChange={(e) => setDefaultTerms(e.target.value)}
                rows={2}
                className={`w-full p-3 rounded-xl border ${isDarkMode ? 'bg-slate-900 border-slate-800 text-slate-100' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
              />
            </div>

            <div>
              <label className="block font-bold text-slate-500 mb-1">Default Invoice Notes / Warranty</label>
              <textarea
                value={defaultNotes}
                onChange={(e) => setDefaultNotes(e.target.value)}
                rows={2}
                className={`w-full p-3 rounded-xl border ${isDarkMode ? 'bg-slate-900 border-slate-800 text-slate-100' : 'bg-slate-50 border-slate-200 text-slate-900'}`}
              />
            </div>

            <div className="flex justify-end pt-2 border-t dark:border-slate-800">
              <button
                onClick={() => {
                  onSaveProfile({
                    ...businessProfile,
                    payment_details: paymentDetails,
                    default_terms: defaultTerms,
                    default_notes: defaultNotes,
                  });
                  alert('Payment and banking instructions saved!');
                }}
                className="px-5 py-2 bg-indigo-600 hover:bg-indigo-700 text-white font-bold text-xs rounded-xl flex items-center gap-1.5 cursor-pointer transition shadow-xs"
              >
                <Save className="w-4 h-4" />
                <span>Save Payment Settings</span>
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Sub-Tab 3: Data Management & Backup */}
      {activeSubTab === 3 && (
        <div className={`p-6 rounded-xl border space-y-6 ${isDarkMode ? 'bg-[#0F172A] border-slate-800' : 'bg-white border-slate-200'}`}>
          <div>
            <h3 className="font-bold text-sm text-slate-800 dark:text-slate-100 uppercase tracking-wider">Disaster Recovery & Data Management</h3>
            <p className="text-xs text-slate-500 mt-1">Export or restore your complete local SQLite database snapshot atomically.</p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-6 text-xs">
            {/* Export */}
            <div className={`p-5 rounded-xl border space-y-3 ${isDarkMode ? 'bg-slate-900/40 border-slate-800' : 'bg-slate-50 border-slate-200'}`}>
              <div className="flex items-center gap-2 font-bold text-sm text-indigo-600">
                <Download className="w-4 h-4" />
                <span>Backup Database JSON</span>
              </div>
              <p className="text-slate-500 text-[11px]">
                Download a single JSON file containing all clients, invoices, estimates, expenses, catalog items, and branding profile.
              </p>
              {onExportDatabase && (
                <button
                  onClick={onExportDatabase}
                  className="w-full py-2.5 bg-indigo-600 hover:bg-indigo-700 text-white font-bold text-xs rounded-xl flex items-center justify-center gap-2 cursor-pointer transition shadow-xs"
                >
                  <Download className="w-4 h-4" />
                  <span>Download Backup JSON</span>
                </button>
              )}
            </div>

            {/* Restore */}
            <div className={`p-5 rounded-xl border space-y-3 ${isDarkMode ? 'bg-slate-900/40 border-slate-800' : 'bg-slate-50 border-slate-200'}`}>
              <div className="flex items-center gap-2 font-bold text-sm text-emerald-600">
                <Upload className="w-4 h-4" />
                <span>Restore Database from Backup</span>
              </div>
              <p className="text-slate-500 text-[11px]">
                Import a previously saved JSON snapshot to restore your data. Warning: This overwrites local records.
              </p>
              <input
                type="file"
                ref={backupInputRef}
                onChange={handleRestoreFileChange}
                accept=".json"
                className="hidden"
              />
              <button
                onClick={() => backupInputRef.current?.click()}
                className="w-full py-2.5 border border-slate-300 dark:border-slate-700 hover:bg-slate-100 dark:hover:bg-slate-800 text-slate-700 dark:text-slate-300 font-bold text-xs rounded-xl flex items-center justify-center gap-2 cursor-pointer transition"
              >
                <Upload className="w-4 h-4" />
                <span>Select JSON File to Restore</span>
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default SettingsTab;
