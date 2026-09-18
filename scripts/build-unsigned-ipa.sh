#!/bin/bash

set -euo pipefail

SCRIPT_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIRECTORY="$(cd "$SCRIPT_DIRECTORY/.." && pwd)"
OUTPUT_DIRECTORY="${1:-$PROJECT_DIRECTORY/dist}"
TEMPORARY_DIRECTORY="$(mktemp -d "${TMPDIR:-/tmp}/rendezvous-ipa.XXXXXX")"

cleanup() {
    rm -rf "$TEMPORARY_DIRECTORY"
}

trap cleanup EXIT

DERIVED_DATA_DIRECTORY="$TEMPORARY_DIRECTORY/DerivedData"
PACKAGE_DIRECTORY="$TEMPORARY_DIRECTORY/package"
APP_SOURCE="$DERIVED_DATA_DIRECTORY/Build/Products/Release-iphoneos/Rendezvous.app"
APP_DESTINATION="$PACKAGE_DIRECTORY/Payload/Rendezvous.app"

mkdir -p "$OUTPUT_DIRECTORY" "$PACKAGE_DIRECTORY/Payload"
OUTPUT_DIRECTORY="$(cd "$OUTPUT_DIRECTORY" && pwd)"

echo "Building the unsigned Release app..."
xcodebuild \
    -quiet \
    -project "$PROJECT_DIRECTORY/Rendezvous.xcodeproj" \
    -scheme Rendezvous \
    -configuration Release \
    -destination "generic/platform=iOS" \
    -derivedDataPath "$DERIVED_DATA_DIRECTORY" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY= \
    DEVELOPMENT_TEAM= \
    COMPILER_INDEX_STORE_ENABLE=NO \
    SWIFT_SERIALIZE_DEBUGGING_OPTIONS=NO \
    GCC_GENERATE_DEBUGGING_SYMBOLS=NO \
    DEBUG_INFORMATION_FORMAT= \
    COPY_PHASE_STRIP=YES \
    STRIP_INSTALLED_PRODUCT=YES \
    build

if [[ ! -d "$APP_SOURCE" ]]; then
    echo "error: The Release app was not produced." >&2
    exit 1
fi

ditto "$APP_SOURCE" "$APP_DESTINATION"

# 再署名を妨げる署名情報とローカル生成物をパッケージから除外する
find "$APP_DESTINATION" -type d -name "_CodeSignature" -prune -exec rm -rf {} +
find "$APP_DESTINATION" -type f \( \
    -name "embedded.mobileprovision" -o \
    -name "*.mobileprovision" -o \
    -name ".DS_Store" \
\) -delete
xattr -cr "$APP_DESTINATION"

INFO_PLIST="$APP_DESTINATION/Info.plist"

if [[ ! -f "$INFO_PLIST" ]]; then
    echo "error: Info.plist is missing from the app bundle." >&2
    exit 1
fi

# Xcodeとビルドマシンを識別する自動生成メタデータを削除する
BUILD_METADATA_KEYS=(
    BuildMachineOSBuild
    DTAppStoreToolsBuild
    DTCompiler
    DTPlatformBuild
    DTPlatformName
    DTPlatformVersion
    DTSDKBuild
    DTSDKName
    DTXcode
    DTXcodeBuild
)

while IFS= read -r plist_path; do
    for key in "${BUILD_METADATA_KEYS[@]}"; do
        /usr/libexec/PlistBuddy \
            -c "Delete :$key" \
            "$plist_path" \
            >/dev/null 2>&1 || true
    done
done < <(find "$APP_DESTINATION" -type f -name "Info.plist")

plutil -lint "$INFO_PLIST" >/dev/null

VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST")"
IPA_NAME="Rendezvous-${VERSION}-unsigned.ipa"
IPA_PATH="$OUTPUT_DIRECTORY/$IPA_NAME"
CHECKSUM_PATH="$IPA_PATH.sha256"

rm -f "$IPA_PATH" "$CHECKSUM_PATH"

echo "Packaging $IPA_NAME..."
(
    cd "$PACKAGE_DIRECTORY"
    COPYFILE_DISABLE=1 /usr/bin/zip -qry -X "$IPA_PATH" Payload
)

(
    cd "$OUTPUT_DIRECTORY"
    shasum -a 256 "$IPA_NAME" > "$(basename "$CHECKSUM_PATH")"
)

echo "Created: $IPA_PATH"
echo "Checksum: $CHECKSUM_PATH"
