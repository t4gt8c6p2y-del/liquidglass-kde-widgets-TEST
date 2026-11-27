#!/usr/bin/env bash
#
# link-photo.sh - create the shared symlinks of the "photo" widget.
#
# Every package symlinks LiquidGlass, MacOSColors, the shaders and the shared
# config pages from 1-common/ instead of copying them. A web upload to GitHub
# cannot carry symlinks, so run this once after `git pull`, then install:
#
#   ./link-photo.sh
#   ./install.sh photo
#
# Safe to run again: existing links are simply refreshed.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

PKG="packages/photo/contents/ui"

if [[ ! -d "$PKG" ]]; then
	echo "[!] $PKG not found: run 'git pull' first." >&2
	exit 1
fi

mkdir -p "$PKG/components" "$PKG/config"

# Same relative targets as every other package (5 levels up to the repo root).
UP="../../../../.."

for f in LiquidGlass.qml MacOSColors.qml WidgetActions.qml links.js styleCodec.js shaders; do
	ln -sfn "$UP/1-common/components/$f" "$PKG/components/$f"
done

for f in ConfigAppearance.qml GlassAppearancePage.qml SliderField.qml; do
	ln -sfn "$UP/1-common/config/$f" "$PKG/config/$f"
done

# Fail loudly if a link does not resolve.
for l in "$PKG"/components/* "$PKG"/config/*; do
	if [[ -L "$l" && ! -e "$l" ]]; then
		echo "[!] Broken link: $l" >&2
		exit 1
	fi
done

echo "[ok] Shared files linked for packages/photo. Now run: ./install.sh photo"
