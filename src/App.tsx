import { useState, useEffect } from 'react';
import {
  LayoutDashboard,
  ReceiptText,
  Wallet,
  Users,
  Building2,
  FileText,
  CheckCircle,
  CreditCard,
  AlertTriangle,
  FileSpreadsheet,
} from 'lucide-react';
import {
  parsePriceToCents,
  calculateDueDate,
  isInvoiceOverdue,
} from './billingRules';

// --- Interfaces & Types ---
interface Client { id: string; name: string; email: string; phone: string; address: string; tax_id: string; created_at: string; }
interface StoredInvoiceItem { id: string; invoice_id: string; description: string; quantity: number; unit_price_cents: number; total_cents: number; created_at: string; }
interface StoredPayment { id: string; invoice_id: string; amount_cents: number; payment_method: string; payment_date: string; notes: string; created_at: string; }
interface InvoiceRecord { id: string; client_id: string; client_name: string; invoice_number: string; subtotal_cents: number; tax_cents: number; total_cents: number; discount_type?: 'none' | 'percent' | 'flat'; discount_value?: number; discount_cents?: number; status: string; issue_date: string; due_date: string; payment_terms: string; terms?: string; notes?: string; created_at: string; }
interface StoredEstimateRecord { id: string; client_id: string; client_name: string; estimate_number: string; subtotal_cents: number; tax_cents: number; total_cents: number; discount_type?: 'none' | 'percent' | 'flat'; discount_value?: number; discount_cents?: number; status: string; issue_date: string; expiry_date: string; converted_invoice_id?: string; terms?: string; notes?: string; created_at: string; }
interface StoredEstimateItem { id: string; estimate_id: string; description: string; quantity: number; unit_price_cents: number; total_cents: number; created_at: string; }
interface SavedItem { id: string; title: string; default_price_cents: number; description: string; created_at: string; }
interface BusinessProfile { id: string; business_name: string; email: string; phone: string; address: string; tax_id: string; payment_details: string; currency_symbol: string; default_terms: string; default_notes: string; logo_base64?: string; signature_base64?: string; signature_label?: string; }

const DEFAULT_BUSINESS_PROFILE: BusinessProfile = {
  id: 'default',
  business_name: 'My Freelance Studio',
  email: 'billing@studio.com',
  phone: '+1 (555) 019-2834',
  address: '100 Tech Plaza, Suite 400, San Francisco, CA 94107',
  tax_id: 'US-EIN-987654321',
  payment_details: 'Bank: Silicon Valley Bank\nAccount: 987654321098\nRouting / SWIFT: SVB12345\nPayPal / UPI: pay@studio.com',
  currency_symbol: '$',
  default_terms: 'Payment due within agreed terms. Thank you for your business!',
  default_notes: 'All work includes 30 days post-delivery support.',
  logo_base64: '',
  signature_base64: '',
  signature_label: 'Authorized Signatory',
};

export default function App() {
  // --- All State Hooks (Retained) ---
  const [businessProfile] = useState<BusinessProfile>(() => { try { const saved = localStorage.getItem('sqlite_business_profile'); if (saved) return JSON.parse(saved); } catch (_) {} return DEFAULT_BUSINESS_PROFILE; });
  const [invoices] = useState<InvoiceRecord[]>(() => { try { const saved = localStorage.getItem('sqlite_invoices_sprint2'); if (saved) return JSON.parse(saved); } catch (_) {} return []; });
  const [payments] = useState<StoredPayment[]>(() => { try { const saved = localStorage.getItem('sqlite_payments_sprint3'); if (saved) return JSON.parse(saved); } catch (_) {} return []; });

  // --- Navigation ---
  const [activeTab, setActiveTab] = useState(0); 
  const tabs = [
    { name: 'Dashboard', icon: LayoutDashboard },
    { name: 'Sales', icon: ReceiptText },
    { name: 'Expenses', icon: Wallet },
    { name: 'Directory & Settings', icon: Users },
  ];

  // --- Helper Functions ---
  const formatMoney = (cents: number) => `${businessProfile.currency_symbol || '$'}${(cents / 100).toFixed(2)}`;

  // --- View Logic ---
  const DashboardView = () => {
    const totalInvoicedCents = invoices.reduce((sum, inv) => sum + inv.total_cents, 0);
    const totalCollectedCents = payments.reduce((sum, p) => sum + p.amount_cents, 0);
    const pendingBalanceCents = invoices.reduce((sum, inv) => {
        const paid = payments.filter(p => p.invoice_id === inv.id).reduce((s, p) => s + p.amount_cents, 0);
        return sum + Math.max(0, inv.total_cents - paid);
    }, 0);

    return (
      <div className="space-y-6">
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
          <MetricTile title="Total Invoiced" value={formatMoney(totalInvoicedCents)} icon={FileText} color="indigo" />
          <MetricTile title="Total Collected" value={formatMoney(totalCollectedCents)} icon={CheckCircle} color="emerald" />
          <MetricTile title="Pending Balance" value={formatMoney(pendingBalanceCents)} icon={CreditCard} color="amber" />
          <MetricTile title="Overdue Amount" value="$0.00" icon={AlertTriangle} color="rose" />
        </div>
      </div>
    );
  };

  const MetricTile = ({ title, value, icon: Icon, color }: any) => (
      <div className="bg-white border border-slate-200 rounded-2xl p-4 shadow-sm flex items-center gap-3">
        <div className={`w-10 h-10 rounded-xl bg-${color}-50 border border-${color}-100 flex items-center justify-center text-${color}-600`}>
          <Icon className="w-5 h-5"/>
        </div>
        <div>
          <p className="text-[10px] text-slate-500 uppercase tracking-wider font-semibold">{title}</p>
          <p className="text-lg font-bold font-mono">{value}</p>
        </div>
      </div>
  );

  return (
    <div className="min-h-screen bg-slate-50 text-slate-900 font-sans flex antialiased">
      <aside className="hidden md:flex flex-col w-[220px] bg-white border-r border-slate-200">
        <div className="p-6 border-b border-slate-100 font-bold text-lg text-indigo-950">FreelanceSuite</div>
        <nav className="flex-1 p-4 space-y-1">
          {tabs.map((tab, idx) => (
            <button key={tab.name} onClick={() => setActiveTab(idx)} className={`w-full flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium transition ${activeTab === idx ? 'bg-indigo-50 text-indigo-700' : 'text-slate-600 hover:bg-slate-50'}`}>
              <tab.icon className="w-5 h-5" /> {tab.name}
            </button>
          ))}
        </nav>
      </aside>
      <div className="flex-1 flex flex-col min-w-0">
        <header className="h-16 bg-white border-b border-slate-200 px-6 flex items-center justify-between sticky top-0 z-10">
          <h2 className="font-semibold text-lg">{tabs[activeTab].name}</h2>
        </header>
        <main className="flex-1 p-6 overflow-y-auto">
            {activeTab === 0 ? <DashboardView/> : <div className="p-8 text-slate-500">Other tabs under construction</div>}
        </main>
      </div>
      <nav className="md:hidden fixed bottom-0 left-0 right-0 bg-white border-t border-slate-200 flex justify-around p-2 z-10">
        {tabs.map((tab, idx) => (
          <button key={tab.name} onClick={() => setActiveTab(idx)} className={`flex flex-col items-center gap-1 p-2 rounded-xl text-xs font-medium ${activeTab === idx ? 'text-indigo-700' : 'text-slate-400'}`}>
            <tab.icon className="w-6 h-6" /> {tab.name}
          </button>
        ))}
      </nav>
    </div>
  );
}
