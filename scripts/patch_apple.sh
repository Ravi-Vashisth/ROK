#!/usr/bin/env bash
set -e

echo "Applying Apple (iOS Info.plist & macOS Entitlements) patches..."

# 1. Patch iOS Info.plist with LSApplicationQueriesSchemes for url_launcher
IOS_PLIST="ios/Runner/Info.plist"
if [ -f "$IOS_PLIST" ]; then
  echo "Patching $IOS_PLIST with LSApplicationQueriesSchemes..."
  python3 - "$IOS_PLIST" << 'PYEOF'
import plistlib
import sys

path = sys.argv[1]
with open(path, 'rb') as f:
    data = plistlib.load(f)

required_schemes = ['whatsapp', 'mailto', 'tel', 'sms', 'https']
existing = data.get('LSApplicationQueriesSchemes', [])
if not isinstance(existing, list):
    existing = []
for scheme in required_schemes:
    if scheme not in existing:
        existing.append(scheme)
data['LSApplicationQueriesSchemes'] = existing

with open(path, 'wb') as f:
    plistlib.dump(data, f)
PYEOF
fi

# 2. Patch macOS Entitlements for outbound network links & user-selected file save/open dialogs
for ENT in "macos/Runner/Release.entitlements" "macos/Runner/DebugProfile.entitlements"; do
  if [ -f "$ENT" ]; then
    echo "Patching $ENT with network client and file access entitlements..."
    python3 - "$ENT" << 'PYEOF'
import plistlib
import sys

path = sys.argv[1]
with open(path, 'rb') as f:
    data = plistlib.load(f)

data['com.apple.security.network.client'] = True
data['com.apple.security.files.user-selected.read-write'] = True

with open(path, 'wb') as f:
    plistlib.dump(data, f)
PYEOF
  fi
done

echo "Apple platform patches applied successfully."
