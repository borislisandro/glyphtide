#!/usr/bin/env python3
"""Run the animation in a normal window, without touching the wallpaper.

    tools/preview.py                       # live window
    tools/preview.py --size 1080x1920      # portrait
    tools/preview.py --shot out.png --time 40   # render one frame and exit

Needs PySide6 (Fedora: python3-pyside6).
"""
import argparse
import sys
from pathlib import Path

from PySide6.QtCore import QTimer, QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQuick import QQuickView

SCENE = Path(__file__).resolve().parent.parent / "package/contents/ui/AsciiScene.qml"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--size", default="1280x720", help="window size, WxH")
    ap.add_argument("--shot", metavar="PNG", help="save one frame to this file and exit")
    ap.add_argument("--time", type=float, help="freeze the animation clock at this value (seconds)")
    ap.add_argument("--seed", type=float, default=0.0)
    ap.add_argument("--set", action="append", default=[], metavar="PROP=VALUE",
                    help="override a scene property, e.g. --set fontPixelSize=20")
    args = ap.parse_args()
    w, h = (int(x) for x in args.size.lower().split("x"))

    app = QGuiApplication(sys.argv[:1])
    view = QQuickView()
    view.setTitle("glyphtide preview")
    view.setResizeMode(QQuickView.ResizeMode.SizeRootObjectToView)

    props = {"seed": args.seed}
    if args.time is not None:
        props.update(running=False, time=args.time)
    for item in args.set:
        key, _, value = item.partition("=")
        try:
            props[key] = float(value) if "." in value else int(value)
        except ValueError:
            props[key] = value
    view.setInitialProperties(props)

    view.setSource(QUrl.fromLocalFile(str(SCENE)))
    if view.status() != QQuickView.Status.Ready:
        for err in view.errors():
            print(err.toString(), file=sys.stderr)
        return 1
    view.resize(w, h)
    view.show()

    if args.shot:
        def grab():
            ok = view.grabWindow().save(args.shot)
            print(f"{'saved' if ok else 'FAILED to save'} {args.shot}")
            app.quit()
        QTimer.singleShot(2600, grab)  # after the fade-in

    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
