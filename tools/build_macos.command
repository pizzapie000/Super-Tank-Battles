#!/bin/zsh
# Double-click in Finder to rebuild a standalone release, including Wii support.
set -eu
task_project="${0:A:h:h}"
task_godot="${SUPERTANK_GODOT:-}"
if [[ -z "$task_godot" ]]; then
    for task_candidate in /Applications/Godot.app/Contents/MacOS/Godot "$HOME/Applications/Godot.app/Contents/MacOS/Godot" "$HOME/Downloads/Godot.app/Contents/MacOS/Godot"; do
        if [[ -x "$task_candidate" ]]; then task_godot="$task_candidate"; break; fi
    done
fi
if [[ -z "$task_godot" ]] && (( $+commands[godot] )); then task_godot="${commands[godot]}"; fi
if [[ ! -x "$task_godot" ]]; then
    print -u2 "Godot was not found. Install Godot or set SUPERTANK_GODOT to its executable."
    exit 1
fi
task_output="${1:-$task_project/builds/macos/Super Tank Battles.app}"
task_output="${task_output:A}"
if [[ "$task_output" != *.app ]]; then print -u2 "The output must end in .app."; exit 1; fi
if [[ -e "$task_output" ]]; then
    task_existing_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$task_output/Contents/Info.plist" 2>/dev/null || true)
    if [[ "$task_existing_id" != "com.supertankbattles.game" ]]; then
        print -u2 "That destination contains another app. Choose a different output path."
        exit 1
    fi
    task_existing_executable=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$task_output/Contents/Info.plist")
    if /usr/sbin/lsof -t "$task_output/Contents/MacOS/$task_existing_executable" >/dev/null 2>&1; then
        print -u2 "Quit the previous game build before replacing it."
        exit 1
    fi
fi
task_bridge="$task_project/tools/wii/Wii Remote Bridge.app"
if [[ ! -x "$task_bridge/Contents/MacOS/WiiRemoteBridge" ]]; then
    print -u2 "Build the Wii bridge with tools/wii/build.command first."
    exit 1
fi
mkdir -p "${task_output:h}"
task_staging=$(mktemp -d "${task_output:h}/.super-tank-build.XXXXXX")
trap 'rm -rf "$task_staging"' EXIT
task_app="$task_staging/Super Tank Battles.app"
"$task_godot" --headless --path "$task_project" --export-release macOS "$task_app"
mkdir -p "$task_app/Contents/Helpers" "$task_app/Contents/Resources/Notices"
# Keep the helper a real signed .app, outside the game's packed resources. Do not
# copy OneDrive's Finder metadata into a signed bundle.
/usr/bin/ditto --norsrc --noextattr "$task_bridge" "$task_app/Contents/Helpers/Wii Remote Bridge.app"
cp "$task_project/tools/wii/NOTICES.txt" "$task_app/Contents/Resources/Notices/Wii.txt"
cp "$task_project/assets/audio/CREDITS.txt" "$task_app/Contents/Resources/Notices/Audio.txt"
"$task_godot" --headless --path "$task_project" --script res://tools/export_notices.gd -- "$task_app/Contents/Resources/Notices/Godot.json"
# Finder may decorate .app folders stored in OneDrive with metadata rejected by
# strict signature verification. Remove only that metadata from this new build.
xattr -r -d com.apple.FinderInfo "$task_app" 2>/dev/null || true
xattr -r -d com.apple.ResourceFork "$task_app" 2>/dev/null || true
codesign --verify --strict "$task_app/Contents/Helpers/Wii Remote Bridge.app"
codesign --force --sign - --identifier com.supertankbattles.game "$task_app"
codesign --verify --deep --strict "$task_app"
# Keep the previous generated build until the new one is complete and signed.
if [[ -e "$task_output" ]]; then mv "$task_output" "$task_staging/previous.app"; fi
if ! mv "$task_app" "$task_output"; then
    if [[ -e "$task_staging/previous.app" ]]; then mv "$task_staging/previous.app" "$task_output"; fi
    exit 1
fi
print "Standalone release ready: $task_output"
