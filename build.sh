#!/bin/bash
set -e

# ── Config ──────────────────────────────────────────────
BUNDLE_NAME="MMS1eImager"
APP_DISPLAY_NAME="MMS-1e SD Card Imager"
VERSION="1.0.0"
DMG_FILENAME="MMS1e-SD-Card-Imager-${VERSION}"
VOLUME_NAME="${APP_DISPLAY_NAME}"
APP_BUNDLE="build/${BUNDLE_NAME}.app"

MODE="${1:-debug}"

# ── Functions ───────────────────────────────────────────

ensure_icon() {
    if [ ! -f "Resources/AppIcon.icns" ]; then
        echo "==> Generating app icon..."
        python3 scripts/gen_icon.py
    fi
}

build_release_universal() {
    echo "==> Building Universal Binary (arm64 + x86_64)..."
    swift build -c release --arch arm64 --arch x86_64
}

# Universal builds output to .build/apple/Products/Release/
# Single-arch builds output to .build/release/
find_binary() {
    local name="$1"
    local universal=".build/apple/Products/Release/${name}"
    local single=".build/release/${name}"
    if [ -f "${universal}" ]; then
        echo "${universal}"
    elif [ -f "${single}" ]; then
        echo "${single}"
    else
        echo "ERROR: Cannot find ${name}" >&2
        exit 1
    fi
}

create_app_bundle() {
    echo "==> Creating .app bundle..."
    rm -rf "${APP_BUNDLE}"
    mkdir -p "${APP_BUNDLE}/Contents/MacOS"
    mkdir -p "${APP_BUNDLE}/Contents/Resources"

    cp "$(find_binary MMS1eImager)" "${APP_BUNDLE}/Contents/MacOS/"
    cp "$(find_binary mms-writer)"  "${APP_BUNDLE}/Contents/MacOS/"
    cp "Resources/Info.plist"       "${APP_BUNDLE}/Contents/"
    cp "Resources/AppIcon.icns"     "${APP_BUNDLE}/Contents/Resources/"
    echo -n "APPL????" > "${APP_BUNDLE}/Contents/PkgInfo"

    # Verify architecture
    local arch_info
    arch_info=$(file "${APP_BUNDLE}/Contents/MacOS/MMS1eImager")
    if echo "${arch_info}" | grep -q "universal"; then
        echo "    Universal Binary (arm64 + x86_64)"
    else
        echo "    $(uname -m) only"
    fi
    echo "    ${APP_BUNDLE}"
}

create_dmg() {
    echo "==> Creating DMG..."

    local DMG_FINAL="build/${DMG_FILENAME}.dmg"
    local DMG_RW="build/_tmp_rw.dmg"
    local STAGING="build/_dmg_staging"

    rm -f "${DMG_FINAL}" "${DMG_RW}"
    rm -rf "${STAGING}"

    # Prepare staging folder
    mkdir -p "${STAGING}"
    cp -R "${APP_BUNDLE}" "${STAGING}/"
    ln -s /Applications "${STAGING}/Applications"

    # Calculate size (app size + 10 MB headroom)
    local SIZE_KB
    SIZE_KB=$(du -sk "${STAGING}" | awk '{print $1}')
    SIZE_KB=$(( SIZE_KB + 10240 ))

    # Create writable DMG
    hdiutil create \
        -size "${SIZE_KB}k" \
        -fs HFS+ \
        -volname "${VOLUME_NAME}" \
        -type UDIF \
        -layout NONE \
        "${DMG_RW}" \
        > /dev/null

    # Mount writable DMG
    local MOUNT_OUTPUT
    MOUNT_OUTPUT=$(hdiutil attach -readwrite -noverify -noautoopen "${DMG_RW}")
    local DEVICE
    DEVICE=$(echo "${MOUNT_OUTPUT}" | grep '/dev/disk' | head -1 | awk '{print $1}')
    local MOUNT_POINT="/Volumes/${VOLUME_NAME}"

    # Copy contents into mounted DMG
    cp -R "${STAGING}/"* "${MOUNT_POINT}/"

    # Set Finder window layout
    echo "    Setting Finder layout..."
    osascript <<APPLESCRIPT
tell application "Finder"
    tell disk "${VOLUME_NAME}"
        open
        delay 1
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 120, 720, 400}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 80
        set position of item "${BUNDLE_NAME}.app" of container window to {130, 140}
        set position of item "Applications" of container window to {390, 140}
        close
    end tell
end tell
APPLESCRIPT

    sync
    sleep 1

    # Detach
    hdiutil detach "${DEVICE}" -quiet 2>/dev/null || hdiutil detach "${DEVICE}" -force -quiet

    # Convert to compressed read-only DMG
    echo "    Compressing..."
    hdiutil convert "${DMG_RW}" \
        -format UDZO \
        -imagekey zlib-level=9 \
        -o "${DMG_FINAL}" \
        > /dev/null

    # Cleanup
    rm -f "${DMG_RW}"
    rm -rf "${STAGING}"

    local SIZE_HUMAN
    SIZE_HUMAN=$(du -h "${DMG_FINAL}" | awk '{print $1}')
    echo ""
    echo "==> DMG ready: ${DMG_FINAL} (${SIZE_HUMAN})"
    echo "    Volume: ${VOLUME_NAME}"
    echo "    Min macOS: 10.15 (Catalina)"
    echo "    Arch: Universal (arm64 + x86_64)"
}

# ── Main ────────────────────────────────────────────────

case "${MODE}" in
    debug)
        echo "Building debug..."
        swift build
        echo "Launching..."
        open .build/debug/${BUNDLE_NAME}
        ;;
    release)
        ensure_icon
        build_release_universal
        create_app_bundle
        echo ""
        echo "==> Done. Launching..."
        open "${APP_BUNDLE}"
        ;;
    dmg)
        ensure_icon
        build_release_universal
        create_app_bundle
        create_dmg
        ;;
    clean)
        echo "Cleaning..."
        rm -rf .build build
        echo "Done."
        ;;
    *)
        echo "Usage: $0 [debug|release|dmg|clean]"
        exit 1
        ;;
esac
