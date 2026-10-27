import fs from 'node:fs';
import path from 'node:path';

const appPath = path.resolve('src/App.tsx');
let content = fs.readFileSync(appPath, 'utf8');

// 1. Insert payments state and helper methods
const stateAnchor = `  const [invoiceItems, setInvoiceItems] = useState<StoredInvoiceItem[]>(() => {`;
const paymentStateCode = `  // Sprint 3: Payments state backed by local storage mimicking SQLite payments table
  const [payments, setPayments] = useState<StoredPayment[]>(() => {
    try {
      const saved = localStorage.getItem('sqlite_payments_sprint3');
      if (saved) return JSON.parse(saved);
    } catch {
      // fallback
    }
    return [
      {
        id: '1714000000000-401',
        invoice_id: '1714000000000-201',
        amount_cents: 24750, // $247.50 (Paid in full)
        payment_method: 'Bank Wire',
        payment_date: '2026-10-02',
        notes: 'Wire Ref #BW-88219',
        created_at: '2026-10-02T12:00:00Z',
      },
    ];
  });

  useEffect(() => {
    try {
      localStorage.setItem('sqlite_payments_sprint3', JSON.stringify(payments));
    } catch (_) {}
  }, [payments]);

  // Payment Recording Modal State (Sprint 3)
  const [isRecordPaymentOpen, setIsRecordPaymentOpen] = useState(false);
  const [paymentTargetInvoice, setPaymentTargetInvoice] = useState<InvoiceRecord | null>(null);
  const [paymentAmountInput, setPaymentAmountInput] = useState('');
  const [paymentMethod, setPaymentMethod] = useState('Bank Wire');
  const [paymentDate, setPaymentDate] = useState(new Date().toISOString().split('T')[0]);
  const [paymentNotes, setPaymentNotes] = useState('');
  const [paymentError, setPaymentError] = useState<string | null>(null);

  const getInvoicePayments = (invId: string) => {
    return payments
      .filter((p) => p.invoice_id === invId)
      .sort((a, b) => b.payment_date.localeCompare(a.payment_date));
  };

  const getInvoicePaidCents = (invId: string) => {
    return payments
      .filter((p) => p.invoice_id === invId)
      .reduce((sum, p) => sum + p.amount_cents, 0);
  };

  const getInvoiceBalanceDueCents = (inv: InvoiceRecord) => {
    const paid = getInvoicePaidCents(inv.id);
    return Math.max(0, inv.total_cents - paid);
  };

  const openRecordPaymentModal = (inv: InvoiceRecord) => {
    setPaymentTargetInvoice(inv);
    const balance = getInvoiceBalanceDueCents(inv);
    setPaymentAmountInput((balance / 100).toFixed(2));
    setPaymentMethod('Bank Wire');
    setPaymentDate(new Date().toISOString().split('T')[0]);
    setPaymentNotes('');
    setPaymentError(null);
    setIsRecordPaymentOpen(true);
  };

  const handleSavePayment = (e: React.FormEvent) => {
    e.preventDefault();
    if (!paymentTargetInvoice) return;

    const amountCents = parsePriceToCents(paymentAmountInput);
    if (amountCents <= 0) {
      setPaymentError('Payment amount must be greater than $0.00');
      return;
    }

    const currentBalance = getInvoiceBalanceDueCents(paymentTargetInvoice);
    if (amountCents > currentBalance) {
      setPaymentError(\`Amount cannot exceed remaining balance of \${formatCents(currentBalance)}\`);
      return;
    }

    const newPayment: StoredPayment = {
      id: generateUniqueId(),
      invoice_id: paymentTargetInvoice.id,
      amount_cents: amountCents,
      payment_method: paymentMethod,
      payment_date: paymentDate || new Date().toISOString().split('T')[0],
      notes: paymentNotes.trim(),
      created_at: new Date().toISOString(),
    };

    const updatedPayments = [...payments, newPayment];
    setPayments(updatedPayments);

    const newPaidTotal = getInvoicePaidCents(paymentTargetInvoice.id) + amountCents;
    if (newPaidTotal >= paymentTargetInvoice.total_cents) {
      setInvoices((prev) =>
        prev.map((i) => (i.id === paymentTargetInvoice.id ? { ...i, status: 'PAID' } : i))
      );
    }

    setIsRecordPaymentOpen(false);
    showToast(
      \`Recorded payment of \${formatCents(amountCents)} for \${paymentTargetInvoice.invoice_number}!\`
    );
  };

`;

if (!content.includes('const [payments, setPayments]')) {
  if (content.includes(stateAnchor)) {
    content = content.replace(stateAnchor, paymentStateCode + stateAnchor);
    console.log('Payment state inserted successfully!');
  } else {
    console.error('Could not find stateAnchor!');
  }
}

// 2. Replace the invoice card loop start
const oldCardMarkup = `                  {invoices.map((inv) => {
                    const isExpanded = expandedInvoiceIds.has(inv.id);
                    const items = invoiceItems.filter((item) => item.invoice_id === inv.id);
                    const isPaid = inv.status.toUpperCase() === 'PAID';
                    const isOverdue = isInvoiceOverdue(inv.status, inv.due_date);
                    const daysLate = calculateDaysOverdue(inv.due_date);`;

const newCardMarkup = `                  {invoices.map((inv) => {
                    const isExpanded = expandedInvoiceIds.has(inv.id);
                    const items = invoiceItems.filter((item) => item.invoice_id === inv.id);
                    const invPayments = getInvoicePayments(inv.id);
                    const paidCents = getInvoicePaidCents(inv.id);
                    const balanceDueCents = getInvoiceBalanceDueCents(inv);
                    const isFullyPaid = paidCents >= inv.total_cents || inv.status.toUpperCase() === 'PAID';
                    const isPartial = paidCents > 0 && !isFullyPaid;
                    const isOverdue = !isFullyPaid && isInvoiceOverdue(inv.status, inv.due_date);
                    const daysLate = calculateDaysOverdue(inv.due_date);`;

if (!content.includes('const isFullyPaid = paidCents >= inv.total_cents')) {
  if (content.includes(oldCardMarkup)) {
    content = content.replace(oldCardMarkup, newCardMarkup);
    console.log('Card markup replaced successfully!');
  } else {
    console.error('Could not find oldCardMarkup!');
  }
}

// 3. Status Badge
const oldBadge = `                                {/* Overdue / Paid / Due Date Badge */}
                                {isPaid ? (
                                  <span className="px-2 py-0.5 rounded text-[10px] font-bold bg-emerald-500/10 text-emerald-400 border border-emerald-500/30">
                                    PAID
                                  </span>
                                ) : isOverdue ? (
                                  <span className="px-2 py-0.5 rounded text-[10px] font-bold bg-rose-500/20 text-rose-300 border border-rose-500/40 flex items-center gap-1">
                                    <AlertTriangle className="w-3 h-3" />
                                    OVERDUE ({daysLate}d late)
                                  </span>
                                ) : (
                                  <span className="px-2 py-0.5 rounded text-[10px] font-medium bg-amber-500/10 text-amber-300 border border-amber-500/30">
                                    Due: {inv.due_date} ({inv.payment_terms})
                                  </span>
                                )}`;

const newBadge = `                                {/* Sprint 3 Status Badge: PAID / PARTIAL / OVERDUE / PENDING */}
                                {isFullyPaid ? (
                                  <span className="px-2 py-0.5 rounded text-[10px] font-bold bg-emerald-500/10 text-emerald-400 border border-emerald-500/30">
                                    PAID
                                  </span>
                                ) : isPartial ? (
                                  <span className="px-2 py-0.5 rounded text-[10px] font-bold bg-amber-500/10 text-amber-300 border border-amber-500/30">
                                    PARTIAL ({formatCents(paidCents)} / {formatCents(inv.total_cents)})
                                  </span>
                                ) : isOverdue ? (
                                  <span className="px-2 py-0.5 rounded text-[10px] font-bold bg-rose-500/20 text-rose-300 border border-rose-500/40 flex items-center gap-1">
                                    <AlertTriangle className="w-3 h-3" />
                                    OVERDUE ({daysLate}d late)
                                  </span>
                                ) : (
                                  <span className="px-2 py-0.5 rounded text-[10px] font-medium bg-slate-800 text-slate-300 border border-slate-700">
                                    Due: {inv.due_date} ({inv.payment_terms})
                                  </span>
                                )}`;

if (content.includes(oldBadge)) {
  content = content.replace(oldBadge, newBadge);
  console.log('Badge replaced successfully!');
}

// 4. Subtitle
const oldSubtitle = `<p className="text-xs text-slate-400 mt-0.5">
                                Terms: {inv.payment_terms} • Issue: {inv.issue_date || inv.created_at.split('T')[0]} • Subtotal: {formatCents(inv.subtotal_cents)} • Tax: {formatCents(inv.tax_cents)} • {items.length} item{items.length === 1 ? '' : 's'}
                              </p>`;

const newSubtitle = `<p className="text-xs text-slate-400 mt-0.5">
                                Terms: {inv.payment_terms} • Issue: {inv.issue_date || inv.created_at.split('T')[0]} • Total: {formatCents(inv.total_cents)}{balanceDueCents > 0 ? \` • Due: \${formatCents(balanceDueCents)}\` : ''} • {items.length} item{items.length === 1 ? '' : 's'}
                              </p>`;

if (content.includes(oldSubtitle)) {
  content = content.replace(oldSubtitle, newSubtitle);
  console.log('Subtitle replaced successfully!');
}

// 5. Card Trailing Total and Buttons
const oldTrailing = `                          <div className="flex items-center gap-3 ml-auto">
                            <span className={\`text-base font-bold font-mono \${isOverdue ? 'text-rose-400' : 'text-emerald-400'}\`}>
                              {formatCents(inv.total_cents)}
                            </span>

                            {/* Status toggle button */}
                            <button
                              type="button"
                              onClick={(e) => {
                                e.stopPropagation();
                                handleToggleInvoiceStatus(inv.id);
                              }}
                              className={\`px-2.5 py-1 rounded text-xs font-semibold border transition cursor-pointer flex items-center gap-1.5 \${
                                isPaid
                                  ? 'bg-emerald-500/10 hover:bg-emerald-500/20 text-emerald-300 border-emerald-500/30'
                                  : 'bg-slate-800 hover:bg-slate-700 text-slate-300 border-slate-700'
                              }\`}
                              title={isPaid ? 'Mark as Pending / Unpaid' : 'Mark as Paid'}
                            >
                              <CheckCircle className={\`w-3.5 h-3.5 \${isPaid ? 'text-emerald-400' : 'text-slate-400'}\`} />
                              <span>{isPaid ? 'Paid' : 'Mark Paid'}</span>
                            </button>

                            {/* PROMINENT, DIRECTLY ACCESSIBLE PDF / PRINT BUTTON */}
                            <button
                              type="button"
                              onClick={(e) => {
                                e.stopPropagation();
                                setPreviewInvoice({ invoice: inv, items });
                              }}
                              className="inline-flex items-center gap-1.5 px-3.5 py-1.5 rounded-lg text-xs font-bold bg-indigo-600 hover:bg-indigo-500 text-white shadow-md shadow-indigo-600/30 transition cursor-pointer shrink-0"
                              title="View & Print A4 PDF Invoice"
                            >
                              <Printer className="w-3.5 h-3.5" />
                              <span>PDF / Print</span>
                            </button>

                            <div className="text-slate-400">
                              {isExpanded ? <ChevronUp className="w-4 h-4" /> : <ChevronDown className="w-4 h-4" />}
                            </div>
                          </div>`;

const newTrailing = `                          <div className="flex items-center gap-3 ml-auto">
                            <div className="text-right">
                              <span className={\`text-base font-bold font-mono block \${isFullyPaid ? 'text-emerald-400' : isOverdue ? 'text-rose-400' : 'text-slate-200'}\`}>
                                {formatCents(inv.total_cents)}
                              </span>
                              {balanceDueCents > 0 && (
                                <span className="text-[11px] font-bold font-mono text-indigo-400 block">
                                  Due: {formatCents(balanceDueCents)}
                                </span>
                              )}
                            </div>

                            {/* Record Payment Button (Sprint 3) */}
                            {balanceDueCents > 0 && (
                              <button
                                type="button"
                                onClick={(e) => {
                                  e.stopPropagation();
                                  openRecordPaymentModal(inv);
                                }}
                                className="inline-flex items-center gap-1.5 px-2.5 py-1.5 rounded-lg text-xs font-bold bg-emerald-600/20 hover:bg-emerald-600/30 text-emerald-300 border border-emerald-500/40 transition cursor-pointer shrink-0"
                                title="Record a Partial or Full Payment"
                              >
                                <CreditCard className="w-3.5 h-3.5 text-emerald-400" />
                                <span>Pay</span>
                              </button>
                            )}

                            {/* PROMINENT, DIRECTLY ACCESSIBLE PDF / PRINT BUTTON */}
                            <button
                              type="button"
                              onClick={(e) => {
                                e.stopPropagation();
                                setPreviewInvoice({ invoice: inv, items });
                              }}
                              className="inline-flex items-center gap-1.5 px-3.5 py-1.5 rounded-lg text-xs font-bold bg-indigo-600 hover:bg-indigo-500 text-white shadow-md shadow-indigo-600/30 transition cursor-pointer shrink-0"
                              title="View & Print A4 PDF Invoice"
                            >
                              <Printer className="w-3.5 h-3.5" />
                              <span>PDF / Print</span>
                            </button>

                            <div className="text-slate-400">
                              {isExpanded ? <ChevronUp className="w-4 h-4" /> : <ChevronDown className="w-4 h-4" />}
                            </div>
                          </div>`;

if (content.includes(oldTrailing)) {
  content = content.replace(oldTrailing, newTrailing);
  console.log('Trailing replaced successfully!');
}

// 6. Expandable section
const oldExpanded = `                        {/* Expandable Line Items View */}
                        {isExpanded && (
                          <div className="border-t border-slate-800/80 bg-slate-950/60 p-4">
                            <div className="flex items-center justify-between mb-2">
                              <h4 className="text-xs font-bold text-slate-300 uppercase tracking-wider">
                                Line Items Breakdown ({inv.payment_terms} • Due: {inv.due_date}):
                              </h4>
                              <button
                                type="button"
                                onClick={() => setPreviewInvoice({ invoice: inv, items })}
                                className="text-xs font-medium text-indigo-400 hover:text-indigo-300 flex items-center gap-1 cursor-pointer"
                              >
                                <Printer className="w-3 h-3" />
                                <span>Open Full A4 Document</span>
                              </button>
                            </div>
                            <div className="divide-y divide-slate-800/40">
                              {items.map((item) => (
                                <div key={item.id} className="py-2 flex items-center justify-between text-xs">
                                  <div className="flex-1 pr-4">
                                    <span className="text-slate-200 font-medium">• {item.description}</span>
                                    <span className="text-slate-500 ml-2">
                                      ({item.quantity} × {formatCents(item.unit_price_cents)})
                                    </span>
                                  </div>
                                  <span className="font-mono font-semibold text-slate-300">
                                    {formatCents(item.total_cents)}
                                  </span>
                                </div>
                              ))}
                            </div>
                          </div>
                        )}`;

const newExpanded = `                        {/* Expandable Line Items & Payments View (Sprint 3) */}
                        {isExpanded && (
                          <div className="border-t border-slate-800/80 bg-slate-950/60 p-4 space-y-4">
                            <div>
                              <div className="flex items-center justify-between mb-2">
                                <h4 className="text-xs font-bold text-slate-300 uppercase tracking-wider">
                                  Line Items Breakdown ({inv.payment_terms} • Due: {inv.due_date}):
                                </h4>
                                <div className="flex items-center gap-2">
                                  {balanceDueCents > 0 && (
                                    <button
                                      type="button"
                                      onClick={() => openRecordPaymentModal(inv)}
                                      className="text-xs font-semibold text-emerald-400 hover:text-emerald-300 flex items-center gap-1 cursor-pointer"
                                    >
                                      <CreditCard className="w-3.5 h-3.5" />
                                      <span>Record Payment</span>
                                    </button>
                                  )}
                                  <button
                                    type="button"
                                    onClick={() => setPreviewInvoice({ invoice: inv, items })}
                                    className="text-xs font-medium text-indigo-400 hover:text-indigo-300 flex items-center gap-1 cursor-pointer ml-2"
                                  >
                                    <Printer className="w-3.5 h-3.5" />
                                    <span>Print A4 Invoice</span>
                                  </button>
                                </div>
                              </div>
                              <div className="divide-y divide-slate-800/40">
                                {items.map((item) => (
                                  <div key={item.id} className="py-2 flex items-center justify-between text-xs">
                                    <div className="flex-1 pr-4">
                                      <span className="text-slate-200 font-medium">• {item.description}</span>
                                      <span className="text-slate-500 ml-2">
                                        ({item.quantity} × {formatCents(item.unit_price_cents)})
                                      </span>
                                    </div>
                                    <span className="font-mono font-semibold text-slate-300">
                                      {formatCents(item.total_cents)}
                                    </span>
                                  </div>
                                ))}
                              </div>
                            </div>

                            {/* Payments Received History Section (Sprint 3) */}
                            {invPayments.length > 0 && (
                              <div className="border-t border-slate-800/60 pt-3">
                                <h4 className="text-xs font-bold text-emerald-400 uppercase tracking-wider mb-2 flex items-center gap-1.5">
                                  <Receipt className="w-3.5 h-3.5" />
                                  <span>Payments Received ({invPayments.length}):</span>
                                </h4>
                                <div className="bg-slate-900/60 border border-slate-800 rounded-lg p-2.5 divide-y divide-slate-800/40">
                                  {invPayments.map((p) => (
                                    <div key={p.id} className="py-1.5 flex items-center justify-between text-xs">
                                      <div>
                                        <span className="font-medium text-emerald-300">{p.payment_date}</span>
                                        <span className="text-slate-400 ml-2">• {p.payment_method}</span>
                                        {p.notes && <span className="text-slate-500 ml-2">({p.notes})</span>}
                                      </div>
                                      <span className="font-mono font-bold text-emerald-400">
                                        {formatCents(p.amount_cents)}
                                      </span>
                                    </div>
                                  ))}
                                </div>
                              </div>
                            )}

                            {/* Balance Due & Financial Summary */}
                            <div className="border-t border-slate-800/60 pt-3 flex justify-end">
                              <div className="w-64 space-y-1 text-xs">
                                <div className="flex justify-between text-slate-400">
                                  <span>Subtotal:</span>
                                  <span className="font-mono">{formatCents(inv.subtotal_cents)}</span>
                                </div>
                                <div className="flex justify-between text-slate-400">
                                  <span>Tax:</span>
                                  <span className="font-mono">{formatCents(inv.tax_cents)}</span>
                                </div>
                                <div className="flex justify-between text-slate-200 font-semibold border-t border-slate-800 pt-1">
                                  <span>Total:</span>
                                  <span className="font-mono">{formatCents(inv.total_cents)}</span>
                                </div>
                                {paidCents > 0 && (
                                  <div className="flex justify-between text-emerald-400 font-medium">
                                    <span>Less Payments Received:</span>
                                    <span className="font-mono">-{formatCents(paidCents)}</span>
                                  </div>
                                )}
                                <div className={\`flex justify-between font-bold p-2 rounded \${balanceDueCents === 0 ? 'bg-emerald-500/10 text-emerald-300 border border-emerald-500/30' : 'bg-indigo-500/10 text-indigo-300 border border-indigo-500/30'}\`}>
                                  <span>Remaining Balance Due:</span>
                                  <span className="font-mono">{formatCents(balanceDueCents)}</span>
                                </div>
                              </div>
                            </div>
                          </div>
                        )}`;

if (content.includes(oldExpanded)) {
  content = content.replace(oldExpanded, newExpanded);
  console.log('Expanded replaced successfully!');
}

// 7. Modal
const modalTarget = `      {/* Business Profile Settings Modal */}`;
const recordPaymentModalCode = `      {/* Record Payment Modal (Sprint 3) */}
      {isRecordPaymentOpen && paymentTargetInvoice && (
        <div className="fixed inset-0 z-50 bg-black/75 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="bg-slate-950 border border-slate-800 rounded-2xl w-full max-w-md overflow-hidden shadow-2xl flex flex-col">
            <div className="p-4 border-b border-slate-800 flex items-center justify-between">
              <div>
                <h3 className="font-bold text-sm text-slate-100 flex items-center gap-2">
                  <CreditCard className="w-4 h-4 text-emerald-400" />
                  <span>Record Payment: {paymentTargetInvoice.invoice_number}</span>
                </h3>
                <p className="text-xs text-slate-400 mt-0.5">{paymentTargetInvoice.client_name}</p>
              </div>
              <button
                type="button"
                onClick={() => setIsRecordPaymentOpen(false)}
                className="p-1.5 text-slate-400 hover:text-slate-200 hover:bg-slate-900 rounded-lg cursor-pointer"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            <form onSubmit={handleSavePayment} className="p-4 space-y-4">
              {/* Balances summary */}
              <div className="bg-slate-900/60 border border-slate-800 rounded-lg p-3 grid grid-cols-3 gap-2 text-center">
                <div>
                  <span className="text-[10px] text-slate-400 block font-semibold uppercase">Total</span>
                  <span className="text-xs font-bold text-slate-200 font-mono">
                    {formatCents(paymentTargetInvoice.total_cents)}
                  </span>
                </div>
                <div>
                  <span className="text-[10px] text-slate-400 block font-semibold uppercase">Paid</span>
                  <span className="text-xs font-bold text-emerald-400 font-mono">
                    {formatCents(getInvoicePaidCents(paymentTargetInvoice.id))}
                  </span>
                </div>
                <div>
                  <span className="text-[10px] text-slate-400 block font-semibold uppercase">Balance Due</span>
                  <span className="text-xs font-bold text-indigo-400 font-mono">
                    {formatCents(getInvoiceBalanceDueCents(paymentTargetInvoice))}
                  </span>
                </div>
              </div>

              {/* Quick Preset Buttons */}
              <div>
                <label className="block text-xs font-semibold text-slate-400 mb-1.5">
                  Quick Amount Presets
                </label>
                <div className="flex gap-2">
                  <button
                    type="button"
                    onClick={() => {
                      const bal = getInvoiceBalanceDueCents(paymentTargetInvoice);
                      setPaymentAmountInput((bal / 100).toFixed(2));
                      setPaymentError(null);
                    }}
                    className="flex-1 py-1.5 px-2 bg-slate-900 hover:bg-slate-800 text-slate-300 border border-slate-700 rounded-lg text-xs font-medium cursor-pointer"
                  >
                    Full ({formatCents(getInvoiceBalanceDueCents(paymentTargetInvoice))})
                  </button>
                  <button
                    type="button"
                    onClick={() => {
                      const bal = getInvoiceBalanceDueCents(paymentTargetInvoice);
                      const deposit = Math.round(bal / 2);
                      setPaymentAmountInput((deposit / 100).toFixed(2));
                      setPaymentError(null);
                    }}
                    className="flex-1 py-1.5 px-2 bg-slate-900 hover:bg-slate-800 text-slate-300 border border-slate-700 rounded-lg text-xs font-medium cursor-pointer"
                  >
                    50% Deposit ({formatCents(Math.round(getInvoiceBalanceDueCents(paymentTargetInvoice) / 2))})
                  </button>
                </div>
              </div>

              {/* Amount Input */}
              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-1">
                  Payment Amount ($ USD) *
                </label>
                <div className="relative">
                  <span className="absolute left-3 top-2.5 text-slate-500 font-mono">$</span>
                  <input
                    type="number"
                    step="0.01"
                    required
                    value={paymentAmountInput}
                    onChange={(e) => {
                      setPaymentAmountInput(e.target.value);
                      setPaymentError(null);
                    }}
                    className="w-full bg-slate-900 border border-slate-700 rounded-lg pl-8 pr-3 py-2 text-sm text-slate-100 font-mono focus:outline-none focus:ring-2 focus:ring-emerald-500"
                    placeholder="0.00"
                  />
                </div>
                {paymentError && (
                  <p className="text-xs text-rose-400 mt-1 font-medium">{paymentError}</p>
                )}
              </div>

              {/* Payment Method */}
              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-1">
                  Payment Method *
                </label>
                <select
                  value={paymentMethod}
                  onChange={(e) => setPaymentMethod(e.target.value)}
                  className="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-2 text-sm text-slate-100 focus:outline-none focus:ring-2 focus:ring-emerald-500"
                >
                  <option value="Bank Wire">Bank Wire</option>
                  <option value="Credit Card">Credit Card</option>
                  <option value="Cash">Cash</option>
                  <option value="UPI / PayPal">UPI / PayPal</option>
                  <option value="Check">Check</option>
                </select>
              </div>

              {/* Payment Date */}
              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-1">
                  Payment Date
                </label>
                <input
                  type="date"
                  value={paymentDate}
                  onChange={(e) => setPaymentDate(e.target.value)}
                  className="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-2 text-sm text-slate-100 focus:outline-none focus:ring-2 focus:ring-emerald-500"
                />
              </div>

              {/* Notes / Reference */}
              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-1">
                  Reference / Notes (Optional)
                </label>
                <input
                  type="text"
                  placeholder="e.g., Wire ref #TX-9021, Check #104"
                  value={paymentNotes}
                  onChange={(e) => setPaymentNotes(e.target.value)}
                  className="w-full bg-slate-900 border border-slate-700 rounded-lg px-3 py-2 text-sm text-slate-100 focus:outline-none focus:ring-2 focus:ring-emerald-500"
                />
              </div>

              <div className="pt-2 flex justify-end gap-2 border-t border-slate-800">
                <button
                  type="button"
                  onClick={() => setIsRecordPaymentOpen(false)}
                  className="px-4 py-2 rounded-lg text-xs font-semibold bg-slate-900 hover:bg-slate-800 text-slate-300 border border-slate-700 cursor-pointer"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-4 py-2 rounded-lg text-xs font-bold bg-emerald-600 hover:bg-emerald-500 text-white shadow-md shadow-emerald-600/30 transition cursor-pointer flex items-center gap-1.5"
                >
                  <CheckCircle className="w-4 h-4" />
                  <span>Save Payment</span>
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
`;

if (content.includes(modalTarget) && !content.includes('Record Payment Modal (Sprint 3)')) {
  content = content.replace(modalTarget, recordPaymentModalCode + modalTarget);
  console.log('Modal added successfully!');
}

// 8. SQLite Schema
const schemaTarget = `                {/* Business Profile Table */}`;
const paymentsSchemaCode = `                {/* Payments Table (Sprint 3) */}
                <div className="border border-slate-800 rounded-lg p-4 bg-slate-900/30">
                  <div className="flex items-center justify-between mb-3">
                    <span className="font-mono font-bold text-xs text-indigo-400">TABLE payments</span>
                    <span className="text-[10px] text-emerald-400 font-semibold bg-emerald-500/10 px-2 py-0.5 rounded border border-emerald-500/30">
                      Sprint 3 Partial Payments
                    </span>
                  </div>
                  <pre className="text-[11px] font-mono text-slate-300 bg-slate-950 p-3 rounded border border-slate-800">{\`CREATE TABLE IF NOT EXISTS payments (
  id TEXT PRIMARY KEY,
  invoice_id TEXT NOT NULL,
  amount_cents INTEGER NOT NULL,
  payment_method TEXT NOT NULL,
  payment_date TEXT NOT NULL,
  notes TEXT DEFAULT '',
  created_at TEXT NOT NULL,
  FOREIGN KEY (invoice_id) REFERENCES invoices (id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_payments_invoice_id ON payments (invoice_id);\`}</pre>
                </div>

`;

if (content.includes(schemaTarget) && !content.includes('TABLE payments')) {
  content = content.replace(schemaTarget, paymentsSchemaCode + schemaTarget);
  console.log('Schema added successfully!');
}

fs.writeFileSync(appPath, content, 'utf8');
console.log('SUCCESSFULLY APPLIED SPRINT 3 TO App.tsx!');
