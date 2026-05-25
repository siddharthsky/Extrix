#!/usr/bin/env bash

set -e

echo "=================================="
echo " Termux Multi-Arch Bootstrap Injector"
echo "=================================="
echo

# Required tools
for cmd in bsdtar unzip zip find cp tar awk sed tr sort grep mktemp; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "[ERROR] Missing tool: $cmd"
        exit 1
    fi
done

# Defaults
DEFAULT_BOOTSTRAPS="/Users/skylake/Documents/stuff/bootstraps"
DEFAULT_DEBS="/Users/skylake/Documents/stuff/debs"

# Ask paths
read -rp "Bootstraps folder [$DEFAULT_BOOTSTRAPS]: " BOOTSTRAPS_DIR
BOOTSTRAPS_DIR="${BOOTSTRAPS_DIR:-$DEFAULT_BOOTSTRAPS}"

read -rp "Deb folder [$DEFAULT_DEBS]: " DEB_FOLDER
DEB_FOLDER="${DEB_FOLDER:-$DEFAULT_DEBS}"

if [ ! -d "$BOOTSTRAPS_DIR" ]; then
    echo "[ERROR] Bootstraps folder not found"
    exit 1
fi

if [ ! -d "$DEB_FOLDER" ]; then
    echo "[ERROR] Deb folder not found"
    exit 1
fi

echo
echo "Bootstraps found:"
find "$BOOTSTRAPS_DIR" -name "*.zip"

echo
echo "Debs found:"
find "$DEB_FOLDER" -name "*.deb"

echo

# Process every bootstrap zip
for BOOTSTRAP_ZIP in "$BOOTSTRAPS_DIR"/*.zip; do

    [ -f "$BOOTSTRAP_ZIP" ] || continue

    FILE=$(basename "$BOOTSTRAP_ZIP")

    # Detect arch from filename
    ARCH=""

    case "$FILE" in
        *aarch64*)
            ARCH="aarch64"
            ;;
        *arm*)
            ARCH="arm"
            ;;
        *x86_64*)
            ARCH="x86_64"
            ;;
        *i686*)
            ARCH="i686"
            ;;
        *)
            echo "[SKIP] Unknown arch: $FILE"
            continue
            ;;
    esac

    echo "=================================="
    echo "BOOTSTRAP: $FILE"
    echo "ARCH: $ARCH"
    echo "=================================="

    WORKDIR=$(mktemp -d)
    BOOTSTRAP_DIR="$WORKDIR/bootstrap"
    DEPS_FILE="$WORKDIR/dependencies.txt"

    mkdir -p "$BOOTSTRAP_DIR"

    echo "[1/5] Extracting bootstrap..."
    unzip -q "$BOOTSTRAP_ZIP" -d "$BOOTSTRAP_DIR"

    echo "[OK] Bootstrap extracted"
    echo

    # Match debs for this arch
    for deb in "$DEB_FOLDER"/*"${ARCH}"*.deb; do

        [ -f "$deb" ] || continue

        PKG=$(basename "$deb")

        echo "----------------------------------"
        echo "Injecting: $PKG"
        echo "----------------------------------"

        PKGDIR="$WORKDIR/pkg-$(basename "$deb" .deb)"
        rm -rf "$PKGDIR"
        mkdir -p "$PKGDIR"

        cd "$PKGDIR"

        echo "[2/5] Extracting deb..."
        bsdtar -xf "$deb"

        # Control archive
        CONTROL_ARCHIVE=""

        for f in control.tar.xz control.tar.gz control.tar.zst control.tar.bz2; do
            [ -f "$f" ] && CONTROL_ARCHIVE="$f" && break
        done

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

        # Data archive
        DATA_ARCHIVE=""

        for f in data.tar.xz data.tar.gz data.tar.zst data.tar.bz2; do
            [ -f "$f" ] && DATA_ARCHIVE="$f" && break
        done

        if [ -z "$DATA_ARCHIVE" ]; then
            echo "[SKIP] No data archive"
            continue
        fi

        echo "[3/5] Extracting payload..."
        tar -xf "$DATA_ARCHIVE"

        echo "[4/5] Copying files..."

        if [ -d data/data/com.termux/files/usr ]; then
            cp -av data/data/com.termux/files/usr/* "$BOOTSTRAP_DIR"/
        elif [ -d usr ]; then
            cp -av usr/* "$BOOTSTRAP_DIR"/
        else
            echo "[WARN] Unknown layout, copying all"
            cp -av . "$BOOTSTRAP_DIR"/
        fi

        echo "[OK] Injected $PKG"
        echo
    done

    echo "[5/5] Rebuilding bootstrap..."

    OUTPUT="$BOOTSTRAPS_DIR/$(basename "$BOOTSTRAP_ZIP" .zip)-custom.zip"

    cd "$BOOTSTRAP_DIR"
    zip -qr9 "$OUTPUT" .

    echo
    echo "[DONE] $OUTPUT"

    echo
    echo "Dependencies ($ARCH):"
    echo "----------------------------------"

    if [ -f "$DEPS_FILE" ]; then
        sort -u "$DEPS_FILE" | tr '\n' ' '
        echo
    else
        echo "No dependencies"
    fi

    echo
    read -rp "Delete temp for $ARCH? (y/n): " clean

    if [[ "$clean" == "y" ]]; then
        rm -rf "$WORKDIR"
        echo "Cleaned."
    else
        echo "Temp kept:"
        echo "$WORKDIR"
    fi

    echo
done

echo "=================================="
echo "All bootstraps completed."
echo "=================================="