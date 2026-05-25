#!/usr/bin/env bash

set -e

echo "=================================="
echo " Termux Bootstrap Deb Injector"
echo "=================================="
echo

# Check tools
for cmd in bsdtar unzip zip find cp tar awk sed tr sort; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "[ERROR] Missing tool: $cmd"
        exit 1
    fi
done

# Default paths
DEFAULT_BOOTSTRAP="/Users/skylake/Documents/stuff/bootstraps/bootstrap-aarch64.zip"
DEFAULT_DEBS="/Users/skylake/Documents/stuff/debs"

# Ask bootstrap path
read -rp "Bootstrap zip [$DEFAULT_BOOTSTRAP]: " BOOTSTRAP_ZIP
BOOTSTRAP_ZIP="${BOOTSTRAP_ZIP:-$DEFAULT_BOOTSTRAP}"

if [ ! -f "$BOOTSTRAP_ZIP" ]; then
    echo "[ERROR] Bootstrap zip not found"
    exit 1
fi

# Ask deb folder
read -rp "Deb folder [$DEFAULT_DEBS]: " DEB_FOLDER
DEB_FOLDER="${DEB_FOLDER:-$DEFAULT_DEBS}"

if [ ! -d "$DEB_FOLDER" ]; then
    echo "[ERROR] Deb folder not found"
    exit 1
fi

echo
echo "Deb files found:"
find "$DEB_FOLDER" -name "*.deb"

WORKDIR=$(mktemp -d)
BOOTSTRAP_DIR="$WORKDIR/bootstrap"
DEPS_FILE="$WORKDIR/dependencies.txt"

echo
echo "[1/4] Extracting bootstrap..."
mkdir -p "$BOOTSTRAP_DIR"
unzip -q "$BOOTSTRAP_ZIP" -d "$BOOTSTRAP_DIR"

echo "[OK] Bootstrap extracted"
echo

# Process each deb
for deb in "$DEB_FOLDER"/*.deb; do

    [ -f "$deb" ] || continue

    PKG=$(basename "$deb")

    echo "=================================="
    echo "Injecting: $PKG"
    echo "=================================="

    PKGDIR="$WORKDIR/pkg-$(basename "$deb" .deb)"
    rm -rf "$PKGDIR"
    mkdir -p "$PKGDIR"

    cd "$PKGDIR"

    echo "[2/4] Extracting deb..."
    bsdtar -xf "$deb"

    # Extract control archive
    CONTROL_ARCHIVE=""
    if [ -f control.tar.xz ]; then
        CONTROL_ARCHIVE=control.tar.xz
    elif [ -f control.tar.gz ]; then
        CONTROL_ARCHIVE=control.tar.gz
    elif [ -f control.tar.zst ]; then
        CONTROL_ARCHIVE=control.tar.zst
    elif [ -f control.tar.bz2 ]; then
        CONTROL_ARCHIVE=control.tar.bz2
    fi

    if [ -n "$CONTROL_ARCHIVE" ]; then
        mkdir -p control_extract
        tar -xf "$CONTROL_ARCHIVE" -C control_extract

        if [ -f control_extract/control ]; then
            awk -F': ' '/^Depends:/ {print $2}' control_extract/control \
                | tr ',' '\n' \
                | sed 's/([^)]*)//g' \
                | sed 's/|.*//g' \
                | awk '{print $1}' \
                >> "$DEPS_FILE"
        fi
    fi

    DATA_ARCHIVE=""

    if [ -f data.tar.xz ]; then
        DATA_ARCHIVE=data.tar.xz
    elif [ -f data.tar.gz ]; then
        DATA_ARCHIVE=data.tar.gz
    elif [ -f data.tar.zst ]; then
        DATA_ARCHIVE=data.tar.zst
    elif [ -f data.tar.bz2 ]; then
        DATA_ARCHIVE=data.tar.bz2
    else
        echo "[SKIP] No data archive found"
        continue
    fi

    echo "[3/4] Extracting payload..."
    tar -xf "$DATA_ARCHIVE"

    echo "[4/4] Copying files..."

    if [ -d data/data/com.termux/files/usr ]; then
        cp -av data/data/com.termux/files/usr/* "$BOOTSTRAP_DIR"/
    elif [ -d ./usr ]; then
        cp -av usr/* "$BOOTSTRAP_DIR"/
    else
        echo "[WARN] Unknown layout, copying all"
        cp -av . "$BOOTSTRAP_DIR"/
    fi

    echo "[OK] Injected $PKG"
    echo
done

echo "Rebuilding bootstrap..."

OUTPUT="$(dirname "$BOOTSTRAP_ZIP")/$(basename "$BOOTSTRAP_ZIP" .zip)-custom.zip"

cd "$BOOTSTRAP_DIR"
zip -qr9 "$OUTPUT" .

echo
echo "=================================="
echo "Done!"
echo "New bootstrap:"
echo "$OUTPUT"
echo "=================================="

echo
echo "Merged dependencies:"
echo "----------------------------------"

if [ -f "$DEPS_FILE" ]; then
    ALL_DEPS=$(sort -u "$DEPS_FILE" | tr '\n' ' ')
    echo "$ALL_DEPS"
else
    echo "No dependencies found"
fi

echo
read -rp "Delete temp files? (y/n): " clean

if [[ "$clean" == "y" ]]; then
    rm -rf "$WORKDIR"
    echo "Cleaned."
else
    echo "Temp kept:"
    echo "$WORKDIR"
fi