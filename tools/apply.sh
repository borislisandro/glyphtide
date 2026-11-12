#!/usr/bin/env bash
# Set Glyphtide as the wallpaper on every screen of the running Plasma session.
set -euo pipefail
id="${1:-io.github.borislisandro.glyphtide}"
qdbus=$(command -v qdbus6 || command -v qdbus-qt6 || command -v qdbus)
"$qdbus" org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "
for (const d of desktops()) {
    d.wallpaperPlugin = '$id';
}"
echo "wallpaper set to $id"
