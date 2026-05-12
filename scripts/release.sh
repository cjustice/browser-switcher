#!/usr/bin/env bash
# Build a release artifact and publish a GitHub Release.
#
# Usage: scripts/release.sh <version>
#   e.g. scripts/release.sh 0.1.0
#
# Produces: build/BrowserSwitcher-<version>.zip
# Publishes: a `v<version>` tag + GitHub Release with the zip attached.
set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <version>   e.g. $0 0.1.0" >&2
    exit 1
fi

VERSION="$1"
TAG="v$VERSION"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_BUNDLE="$ROOT/build/Browser Switcher.app"
ZIP_NAME="BrowserSwitcher-$VERSION.zip"
ZIP_PATH="$ROOT/build/$ZIP_NAME"

cd "$ROOT"

if git rev-parse "$TAG" >/dev/null 2>&1; then
    echo "Tag $TAG already exists. Aborting." >&2
    exit 1
fi

echo "==> building app bundle"
"$ROOT/scripts/build-app.sh"

echo "==> zipping app to $ZIP_PATH"
rm -f "$ZIP_PATH"
(cd "$ROOT/build" && ditto -c -k --keepParent "Browser Switcher.app" "$ZIP_NAME")

SHA256="$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')"
echo "==> sha256: $SHA256"

echo "==> tagging $TAG"
git tag -a "$TAG" -m "Release $TAG"
git push origin "$TAG"

echo "==> creating GitHub release"
gh release create "$TAG" "$ZIP_PATH" \
    --title "Browser Switcher $VERSION" \
    --notes "See README for install instructions."

echo
echo "Release complete."
echo "  Tag:    $TAG"
echo "  Asset:  $ZIP_NAME"
echo "  SHA256: $SHA256"
echo
echo "Paste this sha256 into the cask formula."
