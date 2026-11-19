#!/bin/bash
set -e

APP_NAME="jtv-server"
APP_VER="1.5.7"
ARCH="arm"
REPO_DIR="$HOME/JioTV-AndroidTV-"
SRC_DIR="$REPO_DIR/server"
PKG_DIR="$HOME/${APP_NAME}_${APP_VER}_${ARCH}"
TERMUX_PREFIX="/data/data/com.termux/files/usr"

echo "================================================="
echo "  JioTV Server: Full Build & .deb Packager (arm) "
echo "================================================="

echo -e "\n[1/9] Updating Termux and installing build packages..."
pkg update -y
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
DEBIAN_FRONTEND=noninteractive pkg install nodejs git python make clang binutils -y

echo -e "\n[2/9] Cloning server folder and patching src/server.ts..."
cd "$HOME"
rm -rf "$REPO_DIR"
git clone --filter=blob:none --no-checkout --depth 1 https://github.com/F-e-n-y-x/JioTV-AndroidTV-.git "$REPO_DIR"
cd "$REPO_DIR"
git sparse-checkout set server
git checkout
cd "$SRC_DIR"
sed -i 's/res.setHeader/res.header/g' src/server.ts

echo -e "\n[3/9] Installing server dependencies & running audit fix..."
npm install --ignore-scripts=false
npm audit fix --force || true

echo -e "\n[4/9] Compiling better-sqlite3 native binary..."
cd "$SRC_DIR/node_modules/better-sqlite3"
npx -y node-gyp rebuild
cd "$SRC_DIR"

echo -e "\n[5/9] Building the Web Dashboard..."
cd "$SRC_DIR/web"
npm install --ignore-scripts=false
npm run build
cd "$SRC_DIR"

echo -e "\n[6/9] Compiling TypeScript Backend..."
npm run build

echo -e "\n[7/9] Preparing clean .deb build directory & copying runtime files..."
rm -rf "$PKG_DIR"
mkdir -p "$PKG_DIR/DEBIAN"
mkdir -p "$PKG_DIR$TERMUX_PREFIX/opt/$APP_NAME/web"
mkdir -p "$PKG_DIR$TERMUX_PREFIX/bin"

cp -r "$SRC_DIR/dist" "$PKG_DIR$TERMUX_PREFIX/opt/$APP_NAME/"
cp -r "$SRC_DIR/node_modules" "$PKG_DIR$TERMUX_PREFIX/opt/$APP_NAME/"
cp "$SRC_DIR/package.json" "$PKG_DIR$TERMUX_PREFIX/opt/$APP_NAME/"
cp -r "$SRC_DIR/web/dist" "$PKG_DIR$TERMUX_PREFIX/opt/$APP_NAME/web/"

# Remove devDependencies to shrink package size
cd "$PKG_DIR$TERMUX_PREFIX/opt/$APP_NAME"
npm prune --omit=dev

echo -e "\n[8/9] Creating launcher command & control metadata..."
cat << 'EOF' > "$PKG_DIR$TERMUX_PREFIX/bin/jtv-server"
#!/data/data/com.termux/files/usr/bin/bash
cd /data/data/com.termux/files/usr/opt/jtv-server
exec node dist/server.js "$@"
EOF
chmod 0755 "$PKG_DIR$TERMUX_PREFIX/bin/jtv-server"

cat << EOF > "$PKG_DIR/DEBIAN/control"
Package: $APP_NAME
Version: $APP_VER
Architecture: $ARCH
Maintainer: Custom Build
Depends: nodejs
Description: Prebuilt JioTV Server (arm) with compiled better-sqlite3
EOF

echo -e "\n[9/9] Setting permissions and building .deb package..."
chmod 0755 "$PKG_DIR/DEBIAN"
chmod 0644 "$PKG_DIR/DEBIAN/control"
dpkg-deb --build "$PKG_DIR"

echo "================================================="
echo "  Done! Package created at: ${PKG_DIR}.deb"
echo "================================================="
