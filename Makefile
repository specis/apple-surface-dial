# DialKit release Makefile
#
# Prerequisites:
#   - Xcode Command Line Tools
#   - Apple Developer ID certificate in your keychain
#   - notarytool credentials stored with:
#       xcrun notarytool store-credentials "dialkit-notary" \
#         --apple-id "you@example.com" \
#         --team-id "XXXXXXXXXX" \
#         --password "<app-specific-password>"
#
# Usage:
#   make bundle                  Build and assemble DialKit.app (unsigned)
#   make sign                    Sign with Developer ID (set SIGN_IDENTITY)
#   make notarize                Notarize the signed app
#   make dmg                     Create a distributable DMG
#   make release                 Full pipeline: bundle → sign → notarize → dmg
#   make clean                   Remove build artefacts
#
# Set your Developer ID identity:
#   export SIGN_IDENTITY="Developer ID Application: Your Name (XXXXXXXXXX)"
# Or pass it inline:
#   make release SIGN_IDENTITY="Developer ID Application: Your Name (XXXXXXXXXX)"

APP_NAME        := DialKit
BUNDLE_ID       := com.dialkit.DialKit
VERSION         := 1.0.0
BUILD_NUMBER    := 1

ARCH            := --arch arm64 --arch x86_64
BUILD_DIR       := .build/apple/Products/Release
APP_BUNDLE      := $(APP_NAME).app
DMG_NAME        := $(APP_NAME)-$(VERSION).dmg
STAGING_DIR     := _dmg_staging

NOTARY_PROFILE  := dialkit-notary
SIGN_IDENTITY   ?= Developer ID Application: $(shell security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | sed 's/.*"\(.*\)"/\1/')

.PHONY: all build bundle sign notarize dmg release clean

all: bundle

# ── Build ──────────────────────────────────────────────────────────────────────

build:
	swift build -c release $(ARCH)

# ── Bundle ─────────────────────────────────────────────────────────────────────

bundle: build
	@echo "→ Assembling $(APP_BUNDLE)"
	rm -rf $(APP_BUNDLE)
	mkdir -p $(APP_BUNDLE)/Contents/MacOS
	mkdir -p $(APP_BUNDLE)/Contents/Resources

	# Copy binary (lipo produces universal binary from separate arch builds)
	cp $(BUILD_DIR)/$(APP_NAME) $(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)

	# Inject version into Info.plist and write to bundle
	/usr/libexec/PlistBuddy -c "Copy Resources/Info.plist /tmp/DialKit-Info.plist" /dev/null 2>/dev/null || true
	cp Resources/Info.plist /tmp/DialKit-Info.plist
	/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $(VERSION)" /tmp/DialKit-Info.plist
	/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(BUILD_NUMBER)" /tmp/DialKit-Info.plist
	cp /tmp/DialKit-Info.plist $(APP_BUNDLE)/Contents/Info.plist

	# Copy app icon if present
	@[ -f Resources/AppIcon.icns ] && cp Resources/AppIcon.icns $(APP_BUNDLE)/Contents/Resources/ || true

	@echo "✓ Bundle ready: $(APP_BUNDLE)"

# ── Sign ───────────────────────────────────────────────────────────────────────

sign: bundle
	@echo "→ Signing with: $(SIGN_IDENTITY)"
	codesign \
		--force \
		--deep \
		--options runtime \
		--entitlements Resources/DialKit.entitlements \
		--sign "$(SIGN_IDENTITY)" \
		--timestamp \
		$(APP_BUNDLE)
	@echo "✓ Signed"
	codesign --verify --deep --strict $(APP_BUNDLE)

# ── Notarize ───────────────────────────────────────────────────────────────────

notarize: sign
	@echo "→ Notarizing (this takes 1–5 minutes)"
	ditto -c -k --keepParent $(APP_BUNDLE) $(APP_NAME).zip
	xcrun notarytool submit $(APP_NAME).zip \
		--keychain-profile "$(NOTARY_PROFILE)" \
		--wait
	xcrun stapler staple $(APP_BUNDLE)
	rm $(APP_NAME).zip
	@echo "✓ Notarized and stapled"

# ── DMG ────────────────────────────────────────────────────────────────────────

dmg: notarize
	@echo "→ Creating $(DMG_NAME)"
	rm -rf $(STAGING_DIR) $(DMG_NAME)
	mkdir $(STAGING_DIR)
	cp -r $(APP_BUNDLE) $(STAGING_DIR)/
	ln -s /Applications $(STAGING_DIR)/Applications
	hdiutil create \
		-volname "$(APP_NAME) $(VERSION)" \
		-srcfolder $(STAGING_DIR) \
		-ov \
		-format UDZO \
		-imagekey zlib-level=9 \
		$(DMG_NAME)
	rm -rf $(STAGING_DIR)

	# Sign the DMG too
	codesign --sign "$(SIGN_IDENTITY)" --timestamp $(DMG_NAME)
	@echo "✓ $(DMG_NAME) ready"

# ── Release ────────────────────────────────────────────────────────────────────

release: dmg
	@echo ""
	@echo "══════════════════════════════════════════"
	@echo "  DialKit $(VERSION) release ready"
	@echo "  $(DMG_NAME)"
	@echo "══════════════════════════════════════════"

# ── Clean ──────────────────────────────────────────────────────────────────────

clean:
	rm -rf $(APP_BUNDLE) $(DMG_NAME) $(STAGING_DIR) *.zip .build /tmp/DialKit-Info.plist
