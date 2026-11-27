/*
    Tells whether a window-switching modifier (Alt or Meta) is held.
    While it is, the task switcher may be revealing the desktop even though
    a fullscreen window still nominally covers it.

    Kept in its own file and loaded through a Loader: the module is private
    to Plasma, and the wallpaper must keep working if it ever goes away.
*/
import QtQuick
import org.kde.plasma.private.keyboardindicator as KeyboardIndicator

QtObject {
    readonly property bool held: alt.pressed || meta.pressed

    readonly property KeyboardIndicator.KeyState alt: KeyboardIndicator.KeyState {
        key: Qt.Key_Alt
    }
    readonly property KeyboardIndicator.KeyState meta: KeyboardIndicator.KeyState {
        key: Qt.Key_Meta
    }
}
