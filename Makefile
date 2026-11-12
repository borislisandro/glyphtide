ID      := io.github.borislisandro.asciidrift
PKG     := package
SHADERS := $(PKG)/contents/shaders
QSB     := $(shell command -v qsb-qt6 || command -v qsb || echo /usr/lib64/qt6/bin/qsb)
QSBS    := $(SHADERS)/field.vert.qsb $(SHADERS)/glyph.frag.qsb

.PHONY: all shaders install uninstall apply restart preview clean

all: shaders

shaders: $(QSBS)

# Compiled shaders are committed, so installing needs no Qt dev tools.
# These rules only run after editing a shader.
%.frag.qsb: %.frag
	$(QSB) --glsl "300 es,150" --hlsl 50 --msl 12 -o $@ $<

# -b: Qt Quick needs the batchable variant of vertex shaders
%.vert.qsb: %.vert
	$(QSB) -b --glsl "300 es,150" --hlsl 50 --msl 12 -o $@ $<

install: shaders
	@if kpackagetool6 -t Plasma/Wallpaper -s $(ID) >/dev/null 2>&1; then \
		kpackagetool6 -t Plasma/Wallpaper -u $(PKG); \
	else \
		kpackagetool6 -t Plasma/Wallpaper -i $(PKG); \
	fi

uninstall:
	kpackagetool6 -t Plasma/Wallpaper -r $(ID)

# Set it as the wallpaper on every screen.
apply:
	./tools/apply.sh $(ID)

# plasmashell caches QML: restart it to pick up a reinstalled version.
restart:
	systemctl --user restart plasma-plasmashell.service

preview: shaders
	python3 tools/preview.py

clean:
	rm -f $(QSBS)
