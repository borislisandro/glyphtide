# ascii-drift

An animated ASCII wallpaper for KDE Plasma 6, drawn entirely in monospace
glyphs in a crimson / orange / magenta palette on black. Four patterns, which
it can cycle through by slowly morphing one into the next:

| | |
|---|---|
| **Drift** — translucent sheets sliding over each other | **Dunes** — layered ridgelines rolling sideways |
| **Ripples** — rings spreading from wandering sources | **Aurora** — hanging curtains of light that sway |

![patterns](docs/patterns.png)

It is not a separate program. It comes as two small Plasma add-ons that the
desktop shell itself loads:

- a **wallpaper plugin** — shows up in *Desktop and Wallpaper* settings, keeps
  desktop icons and widgets working, and runs independently on each monitor;
- a **system tray widget** (the `#` icon) — a quick settings panel for the
  wallpaper: pattern, cycle interval, speed, glyph size, shape size, pausing.

## Install

```sh
make install   # install (or upgrade) the wallpaper and the tray widget
make apply     # set it as the wallpaper on every screen
```

Or pick **ASCII Drift** by hand under *Right click desktop → Desktop and
Wallpaper → Wallpaper type*. To go back, choose *Image* there again.

Requirements: Plasma 6 and a monospace font (default: JetBrains Mono). The
compiled shaders are committed, so no build tools are needed to install.

After upgrading an already-running version, run `make restart` (restarts
plasmashell) to load the new code.

## Settings

The tray widget covers the everyday ones; everything is in *Right click
desktop → Desktop and Wallpaper*.

| Setting | Default | |
|---|---|---|
| Pattern | cycle | or pin Drift, Dunes, Ripples or Aurora |
| Change every | 10 min | how long each pattern stays when cycling |
| Glyphs | `` .:-=+*#%@`` | the ramp, from emptiest to densest |
| Font / glyph size | JetBrains Mono, 16 px | smaller = finer grid |
| Speed | 100 % | 0 freezes it |
| Shape size | 100 % | |
| Glow | 12 % | soft colour behind the glyphs |
| Frame rate cap | 0 | 0 follows the display refresh rate; a cap skips whole frames |
| Pause when covered | on | stops animating under a maximized/fullscreen window, resumes the moment it moves |
| Colours | CrimsonDark palette | background + four sheet colours |

## How it works

One draw call, and only its uniforms change from frame to frame:

1. `field.vert` — the mesh has one vertex per character-cell corner (about
   250 × 70 on a 1440p screen), and the vertex shader computes the field
   there: four domain-warped noise "sheets", each with a dense rim of constant
   on-screen width, a stippled interior and fading contour lines. So the
   expensive maths runs a few thousand times per frame, not millions.
2. `glyph.frag` — each pixel extrapolates the interpolated field to the centre
   of its own cell, so the whole cell agrees on one colour and density, then
   draws the matching glyph from an atlas that QML renders once from the
   chosen font. Adjacent glyphs in the ramp are cross-faded so density changes
   morph instead of popping.

The animation clock follows the display's frame clock, so it runs at the
monitor's refresh rate with even pacing.

## Cost

Measured on a 12-thread desktop with an RTX 2060 Super, two monitors
(2560×1440 @ 180 Hz and 1080×1920 @ 165 Hz) both animating at display rate,
against the same session with a static image wallpaper. Readings are noisy
because the rest of the desktop was in use.

| | static image | ascii-drift |
|---|---|---|
| plasmashell CPU (share of one core) | 8–11 % | 12–16 % |
| GPU load (whole system) | 28–29 % | 31–32 % |
| plasmashell video memory | 119–123 MiB | 104–108 MiB |
| plasmashell RAM growth | ~1.5 MiB/min | ~2.2 MiB/min |

While a maximized or fullscreen window covers a screen the animation is
paused and costs nothing.

An earlier two-pass design (field rendered to a small texture every frame)
made plasmashell grow by 4–5 MiB/min on this NVIDIA/Wayland setup; the
single-pass design exists to avoid that.

```
package/                     the Plasma wallpaper package
  contents/ui/AsciiScene.qml   the animation (pure QtQuick)
  contents/ui/main.qml         Plasma wrapper + pause logic
  contents/ui/config.qml       settings page
widget/                      the system tray widget
  contents/ui/main.qml         the popup
  contents/tools/ctl.sh        reads/writes the wallpaper settings via Plasma scripting
  contents/shaders/            shader sources (+ compiled .qsb)
tools/preview.py             run the scene in a window (needs PySide6)
tools/apply.sh               set as wallpaper on all screens
tools/add-to-tray.sh         put the widget in the system tray
```

## Hacking

```sh
make preview                                   # live window
tools/preview.py --size 1080x1920 --seed 2.5   # portrait, other part of the field
tools/preview.py --shot out.png --time 40      # render one frame
tools/preview.py --set pattern=3                # 0 Drift, 1 Dunes, 2 Ripples, 3 Aurora
```

Editing a shader needs `qsb` (Fedora: `qt6-qtshadertools`); `make` rebuilds
the `.qsb` files.

## License

MIT
