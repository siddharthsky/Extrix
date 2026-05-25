#!/usr/bin/env bash

set -euo pipefail

PACKAGES_FILE="./Packages"
PKG_LIST_FILE="./pkg.txt"
BASE_URL="https://linux.domainesia.com/applications/termux/termux-main"
OUTDIR="./downloads"

mkdir -p "$OUTDIR"

echo "=================================="
echo " Termux Deb Downloader"
echo "=================================="
echo

# Check tools
for cmd in awk grep sed curl dirname basename; do
    command -v "$cmd" >/dev/null || {
        echo "[ERROR] Missing tool: $cmd"
        exit 1
    }
done

[ -f "$PACKAGES_FILE" ] || {
    echo "[ERROR] Missing Packages file"
    exit 1
}

[ -f "$PKG_LIST_FILE" ] || {
    echo "[ERROR] Missing pkg.txt"
    exit 1
}

# Read ALL package names
PKGS=$(tr '\n' ' ' < "$PKG_LIST_FILE")

for PKG in $PKGS; do
    echo "----------------------------------"
    echo "[*] Package: $PKG"

    # Find first matching package block
    ENTRY=$(awk -v pkg="$PKG" '
    BEGIN { RS=""; FS="\n" }
    {
        for(i=1;i<=NF;i++) {
            if($i=="Package: " pkg) {
                print $0
                exit
            }
        }
    }' "$PACKAGES_FILE")

    if [ -z "$ENTRY" ]; then
        echo "    not found in Packages"
        continue
    fi

    FILENAME=$(echo "$ENTRY" | awk -F': ' '/^Filename:/ {print $2; exit}')

    if [ -z "$FILENAME" ]; then
        echo "    filename missing"
        continue
    fi

    DIR=$(dirname "$FILENAME")
    FILE=$(basename "$FILENAME")

    VERSION=$(echo "$FILE" | sed -E 's/^.+_([^_]+)_[^_]+\.deb$/\1/')

    echo "    version: $VERSION"

    for ARCH in aarch64 arm i686 x86_64; do
        DEB="${PKG}_${VERSION}_${ARCH}.deb"
        URL="${BASE_URL}/${DIR}/${DEB}"

        echo "    -> $DEB"

        if [ -f "$OUTDIR/$DEB" ]; then
            echo "       exists"
            continue
        fi

        if curl --silent --fail --head "$URL" >/dev/null; then
            echo "       downloading"
            curl -L "$URL" -o "$OUTDIR/$DEB"
        else
            echo "       not found"
        fi
    done
done

echo
echo "Done"
echo "Saved to: $OUTDIR"