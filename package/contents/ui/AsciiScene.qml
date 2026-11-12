/*
    ascii-drift — the animation itself. Pure QtQuick, no Plasma imports, so the
    same file runs inside the wallpaper and inside tools/preview.py.

    Pipeline:
      field  (ShaderEffect, cols x rows px)  -> colour + density per character cell
      atlas  (Text items rendered once)      -> one texture holding the glyph ramp
      glyphs (ShaderEffect, full size)       -> picks a glyph per cell from the atlas
*/
import QtQuick

Item {
    id: scene

    // Look
    property string glyphs: " .:-=+*#%@"
    property string fontFamily: "JetBrains Mono"
    property int fontPixelSize: 16
    property color backgroundColor: "#0b0809"
    property color colorA: "#e3253d"
    property color colorB: "#ff7a1a"
    property color colorC: "#e52161"
    property color colorD: "#7a0420"
    property real glow: 0.12

    // Motion
    property real speed: 1.0
    property real zoom: 1.0
    property int fps: 60          // 0 = follow the display refresh rate
    property bool running: true
    property real seed: 0         // different value per screen -> different shapes
    property real time: 0         // animation clock; set it yourself when running is false

    readonly property var glyphList: Array.from(glyphs.length > 0 ? glyphs : " ")
    readonly property int cellW: Math.max(4, Math.ceil(metrics.advanceWidth("M")))
    readonly property int cellH: Math.max(6, Math.ceil(metrics.height))
    readonly property int cols: Math.max(1, Math.ceil(width / cellW))
    readonly property int rows: Math.max(1, Math.ceil(height / cellH))

    FontMetrics {
        id: metrics
        font.family: scene.fontFamily
        font.pixelSize: scene.fontPixelSize
    }

    // ---- clock -----------------------------------------------------------
    // The clock ping-pongs over an hour so the float sent to the GPU stays
    // small and precise no matter how many days the session has been up.
    property real _clock: 0
    property real _last: 0
    readonly property real _period: 3600

    function advance(dt) {
        _clock += Math.min(dt, 0.25) * speed;
        const phase = _clock % (2 * _period);
        time = phase < _period ? phase : 2 * _period - phase;
    }

    Timer {
        interval: Math.max(4, Math.round(1000 / Math.max(1, scene.fps)))
        repeat: true
        running: scene.running && scene.fps > 0 && scene.visible
        onRunningChanged: scene._last = Date.now()
        onTriggered: {
            const now = Date.now();
            scene.advance((now - scene._last) / 1000);
            scene._last = now;
        }
    }

    FrameAnimation {
        running: scene.running && scene.fps <= 0 && scene.visible
        onTriggered: scene.advance(frameTime)
    }

    // ---- pass 1: field, one pixel per cell --------------------------------
    ShaderEffect {
        id: field
        width: scene.cols
        height: scene.rows
        blending: false

        property real time: scene.time
        property real zoom: Math.max(0.05, scene.zoom)
        property real seed: scene.seed
        property size grid: Qt.size(scene.cols, scene.rows)
        property size cell: Qt.size(scene.cellW, scene.cellH)
        property color colorA: scene.colorA
        property color colorB: scene.colorB
        property color colorC: scene.colorC
        property color colorD: scene.colorD

        fragmentShader: Qt.resolvedUrl("../shaders/field.frag.qsb")
    }

    ShaderEffectSource {
        id: fieldTexture
        sourceItem: field
        hideSource: true
        live: true
        smooth: false
        format: ShaderEffectSource.RGBA16F
        textureSize: Qt.size(scene.cols, scene.rows)
    }

    // ---- glyph atlas: the ramp, one glyph per cell, rendered once ----------
    Item {
        id: atlas
        width: scene.cellW * scene.glyphList.length
        height: scene.cellH

        Repeater {
            model: scene.glyphList
            Text {
                required property int index
                required property string modelData
                x: index * scene.cellW
                width: scene.cellW
                height: scene.cellH
                text: modelData
                color: "white"
                font: metrics.font
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                renderType: Text.NativeRendering
            }
        }
    }

    ShaderEffectSource {
        id: atlasTexture
        sourceItem: atlas
        hideSource: true
        live: true   // re-renders only when the glyphs/font actually change
        smooth: true
    }

    // ---- pass 2: glyphs -----------------------------------------------------
    ShaderEffect {
        id: glyphPass
        anchors.fill: parent
        blending: false

        property var field: fieldTexture
        property var atlas: atlasTexture
        property size resolution: Qt.size(width, height)
        property size grid: Qt.size(scene.cols, scene.rows)
        property size cell: Qt.size(scene.cellW, scene.cellH)
        property real glyphCount: scene.glyphList.length
        property real glow: scene.glow
        property real fade: 0
        property color background: scene.backgroundColor

        fragmentShader: Qt.resolvedUrl("../shaders/glyph.frag.qsb")

        NumberAnimation on fade {
            from: 0
            to: 1
            duration: 1800
            easing.type: Easing.OutCubic
        }
    }
}
