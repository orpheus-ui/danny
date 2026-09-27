#!/bin/bash
# Release steps, run in order by .github/workflows/release.yml and `make package`:
#
#   version | build | sign | notarize <path> | package | checksums | notes
#
# Every step works without Apple credentials: signing falls back to ad-hoc and
# notarization is skipped, so forks and local runs still produce a working
# (unsigned) build. docs/releasing.md explains the secrets that turn it on.
#
# Signing:      DEVELOPER_ID      "Developer ID Application: Name (TEAMID)"
# Notarization: NOTARY_KEY_PATH, NOTARY_KEY_ID, NOTARY_ISSUER_ID (App Store Connect API key)
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME=Danny
OUT=build/release
DERIVED=build/DerivedData-release
APP="$OUT/$APP_NAME.app"

version() { sed -n 's/^ *MARKETING_VERSION: "\(.*\)"$/\1/p' project.yml | head -1; }
signed() { [ -n "${DEVELOPER_ID:-}" ]; }
notarizing() { [ -n "${NOTARY_KEY_ID:-}" ] && [ -n "${NOTARY_KEY_PATH:-}" ] && [ -n "${NOTARY_ISSUER_ID:-}" ]; }

cmd_version() { version; }

# Universal Release build. The build number is the commit count, so it only grows.
cmd_build() {
  xcodegen generate --quiet
  rm -rf "$OUT" && mkdir -p "$OUT"
  xcodebuild -project Danny.xcodeproj -scheme Danny -configuration Release \
    -destination 'generic/platform=macOS' -derivedDataPath "$DERIVED" \
    CURRENT_PROJECT_VERSION="$(git rev-list --count HEAD)" \
    CODE_SIGNING_ALLOWED=NO build | { command -v xcbeautify >/dev/null && xcbeautify --quiet || cat; }
  cp -R "$DERIVED/Build/Products/Release/$APP_NAME.app" "$APP"
  echo "✓ Built $APP_NAME $(version) ($(lipo -archs "$APP/Contents/MacOS/$APP_NAME"))"
}

# Inside-out: bundled helpers first (with their own entitlements), then the app.
# Hardened runtime is required for notarization.
cmd_sign() {
  local identity="-" timestamp="--timestamp=none"
  if signed; then identity="$DEVELOPER_ID" timestamp="--timestamp"; fi
  local helper
  for helper in "$APP"/Contents/Resources/bin/*; do
    [ -f "$helper" ] && [ -x "$helper" ] || continue
    codesign --force --options runtime "$timestamp" --sign "$identity" \
      --entitlements scripts/helper.entitlements "$helper"
  done
  codesign --force --options runtime "$timestamp" --sign "$identity" "$APP"
  codesign --verify --deep --strict "$APP"
  if signed; then echo "✓ Signed with Developer ID"; else echo "⚠ Ad-hoc signed (no DEVELOPER_ID)"; fi
}

# notarize <.app|.dmg> — submits to Apple, waits, staples the ticket.
cmd_notarize() {
  local target="$1"
  if ! notarizing; then
    echo "⚠ No notary credentials — skipping notarization of $(basename "$target")"
    return
  fi
  local submission="$target"
  if [ "${target##*.}" = "app" ]; then
    submission="$OUT/notarize.zip"
    ditto -c -k --keepParent "$target" "$submission"
  fi
  xcrun notarytool submit "$submission" --key "$NOTARY_KEY_PATH" \
    --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER_ID" --wait
  xcrun stapler staple "$target"
  [ "$submission" = "$target" ] || rm -f "$submission"
  echo "✓ Notarized and stapled $(basename "$target")"
}

# A zip (for Sparkle and Homebrew) and a drag-to-Applications DMG.
cmd_package() {
  local v dmg stage
  v=$(version)
  dmg="$OUT/$APP_NAME-$v.dmg"
  ditto -c -k --sequesterRsrc --keepParent "$APP" "$OUT/$APP_NAME-$v.zip"
  stage="$OUT/dmg"
  rm -rf "$stage" && mkdir -p "$stage"
  cp -R "$APP" "$stage/"
  ln -s /Applications "$stage/Applications"
  hdiutil create -quiet -volname "$APP_NAME" -srcfolder "$stage" -fs APFS -format ULFO -ov "$dmg"
  rm -rf "$stage"
  if signed; then codesign --force --timestamp --sign "$DEVELOPER_ID" "$dmg"; fi
  echo "✓ Packaged $APP_NAME-$v.dmg and $APP_NAME-$v.zip"
}

cmd_checksums() {
  local v
  v=$(version)
  (cd "$OUT" && shasum -a 256 "$APP_NAME-$v.dmg" "$APP_NAME-$v.zip" > SHA256SUMS.txt && cat SHA256SUMS.txt)
}

# Release notes: commits since the last release, grouped by git-cliff (cliff.toml).
cmd_notes() {
  local v
  v=$(version)
  {
    if ! notarizing; then
      cat <<'EOF'
> **Unsigned build.** macOS will block the first launch. Open it once, then go to
> **System Settings → Privacy & Security** and click **Open Anyway**.
> Details: docs/releasing.md#installing-an-unsigned-build

EOF
    fi
    git cliff --unreleased --tag "v$v" --strip all
  } > "$OUT/notes.md"
  echo "✓ Notes in $OUT/notes.md"
}

step="${1:-}"
shift || true
case "$step" in
  version | build | sign | notarize | package | checksums | notes) "cmd_$step" "$@" ;;
  *)
    echo "usage: $0 version|build|sign|notarize <path>|package|checksums|notes" >&2
    exit 64
    ;;
esac
