SHELL := /bin/bash
APP_NAME := SiekerCheck
BUNDLE := .build/$(APP_NAME).app
EXECUTABLE := $(BUNDLE)/Contents/MacOS/$(APP_NAME)
# The newest Command Line Tools SDK can be newer than the installed swiftc,
# which refuses it; pick-sdk.sh probes for one this compiler accepts.
SDK ?= $(shell scripts/pick-sdk.sh $(SWIFT_TARGET))
SWIFT_TARGET ?= arm64-apple-macosx15.0
INSTALL_DIR ?= $(HOME)/Applications
INSTALLED_APP := $(INSTALL_DIR)/$(APP_NAME).app

VERSION ?= 1.0
ICONSET := Resources/AppIcon.iconset
ICNS := Resources/AppIcon.icns
DMG := .build/$(APP_NAME)-$(VERSION).dmg

FRAMEWORKS := -framework AppKit -framework SwiftUI -framework AVFoundation \
	-framework CoreAudio -framework CoreMedia -framework IOKit \
	-framework CoreGraphics -framework UniformTypeIdentifiers

SOURCES := $(shell find Sources/SiekerCheck -name '*.swift' | sort)
# The dependency-free slice that the headless test target compiles on its own.
LOGIC_SOURCES := Sources/SiekerCheck/Core/PixelSequence.swift \
	Sources/SiekerCheck/Core/ToneMath.swift \
	Sources/SiekerCheck/Core/KeyboardLayout.swift \
	Sources/SiekerCheck/Core/BatteryReport.swift \
	Sources/SiekerCheck/Core/ReportBuilder.swift

.PHONY: build run check test icon dmg-background dmg install uninstall clean

build:
	mkdir -p .build
	swiftc -target $(SWIFT_TARGET) -sdk $(SDK) -O -swift-version 5 $(FRAMEWORKS) $(SOURCES) -o .build/$(APP_NAME)
	mkdir -p $(BUNDLE)/Contents/MacOS $(BUNDLE)/Contents/Resources
	cp .build/$(APP_NAME) $(EXECUTABLE)
	cp Resources/Info.plist $(BUNDLE)/Contents/Info.plist
	cp $(ICNS) $(BUNDLE)/Contents/Resources/$(APP_NAME).icns
	codesign --force --deep --sign - $(BUNDLE)

check:
	swiftc -typecheck -target $(SWIFT_TARGET) -sdk $(SDK) -swift-version 5 $(FRAMEWORKS) $(SOURCES)
	plutil -lint Resources/Info.plist
	@/usr/libexec/PlistBuddy -c 'Print :NSMicrophoneUsageDescription' Resources/Info.plist >/dev/null \
		&& echo "Info.plist: microphone usage string present"
	@/usr/libexec/PlistBuddy -c 'Print :NSCameraUsageDescription' Resources/Info.plist >/dev/null \
		&& echo "Info.plist: camera usage string present"

test:
	mkdir -p .build
	swiftc -target $(SWIFT_TARGET) -sdk $(SDK) -swift-version 5 -parse-as-library \
		$(LOGIC_SOURCES) test/logic_tests.swift -o .build/logic-tests
	.build/logic-tests

# Redraws the icon from scripts/make-icon.swift. The .icns is committed so a
# normal build does not need this step.
icon:
	mkdir -p .build
	swiftc -target $(SWIFT_TARGET) -sdk $(SDK) -O -parse-as-library \
		-framework CoreGraphics -framework ImageIO \
		scripts/IconArt.swift scripts/make-icon.swift -o .build/make-icon
	.build/make-icon $(ICONSET)
	iconutil -c icns $(ICONSET) -o $(ICNS)
	@echo "wrote $(ICNS)"

# Redraws the installer window background. Both are committed so a normal
# build does not need these steps.
dmg-background:
	mkdir -p .build
	swiftc -target $(SWIFT_TARGET) -sdk $(SDK) -O -parse-as-library \
		-framework CoreGraphics -framework CoreText -framework ImageIO \
		scripts/IconArt.swift scripts/make-dmg-background.swift -o .build/make-dmg-background
	.build/make-dmg-background Resources

# A drag-to-Applications installer image: the app plus an /Applications
# symlink, compressed read-only so it mounts instantly and cannot be edited.
# The app inside is ad-hoc signed, so another Mac needs the usual
# right-click -> Open (or its own Developer ID signature) on first launch.
dmg: build dmg-background
	rm -rf .build/dmg .build/$(APP_NAME)-rw.dmg
	mkdir -p .build/dmg/.background
	cp -R $(BUNDLE) .build/dmg/$(APP_NAME).app
	ln -s /Applications .build/dmg/Applications
	# Finder looks for exactly "background.png" and auto-detects background@2x.png.
	cp Resources/dmg-background.png .build/dmg/.background/background.png
	cp Resources/dmg-background@2x.png .build/dmg/.background/background@2x.png
	# Finder can only write the window layout into a mounted read-write image,
	# so build one, lay it out, then compress the result.
	hdiutil create -quiet -volname $(APP_NAME) -srcfolder .build/dmg -ov -format UDRW .build/$(APP_NAME)-rw.dmg
	hdiutil attach -quiet -nobrowse .build/$(APP_NAME)-rw.dmg -mountpoint /Volumes/$(APP_NAME)
	-osascript scripts/layout-dmg.applescript $(APP_NAME) $(APP_NAME) || true
	hdiutil detach -quiet /Volumes/$(APP_NAME)
	diskutil image create from .build/$(APP_NAME)-rw.dmg --format UDZO $(DMG)
	rm -f .build/$(APP_NAME)-rw.dmg
	@echo "wrote $(DMG)"

run: build
	open $(BUNDLE)

# Puts a launchable copy in ~/Applications so a stable path owns the
# microphone/camera permission grant instead of a build folder that changes.
install: build
	mkdir -p $(INSTALL_DIR)
	-pkill -x $(APP_NAME)
	sleep 1
	rm -rf $(INSTALLED_APP)
	cp -R $(BUNDLE) $(INSTALLED_APP)
	-xattr -cr $(INSTALLED_APP)
	codesign --force --deep --sign - $(INSTALLED_APP)
	/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f $(INSTALLED_APP)
	@echo "Installed $(INSTALLED_APP) - open it from Launchpad, or: open $(INSTALLED_APP)"

uninstall:
	pkill -x $(APP_NAME) 2>/dev/null || true
	rm -rf $(INSTALLED_APP)
	/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u $(INSTALLED_APP) 2>/dev/null || true
	@echo "Removed $(INSTALLED_APP)"

clean:
	rm -rf .build
