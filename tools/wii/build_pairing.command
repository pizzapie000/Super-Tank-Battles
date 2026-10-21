#!/bin/zsh
set -eu
cd "${0:A:h}"
task_destination="${1:-$HOME/Applications/WiimotePair.app}"
if [[ -e "$task_destination" ]]; then
  print -u2 "Destination already exists; choose a new path to preserve it: $task_destination"
  exit 1
fi
task_staging="$(mktemp -d)/WiimotePair.app"
mkdir -p "$task_staging/Contents/MacOS" "$task_staging/Contents/Resources/Source/pairing-source"
xcrun clang -fobjc-arc -mmacosx-version-min=12.0 -framework Cocoa -framework CoreBluetooth -framework IOBluetooth -framework IOKit pairing-source/LocalUI.m pairing-source/ViewController.m -o "$task_staging/Contents/MacOS/WiimotePair"
cp pairing-source/* "$task_staging/Contents/Resources/Source/pairing-source/"
cp build_pairing.command "$task_staging/Contents/Resources/Source/"
cat > "$task_staging/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>WiimotePair</string>
<key>CFBundleIdentifier</key><string>org.dolphin-emu.WiimotePair.local</string>
<key>CFBundleExecutable</key><string>WiimotePair</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1.2-local-hid</string>
<key>LSMinimumSystemVersion</key><string>12.0</string>
<key>NSBluetoothAlwaysUsageDescription</key><string>Pair your Wii Remotes with this Mac for Super Tank Battles.</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - --identifier org.dolphin-emu.WiimotePair.local "$task_staging"
codesign --verify --deep --strict "$task_staging"
mkdir -p "${task_destination:h}"
ditto "$task_staging" "$task_destination"
print "Installed locally compiled pairing utility: $task_destination"
