import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kquickcontrols as KQuickControls

Kirigami.FormLayout {
    id: root
    twinFormLayouts: parentLayout
    property alias formLayout: root

    property int cfg_Pattern: -1
    property alias cfg_CycleMinutes: cycleMinutes.value
    property alias cfg_Glyphs: glyphs.text
    property alias cfg_FontFamily: fontFamily.text
    property alias cfg_FontSize: fontSize.value
    property alias cfg_Speed: speed.value
    property alias cfg_Zoom: zoom.value
    property alias cfg_Glow: glow.value
    property alias cfg_Fps: fps.value
    property alias cfg_PauseWhenCovered: pause.checked
    property alias cfg_BackgroundColor: backgroundColor.color
    property alias cfg_ColorA: colorA.color
    property alias cfg_ColorB: colorB.color
    property alias cfg_ColorC: colorC.color
    property alias cfg_ColorD: colorD.color

    QQC2.ComboBox {
        Kirigami.FormData.label: "Pattern:"
        model: ["Cycle through all", "Drift", "Dunes", "Ripples", "Aurora"]
        currentIndex: root.cfg_Pattern + 1
        onActivated: root.cfg_Pattern = currentIndex - 1
    }
    QQC2.SpinBox {
        id: cycleMinutes
        Kirigami.FormData.label: "Change every (min):"
        from: 1; to: 720
        enabled: root.cfg_Pattern < 0
    }

    Item { Kirigami.FormData.isSection: true }

    QQC2.TextField {
        id: glyphs
        Kirigami.FormData.label: "Glyphs (empty → dense):"
        font.family: "monospace"
    }
    QQC2.TextField {
        id: fontFamily
        Kirigami.FormData.label: "Font:"
    }
    QQC2.SpinBox {
        id: fontSize
        Kirigami.FormData.label: "Glyph size (px):"
        from: 6; to: 64
    }

    Item { Kirigami.FormData.isSection: true }

    QQC2.SpinBox {
        id: speed
        Kirigami.FormData.label: "Speed (%):"
        from: 0; to: 1000; stepSize: 10
    }
    QQC2.SpinBox {
        id: zoom
        Kirigami.FormData.label: "Shape size (%):"
        from: 20; to: 500; stepSize: 10
    }
    QQC2.SpinBox {
        id: glow
        Kirigami.FormData.label: "Glow (%):"
        from: 0; to: 100; stepSize: 2
    }
    QQC2.SpinBox {
        id: fps
        Kirigami.FormData.label: "Frame rate cap (0 = display):"
        from: 0; to: 240; stepSize: 5
    }
    QQC2.CheckBox {
        id: pause
        text: "Pause while a maximized window covers the screen"
    }

    Item { Kirigami.FormData.isSection: true }

    KQuickControls.ColorButton { id: backgroundColor; Kirigami.FormData.label: "Background:" }
    RowLayout {
        Kirigami.FormData.label: "Sheets:"
        KQuickControls.ColorButton { id: colorD }
        KQuickControls.ColorButton { id: colorA }
        KQuickControls.ColorButton { id: colorB }
        KQuickControls.ColorButton { id: colorC }
    }
}
