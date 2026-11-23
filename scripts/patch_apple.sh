#!/usr/bin/env bash
set -e

echo "Applying Apple (iOS Info.plist & macOS Entitlements) patches..."

# 1. Patch iOS Info.plist with LSApplicationQueriesSchemes & Files/PhotoLibrary keys idempotently
IOS_PLIST="ios/Runner/Info.plist"
if [ -f "$IOS_PLIST" ]; then
  echo "Patching $IOS_PLIST with LSApplicationQueriesSchemes, file sharing, and photo library usage..."
  python3 - "$IOS_PLIST" << 'PYEOF'
import plistlib
import sys

path = sys.argv[1]
with open(path, 'rb') as f:
    data = plistlib.load(f)

required_schemes = ['whatsapp', 'whatsapp-smb', 'mailto', 'tel', 'sms', 'https']
existing = data.get('LSApplicationQueriesSchemes', [])
if not isinstance(existing, list):
    existing = []
for scheme in required_schemes:
    if scheme not in existing:
        existing.append(scheme)
data['LSApplicationQueriesSchemes'] = existing

data['UIFileSharingEnabled'] = True
data['LSSupportsOpeningDocumentsInPlace'] = True
data.setdefault(
    'NSPhotoLibraryUsageDescription',
    'Select a business logo image for invoices, quotes, and statements.'
)

with open(path, 'wb') as f:
    plistlib.dump(data, f)
PYEOF
fi

# 2. Patch macOS Entitlements for outbound network links, file dialogs, and sandboxed printing
for ENT in "macos/Runner/Release.entitlements" "macos/Runner/DebugProfile.entitlements"; do
  if [ -f "$ENT" ]; then
    echo "Patching $ENT with network client, file access, and print entitlements..."
    python3 - "$ENT" << 'PYEOF'
import plistlib
import sys

path = sys.argv[1]
with open(path, 'rb') as f:
    data = plistlib.load(f)

data['com.apple.security.network.client'] = True
data['com.apple.security.files.user-selected.read-write'] = True
data['com.apple.security.print'] = True

with open(path, 'wb') as f:
    plistlib.dump(data, f)
PYEOF
  fi
done

# 3. Patch macOS MainFlutterWindow.swift idempotently to enforce minimum 420x560 window bounds
MACOS_WINDOW="macos/Runner/MainFlutterWindow.swift"
if [ -f "$MACOS_WINDOW" ]; then
  echo "Patching $MACOS_WINDOW with minimum window bounds (420x560)..."
  python3 - "$MACOS_WINDOW" << 'PYEOF'
import re
import sys

path = sys.argv[1]
with open(path, 'r', encoding='utf-8') as f:
    src = f.read()

if 'minSize = NSSize' not in src:
    pattern = re.compile(r'([ \t]*override\s+func\s+awakeFromNib\s*\(\s*\)\s*\{\s*\n)([ \t]*)')
    match = pattern.search(src)
    if match:
        header = match.group(1)
        body_indent = match.group(2) or '    '
        replacement = f'{header}{body_indent}self.minSize = NSSize(width: 420, height: 560)\n{body_indent}'
        updated = src[:match.start()] + replacement + src[match.end():]
        with open(path, 'w', encoding='utf-8') as f:
            f.write(updated)
    else:
        print(f'Warning: awakeFromNib() not found in {path}; skipping minSize patch.', file=sys.stderr)
PYEOF
fi

echo "Apple platform patches applied successfully."
