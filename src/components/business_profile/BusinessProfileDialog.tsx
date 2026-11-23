import React, { useState, useRef, useEffect } from 'react';
import { Settings, X, Save, Image, PenTool, Trash2, CheckCircle2 } from 'lucide-react';
import {
  TAX_MODE_LABELS,
  TaxMode,
  getCurrencyDecimals,
  getRegionalTaxIdLabel,
  normalizeTaxMode,
  validateUploadedFileBytes,
} from '../../billingRules';

interface BusinessProfileDialogProps {
  businessProfile: any;
  isDarkMode: boolean;
  onClose: () => void;
  onSaveProfile: (profileData: any) => void;
}

const CURRENCY_SYMBOL_MAP: Record<string, string> = {
  USD: '$',
  INR: '₹',
  EUR: '€',
  GBP: '£',
  JPY: '¥',
  KRW: '₩',
  CAD: 'C$',
  AUD: 'A$',
  AED: 'AED',
  SAR: 'SAR',
  KWD: 'KWD',
  BHD: 'BHD',
  OMR: 'OMR',
  JOD: 'JOD',
  TND: 'TND',
};

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
  const [defaultTaxMode, setDefaultTaxMode] = useState<TaxMode>(
    normalizeTaxMode(businessProfile.default_tax_mode)
  );
  const [defaultPstRatePercentage, setDefaultPstRatePercentage] = useState<string>(
    String(businessProfile.default_pst_rate_percentage ?? 7)
  );
  const [paymentDetails, setPaymentDetails] = useState<string>(businessProfile.payment_details || '');
  const [paymentQrPayload, setPaymentQrPayload] = useState<string>(businessProfile.payment_qr_payload || '');
  const [invoicePrefix, setInvoicePrefix] = useState<string>(businessProfile.invoice_prefix || 'INV-');
  const [estimatePrefix, setEstimatePrefix] = useState<string>(businessProfile.estimate_prefix || 'EST-');
  const [nextInvoiceNumber, setNextInvoiceNumber] = useState<string>(
    String(Math.max(1, Number(businessProfile.next_invoice_number) || 1))
  );
  const [defaultTerms, setDefaultTerms] = useState<string>(businessProfile.default_terms || '');
  const [defaultNotes, setDefaultNotes] = useState<string>(businessProfile.default_notes || '');
  const [logoBase64, setLogoBase64] = useState<string>(businessProfile.logo_base64 || '');
  const [signatureBase64, setSignatureBase64] = useState<string>(businessProfile.signature_base64 || '');
  const [uploadError, setUploadError] = useState<string>('');
  const [formError, setFormError] = useState<string>('');

  const logoInputRef = useRef<HTMLInputElement>(null);
  const signatureInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        onClose();
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [onClose]);

  const handleFileUpload = async (e: React.ChangeEvent<HTMLInputElement>, type: 'logo' | 'signature') => {
    const file = e.target.files?.[0];
    e.target.value = '';
    if (!file) return;

    try {
      const buffer = await file.arrayBuffer();
      const validation = validateUploadedFileBytes({
        bytes: new Uint8Array(buffer),
        filename: file.name,
        allowPdf: false,
      });
      if (!validation.isValid || !validation.mimeType) {
        setUploadError(validation.errorMessage || 'Invalid image selected.');
        return;
      }

      const reader = new FileReader();
      reader.onload = (uploadEvent) => {
        const result = uploadEvent.target?.result;
        if (typeof result === 'string') {
          const commaIdx = result.indexOf(',');
          const payload = commaIdx >= 0 ? result.slice(commaIdx + 1) : result;
          const normalizedDataUri = `data:${validation.mimeType};base64,${payload}`;
          if (type === 'logo') {
            setLogoBase64(normalizedDataUri);
          } else {
            setSignatureBase64(normalizedDataUri);
          }
          setUploadError('');
        }
      };
      reader.readAsDataURL(file);
    } catch {
      setUploadError('Unable to read selected image file.');
    }
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    const trimmedInvPrefix = invoicePrefix.trim();
    const trimmedEstPrefix = estimatePrefix.trim();
    const nextNumRaw = nextInvoiceNumber.trim();
    const parsedNextNum = /^\d+$/.test(nextNumRaw) ? Number.parseInt(nextNumRaw, 10) : NaN;

    if (!businessName.trim()) {
      setFormError('Business Name is required.');
      return;
    }
    if (!trimmedInvPrefix) {
      setFormError('Invoice Prefix cannot be empty.');
      return;
    }
    if (!trimmedEstPrefix) {
      setFormError('Estimate Prefix cannot be empty.');
      return;
    }
    if (!Number.isInteger(parsedNextNum) || parsedNextNum < 1) {
      setFormError('Next Invoice Number must be a whole number >= 1.');
      return;
    }
    setFormError('');

    const sym = CURRENCY_SYMBOL_MAP[currencyCode] || '$';
    const parsedPst = Math.min(100, Math.max(0, Math.round(Number(defaultPstRatePercentage) || 0)));

    onSaveProfile({
      ...businessProfile,
      business_name: businessName.trim(),
      email,
      phone,
      address,
      tax_id: taxId,
      currency_code: currencyCode,
      currency_symbol: sym,
      currency_decimals: getCurrencyDecimals(currencyCode),
      default_tax_mode: defaultTaxMode,
      default_pst_rate_percentage: defaultTaxMode === 'ca_dual' ? parsedPst : 0,
      invoice_prefix: trimmedInvPrefix,
      estimate_prefix: trimmedEstPrefix,
      next_invoice_number: parsedNextNum,
      payment_details: paymentDetails,
      payment_qr_payload: paymentQrPayload.trim(),
      default_terms: defaultTerms,
      default_notes: defaultNotes,
      logo_base64: logoBase64,
      signature_base64: signatureBase64,
    });
    onClose();
  };

  const taxIdLabel = getRegionalTaxIdLabel(defaultTaxMode, false);

  return (
    <div
      className="fixed inset-0 bg-black/50 backdrop-blur-xs flex items-center justify-center p-4 z-50"
      onClick={(e) => {
        if (e.target === e.currentTarget) {
          onClose();
        }
      }}
    >
      <div
        role="dialog"
        aria-modal="true"
        className={`w-full max-w-lg max-h-[90vh] flex flex-col rounded-xl border shadow-xl overflow-hidden ${isDarkMode ? 'bg-[#0F172A] border-slate-800 text-slate-100' : 'bg-white border-slate-200 text-slate-900'}`}
      >
        <div className="p-4 border-b dark:border-slate-800 flex items-center justify-between shrink-0">
          <div className="flex items-center gap-2">
            <Settings className="w-5 h-5 accent-text" />
            <h3 className="font-bold text-sm">Business Profile & Settings</h3>
          </div>
          <button onClick={onClose} className="p-1 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-800 transition cursor-pointer">
            <X className="w-4 h-4" />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="p-5 space-y-4 overflow-y-auto text-xs flex-1">
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

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
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

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <label className="block font-bold text-slate-500 mb-1">{taxIdLabel}</label>
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
                <option value="KRW">KRW (₩)</option>
                <option value="CAD">CAD (C$)</option>
                <option value="AUD">AUD (A$)</option>
                <option value="AED">AED (UAE)</option>
                <option value="SAR">SAR (KSA)</option>
                <option value="KWD">KWD (Kuwait - 3 dec)</option>
                <option value="BHD">BHD (Bahrain - 3 dec)</option>
                <option value="OMR">OMR (Oman - 3 dec)</option>
                <option value="JOD">JOD (Jordan - 3 dec)</option>
                <option value="TND">TND (Tunisia - 3 dec)</option>
              </select>
            </div>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div className={defaultTaxMode === 'ca_dual' ? '' : 'sm:col-span-2'}>
              <label className="block font-bold text-slate-500 mb-1">Default Regional Tax Compliance Mode</label>
              <select
                value={defaultTaxMode}
                onChange={(e) => setDefaultTaxMode(normalizeTaxMode(e.target.value))}
                className={`w-full p-2.5 rounded-xl border ${isDarkMode ? 'bg-slate-900 border-slate-800' : 'bg-slate-50 border-slate-200'}`}
              >
                {(Object.keys(TAX_MODE_LABELS) as TaxMode[]).map((mode) => (
                  <option key={mode} value={mode}>
                    {TAX_MODE_LABELS[mode]}
                  </option>
                ))}
              </select>
            </div>
            {defaultTaxMode === 'ca_dual' && (
              <div>
                <label className="block font-bold text-slate-500 mb-1">Default Canada PST %</label>
                <input
                  type="number"
                  min={0}
                  max={100}
                  value={defaultPstRatePercentage}
                  onChange={(e) => setDefaultPstRatePercentage(e.target.value)}
                  className={`w-full p-2.5 rounded-xl border font-mono tabular-nums ${isDarkMode ? 'bg-slate-900 border-slate-800' : 'bg-slate-50 border-slate-200'}`}
                />
              </div>
            )}
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

          <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
            <div>
              <label className="block font-bold text-slate-500 mb-1">Invoice Prefix *</label>
              <input
                type="text"
                value={invoicePrefix}
                onChange={(e) => setInvoicePrefix(e.target.value)}
                placeholder="INV-"
                className={`w-full p-2.5 rounded-xl border ${isDarkMode ? 'bg-slate-900 border-slate-800' : 'bg-slate-50 border-slate-200'}`}
                required
              />
            </div>
            <div>
              <label className="block font-bold text-slate-500 mb-1">Estimate Prefix *</label>
              <input
                type="text"
                value={estimatePrefix}
                onChange={(e) => setEstimatePrefix(e.target.value)}
                placeholder="EST-"
                className={`w-full p-2.5 rounded-xl border ${isDarkMode ? 'bg-slate-900 border-slate-800' : 'bg-slate-50 border-slate-200'}`}
                required
              />
            </div>
            <div>
              <label className="block font-bold text-slate-500 mb-1">Next Invoice # *</label>
              <input
                type="number"
                min={1}
                step={1}
                value={nextInvoiceNumber}
                onChange={(e) => setNextInvoiceNumber(e.target.value)}
                className={`w-full p-2.5 rounded-xl border font-mono tabular-nums ${isDarkMode ? 'bg-slate-900 border-slate-800' : 'bg-slate-50 border-slate-200'}`}
                required
              />
            </div>
          </div>

          {/* Logo & Signature Branding Controls (Never dumps raw base64) */}
          {(formError || uploadError) && (
            <div className="p-2.5 rounded-xl border border-rose-300 dark:border-rose-800 bg-rose-50 dark:bg-rose-950/60 text-rose-700 dark:text-rose-300 text-xs font-semibold">
              {formError || uploadError}
            </div>
          )}
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
                    {!logoBase64.startsWith('idb://') && (
                      <img
                        src={logoBase64}
                        alt="Logo Preview"
                        className="w-10 h-10 object-contain rounded-lg border border-slate-200 dark:border-slate-700 bg-white"
                      />
                    )}
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
                  className="w-full py-2 px-3 border border-dashed rounded-lg text-slate-500 accent-dashed-hover transition text-center cursor-pointer"
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
                    {!signatureBase64.startsWith('idb://') && (
                      <img
                        src={signatureBase64}
                        alt="Signature Preview"
                        className="w-10 h-10 object-contain rounded-lg border border-slate-200 dark:border-slate-700 bg-white"
                      />
                    )}
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
                  className="w-full py-2 px-3 border border-dashed rounded-lg text-slate-500 accent-dashed-hover transition text-center cursor-pointer"
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
            <label className="block font-bold text-slate-500 mb-1">Scan-to-Pay QR Payload (UPI ID or Payment URL)</label>
            <input
              type="text"
              value={paymentQrPayload}
              onChange={(e) => setPaymentQrPayload(e.target.value)}
              placeholder="e.g. business@upi or https://pay.example.com/studio"
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
              className="px-4 py-2 accent-btn font-bold text-xs rounded-xl flex items-center gap-1.5 transition cursor-pointer"
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
