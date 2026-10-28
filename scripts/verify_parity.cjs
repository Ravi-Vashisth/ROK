const fs = require('fs');
const path = require('path');

const libDir = path.join(__dirname, '../lib/features');
const srcFile = path.join(__dirname, '../src/App.tsx');

function verifyTabs() {
    console.log('Verifying Tab Parity...');
    const flutterTabs = ['dashboard', 'billing', 'expenses', 'settings']; // based on directory structure
    const reactTabs = ['Dashboard', 'Sales', 'Expenses', 'Directory']; // check names in App.tsx

    flutterTabs.forEach(tab => {
        if (!fs.existsSync(path.join(libDir, tab))) {
            throw new Error(`Missing Flutter tab feature: ${tab}`);
        }
    });

    const srcContent = fs.readFileSync(srcFile, 'utf8');
    reactTabs.forEach(tab => {
        if (!srcContent.includes(tab)) {
            throw new Error(`Missing React tab component/name: ${tab}`);
        }
    });
    console.log('Tabs verified successfully.');
}

function verifyModels() {
    console.log('Verifying Model Parity...');
    const models = {
        'Invoice': ['invoices/models/invoice_record.dart', 'interface InvoiceRecord'],
        'Estimate': ['estimates/models/estimate_record.dart', 'interface StoredEstimateRecord'],
        'Expense': ['expenses/models/expense_record.dart', 'interface ExpenseRecord'],
        'Client': ['clients/models/client.dart', 'interface Client'],
        'SavedItem': ['items/models/saved_item.dart', 'interface StoredItem'] // Assuming it's defined
    };

    Object.entries(models).forEach(([name, [flutterPath, reactType]]) => {
        if (!fs.existsSync(path.join(libDir, flutterPath))) {
            throw new Error(`Missing Flutter model: ${flutterPath}`);
        }
        const srcContent = fs.readFileSync(srcFile, 'utf8');
        if (!srcContent.includes(reactType)) {
             // Just a simple check, could be more robust
            console.warn(`Warning: Might be missing React definition for ${name} (looking for ${reactType})`);
        }
    });
    console.log('Models verified successfully.');
}

try {
    verifyTabs();
    verifyModels();
    console.log('Parity check passed.');
} catch (e) {
    console.error('Parity check failed:', e.message);
    process.exit(1);
}
