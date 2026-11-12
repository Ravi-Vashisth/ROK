import React, { useState, useRef } from 'react';
import { Settings, X, Save, Image, PenTool, Trash2, CheckCircle2 } from 'lucide-react';

interface BusinessProfileDialogProps {
  businessProfile: any;
  isDarkMode: boolean;
  onClose: () => void;
  onSaveProfile: (profileData: any) => void;
}

export const BusinessProfileDialog: React.FC<BusinessProfileDialogProps> = ({
  businessProfile,
  isDarkMode,
  onClose,
  onSaveProfile,
}) => {
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

  const handleFileUpload = (e: React.ChangeEvent<HTMLInputElement>, type: 'logo' | 'signature') => {
    const file = e.target.files?.[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = (uploadEvent) => {
      const base64 = uploadEvent.target?.result as string;
      if (type === 'logo') {
        setLogoBase64(base64);
      } else {
        setSignatureBase64(base64);
      }
    };
    reader.readAsDataURL(file);
    e.target.value = '';
  };

  const handleSubmit = (e: React.FormEvent) => {
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
    onClose();
  };

  return (
    <div className="fixed inset-0 bg-black/50 backdrop-blur-xs flex items-center justify-center p-4 z-50">
      <div className={`w-full max-w-lg rounded-xl border shadow-xl overflow-hidden ${isDarkMode ? 'bg-[#0F172A] border-slate-800 text-slate-100' : 'bg-white border-slate-200 text-slate-900'}`}>
        <div className="p-4 border-b flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Settings className="w-5 h-5 text-indigo-500" />
            <h3 className="font-bold text-sm">Business Profile & Settings</h3>
          </div>
          <button onClick={onClose} className="p-1 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-800 transition">
            <X className="w-4 h-4" />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="p-5 space-y-4 max-h-[80vh] overflow-y-auto text-xs">
          <div>
            <label className="block font-bold text-slate-500 mb-1">Business Name *</label>
            <input
              type="text"
              value={businessName}
              onChange={(e) => setBusinessName(e.target.value)}
              className={`w-full p-2.5 rounded-xl border ${isDarkMode ? 'bg-slate-900 border-slate-800' : 'bg-slate-50 border-slate-200'}`}
              required
            />
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block font-bold text-slate-500 mb-1">Business Email</label>
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                className={`w-full p-2.5 rounded-xl border ${isDarkMode ? 'bg-slate-900 border-slate-800' : 'bg-slate-50 border-slate-200'}`}
              />
            </div>
            <div>
              <label className="block font-bold text-slate-500 mb-1">Phone Number</label>
              <input
                type="text"
                value={phone}
                onChange={(e) => setPhone(e.target.value)}
                className={`w-full p-2.5 rounded-xl border ${isDarkMode ? 'bg-slate-900 border-slate-800' : 'bg-slate-50 border-slate-200'}`}
              />
            </div>
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block font-bold text-slate-500 mb-1">Tax ID / GSTIN / VAT</label>
              <input
                type="text"
                value={taxId}
                onChange={(e) => setTaxId(e.target.value)}
                className={`w-full p-2.5 rounded-xl border ${isDarkMode ? 'bg-slate-900 border-slate-800' : 'bg-slate-50 border-slate-200'}`}
              />
            </div>
            <div>
              <label className="block font-bold text-slate-500 mb-1">Default Currency</label>
              <select
                value={currencyCode}
                onChange={(e) => setCurrencyCode(e.target.value)}
                className={`w-full p-2.5 rounded-xl border ${isDarkMode ? 'bg-slate-900 border-slate-800' : 'bg-slate-50 border-slate-200'}`}
              >
                <option value="USD">USD ($)</option>
                <option value="INR">INR (₹)</option>
                <option value="EUR">EUR (€)</option>
                <option value="GBP">GBP (£)</option>
                <option value="JPY">JPY (¥)</option>
              </select>
            </div>
          </div>

          <div>
            <label className="block font-bold text-slate-500 mb-1">Business Address</label>
            <input
              type="text"
              value={address}
              onChange={(e) => setAddress(e.target.value)}
              className={`w-full p-2.5 rounded-xl border ${isDarkMode ? 'bg-slate-900 border-slate-800' : 'bg-slate-50 border-slate-200'}`}
            />
          </div>

          {/* Logo & Signature Branding Controls (Never dumps raw base64) */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 pt-1">
            {/* Company Logo */}
            <div className={`p-3 rounded-xl border ${isDarkMode ? 'bg-slate-900/60 border-slate-800' : 'bg-slate-50 border-slate-200'}`}>
              <label className="block font-bold text-slate-500 mb-2 flex items-center gap-1.5">
                <Image className="w-3.5 h-3.5" />
                <span>Company Logo</span>
              </label>
              <input
                type="file"
                ref={logoInputRef}
                onChange={(e) => handleFileUpload(e, 'logo')}
                accept="image/*"
                className="hidden"
              />
              {logoBase64 ? (
                <div className="flex items-center justify-between gap-2">
                  <div className="flex items-center gap-2">
                    <img
                      src={logoBase64}
                      alt="Logo Preview"
                      className="w-10 h-10 object-contain rounded-lg border border-slate-200 dark:border-slate-700 bg-white"
                    />
                    <span className="text-[11px] font-bold text-emerald-600 flex items-center gap-1">
                      <CheckCircle2 className="w-3.5 h-3.5" />
                      Logo Configured
                    </span>
                  </div>
                  <button
                    type="button"
                    onClick={() => setLogoBase64('')}
                    className="p-1 rounded-md text-rose-500 hover:bg-rose-50 dark:hover:bg-rose-950/50 transition cursor-pointer"
                    title="Remove Logo"
                  >
                    <Trash2 className="w-3.5 h-3.5" />
                  </button>
                </div>
              ) : (
                <button
                  type="button"
                  onClick={() => logoInputRef.current?.click()}
                  className="w-full py-2 px-3 border border-dashed rounded-lg text-slate-500 hover:border-indigo-500 hover:text-indigo-600 transition text-center cursor-pointer"
                >
                  + Upload Logo Image
                </button>
              )}
            </div>

            {/* Digital Signature */}
            <div className={`p-3 rounded-xl border ${isDarkMode ? 'bg-slate-900/60 border-slate-800' : 'bg-slate-50 border-slate-200'}`}>
              <label className="block font-bold text-slate-500 mb-2 flex items-center gap-1.5">
                <PenTool className="w-3.5 h-3.5" />
                <span>Digital Signature</span>
              </label>
              <input
                type="file"
                ref={signatureInputRef}
                onChange={(e) => handleFileUpload(e, 'signature')}
                accept="image/*"
                className="hidden"
              />
              {signatureBase64 ? (
                <div className="flex items-center justify-between gap-2">
                  <div className="flex items-center gap-2">
                    <img
                      src={signatureBase64}
                      alt="Signature Preview"
                      className="w-10 h-10 object-contain rounded-lg border border-slate-200 dark:border-slate-700 bg-white"
                    />
                    <span className="text-[11px] font-bold text-emerald-600 flex items-center gap-1">
                      <CheckCircle2 className="w-3.5 h-3.5" />
                      ✔ Digital Signature Configured
                    </span>
                  </div>
                  <button
                    type="button"
                    onClick={() => setSignatureBase64('')}
                    className="p-1 rounded-md text-rose-500 hover:bg-rose-50 dark:hover:bg-rose-950/50 transition cursor-pointer"
                    title="Remove Signature"
                  >
                    <Trash2 className="w-3.5 h-3.5" />
                  </button>
                </div>
              ) : (
                <button
                  type="button"
                  onClick={() => signatureInputRef.current?.click()}
                  className="w-full py-2 px-3 border border-dashed rounded-lg text-slate-500 hover:border-indigo-500 hover:text-indigo-600 transition text-center cursor-pointer"
                >
                  + Upload Signature Image
                </button>
              )}
            </div>
          </div>

          <div>
            <label className="block font-bold text-slate-500 mb-1">Default Payment Instructions (Bank / UPI / PayPal)</label>
            <textarea
              value={paymentDetails}
              onChange={(e) => setPaymentDetails(e.target.value)}
              rows={2}
              className={`w-full p-2.5 rounded-xl border ${isDarkMode ? 'bg-slate-900 border-slate-800' : 'bg-slate-50 border-slate-200'}`}
            />
          </div>

          <div>
            <label className="block font-bold text-slate-500 mb-1">Default Invoice Terms & Conditions</label>
            <textarea
              value={defaultTerms}
              onChange={(e) => setDefaultTerms(e.target.value)}
              rows={2}
              className={`w-full p-2.5 rounded-xl border ${isDarkMode ? 'bg-slate-900 border-slate-800' : 'bg-slate-50 border-slate-200'}`}
            />
          </div>

          <div className="pt-2 flex justify-end gap-2 border-t">
            <button
              type="button"
              onClick={onClose}
              className="px-4 py-2 border rounded-xl text-xs font-bold hover:bg-slate-100 dark:hover:bg-slate-800 transition"
            >
              Cancel
            </button>
            <button
              type="submit"
              className="px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white font-bold text-xs rounded-xl flex items-center gap-1.5 transition cursor-pointer"
            >
              <Save className="w-4 h-4" />
              <span>Save Business Settings</span>
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

export default BusinessProfileDialog;
