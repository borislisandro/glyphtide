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

        onCountChanged: coverCheck.restart()
        onDataChanged: coverCheck.restart()
        onModelReset: coverCheck.restart()
        onVirtualDesktopChanged: coverCheck.restart()
        onScreenGeometryChanged: coverCheck.restart()
    }

    Timer {
        id: coverCheck
        interval: 150
        running: true
        onTriggered: {
            let hidden = false;
            for (let i = 0; i < tasks.count && !hidden; ++i) {
                const idx = tasks.index(i, 0);
                hidden = tasks.data(idx, TaskManager.AbstractTasksModel.IsMaximized) === true
                      || tasks.data(idx, TaskManager.AbstractTasksModel.IsFullScreen) === true;
            }
            root.covered = hidden;
        }
    }
}
