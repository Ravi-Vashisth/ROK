import { useState, useEffect } from 'react';
import { 
  Building2, 
  FileText, 
  Plus, 
  Save, 
  Database, 
  Copy, 
  Check, 
  Download, 
  Monitor, 
  Code2, 
  Calculator,
  RefreshCw,
  HardDrive
} from 'lucide-react';
import {
  parsePriceToCents,
  calculateInvoice,
  formatNextInvoiceNumber,
  formatCents,
} from './billingRules';

interface Client {
  id: string;
  name: string;
  created_at: string;
}

interface InvoiceRecord {
  id: string;
  client_id: string;
  client_name: string;
  invoice_number: string;
  subtotal_cents: number;
  tax_cents: number;
  total_cents: number;
  status: string;
  created_at: string;
}

const PUBSPEC_CONTENT = `name: billing_app
description: Minimal 100% offline foundational walking-skeleton for desktop billing.
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.6.1
  sqlite3: ^2.4.6
  sqlite3_flutter_libs: ^0.5.24
  path_provider: ^2.1.4
  path: ^1.9.0
  intl: ^0.19.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0

flutter:
  uses-material-design: true`;

const DART_MAIN_PREVIEW = `// lib/main.dart
// Available in project workspace root /lib/main.dart
// 100% complete single file with sqlite3, Riverpod, strict integer cents`;

export default function App() {
  const [activeTab, setActiveTab] = useState<'app' | 'flutter_code' | 'schema'>('app');
  const [codeSubTab, setCodeSubTab] = useState<'main' | 'pubspec'>('main');

  // Local storage backed state mimicking SQLite tables
  const [clients, setClients] = useState<Client[]>(() => {
    try {
      const saved = localStorage.getItem('sqlite_clients');
      if (saved) return JSON.parse(saved);
    } catch {
      // fallback
    }
    return [
      { id: '1714000000000-101', name: 'Acme Global Corp', created_at: '2026-10-26T10:00:00Z' },
      { id: '1714000000000-102', name: 'Apex Design Studio', created_at: '2026-10-26T11:00:00Z' },
    ];
  });

  const [invoices, setInvoices] = useState<InvoiceRecord[]>(() => {
    try {
      const saved = localStorage.getItem('sqlite_invoices');
      if (saved) return JSON.parse(saved);
    } catch {
      // fallback
    }
    return [
      {
        id: '1714000000000-201',
        client_id: '1714000000000-101',
        client_name: 'Acme Global Corp',
        invoice_number: 'INV-0001',
        subtotal_cents: 15500, // $155.00
        tax_cents: 1550,       // $15.50
        total_cents: 17050,    // $170.50
        status: 'PAID',
        created_at: '2026-10-26T12:00:00Z',
      },
    ];
  });

  // Form Inputs
  const [newClientName, setNewClientName] = useState('');
  const [selectedClientId, setSelectedClientId] = useState<string>('1714000000000-101');
  const [itemDescription, setItemDescription] = useState('Quarterly Software License');
  const [priceInput, setPriceInput] = useState('15.50');
  const [quantityInput, setQuantityInput] = useState('10');
  const [taxPctInput, setTaxPctInput] = useState('10');

  // Feedback states
  const [copiedKey, setCopiedKey] = useState<string | null>(null);
  const [toastMessage, setToastMessage] = useState<string | null>(null);
  const [mainDartContent, setMainDartContent] = useState<string>('');

  // Persist to local storage
  useEffect(() => {
    try {
      localStorage.setItem('sqlite_clients', JSON.stringify(clients));
    } catch (e) {
      console.error(e);
    }
  }, [clients]);

  useEffect(() => {
    try {
      localStorage.setItem('sqlite_invoices', JSON.stringify(invoices));
    } catch (e) {
      console.error(e);
    }
  }, [invoices]);

  // Fetch lib/main.dart for the code viewer
  useEffect(() => {
    fetch('/lib/main.dart')
      .then((res) => (res.ok ? res.text() : ''))
      .then((text) => {
        if (text) setMainDartContent(text);
      })
      .catch(() => {});
  }, []);

  const showToast = (msg: string) => {
    setToastMessage(msg);
    setTimeout(() => setToastMessage(null), 3000);
  };

  const handleCopy = (text: string, key: string) => {
    navigator.clipboard.writeText(text);
    setCopiedKey(key);
    showToast(`Copied ${key} to clipboard!`);
    setTimeout(() => setCopiedKey(null), 2000);
  };

  const handleDownload = (filename: string, content: string) => {
    const blob = new Blob([content], { type: 'text/plain;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    a.click();
    URL.revokeObjectURL(url);
    showToast(`Downloaded ${filename}`);
  };

  // Financial Calculations for current input
  const priceCents = parsePriceToCents(priceInput);
  const qty = parseInt(quantityInput, 10) || 1;
  const taxPct = parseInt(taxPctInput, 10) || 0;
  const calculation = calculateInvoice(priceCents, qty, taxPct);

  // Add client
  const handleAddClient = (e: React.FormEvent) => {
    e.preventDefault();
    const trimmed = newClientName.trim();
    if (!trimmed) return;
    const newId = `${Date.now()}-${Math.floor(Math.random() * 900000 + 100000)}`;
    const newClient: Client = {
      id: newId,
      name: trimmed,
      created_at: new Date().toISOString(),
    };
    setClients((prev) => [...prev, newClient]);
    setSelectedClientId(newId);
    setNewClientName('');
    showToast(`Client "${trimmed}" committed to local SQLite!`);
  };

  // Save Invoice
  const handleSaveInvoice = (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedClientId) {
      alert('Please select or create a client first.');
      return;
    }
    if (priceCents <= 0) {
      alert('Please enter a valid price.');
      return;
    }

    const client = clients.find((c) => c.id === selectedClientId);
    const nextInvoiceNumber = formatNextInvoiceNumber(invoices.length);
    const newId = `${Date.now()}-${Math.floor(Math.random() * 900000 + 100000)}`;

    const newInvoice: InvoiceRecord = {
      id: newId,
      client_id: selectedClientId,
      client_name: client ? client.name : 'Unknown Client',
      invoice_number: nextInvoiceNumber,
      subtotal_cents: calculation.subtotalCents,
      tax_cents: calculation.taxCents,
      total_cents: calculation.totalCents,
      status: 'PAID',
      created_at: new Date().toISOString(),
    };

    setInvoices((prev) => [newInvoice, ...prev]);
    showToast(`Invoice ${nextInvoiceNumber} saved! Total: ${formatCents(calculation.totalCents)}`);
    setItemDescription('');
    setPriceInput('');
    setQuantityInput('1');
  };

  return (
    <div className="min-h-screen bg-slate-900 text-slate-100 flex flex-col font-sans antialiased">
      {/* Toast Notification */}
      {toastMessage && (
        <div className="fixed bottom-5 right-5 z-50 bg-emerald-600 text-white px-4 py-2.5 rounded-lg shadow-xl text-sm font-medium flex items-center gap-2 transition-all">
          <Check className="w-4 h-4" />
          <span>{toastMessage}</span>
        </div>
      )}

      {/* Top Header */}
      <header className="border-b border-slate-800 bg-slate-950/80 backdrop-blur sticky top-0 z-40">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 py-3.5 flex flex-wrap items-center justify-between gap-4">
          <div className="flex items-center gap-3">
            <div className="w-9 h-9 rounded-lg bg-indigo-600/20 border border-indigo-500/40 flex items-center justify-center text-indigo-400">
              <HardDrive className="w-5 h-5" />
            </div>
            <div>
              <div className="flex items-center gap-2">
                <h1 className="text-base font-bold text-white tracking-tight">Offline Billing Foundation</h1>
                <span className="px-2 py-0.5 rounded text-[11px] font-semibold bg-emerald-500/10 text-emerald-400 border border-emerald-500/30">
                  100% Local SQLite
                </span>
                <span className="px-2 py-0.5 rounded text-[11px] font-semibold bg-indigo-500/10 text-indigo-400 border border-indigo-500/30">
                  Desktop Ready
                </span>
              </div>
              <p className="text-xs text-slate-400">
                PONYTAIL / YAGNI • Strict 64-bit integer cents • SQLite3 local hard drive storage
              </p>
            </div>
          </div>

          {/* Navigation Tabs */}
          <div className="flex items-center gap-1.5 bg-slate-900 border border-slate-800 p-1 rounded-lg">
            <button
              onClick={() => setActiveTab('app')}
              className={`flex items-center gap-2 px-3.5 py-1.5 rounded-md text-xs font-semibold transition ${
                activeTab === 'app'
                  ? 'bg-indigo-600 text-white shadow-sm'
                  : 'text-slate-400 hover:text-slate-200 hover:bg-slate-800/60'
              }`}
            >
              <Monitor className="w-3.5 h-3.5" />
              Interactive App
            </button>
            <button
              onClick={() => setActiveTab('flutter_code')}
              className={`flex items-center gap-2 px-3.5 py-1.5 rounded-md text-xs font-semibold transition ${
                activeTab === 'flutter_code'
                  ? 'bg-indigo-600 text-white shadow-sm'
                  : 'text-slate-400 hover:text-slate-200 hover:bg-slate-800/60'
              }`}
            >
              <Code2 className="w-3.5 h-3.5" />
              Flutter Deliverables
            </button>
            <button
              onClick={() => setActiveTab('schema')}
              className={`flex items-center gap-2 px-3.5 py-1.5 rounded-md text-xs font-semibold transition ${
                activeTab === 'schema'
                  ? 'bg-indigo-600 text-white shadow-sm'
                  : 'text-slate-400 hover:text-slate-200 hover:bg-slate-800/60'
              }`}
            >
              <Database className="w-3.5 h-3.5" />
              SQLite Schema
            </button>
          </div>
        </div>
      </header>

      {/* Main Body */}
      <main className="flex-1 max-w-7xl mx-auto w-full px-4 sm:px-6 py-6">
        {activeTab === 'app' && (
          <div className="space-y-6">
            {/* Top row: Client Management Card */}
            <div className="bg-slate-950 border border-slate-800 rounded-xl p-5 shadow-sm">
              <div className="flex items-center justify-between mb-4 pb-3 border-b border-slate-800/80">
                <div className="flex items-center gap-2">
                  <Building2 className="w-4 h-4 text-indigo-400" />
                  <h2 className="text-sm font-bold text-slate-100 uppercase tracking-wider">1. Client Selection</h2>
                </div>
                <span className="text-xs text-slate-400">
                  {clients.length} client{clients.length === 1 ? '' : 's'} in SQLite
                </span>
              </div>

              <div className="grid grid-cols-1 lg:grid-cols-12 gap-4 items-end">
                {/* Add Client Form */}
                <form onSubmit={handleAddClient} className="lg:col-span-6 flex items-end gap-2">
                  <div className="flex-1">
                    <label htmlFor="new-client-name" className="block text-xs font-medium text-slate-400 mb-1.5">
                      New Client Name
                    </label>
                    <input
                      id="new-client-name"
                      type="text"
                      value={newClientName}
                      onChange={(e) => setNewClientName(e.target.value)}
                      placeholder="e.g. Acme Corporation"
                      className="w-full bg-slate-900 border border-slate-700/80 rounded-lg px-3 py-2 text-sm text-slate-100 placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
                    />
                  </div>
                  <button
                    type="submit"
                    className="inline-flex items-center gap-1.5 bg-slate-800 hover:bg-slate-700 text-slate-100 border border-slate-700 px-3.5 py-2 rounded-lg text-sm font-medium transition cursor-pointer"
                  >
                    <Plus className="w-4 h-4" />
                    Add Client
                  </button>
                </form>

                {/* Dropdown to pick client */}
                <div className="lg:col-span-6">
                  <label htmlFor="select-client" className="block text-xs font-medium text-slate-400 mb-1.5">
                    Select Saved Client
                  </label>
                  <select
                    id="select-client"
                    value={selectedClientId}
                    onChange={(e) => setSelectedClientId(e.target.value)}
                    className="w-full bg-slate-900 border border-slate-700/80 rounded-lg px-3 py-2 text-sm text-slate-100 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
                  >
                    <option value="">-- Choose a client from SQLite --</option>
                    {clients.map((c) => (
                      <option key={c.id} value={c.id}>
                        {c.name}
                      </option>
                    ))}
                  </select>
                </div>
              </div>
            </div>

            {/* Second row: Invoice Inputs Card */}
            <div className="bg-slate-950 border border-slate-800 rounded-xl p-5 shadow-sm">
              <div className="flex items-center justify-between mb-4 pb-3 border-b border-slate-800/80">
                <div className="flex items-center gap-2">
                  <FileText className="w-4 h-4 text-indigo-400" />
                  <h2 className="text-sm font-bold text-slate-100 uppercase tracking-wider">2. Invoice Inputs</h2>
                </div>
                <div className="text-xs text-indigo-400 font-mono">
                  Next Invoice #: <span className="font-bold">{formatNextInvoiceNumber(invoices.length)}</span>
                </div>
              </div>

              <form onSubmit={handleSaveInvoice} className="space-y-4">
                <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-12 gap-4">
                  <div className="lg:col-span-5">
                    <label htmlFor="item-desc" className="block text-xs font-medium text-slate-400 mb-1.5">
                      Item Description
                    </label>
                    <input
                      id="item-desc"
                      type="text"
                      value={itemDescription}
                      onChange={(e) => setItemDescription(e.target.value)}
                      placeholder="e.g. Consultation & Strategy"
                      className="w-full bg-slate-900 border border-slate-700/80 rounded-lg px-3 py-2 text-sm text-slate-100 placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-indigo-500"
                    />
                  </div>

                  <div className="lg:col-span-3">
                    <label htmlFor="item-price" className="block text-xs font-medium text-slate-400 mb-1.5">
                      Price ($)
                    </label>
                    <div className="relative">
                      <span className="absolute left-3 top-2 text-slate-500 text-sm">$</span>
                      <input
                        id="item-price"
                        type="text"
                        value={priceInput}
                        onChange={(e) => setPriceInput(e.target.value)}
                        placeholder="15.50"
                        className="w-full bg-slate-900 border border-slate-700/80 rounded-lg pl-7 pr-3 py-2 text-sm text-slate-100 placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-indigo-500"
                      />
                    </div>
                    <span className="text-[11px] text-slate-500 mt-1 block">
                      Parsed: {priceCents} integer cents
                    </span>
                  </div>

                  <div className="lg:col-span-2">
                    <label htmlFor="item-qty" className="block text-xs font-medium text-slate-400 mb-1.5">
                      Quantity
                    </label>
                    <input
                      id="item-qty"
                      type="number"
                      min="1"
                      value={quantityInput}
                      onChange={(e) => setQuantityInput(e.target.value)}
                      className="w-full bg-slate-900 border border-slate-700/80 rounded-lg px-3 py-2 text-sm text-slate-100 focus:outline-none focus:ring-2 focus:ring-indigo-500"
                    />
                  </div>

                  <div className="lg:col-span-2">
                    <label htmlFor="item-tax" className="block text-xs font-medium text-slate-400 mb-1.5">
                      Tax %
                    </label>
                    <div className="relative">
                      <input
                        id="item-tax"
                        type="number"
                        min="0"
                        max="100"
                        value={taxPctInput}
                        onChange={(e) => setTaxPctInput(e.target.value)}
                        className="w-full bg-slate-900 border border-slate-700/80 rounded-lg pr-7 pl-3 py-2 text-sm text-slate-100 focus:outline-none focus:ring-2 focus:ring-indigo-500"
                      />
                      <span className="absolute right-3 top-2 text-slate-500 text-sm">%</span>
                    </div>
                  </div>
                </div>

                {/* Calculation breakdown banner and commit button */}
                <div className="bg-slate-900 border border-slate-800 rounded-lg p-4 flex flex-col md:flex-row md:items-center justify-between gap-4 mt-2">
                  <div className="flex items-center gap-4 text-xs sm:text-sm">
                    <div className="flex items-center gap-1.5 text-slate-400">
                      <Calculator className="w-4 h-4 text-indigo-400" />
                      <span>Subtotal:</span>
                      <strong className="text-slate-200">{formatCents(calculation.subtotalCents)}</strong>
                    </div>
                    <span className="text-slate-600">+</span>
                    <div className="text-slate-400">
                      <span>Tax (Round-Half-Up):</span>{' '}
                      <strong className="text-slate-200">{formatCents(calculation.taxCents)}</strong>
                    </div>
                    <span className="text-slate-600">=</span>
                    <div className="text-indigo-400 text-base font-bold">
                      <span>Total: {formatCents(calculation.totalCents)}</span>
                    </div>
                  </div>

                  <button
                    type="submit"
                    className="inline-flex items-center justify-center gap-2 bg-indigo-600 hover:bg-indigo-500 text-white font-medium px-5 py-2.5 rounded-lg text-sm transition shadow-sm cursor-pointer"
                  >
                    <Save className="w-4 h-4" />
                    Save Invoice Locally
                  </button>
                </div>
              </form>
            </div>

            {/* Third row: Offline Invoices List */}
            <div className="bg-slate-950 border border-slate-800 rounded-xl p-5 shadow-sm">
              <div className="flex items-center justify-between mb-4 pb-3 border-b border-slate-800/80">
                <div className="flex items-center gap-2">
                  <HardDrive className="w-4 h-4 text-emerald-400" />
                  <h2 className="text-sm font-bold text-slate-100 uppercase tracking-wider">
                    Offline Invoices ({invoices.length})
                  </h2>
                </div>
                <div className="text-xs text-slate-400">
                  Total Value:{' '}
                  <span className="font-bold text-emerald-400">
                    {formatCents(invoices.reduce((acc, inv) => acc + inv.total_cents, 0))}
                  </span>
                </div>
              </div>

              {invoices.length === 0 ? (
                <div className="text-center py-12 border border-dashed border-slate-800 rounded-lg text-slate-500 text-sm">
                  No invoices saved in local SQLite yet. Add a client and click &quot;Save Invoice Locally&quot; above.
                </div>
              ) : (
                <div className="overflow-x-auto">
                  <table className="w-full text-left text-sm">
                    <thead>
                      <tr className="border-b border-slate-800 text-slate-400 text-xs uppercase tracking-wider">
                        <th className="pb-3 font-semibold">Invoice #</th>
                        <th className="pb-3 font-semibold">Client Name</th>
                        <th className="pb-3 font-semibold text-right">Subtotal</th>
                        <th className="pb-3 font-semibold text-right">Tax</th>
                        <th className="pb-3 font-semibold text-right">Total (Formatted)</th>
                        <th className="pb-3 font-semibold text-center">Status</th>
                        <th className="pb-3 font-semibold text-right">Created</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-slate-800/60">
                      {invoices.map((inv) => (
                        <tr key={inv.id} className="hover:bg-slate-900/50 transition">
                          <td className="py-3 font-mono font-bold text-indigo-400 text-xs">
                            <span className="bg-indigo-500/10 px-2 py-0.5 rounded border border-indigo-500/20">
                              {inv.invoice_number}
                            </span>
                          </td>
                          <td className="py-3 font-medium text-slate-200">{inv.client_name}</td>
                          <td className="py-3 text-right font-mono text-slate-400">{formatCents(inv.subtotal_cents)}</td>
                          <td className="py-3 text-right font-mono text-slate-400">{formatCents(inv.tax_cents)}</td>
                          <td className="py-3 text-right font-mono font-bold text-emerald-400">
                            {formatCents(inv.total_cents)}
                          </td>
                          <td className="py-3 text-center">
                            <span className="px-2 py-0.5 rounded text-[11px] font-semibold bg-emerald-500/10 text-emerald-400 border border-emerald-500/30">
                              {inv.status}
                            </span>
                          </td>
                          <td className="py-3 text-right text-xs text-slate-500 font-mono">
                            {new Date(inv.created_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </div>
          </div>
        )}

        {/* Deliverables Tab */}
        {activeTab === 'flutter_code' && (
          <div className="space-y-6">
            <div className="bg-slate-950 border border-slate-800 rounded-xl p-5 shadow-sm">
              <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-4 border-b border-slate-800">
                <div>
                  <h2 className="text-base font-bold text-white">Deliverables: Complete Flutter Desktop Code</h2>
                  <p className="text-xs text-slate-400 mt-0.5">
                    Minimal, single-file <code className="text-indigo-300">lib/main.dart</code> and <code className="text-indigo-300">pubspec.yaml</code>. 
                    Uses <code className="text-indigo-300">sqlite3</code>, <code className="text-indigo-300">sqlite3_flutter_libs</code>, and <code className="text-indigo-300">flutter_riverpod</code>.
                  </p>
                </div>

                <div className="flex items-center gap-2">
                  <div className="flex bg-slate-900 border border-slate-800 p-1 rounded-lg">
                    <button
                      onClick={() => setCodeSubTab('main')}
                      className={`px-3 py-1 text-xs font-semibold rounded ${
                        codeSubTab === 'main' ? 'bg-indigo-600 text-white' : 'text-slate-400 hover:text-white'
                      }`}
                    >
                      lib/main.dart
                    </button>
                    <button
                      onClick={() => setCodeSubTab('pubspec')}
                      className={`px-3 py-1 text-xs font-semibold rounded ${
                        codeSubTab === 'pubspec' ? 'bg-indigo-600 text-white' : 'text-slate-400 hover:text-white'
                      }`}
                    >
                      pubspec.yaml
                    </button>
                  </div>

                  <button
                    onClick={() => {
                      const text = codeSubTab === 'main' ? (mainDartContent || DART_MAIN_PREVIEW) : PUBSPEC_CONTENT;
                      const filename = codeSubTab === 'main' ? 'main.dart' : 'pubspec.yaml';
                      handleDownload(filename, text);
                    }}
                    className="inline-flex items-center gap-1.5 bg-slate-800 hover:bg-slate-700 text-slate-200 px-3 py-1.5 rounded-lg text-xs font-medium border border-slate-700 cursor-pointer"
                  >
                    <Download className="w-3.5 h-3.5" />
                    Download
                  </button>

                  <button
                    onClick={() => {
                      const text = codeSubTab === 'main' ? (mainDartContent || DART_MAIN_PREVIEW) : PUBSPEC_CONTENT;
                      handleCopy(text, codeSubTab === 'main' ? 'lib/main.dart' : 'pubspec.yaml');
                    }}
                    className="inline-flex items-center gap-1.5 bg-indigo-600 hover:bg-indigo-500 text-white px-3 py-1.5 rounded-lg text-xs font-medium cursor-pointer"
                  >
                    {copiedKey ? <Check className="w-3.5 h-3.5" /> : <Copy className="w-3.5 h-3.5" />}
                    Copy Code
                  </button>
                </div>
              </div>

              {/* Code display */}
              <div className="mt-4">
                <div className="bg-slate-900 border border-slate-800 rounded-lg p-4 font-mono text-xs overflow-x-auto text-slate-200 max-h-[600px] leading-relaxed">
                  <pre>
                    {codeSubTab === 'main' ? (mainDartContent || DART_MAIN_PREVIEW) : PUBSPEC_CONTENT}
                  </pre>
                </div>
              </div>

              {/* Run Instructions */}
              <div className="mt-6 p-4 rounded-lg bg-indigo-950/30 border border-indigo-800/40 text-xs space-y-2 text-slate-300">
                <h4 className="font-semibold text-indigo-300 uppercase tracking-wider text-[11px]">How to Run Offline on Your Computer</h4>
                <ol className="list-decimal list-inside space-y-1 text-slate-400">
                  <li>Create a new Flutter project: <code className="text-slate-200">flutter create --platforms=windows,macos billing_app</code></li>
                  <li>Replace your <code className="text-slate-200">pubspec.yaml</code> and <code className="text-slate-200">lib/main.dart</code> with the deliverables above.</li>
                  <li>Run <code className="text-slate-200">flutter pub get</code> to install dependencies.</li>
                  <li>Run offline on Windows: <code className="text-slate-200">flutter run -d windows</code> or on macOS: <code className="text-slate-200">flutter run -d macos</code>.</li>
                  <li>The app connects directly to <code className="text-slate-200">billing_local.db</code> in the local application documents directory with zero cloud calls.</li>
                </ol>
              </div>
            </div>
          </div>
        )}

        {/* Schema Tab */}
        {activeTab === 'schema' && (
          <div className="space-y-6">
            <div className="bg-slate-950 border border-slate-800 rounded-xl p-5 shadow-sm">
              <div className="flex items-center justify-between pb-4 border-b border-slate-800">
                <div>
                  <h2 className="text-base font-bold text-white">Local SQLite Database Specifications</h2>
                  <p className="text-xs text-slate-400 mt-0.5">
                    File: <code className="text-indigo-300">billing_local.db</code> located in <code className="text-indigo-300">getApplicationDocumentsDirectory()</code>
                  </p>
                </div>
                <button
                  onClick={() => {
                    localStorage.removeItem('sqlite_clients');
                    localStorage.removeItem('sqlite_invoices');
                    setClients([]);
                    setInvoices([]);
                    showToast('Local database cleared!');
                  }}
                  className="inline-flex items-center gap-1.5 text-xs text-rose-400 hover:text-rose-300 bg-rose-500/10 hover:bg-rose-500/20 border border-rose-500/30 px-3 py-1.5 rounded-lg cursor-pointer transition"
                >
                  <RefreshCw className="w-3.5 h-3.5" />
                  Reset / Clear DB
                </button>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mt-5">
                {/* Clients Table */}
                <div className="bg-slate-900 border border-slate-800 rounded-lg p-4">
                  <h3 className="text-sm font-bold text-indigo-400 font-mono mb-2">TABLE clients</h3>
                  <div className="bg-slate-950 p-3 rounded font-mono text-xs text-slate-300 overflow-x-auto">
                    <pre>{`CREATE TABLE IF NOT EXISTS clients (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  created_at TEXT NOT NULL
);`}</pre>
                  </div>
                  <div className="mt-3 text-xs text-slate-400">
                    Stores client master records with ISO8601 timestamps.
                  </div>
                </div>

                {/* Invoices Table */}
                <div className="bg-slate-900 border border-slate-800 rounded-lg p-4">
                  <h3 className="text-sm font-bold text-indigo-400 font-mono mb-2">TABLE invoices</h3>
                  <div className="bg-slate-950 p-3 rounded font-mono text-xs text-slate-300 overflow-x-auto">
                    <pre>{`CREATE TABLE IF NOT EXISTS invoices (
  id TEXT PRIMARY KEY,
  client_id TEXT NOT NULL,
  invoice_number TEXT NOT NULL UNIQUE,
  subtotal_cents INTEGER NOT NULL,
  tax_cents INTEGER NOT NULL,
  total_cents INTEGER NOT NULL,
  status TEXT NOT NULL,
  created_at TEXT NOT NULL,
  FOREIGN KEY (client_id) REFERENCES clients (id)
);`}</pre>
                  </div>
                  <div className="mt-3 text-xs text-slate-400">
                    All monetary amounts are strictly 64-bit integers in minor units (cents).
                  </div>
                </div>
              </div>

              {/* Financial Integrity Guarantees */}
              <div className="mt-6 border-t border-slate-800 pt-5 space-y-3">
                <h4 className="text-xs font-bold text-slate-300 uppercase tracking-wider">Financial Integrity Rules Implemented</h4>
                <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 text-xs">
                  <div className="bg-slate-900 p-3 rounded-lg border border-slate-800">
                    <div className="font-semibold text-emerald-400 mb-1">1. Zero Float Math</div>
                    <p className="text-slate-400">Every calculation uses exact integer multiplication and division. No IEEE-754 double floating point precision drift.</p>
                  </div>
                  <div className="bg-slate-900 p-3 rounded-lg border border-slate-800">
                    <div className="font-semibold text-emerald-400 mb-1">2. Integer Round-Half-Up</div>
                    <p className="text-slate-400">Tax is calculated strictly with integer round-half-up: <code className="text-slate-300">(subtotal * tax + 50) ~/ 100</code>.</p>
                  </div>
                  <div className="bg-slate-900 p-3 rounded-lg border border-slate-800">
                    <div className="font-semibold text-emerald-400 mb-1">3. Sequential Invoices</div>
                    <p className="text-slate-400">Zero-padded sequential formatting starting at <code className="text-slate-300">INV-0001</code> based on SQLite row count.</p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}
      </main>
    </div>
  );
}
