
#!/bin/bash
set -e

BASE_URL="https://raw.githubusercontent.com/siddharthsky/Extrix/refs/heads/main/pi"

echo "Detecting device architecture..."

ARCH=$(uname -m)

case "$ARCH" in
    aarch64|arm64)
        DEB_FILE="jtvs-1.5.7-aarch64.deb"
        ;;
    arm|armv7l|armv8l)
        DEB_FILE="jtvs-1.5.7-arm.deb"
        ;;
    *)
        echo "Error: Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

DEB_URL="$BASE_URL/$DEB_FILE"

echo "Detected architecture: $ARCH"
echo "Selected package: $DEB_FILE"

echo "[1/3] Updating Termux packages (silent)..."

pkg update -y

DEBIAN_FRONTEND=noninteractive apt-get upgrade -y \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold"

DEBIAN_FRONTEND=noninteractive pkg install curl -y

echo "[2/3] Downloading $DEB_FILE..."

curl -fL --progress-bar -o "$DEB_FILE" "$DEB_URL"

echo "[3/3] Installing $DEB_FILE (silent)..."

DEBIAN_FRONTEND=noninteractive apt-get install -y \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold" \
    "./$DEB_FILE"

rm -f "$DEB_FILE"

echo ""
echo "=================================="
echo " Installation complete!"
echo "=================================="
echo "Restart CTx Engine to start server"
