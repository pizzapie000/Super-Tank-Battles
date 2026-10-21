#!/bin/zsh
set -eu
cd "${0:A:h}"
task_bundle="Wii Remote Bridge.app"
mkdir -p "$task_bundle/Contents/MacOS"
task_arch="$(uname -m)"
xcrun swiftc -swift-version 5 -O -target "$task_arch-apple-macos12.0" WiiProtocol.swift WiiHID.swift WiiBridge.swift -framework AppKit -framework CoreBluetooth -framework IOBluetooth -framework IOKit -o "$task_bundle/Contents/MacOS/WiiRemoteBridge"
cp Info.plist "$task_bundle/Contents/Info.plist"
codesign --force --sign - --identifier com.supertankbattles.wiibridge "$task_bundle"
"$task_bundle/Contents/MacOS/WiiRemoteBridge" --self-test
