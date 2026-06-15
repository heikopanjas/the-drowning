#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
PROJECT="${ROOT}/TheDrowning.xcodeproj"
PROJECT_SPEC="${ROOT}/project.yml"
SCHEME="TheDrowning"
APP_NAME="The Drowning"
ARCHIVE_NAME="TheDrowning"
BUILD_DIR="${ROOT}/.build"
DERIVED_DATA="${BUILD_DIR}/DerivedData"
DEBUG_APP="${BUILD_DIR}/Products/Debug/${APP_NAME}.app"
ARCHIVE_PATH="${BUILD_DIR}/${ARCHIVE_NAME}.xcarchive"
EXPORT_PATH="${BUILD_DIR}/export"
EXPORT_PLIST="${ROOT}/exportOptions.plist"
NOTARIZE_PROFILE="${NOTARIZE_PROFILE:-TheDrowning-Notarize}"
BUILD_ARCH="arm64"
DEBUG_DESTINATION="platform=macOS,arch=${BUILD_ARCH}"
RELEASE_DESTINATION="generic/platform=macOS"
TEAM_ID="8J2G689FCZ"
ZIP_PATH="${BUILD_DIR}/${ARCHIVE_NAME}.zip"

RELEASE=false
CLEAN=false
NOTARIZE=false

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Build The Drowning macOS app from the generated root Xcode project.
Apple Silicon (arm64) only - not a universal binary.

Modes:
    (default)     Debug build -> ${DEBUG_APP}
    --release     Release archive + Developer ID export -> ${EXPORT_PATH}/${APP_NAME}.app

Options:
    --release     Clean, archive, export, and optionally notarize for distribution
    --clean       Clean build artifacts before a debug build (release always cleans)
    --notarize    Submit the exported release app for notarization and staple
                  (requires --release)
    -h, --help    Show this help message

Examples:
    $(basename "$0")                      # Debug build
    $(basename "$0") --clean              # Clean, then debug build
    $(basename "$0") --release            # Clean, archive, and export
    $(basename "$0") --release --notarize # Clean, archive, export, notarize, and staple

Release builds use this Developer ID export options plist:
    ${EXPORT_PLIST}

Notarization (--notarize) requires a notarytool Keychain profile (default: ${NOTARIZE_PROFILE}).
Create it once with an app-specific password from account.apple.com:

    xcrun notarytool store-credentials "${NOTARIZE_PROFILE}" \\
      --apple-id "you@example.com" \\
      --team-id ${TEAM_ID} \\
      --password "xxxx-xxxx-xxxx-xxxx"

Override profile name: NOTARIZE_PROFILE=my-profile $(basename "$0") --release --notarize
EOF
    exit 0
}

for arg in "$@"; do
    case "$arg" in
        --release) RELEASE=true ;;
        --clean) CLEAN=true ;;
        --notarize) NOTARIZE=true ;;
        -h|--help) usage ;;
        *)
            echo "Unknown option: $arg" >&2
            usage
            ;;
    esac
done

if [ "$NOTARIZE" = true ] && [ "$RELEASE" = false ]; then
    echo "Error: --notarize requires --release." >&2
    exit 1
fi

if [ "$RELEASE" = true ]; then
    CLEAN=true
fi

require_xcode() {
    if xcodebuild -version &>/dev/null; then
        return 0
    fi

    echo "Error: xcodebuild requires full Xcode.app, not Command Line Tools alone." >&2
    echo "" >&2

    local active_dir="(unknown)"
    if active_dir="$(xcode-select -p 2>/dev/null)"; then
        echo "Active developer directory: ${active_dir}" >&2
    fi

    local -a xcode_apps=()
    local candidate
    for candidate in /Applications/Xcode.app /Applications/Xcode-beta.app; do
        if [ -d "$candidate" ]; then
            xcode_apps+=("$candidate")
        fi
    done

    if [ "${#xcode_apps[@]}" -gt 0 ]; then
        echo "" >&2
        echo "Found Xcode installation(s). Point xcode-select at one of them:" >&2
        for candidate in "${xcode_apps[@]}"; do
            echo "  sudo xcode-select -s \"${candidate}/Contents/Developer\"" >&2
        done
        echo "" >&2
        echo "Or run this build once without changing the global setting:" >&2
        echo "  DEVELOPER_DIR=\"${xcode_apps[0]}/Contents/Developer\" $(basename "$0")" >&2
    else
        echo "" >&2
        echo "Install Xcode from the App Store, then run:" >&2
        echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer" >&2
    fi

    exit 1
}

require_project() {
    if [ -d "$PROJECT" ]; then
        return 0
    fi

    echo "Error: missing generated project: ${PROJECT}" >&2
    echo "Regenerate it from ${PROJECT_SPEC} with: xcodegen generate" >&2
    exit 1
}

require_export_options() {
    if [ -f "$EXPORT_PLIST" ]; then
        return 0
    fi

    echo "Error: missing export options plist: ${EXPORT_PLIST}" >&2
    echo "Release builds require the checked-in Developer ID export options file." >&2
    exit 1
}

read_build_version() {
    local settings
    if ! settings="$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -showBuildSettings 2>&1)"; then
        echo "Error: failed to read build settings from ${PROJECT}" >&2
        echo "$settings" >&2
        exit 1
    fi

    VERSION="$(echo "$settings" | awk '/MARKETING_VERSION/ { print $3; exit }')"
    BUILD_NUMBER="$(echo "$settings" | awk '/CURRENT_PROJECT_VERSION/ { print $3; exit }')"

    if [ -z "$VERSION" ] || [ -z "$BUILD_NUMBER" ]; then
        echo "Error: could not read MARKETING_VERSION or CURRENT_PROJECT_VERSION from ${PROJECT}" >&2
        exit 1
    fi
}

check_notary_profile() {
    if xcrun notarytool history --keychain-profile "$NOTARIZE_PROFILE" &>/dev/null; then
        return 0
    fi

    echo "Error: notarytool Keychain profile not found: ${NOTARIZE_PROFILE}" >&2
    echo "" >&2
    echo "Create credentials (one-time):" >&2
    echo "  xcrun notarytool store-credentials \"${NOTARIZE_PROFILE}\" \\" >&2
    echo "    --apple-id \"YOUR_APPLE_ID\" \\" >&2
    echo "    --team-id ${TEAM_ID} \\" >&2
    echo "    --password \"APP_SPECIFIC_PASSWORD\"" >&2
    echo "" >&2
    echo "App-specific password: https://account.apple.com/account/manage" >&2
    echo "Or set NOTARIZE_PROFILE to an existing profile name." >&2
    return 1
}

build_debug() {
    if [ "$CLEAN" = true ]; then
        echo "==> Cleaning (Debug)..."
        xcodebuild \
            -project "$PROJECT" \
            -scheme "$SCHEME" \
            -configuration Debug \
            -destination "$DEBUG_DESTINATION" \
            -derivedDataPath "$DERIVED_DATA" \
            clean -quiet
        echo "    Done."
        echo ""
    fi

    echo "==> Building (Debug)..."
    xcodebuild \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -configuration Debug \
        -destination "$DEBUG_DESTINATION" \
        -derivedDataPath "$DERIVED_DATA" \
        build -quiet
    echo "    App: ${DEBUG_APP}"
    echo ""
    echo "==> Build complete: ${DEBUG_APP}"
}

build_release() {
    require_export_options

    if [ "$CLEAN" = true ]; then
        echo "==> Cleaning (Release)..."
        xcodebuild \
            -project "$PROJECT" \
            -scheme "$SCHEME" \
            -destination "$RELEASE_DESTINATION" \
            clean -quiet
        rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH" "$ZIP_PATH"
        echo "    Done."
        echo ""
    fi

    mkdir -p "$BUILD_DIR"

    echo "==> Archiving (Release)..."
    xcodebuild archive \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -configuration Release \
        -destination "$RELEASE_DESTINATION" \
        -archivePath "$ARCHIVE_PATH" \
        -quiet
    echo "    Archive: ${ARCHIVE_PATH}"
    echo ""

    echo "==> Exporting with Developer ID signing..."
    rm -rf "$EXPORT_PATH"
    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportPath "$EXPORT_PATH" \
        -exportOptionsPlist "$EXPORT_PLIST" \
        -quiet
    echo "    App: ${EXPORT_PATH}/${APP_NAME}.app"
    echo ""

    if [ "$NOTARIZE" = true ]; then
        check_notary_profile

        echo "==> Creating zip for notarization..."
        rm -f "$ZIP_PATH"
        ditto -c -k --keepParent "${EXPORT_PATH}/${APP_NAME}.app" "$ZIP_PATH"
        echo "    Zip: ${ZIP_PATH}"
        echo ""

        echo "==> Submitting for notarization (this may take a few minutes)..."
        xcrun notarytool submit "$ZIP_PATH" \
            --keychain-profile "$NOTARIZE_PROFILE" \
            --wait
        echo ""

        echo "==> Stapling notarization ticket..."
        xcrun stapler staple "${EXPORT_PATH}/${APP_NAME}.app"
        echo ""

        echo "==> Verifying..."
        spctl -a -vvv "${EXPORT_PATH}/${APP_NAME}.app" 2>&1 | head -5
        echo ""

        rm -f "$ZIP_PATH"
    fi

    echo "==> Build complete: ${EXPORT_PATH}/${APP_NAME}.app"
}

require_xcode
require_project
read_build_version

echo "==> The Drowning ${VERSION} (${BUILD_NUMBER})"
echo ""

if [ "$RELEASE" = true ]; then
    build_release
else
    build_debug
fi
