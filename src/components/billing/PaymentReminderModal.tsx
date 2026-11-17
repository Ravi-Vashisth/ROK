import React, { useState, useEffect } from 'react';
import { X, Copy, MessageCircle, MessageSquare, Mail, Check } from 'lucide-react';
import {
  buildPaymentReminderMessage,
  buildWhatsAppUrl,
  buildMailtoUrl,
  buildSmsUrl,
  normalizePhoneForUri,
  getCurrencyDecimals,
} from '../../billingRules';

interface PaymentReminderModalProps {
  invoice: any | null;
  client?: any | null;
  businessProfile: any;
  isDarkMode: boolean;
  onClose: () => void;
  onCopied?: (msg: string) => void;
}

export const PaymentReminderModal: React.FC<PaymentReminderModalProps> = ({
  invoice,
  client,
  businessProfile,
  isDarkMode,
  onClose,
  onCopied,
}) => {
  const sym = invoice?.currency_symbol || businessProfile?.currency_symbol || '$';
  const curCode = invoice?.currency_code || businessProfile?.currency_code || 'USD';
  const dec =
    invoice?.currency_decimals ??
    businessProfile?.currency_decimals ??
    getCurrencyDecimals(curCode || sym);

  const clientName = client?.name || invoice?.client_name || 'Client';
  const clientEmail = (client?.email || '').trim();
  const clientPhone = (client?.phone || '').trim();
  const normalizedPhone = normalizePhoneForUri(clientPhone);

  const defaultMessage = invoice
    ? buildPaymentReminderMessage({
        invoiceNumber: invoice.invoice_number,
        clientName,
        balanceDueUnits: invoice.balance_due_cents ?? invoice.total_cents ?? 0,
        currencySymbol: sym,
        currencyDecimals: dec,
        dueDate: invoice.due_date || '',
        businessName: businessProfile?.business_name || 'Accounts Team',
      })
    : '';

  const [message, setMessage] = useState<string>(defaultMessage);
  const [copiedJustNow, setCopiedJustNow] = useState<boolean>(false);

  useEffect(() => {
    setMessage(defaultMessage);
    setCopiedJustNow(false);
  }, [defaultMessage]);

  if (!invoice) return null;

  const subject = `Invoice ${invoice.invoice_number} Payment Reminder`;
  const waUrl = buildWhatsAppUrl(clientPhone, message);
  const smsUrl = buildSmsUrl(clientPhone, message);
  const mailtoUrl = buildMailtoUrl(clientEmail, subject, message);

  const handleCopy = async () => {
    try {
      await navigator.clipboard.writeText(message);
    } catch (_) {
      // Clipboard API may be restricted in headless contexts
    }
    setCopiedJustNow(true);
    setTimeout(() => setCopiedJustNow(false), 2000);
    onCopied?.('Payment reminder copied to clipboard.');
  };

  return (
    <div className="fixed inset-0 bg-black/50 backdrop-blur-xs flex items-center justify-center p-4 z-50">
      <div
        className={`w-full max-w-md max-h-[90vh] overflow-y-auto rounded-xl border p-6 space-y-4 shadow-xl ${
          isDarkMode ? 'bg-[#0F172A] border-slate-800 text-slate-100' : 'bg-white border-slate-200 text-slate-900'
        }`}
      >
        <div className="flex items-center justify-between">
          <div>
            <h3 className="font-bold text-sm">Send Payment Reminder</h3>
            <p className="text-xs text-slate-500 mt-0.5">
              Invoice <span className="font-mono font-bold text-indigo-500">{invoice.invoice_number}</span> for {clientName}
            </p>
            {(clientEmail || normalizedPhone) && (
              <p className="text-[11px] text-slate-400 mt-0.5">
                {[clientEmail, normalizedPhone].filter(Boolean).join(' • ')}
              </p>
            )}
          </div>
          <button
            onClick={onClose}
            className="text-slate-400 hover:text-slate-600 cursor-pointer"
            aria-label="Close reminder dialog"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        <div>
          <label className="block text-[11px] font-bold text-slate-500 mb-1.5">
            Reminder Message
          </label>
          <textarea
            value={message}
            onChange={(e) => setMessage(e.target.value)}
            rows={4}
            className={`w-full p-3 rounded-xl border text-xs leading-relaxed focus:outline-none focus:ring-2 focus:ring-indigo-500 ${
              isDarkMode
                ? 'bg-slate-900 border-slate-800 text-slate-200'
                : 'bg-slate-50 border-slate-200 text-slate-800'
            }`}
          />
        </div>

        <div className="space-y-2">
          <button
            type="button"
            onClick={handleCopy}
            className={`w-full p-3 rounded-xl border text-xs font-bold flex items-center justify-between transition cursor-pointer ${
              isDarkMode
                ? 'bg-slate-900 border-slate-800 hover:bg-slate-800 text-slate-200'
                : 'bg-slate-50 border-slate-200 hover:bg-slate-100 text-slate-800'
            }`}
          >
            <span className="flex items-center gap-2.5">
              {copiedJustNow ? (
                <Check className="w-4 h-4 text-emerald-500" />
              ) : (
                <Copy className="w-4 h-4 text-slate-500" />
              )}
              <span>{copiedJustNow ? 'Copied to Clipboard' : 'Copy Reminder Message'}</span>
            </span>
          </button>

          <a
            href={waUrl}
            target="_blank"
            rel="noopener noreferrer"
            className={`w-full p-3 rounded-xl border text-xs font-bold flex items-center justify-between transition ${
              isDarkMode
                ? 'bg-emerald-950/30 border-emerald-900/50 hover:bg-emerald-950/50 text-emerald-300'
                : 'bg-emerald-50 border-emerald-200 hover:bg-emerald-100 text-emerald-800'
            }`}
          >
            <span className="flex items-center gap-2.5">
              <MessageCircle className="w-4 h-4 text-emerald-600" />
              <span>Send via WhatsApp</span>
            </span>
            <span className="text-[11px] font-normal opacity-80">
              {normalizedPhone || 'Choose contact'}
            </span>
          </a>

          {smsUrl ? (
            <a
              href={smsUrl}
              className={`w-full p-3 rounded-xl border text-xs font-bold flex items-center justify-between transition ${
                isDarkMode
                  ? 'bg-indigo-950/30 border-indigo-900/50 hover:bg-indigo-950/50 text-indigo-300'
                  : 'bg-indigo-50 border-indigo-200 hover:bg-indigo-100 text-indigo-800'
              }`}
            >
              <span className="flex items-center gap-2.5">
                <MessageSquare className="w-4 h-4 text-indigo-600" />
                <span>Send SMS</span>
              </span>
              <span className="text-[11px] font-normal opacity-80">{normalizedPhone}</span>
            </a>
          ) : (
            <div
              className={`w-full p-3 rounded-xl border text-xs font-semibold flex items-center justify-between opacity-50 cursor-not-allowed ${
                isDarkMode ? 'bg-slate-900 border-slate-800 text-slate-400' : 'bg-slate-50 border-slate-200 text-slate-400'
              }`}
            >
              <span className="flex items-center gap-2.5">
                <MessageSquare className="w-4 h-4" />
                <span>Send SMS</span>
              </span>
              <span className="text-[11px] font-normal">No client phone on file</span>
            </div>
          )}

          <a
            href={mailtoUrl}
            className={`w-full p-3 rounded-xl border text-xs font-bold flex items-center justify-between transition ${
              isDarkMode
                ? 'bg-sky-950/30 border-sky-900/50 hover:bg-sky-950/50 text-sky-300'
                : 'bg-sky-50 border-sky-200 hover:bg-sky-100 text-sky-800'
            }`}
          >
            <span className="flex items-center gap-2.5">
              <Mail className="w-4 h-4 text-sky-600" />
              <span>Send Email</span>
            </span>
            <span className="text-[11px] font-normal opacity-80">
              {clientEmail || 'Default mail app'}
            </span>
          </a>
        </div>

        <div className="flex justify-end pt-1">
          <button
            type="button"
            onClick={onClose}
            className="px-4 py-1.5 text-xs font-bold rounded-xl border border-slate-300 dark:border-slate-700 hover:bg-slate-100 dark:hover:bg-slate-800 cursor-pointer"
          >
            Close
          </button>
        </div>
      </div>
    </div>
  );
};
