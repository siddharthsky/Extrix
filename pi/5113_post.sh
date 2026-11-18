#!/bin/bash
set -e

DEB_URL="https://raw.githubusercontent.com/siddharthsky/Extrix/refs/heads/main/pi/jtvs-1.5.7-aarch64.deb"
DEB_FILE="jtvs-1.5.7-aarch64.deb"

echo "[1/3] Updating Termux packages (silent)..."
pkg update -y
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y \
  -o Dpkg::Options::="--force-confdef" \
  -o Dpkg::Options::="--force-confold"
DEBIAN_FRONTEND=noninteractive pkg install curl -y

echo "[2/3] Downloading $DEB_FILE..."
curl -fsSL -o "$DEB_FILE" "$DEB_URL"

echo "[3/3] Installing $DEB_FILE (silent)..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  -o Dpkg::Options::="--force-confdef" \
  -o Dpkg::Options::="--force-confold" \
  "./$DEB_FILE"

rm -f "$DEB_FILE"

echo "Done! Installation complete. Run 'jtv-server' whenever you are ready."
