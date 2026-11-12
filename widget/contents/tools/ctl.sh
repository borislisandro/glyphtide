#!/usr/bin/env bash
# Talks to the running Plasma shell on behalf of the Glyphtide widget.
#   ctl.sh get              print the wallpaper's current settings as JSON
#   ctl.sh set KEY VALUE    change one setting on every screen using the wallpaper
#   ctl.sh enable           make Glyphtide the wallpaper on every screen
set -euo pipefail
id=io.github.borislisandro.glyphtide
qdbus=$(command -v qdbus6 || command -v qdbus-qt6 || command -v qdbus)
run() { "$qdbus" org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$1"; }

case "${1:-}" in
get)
    run "
        var out = { active: false };
        for (const d of desktops()) {
            if (d.wallpaperPlugin != '$id') continue;
            d.currentConfigGroup = ['Wallpaper', '$id', 'General'];
            out = {
                active: true,
                Pattern: Number(d.readConfig('Pattern', -1)),
                CycleMinutes: Number(d.readConfig('CycleMinutes', 10)),
                Speed: Number(d.readConfig('Speed', 100)),
                FontSize: Number(d.readConfig('FontSize', 16)),
                Zoom: Number(d.readConfig('Zoom', 100)),
                PauseWhenCovered: String(d.readConfig('PauseWhenCovered', true)) == 'true'
            };
            break;
        }
        print(JSON.stringify(out));"
    ;;
set)
    key="${2:-}"; value="${3:-}"
    [[ "$key" =~ ^[A-Za-z]+$ ]] || { echo "bad key" >&2; exit 2; }
    [[ "$value" =~ ^(-?[0-9]+|true|false)$ ]] || { echo "bad value" >&2; exit 2; }
    run "
        for (const d of desktops()) {
            if (d.wallpaperPlugin != '$id') continue;
            d.currentConfigGroup = ['Wallpaper', '$id', 'General'];
            d.writeConfig('$key', $value);
            d.reloadConfig();
        }"
    ;;
enable)
    run "for (const d of desktops()) d.wallpaperPlugin = '$id';"
    ;;
*)
    echo "usage: $0 get | set KEY VALUE | enable" >&2; exit 2 ;;
esac
