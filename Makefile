ID      := io.github.borislisandro.glyphtide
PKG     := package
SHADERS := $(PKG)/contents/shaders
QSB     := $(shell command -v qsb-qt6 || command -v qsb || echo /usr/lib64/qt6/bin/qsb)
QSBS    := $(SHADERS)/field.vert.qsb $(SHADERS)/glyph.frag.qsb

.PHONY: all shaders install uninstall apply tray restart preview clean

all: shaders

shaders: $(QSBS)

# Compiled shaders are committed, so installing needs no Qt dev tools.
# These rules only run after editing a shader.
%.frag.qsb: %.frag
	$(QSB) --glsl "300 es,150" --hlsl 50 --msl 12 -o $@ $<

# -b: Qt Quick needs the batchable variant of vertex shaders
%.vert.qsb: %.vert
	$(QSB) -b --glsl "300 es,150" --hlsl 50 --msl 12 -o $@ $<

# install-or-upgrade a package: $(call kpkg,<type>,<id>,<dir>)
define kpkg
	@if kpackagetool6 -t $(1) -s $(2) >/dev/null 2>&1; then \
		kpackagetool6 -t $(1) -u $(3); \
	else \
		kpackagetool6 -t $(1) -i $(3); \
	fi
endef

install: shaders
	$(call kpkg,Plasma/Wallpaper,$(ID),$(PKG))
	$(call kpkg,Plasma/Applet,$(ID).widget,widget)
	@sleep 1; ./tools/add-to-tray.sh $(ID).widget

uninstall:
	-kpackagetool6 -t Plasma/Wallpaper -r $(ID)
	-kpackagetool6 -t Plasma/Applet -r $(ID).widget

# Set it as the wallpaper on every screen.
apply:
	./tools/apply.sh $(ID)

# Show the settings widget in the system tray.
tray:
	./tools/add-to-tray.sh $(ID).widget

# plasmashell caches QML: restart it to pick up a reinstalled version.
restart:
	systemctl --user restart plasma-plasmashell.service

preview: shaders
	python3 tools/preview.py

clean:
	rm -f $(QSBS)
