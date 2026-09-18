#!/bin/bash

set -euo pipefail

fail() {
    echo "verification failed: $1" >&2
    exit 1
}

if [[ $# -ne 1 ]]; then
    echo "usage: $0 <path-to-ipa>" >&2
    exit 64
fi

IPA_PATH="$1"

if [[ ! -f "$IPA_PATH" ]]; then
    fail "IPA file does not exist."
fi

AUDIT_DIRECTORY="$(mktemp -d "${TMPDIR:-/tmp}/rendezvous-ipa-audit.XXXXXX")"

cleanup() {
    rm -rf "$AUDIT_DIRECTORY"
}

trap cleanup EXIT

unzip -tqq "$IPA_PATH" || fail "ZIP structure is damaged."

# 絶対パスや親ディレクトリ参照を含む危険なZIPエントリを拒否する
if zipinfo -1 "$IPA_PATH" | grep -Eq '(^/|(^|/)\.\.(/|$))'; then
    fail "IPA contains an unsafe ZIP path."
fi

unzip -q "$IPA_PATH" -d "$AUDIT_DIRECTORY"

if [[ ! -d "$AUDIT_DIRECTORY/Payload" ]]; then
    fail "Payload directory is missing."
fi

UNEXPECTED_TOP_LEVEL="$(
    find "$AUDIT_DIRECTORY" \
        -mindepth 1 \
        -maxdepth 1 \
        ! -name Payload \
        -print \
        -quit
)"

if [[ -n "$UNEXPECTED_TOP_LEVEL" ]]; then
    fail "IPA contains data outside Payload."
fi

APP_COUNT="$(
    find "$AUDIT_DIRECTORY/Payload" \
        -mindepth 1 \
        -maxdepth 1 \
        -type d \
        -name "*.app" \
        | wc -l \
        | tr -d ' '
)"

if [[ "$APP_COUNT" != "1" ]]; then
    fail "Payload must contain exactly one app bundle."
fi

APP_DIRECTORY="$(
    find "$AUDIT_DIRECTORY/Payload" \
        -mindepth 1 \
        -maxdepth 1 \
        -type d \
        -name "*.app" \
        -print \
        -quit
)"
INFO_PLIST="$APP_DIRECTORY/Info.plist"

if [[ ! -f "$INFO_PLIST" ]]; then
    fail "Info.plist is missing."
fi

plutil -lint "$INFO_PLIST" >/dev/null || fail "Info.plist is invalid."

BUNDLE_IDENTIFIER="$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$INFO_PLIST")"
VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST")"
BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$INFO_PLIST")"
EXECUTABLE_NAME="$(/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "$INFO_PLIST")"
EXECUTABLE_PATH="$APP_DIRECTORY/$EXECUTABLE_NAME"

if [[ ! -f "$EXECUTABLE_PATH" || ! -x "$EXECUTABLE_PATH" ]]; then
    fail "The app executable is missing or is not executable."
fi

# プロジェクト、ソース、署名、プロビジョニング情報がないことを確認する
FORBIDDEN_FILE="$(
    find "$APP_DIRECTORY" \( \
        -name "_CodeSignature" -o \
        -name "embedded.mobileprovision" -o \
        -name "*.mobileprovision" -o \
        -name "*.dSYM" -o \
        -name "*.xcodeproj" -o \
        -name "*.xcworkspace" -o \
        -name "project.pbxproj" -o \
        -name "*.swift" -o \
        -name "*.m" -o \
        -name "*.mm" -o \
        -name "*.c" -o \
        -name "*.h" -o \
        -name ".DS_Store" \
    \) -print -quit
)"

if [[ -n "$FORBIDDEN_FILE" ]]; then
    fail "Forbidden build or source file found: $(basename "$FORBIDDEN_FILE")"
fi

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
    plutil -lint "$plist_path" >/dev/null \
        || fail "A nested Info.plist is invalid."

    for key in "${BUILD_METADATA_KEYS[@]}"; do
        if /usr/libexec/PlistBuddy \
            -c "Print :$key" \
            "$plist_path" \
            >/dev/null 2>&1; then
            fail "An Info.plist still contains $key."
        fi
    done
done < <(find "$APP_DIRECTORY" -type f -name "Info.plist")

# バンドル全体からローカルユーザー、Xcode、CI作業パスの痕跡を検索する
FORBIDDEN_PATH_PATTERN='(/Users/[^/]+/|/home/runner/|/runner/_work/|/private/var/folders/|/var/folders/|/tmp/|/Applications/Xcode[^/]*/|/Library/Developer/|Xcode|DerivedData|\.xcodeproj|project\.pbxproj)'
PATH_MATCHES="$(
    LC_ALL=C grep -R -a -E -l "$FORBIDDEN_PATH_PATTERN" "$APP_DIRECTORY" 2>/dev/null || true
)"

if [[ -n "$PATH_MATCHES" ]]; then
    fail "A local build path or Xcode reference remains in the app bundle."
fi

if codesign -dv "$APP_DIRECTORY" >/dev/null 2>&1; then
    fail "The app is still code signed."
fi

# 元のIPAを変更せず、展開した複製が再署名できることを確認する
RESIGN_DIRECTORY="$AUDIT_DIRECTORY/resign-check"
RESIGN_APP="$RESIGN_DIRECTORY/$(basename "$APP_DIRECTORY")"
mkdir -p "$RESIGN_DIRECTORY"
ditto "$APP_DIRECTORY" "$RESIGN_APP"
codesign --force --sign - --timestamp=none "$RESIGN_APP" >/dev/null 2>&1 \
    || fail "The app could not be re-signed."
codesign --verify --deep --strict "$RESIGN_APP" >/dev/null 2>&1 \
    || fail "The re-signed app did not pass code-signature verification."

ARCHITECTURES="$(lipo -archs "$EXECUTABLE_PATH")"

if [[ " $ARCHITECTURES " != *" arm64 "* ]]; then
    fail "The device arm64 architecture is missing."
fi

if [[ " $ARCHITECTURES " == *" x86_64 "* ]]; then
    fail "A simulator architecture is present."
fi

CRYPT_IDS="$(
    otool -l "$EXECUTABLE_PATH" \
        | awk '/^[[:space:]]*cryptid / { print $2 }'
)"

if [[ -z "$CRYPT_IDS" ]]; then
    fail "The executable has no encryption load command."
fi

if echo "$CRYPT_IDS" | grep -Eqv '^0$'; then
    fail "The executable is encrypted."
fi

FILE_COUNT="$(find "$APP_DIRECTORY" -type f | wc -l | tr -d ' ')"
CHECKSUM="$(shasum -a 256 "$IPA_PATH" | awk '{ print $1 }')"

echo "IPA verification passed"
echo "File: $(basename "$IPA_PATH")"
echo "Bundle ID: $BUNDLE_IDENTIFIER"
echo "Version: $VERSION ($BUILD_NUMBER)"
echo "Architectures: $ARCHITECTURES"
echo "App files: $FILE_COUNT"
echo "Signed: no"
echo "Encrypted: no"
echo "Re-sign check: passed"
echo "SHA-256: $CHECKSUM"
