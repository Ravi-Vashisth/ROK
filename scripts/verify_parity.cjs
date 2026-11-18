const fs = require('fs');
const path = require('path');

const rootDir = path.join(__dirname, '..');
const libDir = path.join(rootDir, 'lib');
const featuresDir = path.join(libDir, 'features');
const testDir = path.join(rootDir, 'test');
const srcDir = path.join(rootDir, 'src');
const appFile = path.join(srcDir, 'App.tsx');

function walkFiles(dir, extFilter, excludeNames = new Set()) {
  const results = [];
  if (!fs.existsSync(dir)) return results;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      results.push(...walkFiles(fullPath, extFilter, excludeNames));
    } else if (
      entry.name.endsWith(extFilter) &&
      !excludeNames.has(entry.name)
    ) {
      results.push(fullPath);
    }
  }
  return results;
}

function verifyTabsAndFeatures() {
  console.log('Verifying Feature & Tab Parity...');
  const flutterFeatures = [
    'dashboard',
    'invoices',
    'estimates',
    'expenses',
    'clients',
    'settings',
    'business_profile',
    'items',
    'payments',
  ];
  const reactTabs = ['Dashboard', 'Sales', 'Expenses', 'Settings'];

  for (const feature of flutterFeatures) {
    if (!fs.existsSync(path.join(featuresDir, feature))) {
      throw new Error(`Missing Flutter feature directory: lib/features/${feature}`);
    }
  }

  if (!fs.existsSync(appFile)) {
    throw new Error('Missing React entry file: src/App.tsx');
  }
  const appContent = fs.readFileSync(appFile, 'utf8');
  for (const tab of reactTabs) {
    if (!appContent.includes(tab)) {
      throw new Error(`Missing React primary tab reference in src/App.tsx: ${tab}`);
    }
  }
  console.log('Features and tabs verified successfully.');
}

function verifyModels() {
  console.log('Verifying Model Parity...');
  const reactFiles = [
    ...walkFiles(srcDir, '.tsx', new Set(['modularFiles.ts'])),
    ...walkFiles(srcDir, '.ts', new Set(['modularFiles.ts'])),
  ];
  const reactCombined = reactFiles
    .map((filePath) => fs.readFileSync(filePath, 'utf8'))
    .join('\n');

  const models = {
    Invoice: ['invoices/models/invoice_record.dart', 'interface InvoiceRecord'],
    Estimate: ['estimates/models/estimate_record.dart', 'interface StoredEstimateRecord'],
    Expense: ['expenses/models/expense_record.dart', 'interface ExpenseRecord'],
    Client: ['clients/models/client.dart', 'interface Client'],
    SavedItem: ['items/models/saved_item.dart', 'interface StoredItem'],
  };

  for (const [name, [flutterRelPath, reactSignature]] of Object.entries(models)) {
    const flutterPath = path.join(featuresDir, flutterRelPath);
    if (!fs.existsSync(flutterPath)) {
      throw new Error(`Missing Flutter model (${name}): lib/features/${flutterRelPath}`);
    }
    if (!reactCombined.includes(reactSignature)) {
      throw new Error(
        `Missing React model definition for ${name} (expected "${reactSignature}" across src/ excluding modularFiles.ts)`
      );
    }
  }
  console.log('Models verified successfully.');
}

function verifyDartImports() {
  console.log('Verifying Dart Package Import Hygiene...');
  const dartFiles = [...walkFiles(libDir, '.dart'), ...walkFiles(testDir, '.dart')];
  const violations = [];

  for (const filePath of dartFiles) {
    const relFile = path.relative(rootDir, filePath).replace(/\\/g, '/');
    const lines = fs.readFileSync(filePath, 'utf8').split(/\r?\n/);
    lines.forEach((line, idx) => {
      const match = line.match(/^\s*(?:import|export|part)\s+['"]([^'"]+)['"]/);
      if (!match) return;
      const target = match[1];
      if (!target.startsWith('dart:') && !target.startsWith('package:')) {
        violations.push(`${relFile}:${idx + 1} uses relative import "${target}"`);
        return;
      }
      if (target.startsWith('package:billing_app/')) {
        const targetRelPath = target.slice('package:billing_app/'.length);
        const resolved = path.join(libDir, targetRelPath);
        if (!fs.existsSync(resolved)) {
          violations.push(`${relFile}:${idx + 1} references missing package file "${target}"`);
        }
      }
    });
  }

  if (violations.length > 0) {
    throw new Error(
      `Dart import hygiene violations (${violations.length}):\n  - ${violations.join('\n  - ')}`
    );
  }
  console.log(`Verified ${dartFiles.length} Dart files with 0 relative or broken imports.`);
}

function verifyOfflineAssets() {
  console.log('Verifying Offline PDF Font Assets...');
  const requiredFonts = [
    'assets/fonts/DejaVuSans.ttf',
    'assets/fonts/DejaVuSans-Bold.ttf',
  ];
  for (const fontRelPath of requiredFonts) {
    if (!fs.existsSync(path.join(rootDir, fontRelPath))) {
      throw new Error(`Missing required offline font asset: ${fontRelPath}`);
    }
  }
  console.log('Offline assets verified successfully.');
}

try {
  verifyTabsAndFeatures();
  verifyModels();
  verifyDartImports();
  verifyOfflineAssets();
  console.log('Parity check passed.');
} catch (err) {
  console.error('Parity check failed:', err.message);
  process.exit(1);
}
