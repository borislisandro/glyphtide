# Glyphtide

An animated ASCII wallpaper for KDE Plasma 6: slow, flowing shapes drawn
entirely out of text characters.

![Glyphtide, Drift pattern](docs/preview.png)

It has four patterns and can cycle through them, morphing from one to the next:

- **Drift** (pictured): translucent sheets sliding over each other
- **Dunes**: layered ridgelines rolling sideways
- **Ripples**: rings spreading from wandering points
- **Aurora**: curtains of light hanging from the top of the screen

## Use

Requires KDE Plasma 6 (Wayland or X11) and a monospace font.

```sh
make install   # installs the wallpaper and a tray icon
make apply     # sets it as the wallpaper on every screen
```

Click the `#` icon in the system tray to pick a pattern, speed and size.
Colours, glyphs and font are under *right-click desktop → Desktop and Wallpaper*.

To go back, choose *Image* as the wallpaper type; `make uninstall` removes it.

## License

MIT
