/*
    ascii-drift — Plasma 6 wallpaper wrapper.
    Feeds the user's settings into AsciiScene and pauses it while a
    maximized/fullscreen window hides this screen's desktop.
*/
import QtQuick
import QtQuick.Window
import org.kde.plasma.plasmoid
import org.kde.taskmanager as TaskManager

WallpaperItem {
    id: root

    readonly property var cfg: root.configuration
    property bool covered: false

    accentColor: cfg.ColorA

    AsciiScene {
        anchors.fill: parent

        glyphs: root.cfg.Glyphs
        fontFamily: root.cfg.FontFamily
        fontPixelSize: Math.max(6, root.cfg.FontSize)
        speed: root.cfg.Speed / 100
        zoom: root.cfg.Zoom / 100
        glow: root.cfg.Glow / 100
        fps: root.cfg.Fps
        backgroundColor: root.cfg.BackgroundColor
        colorA: root.cfg.ColorA
        colorB: root.cfg.ColorB
        colorC: root.cfg.ColorC
        colorD: root.cfg.ColorD

        // each monitor shows a different part of the field
        seed: (Screen.virtualX * 7 + Screen.virtualY * 13) / 1000
        running: !(root.cfg.PauseWhenCovered && root.covered)
    }

    // ---- pause when the desktop is not visible anyway ----------------------
    TaskManager.VirtualDesktopInfo { id: desktopInfo }
    TaskManager.ActivityInfo { id: activityInfo }

    TaskManager.TasksModel {
        id: tasks
        sortMode: TaskManager.TasksModel.SortDisabled
        groupMode: TaskManager.TasksModel.GroupDisabled
        screenGeometry: Qt.rect(Screen.virtualX, Screen.virtualY, Screen.width, Screen.height)
        virtualDesktop: desktopInfo.currentDesktop
        activity: activityInfo.currentActivity
        filterByScreen: true
        filterByVirtualDesktop: true
        filterByActivity: true
        filterMinimized: true

        // start(), not restart(): a window being dragged emits changes
        // continuously and must not keep postponing the check.
        onCountChanged: coverCheck.start()
        onDataChanged: coverCheck.start()
        onModelReset: coverCheck.start()
        onVirtualDesktopChanged: coverCheck.start()
        onActivityChanged: coverCheck.start()
        onScreenGeometryChanged: coverCheck.start()
    }

    // A window only hides the desktop if it is maximized/fullscreen AND its
    // frame really spans the screen (a maximized window that is being dragged
    // by its title bar no longer does).
    function desktopHidden() {
        const sw = Screen.width, sh = Screen.height;
        for (let i = 0; i < tasks.count; ++i) {
            const idx = tasks.index(i, 0);
            const big = tasks.data(idx, TaskManager.AbstractTasksModel.IsMaximized) === true
                     || tasks.data(idx, TaskManager.AbstractTasksModel.IsFullScreen) === true;
            if (!big)
                continue;
            const g = tasks.data(idx, TaskManager.AbstractTasksModel.Geometry);
            if (!g || g.width <= 0)
                return true;
            const dx = Math.abs(g.x - Screen.virtualX), dy = g.y - Screen.virtualY;
            if (dx <= 8 && dy >= 0 && dy <= sh * 0.15 && g.width >= sw - 16 && g.height >= sh * 0.8)
                return true;
        }
        return false;
    }

    // Resume instantly, pause only after the desktop has stayed hidden a moment.
    Timer {
        id: coverCheck
        interval: 40
        running: true
        onTriggered: {
            if (root.desktopHidden()) {
                if (!root.covered)
                    pauseDelay.start();
            } else {
                pauseDelay.stop();
                root.covered = false;
            }
        }
    }

    Timer {
        id: pauseDelay
        interval: 700
        onTriggered: root.covered = root.desktopHidden()
    }
}
