APP := build/DockAnchor.app
INSTALL_DIR ?= /Applications
BIN_DIR ?= $(HOME)/.local/bin
# A stable identity keeps the Accessibility grant across rebuilds; ad-hoc ("-") forces a re-grant every build.
SIGN_IDENTITY ?= $(shell security find-identity -v -p codesigning 2>/dev/null | grep -m1 -o '"Apple Development[^"]*"' | tr -d '"' || true)
SIGN := $(if $(SIGN_IDENTITY),$(SIGN_IDENTITY),-)

.PHONY: app icon test install uninstall run release clean

app:
	swift build -c release --product DockAnchorApp
	swift build -c release --product dockanchor
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Helpers $(APP)/Contents/Resources
	cp Resources/Info.plist $(APP)/Contents/Info.plist
	cp Resources/AppIcon.icns $(APP)/Contents/Resources/AppIcon.icns
	cp "$$(swift build -c release --show-bin-path)/DockAnchorApp" $(APP)/Contents/MacOS/DockAnchor
	cp "$$(swift build -c release --show-bin-path)/dockanchor" $(APP)/Contents/Helpers/dockanchor
	codesign --force --sign "$(SIGN)" --identifier io.frbarbre.dockanchor.cli $(APP)/Contents/Helpers/dockanchor
	codesign --force --sign "$(SIGN)" $(APP)
	@echo "Built $(APP) (signed with: $(SIGN))"

icon:
	rm -rf build/icon && mkdir -p build/icon/AppIcon.iconset
	swift scripts/make-icon.swift build/icon/icon.png
	for s in 16 32 128 256 512; do \
		sips -z $$s $$s build/icon/icon.png --out build/icon/AppIcon.iconset/icon_$${s}x$${s}.png >/dev/null; \
		sips -z $$((s*2)) $$((s*2)) build/icon/icon.png --out build/icon/AppIcon.iconset/icon_$${s}x$${s}@2x.png >/dev/null; \
	done
	iconutil -c icns build/icon/AppIcon.iconset -o Resources/AppIcon.icns

test:
	swift test

install: app
	-pkill -x DockAnchor
	rm -rf "$(INSTALL_DIR)/DockAnchor.app"
	cp -R $(APP) "$(INSTALL_DIR)/"
	mkdir -p "$(BIN_DIR)"
	ln -sf "$(INSTALL_DIR)/DockAnchor.app/Contents/Helpers/dockanchor" "$(BIN_DIR)/dockanchor"
	open "$(INSTALL_DIR)/DockAnchor.app"

uninstall:
	-pkill -x DockAnchor
	rm -rf "$(INSTALL_DIR)/DockAnchor.app" "$(BIN_DIR)/dockanchor"

run: app
	-pkill -x DockAnchor
	open $(APP)

release:
	./scripts/release.sh

clean:
	rm -rf .build build
