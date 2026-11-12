/*
    ascii-drift — panel / system tray widget.
    A small remote control for the wallpaper: it reads the wallpaper's settings
    when opened and writes each change straight back, on every screen.
*/
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasma5support as P5Support

PlasmoidItem {
    id: root

    Plasmoid.icon: Qt.resolvedUrl("../icons/asciidrift.svg").toString().replace("file://", "")
    Plasmoid.status: PlasmaCore.Types.ActiveStatus // always shown in the tray, never tucked into the overflow
    toolTipMainText: "ASCII Drift"
    toolTipSubText: !state.active ? "Wallpaper not in use"
                  : state.Pattern < 0 ? "Cycling patterns every " + state.CycleMinutes + " min"
                  : patterns[state.Pattern + 1]

    readonly property var patterns: ["Cycle through all", "Drift", "Dunes", "Ripples", "Aurora"]
    readonly property string ctl: "bash '" + Qt.resolvedUrl("../tools/ctl.sh").toString().replace("file://", "") + "'"

    property var state: ({ active: false, Pattern: -1, CycleMinutes: 10, Speed: 100, FontSize: 16, Zoom: 100, PauseWhenCovered: true })
    property bool loading: false

    P5Support.DataSource {
        id: exec
        engine: "executable"
        onNewData: (source, data) => {
            disconnectSource(source);
            if (source.endsWith(" get")) {
                try {
                    root.loading = true;
                    root.state = JSON.parse(data["stdout"]);
                } catch (e) {
                    console.warn("ascii-drift widget: could not read settings:", data["stdout"], data["stderr"]);
                } finally {
                    root.loading = false;
                }
            } else if (source.endsWith(" enable")) {
                root.refresh();
            }
        }
    }

    function refresh() { exec.connectSource(ctl + " get"); }

    function set(key, value) {
        if (loading || state[key] === value)
            return;
        const next = Object.assign({}, state);
        next[key] = value;
        state = next;
        exec.connectSource(ctl + " set " + key + " " + value);
    }

    Component.onCompleted: refresh()
    onExpandedChanged: if (root.expanded) refresh()

    fullRepresentation: ColumnLayout {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 16
        Layout.preferredWidth: Kirigami.Units.gridUnit * 18
        Layout.maximumWidth: Kirigami.Units.gridUnit * 22
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Heading {
            level: 3
            text: "ASCII Drift"
            Layout.margins: Kirigami.Units.smallSpacing
        }

        ColumnLayout {
            visible: !root.state.active
            Layout.margins: Kirigami.Units.largeSpacing
            PlasmaComponents.Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: "ASCII Drift is not the current wallpaper."
            }
            PlasmaComponents.Button {
                text: "Use it on all screens"
                icon.name: "preferences-desktop-wallpaper"
                onClicked: exec.connectSource(root.ctl + " enable")
            }
        }

        Kirigami.FormLayout {
            visible: root.state.active
            Layout.fillWidth: true

            PlasmaComponents.ComboBox {
                Kirigami.FormData.label: "Pattern:"
                model: root.patterns
                currentIndex: root.state.Pattern + 1
                onActivated: root.set("Pattern", currentIndex - 1)
            }
            PlasmaComponents.SpinBox {
                Kirigami.FormData.label: "Change every (min):"
                enabled: root.state.Pattern < 0
                from: 1; to: 720
                value: root.state.CycleMinutes
                onValueModified: root.set("CycleMinutes", value)
            }
            RowLayout {
                Kirigami.FormData.label: "Speed:"
                PlasmaComponents.Slider {
                    Layout.fillWidth: true
                    from: 0; to: 400; stepSize: 10
                    value: root.state.Speed
                    onMoved: root.set("Speed", Math.round(value))
                }
                PlasmaComponents.Label {
                    text: root.state.Speed + " %"
                    Layout.minimumWidth: Kirigami.Units.gridUnit * 3
                }
            }
            PlasmaComponents.SpinBox {
                Kirigami.FormData.label: "Glyph size (px):"
                from: 6; to: 64
                value: root.state.FontSize
                onValueModified: root.set("FontSize", value)
            }
            PlasmaComponents.SpinBox {
                Kirigami.FormData.label: "Shape size (%):"
                from: 20; to: 500; stepSize: 10
                value: root.state.Zoom
                onValueModified: root.set("Zoom", value)
            }
            PlasmaComponents.CheckBox {
                text: "Pause under maximized windows"
                checked: root.state.PauseWhenCovered
                onToggled: root.set("PauseWhenCovered", checked)
            }
        }

        PlasmaComponents.Label {
            visible: root.state.active
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing
            wrapMode: Text.WordWrap
            opacity: 0.6
            font: Kirigami.Theme.smallFont
            text: "Colours, glyphs and font: right-click the desktop → Desktop and Wallpaper."
        }

        Item { Layout.fillHeight: true }
    }
}
