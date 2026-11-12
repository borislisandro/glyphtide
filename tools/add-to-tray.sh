#!/usr/bin/env bash
# Put the Glyphtide widget in the system tray (always visible).
# Upgrading the widget with kpackagetool removes it from the tray, so
# `make install` runs this again afterwards.
set -euo pipefail
id="${1:-io.github.borislisandro.glyphtide.widget}"
qdbus=$(command -v qdbus6 || command -v qdbus-qt6 || command -v qdbus)
"$qdbus" org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "
var out = '';
for (const p of panels()) for (const w of p.widgets()) {
    if (w.type != 'org.kde.plasma.systemtray') continue;
    w.currentConfigGroup = ['General'];
    for (const key of ['extraItems', 'shownItems']) {
        var items = String(w.readConfig(key, '')).split(',').filter(function (s) { return s.length > 0; });
        if (items.indexOf('$id') < 0) items.push('$id');
        w.writeConfig(key, items.join(','));
    }
    w.reloadConfig();
    out += 'added to the system tray on panel ' + p.id + '\n';
}
print(out || 'no system tray found: add the widget by hand (right-click a panel → Add Widgets)\n');"
