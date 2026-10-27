import fs from 'node:fs';
import path from 'node:path';

const appPath = path.resolve('src/App.tsx');
let content = fs.readFileSync(appPath, 'utf8');

// A. Insert StoredEstimateRecord & StoredEstimateItem interfaces
const interfaceAnchor = `interface StoredPayment {`;
const estimateInterfaces = `interface StoredEstimateRecord {
  id: string;
  client_id: string;
  client_name: string;
  estimate_number: string;
  subtotal_cents: number;
  tax_cents: number;
  total_cents: number;
  status: string; // 'PENDING', 'ACCEPTED', 'DECLINED', 'CONVERTED'
  issue_date: string;
  expiry_date: string;
  converted_invoice_id?: string;
  created_at: string;
}

interface StoredEstimateItem {
  id: string;
  estimate_id: string;
  description: string;
  quantity: number;
  unit_price_cents: number;
  total_cents: number;
  created_at: string;
}

`;

if (!content.includes('interface StoredEstimateRecord')) {
  content = content.replace(interfaceAnchor, estimateInterfaces + interfaceAnchor);
  console.log('Estimate interfaces added.');
}

// B. Update BusinessProfile interface to include currency_symbol
const profileAnchor = `  payment_details: string;`;
const newProfileField = `  payment_details: string;
  currency_symbol: string;`;

if (!content.includes('currency_symbol: string;')) {
  content = content.replace(profileAnchor, newProfileField);
  console.log('BusinessProfile interface updated.');
}

// C. Update formatCents in App.tsx to accept currencySymbol
const formatCentsOld = `  const formatCents = (cents: number) => {
    return \`$\${(cents / 100).toFixed(2)}\`;
  };`;

const formatCentsNew = `  const formatCents = (cents: number, overrideSymbol?: string) => {
    const sym = overrideSymbol || currencySymbol || '$';
    return \`\${sym}\${(cents / 100).toFixed(2)}\`;
  };`;

if (content.includes(formatCentsOld)) {
  content = content.replace(formatCentsOld, formatCentsNew);
  console.log('formatCents updated to support currencySymbol.');
}

// D. Insert Currency Symbol, Tab, and Estimates state right after payments state
const stateAnchor = `  const [payments, setPayments] = useState<StoredPayment[]>(() => {`;
const sprint4StateCode = `  // Sprint 4: Currency Symbol State
  const [currencySymbol, setCurrencySymbol] = useState<string>(() => {
    try {
      return localStorage.getItem('sqlite_currency_symbol') || '$';
    } catch {
      return '$';
    }
  });

  useEffect(() => {
    try {
      localStorage.setItem('sqlite_currency_symbol', currencySymbol);
    } catch (_) {}
  }, [currencySymbol]);

  // Sprint 4: Active Tab State ('invoices' | 'estimates')
  const [activeTab, setActiveTab] = useState<'invoices' | 'estimates'>('invoices');

  // Sprint 4: Estimates State
  const [estimates, setEstimates] = useState<StoredEstimateRecord[]>(() => {
    try {
      const saved = localStorage.getItem('sqlite_estimates_sprint4');
      if (saved) return JSON.parse(saved);
    } catch {}
    return [
      {
        id: '1714000000000-501',
        client_id: '1714000000000-101',
        client_name: 'Acme Corporation',
        estimate_number: 'EST-0001',
        subtotal_cents: 20000,
        tax_cents: 2000,
        total_cents: 22000,
        status: 'PENDING',
        issue_date: '2026-10-20',
        expiry_date: '2026-11-20',
        created_at: '2026-10-20T12:00:00Z',
      },
    ];
  });

  const [estimateItems, setEstimateItems] = useState<StoredEstimateItem[]>(() => {
    try {
      const saved = localStorage.getItem('sqlite_estimate_items_sprint4');
      if (saved) return JSON.parse(saved);
    } catch {}
    return [
      {
        id: '1714000000000-601',
        estimate_id: '1714000000000-501',
        description: 'Phase 2 Cloud Infrastructure Proposal',
        quantity: 1,
        unit_price_cents: 20000,
        total_cents: 20000,
        created_at: '2026-10-20T12:00:00Z',
      },
    ];
  });

  useEffect(() => {
    try {
      localStorage.setItem('sqlite_estimates_sprint4', JSON.stringify(estimates));
    } catch (_) {}
  }, [estimates]);

  useEffect(() => {
    try {
      localStorage.setItem('sqlite_estimate_items_sprint4', JSON.stringify(estimateItems));
    } catch (_) {}
  }, [estimateItems]);

  // CSV Export Modal State
  const [isCsvModalOpen, setIsCsvModalOpen] = useState(false);

  const getNextEstimateNumber = () => {
    return \`EST-\${String(estimates.length + 1).padStart(4, '0')}\`;
  };

  const handleSaveEstimate = (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedClientId) {
      showToast('Please select or create a client first.');
      return;
    }
    if (cartItems.length === 0) {
      showToast('Please add at least one line item to the estimate.');
      return;
    }

    const client = clients.find((c) => c.id === selectedClientId);
    const estId = \`\${Date.now()}-\${Math.floor(Math.random() * 900000 + 100000)}\`;
    const estNumber = getNextEstimateNumber();
    const createdAt = new Date().toISOString();

    const now = new Date();
    const exp = new Date(now);
    exp.setDate(exp.getDate() + 30);
    const expiryStr = exp.toISOString().split('T')[0];

    const newEstimate: StoredEstimateRecord = {
      id: estId,
      client_id: selectedClientId,
      client_name: client ? client.name : 'Selected Client',
      estimate_number: estNumber,
      subtotal_cents: cartSubtotalCents,
      tax_cents: cartTaxCents,
      total_cents: cartTotalCents,
      status: 'PENDING',
      issue_date: issueDate || now.toISOString().split('T')[0],
      expiry_date: expiryStr,
      created_at: createdAt,
    };

    const newEstItems: StoredEstimateItem[] = cartItems.map((item, idx) => ({
      id: \`\${Date.now()}-\${idx}-\${Math.floor(Math.random() * 900000 + 100000)}\`,
      estimate_id: estId,
      description: item.description,
      quantity: item.quantity,
      unit_price_cents: item.unitPriceCents,
      total_cents: item.totalCents,
      created_at: createdAt,
    }));

    setEstimates((prev) => [newEstimate, ...prev]);
    setEstimateItems((prev) => [...prev, ...newEstItems]);
    showToast(\`Estimate \${estNumber} saved successfully!\`);
  };

  const handleConvertEstimateToInvoice = (est: StoredEstimateRecord) => {
    const estLineItems = estimateItems.filter((it) => it.estimate_id === est.id);
    const invId = \`\${Date.now()}-\${Math.floor(Math.random() * 900000 + 100000)}\`;
    const invNum = getNextInvoiceNumber();
    const createdAt = new Date().toISOString();

    const newInvoice: InvoiceRecord = {
      id: invId,
      client_id: est.client_id,
      client_name: est.client_name,
      invoice_number: invNum,
      subtotal_cents: est.subtotal_cents,
      tax_cents: est.tax_cents,
      total_cents: est.total_cents,
      status: 'PENDING',
      issue_date: new Date().toISOString().split('T')[0],
      due_date: calculateDueDate(new Date().toISOString().split('T')[0], 'Net 15 Days'),
      payment_terms: 'Net 15 Days',
      created_at: createdAt,
    };

    const newInvItems: StoredInvoiceItem[] = estLineItems.map((item, idx) => ({
      id: \`\${Date.now()}-\${idx}-\${Math.floor(Math.random() * 900000 + 100000)}\`,
      invoice_id: invId,
      description: item.description,
      quantity: item.quantity,
      unit_price_cents: item.unit_price_cents,
      total_cents: item.total_cents,
      created_at: createdAt,
    }));

    setInvoices((prev) => [newInvoice, ...prev]);
    setInvoiceItems((prev) => [...prev, ...newInvItems]);

    // Mark estimate as CONVERTED
    setEstimates((prev) =>
      prev.map((e) => (e.id === est.id ? { ...e, status: 'CONVERTED', converted_invoice_id: invId } : e))
    );

    showToast(\`Converted Estimate \${est.estimate_number} into Invoice \${invNum}!\`);
    setActiveTab('invoices');
  };

  const generateCsvString = () => {
    const headers = [
      'Invoice Number',
      'Issue Date',
      'Due Date',
      'Client Name',
      'Client Tax ID',
      'Subtotal',
      'Tax',
      'Total',
      'Amount Paid',
      'Balance Due',
      'Status',
    ];

    const rows = [headers];
    const clientTaxMap: Record<string, string> = {};
    clients.forEach((c) => (clientTaxMap[c.id] = c.tax_id || ''));

    invoices.forEach((inv) => {
      const paid = getInvoicePaidCents(inv.id);
      const bal = getInvoiceBalanceDueCents(inv);
      rows.push([
        inv.invoice_number,
        inv.issue_date,
        inv.due_date,
        inv.client_name,
        clientTaxMap[inv.client_id] || '',
        formatCents(inv.subtotal_cents),
        formatCents(inv.tax_cents),
        formatCents(inv.total_cents),
        formatCents(paid),
        formatCents(bal),
        inv.status,
      ]);
    });

    return rows
      .map((row) =>
        row
          .map((f) => {
            const escaped = String(f).replace(/"/g, '""');
            if (escaped.includes(',') || escaped.includes('"') || escaped.includes('\n')) {
              return \`"\${escaped}"\`;
            }
            return escaped;
          })
          .join(',')
      )
      .join('\n');
  };

`;

if (!content.includes('const [activeTab, setActiveTab]')) {
  content = content.replace(stateAnchor, sprint4StateCode + stateAnchor);
  console.log('Sprint 4 state inserted successfully!');
}

fs.writeFileSync(appPath, content, 'utf8');
console.log('App.tsx updated for Sprint 4 successfully!');
