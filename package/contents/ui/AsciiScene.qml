/*
    ascii-drift — the animation itself. Pure QtQuick, no Plasma imports, so the
    same file runs inside the wallpaper and inside tools/preview.py.

    One ShaderEffect draws everything:
      vertex shader    -> colour + density of the field, once per cell corner
      fragment shader  -> picks a glyph per cell from the atlas
      atlas            -> the glyph ramp, rendered to a texture once
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

    // Pattern: -1 cycles through all of them, otherwise an index into patternNames
    readonly property var patternNames: ["Drift", "Dunes", "Ripples", "Aurora"]
    property int pattern: -1
    property int cycleMinutes: 10

    // Motion
    property real speed: 1.0
    property real zoom: 1.0
    property int fps: 0           // 0 = follow the display refresh rate
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

    // ---- pattern switching -------------------------------------------------
    // The shader always knows two patterns and a mix factor; switching is a
    // slow morph from one to the other.
    property int _shown: 0
    property int _target: 0
    property real _mix: 0

    function wrap(n) {
        const c = patternNames.length;
        return ((n % c) + c) % c;
    }

    function slot() {
        // which pattern the cycle is on right now: derived from the wall clock,
        // so every monitor agrees and each session starts somewhere different
        return wrap(Math.floor(Date.now() / (Math.max(1, cycleMinutes) * 60000)));
    }

    function show(n) {
        n = wrap(n);
        if (morph.running) {
            morph.stop();
            _shown = _target;
            _mix = 0;
        }
        if (n === _shown)
            return;
        _target = n;
        morph.start();
    }

    Component.onCompleted: _shown = _target = (pattern >= 0 ? wrap(pattern) : slot())
    onPatternChanged: show(pattern >= 0 ? pattern : slot())

    NumberAnimation {
        id: morph
        target: scene
        property: "_mix"
        from: 0
        to: 1
        duration: 6000
        easing.type: Easing.InOutSine
        onFinished: {
            scene._shown = scene._target;
            scene._mix = 0;
        }
    }

    Timer {
        interval: 5000
        repeat: true
        running: scene.pattern < 0 && scene.running
        onTriggered: scene.show(scene.slot())
    }

    // ---- clock -----------------------------------------------------------
    // The clock ping-pongs over an hour so the float sent to the GPU stays
    // small and precise no matter how many days the session has been up.
    property real _clock: 0
    readonly property real _period: 3600

    function advance(dt) {
        _clock += Math.min(dt, 0.25) * speed;
        const phase = _clock % (2 * _period);
        time = phase < _period ? phase : 2 * _period - phase;
    }

    // Driven by the display's own frame clock, so every update lands exactly
    // on a vsync. With a cap, whole frames are skipped (180 Hz capped at 60
    // -> every 3rd frame), which keeps the pacing perfectly even.
    FrameAnimation {
        property real pending: 0
        running: scene.running && scene.visible
        onRunningChanged: pending = 0
        onTriggered: {
            pending += frameTime;
            if (scene.fps <= 0 || pending + 0.0006 >= 1 / scene.fps) {
                scene.advance(pending);
                pending = 0;
            }
        }
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
        live: true   // re-renders only when the glyphs/font actually change, not per frame
        smooth: true
    }

    // ---- the one draw call ------------------------------------------------
    // Only uniforms change from frame to frame: no intermediate render target,
    // no geometry re-upload.
    ShaderEffect {
        id: glyphPass
        width: scene.cols * scene.cellW
        height: scene.rows * scene.cellH
        blending: false
        mesh: GridMesh { resolution: Qt.size(scene.cols, scene.rows) }

        property var atlas: atlasTexture
        property real time: scene.time
        property real zoom: Math.max(0.05, scene.zoom)
        property real seed: scene.seed
        property real glyphCount: scene.glyphList.length
        property real glow: scene.glow
        property real fade: 0
        property real patternA: scene._shown
        property real patternB: scene._target
        property real patternMix: scene._mix
        property size resolution: Qt.size(width, height)
        property size cell: Qt.size(scene.cellW, scene.cellH)
        property color background: scene.backgroundColor
        property color colorA: scene.colorA
        property color colorB: scene.colorB
        property color colorC: scene.colorC
        property color colorD: scene.colorD

        vertexShader: Qt.resolvedUrl("../shaders/field.vert.qsb")
        fragmentShader: Qt.resolvedUrl("../shaders/glyph.frag.qsb")

        NumberAnimation on fade {
            from: 0
            to: 1
            duration: 1800
            easing.type: Easing.OutCubic
        }
    }
}
