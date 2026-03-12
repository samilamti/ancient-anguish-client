#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:?Usage: build-deb.sh <version>}"
# Strip leading 'v' from version tag
VERSION="${VERSION#v}"
ARCH="amd64"
PKG_NAME="ancient-anguish-client"
PKG_DIR="${PKG_NAME}_${VERSION}_${ARCH}"

BUNDLE_DIR="build/linux/x64/release/bundle"
INSTALL_DIR="opt/${PKG_NAME}"

# Clean and create package directory structure
rm -rf "${PKG_DIR}"
mkdir -p "${PKG_DIR}/${INSTALL_DIR}"
mkdir -p "${PKG_DIR}/DEBIAN"
mkdir -p "${PKG_DIR}/usr/bin"
mkdir -p "${PKG_DIR}/usr/share/applications"
mkdir -p "${PKG_DIR}/usr/share/icons/hicolor/256x256/apps"

# Copy application files
cp -r "${BUNDLE_DIR}"/* "${PKG_DIR}/${INSTALL_DIR}/"

# Create symlink for PATH access
ln -s "/${INSTALL_DIR}/ancient_anguish_client" "${PKG_DIR}/usr/bin/${PKG_NAME}"

# Copy .desktop file and icon
cp installers/linux/ancient-anguish-client.desktop "${PKG_DIR}/usr/share/applications/"
cp installers/linux/ancient-anguish-client.png "${PKG_DIR}/usr/share/icons/hicolor/256x256/apps/${PKG_NAME}.png"

# Calculate installed size in KB
INSTALLED_SIZE=$(du -sk "${PKG_DIR}" | cut -f1)

# Create control file
cat > "${PKG_DIR}/DEBIAN/control" << CTRL
Package: ${PKG_NAME}
Version: ${VERSION}
Section: games
Priority: optional
Architecture: ${ARCH}
Depends: libgtk-3-0, libasound2
Installed-Size: ${INSTALLED_SIZE}
Maintainer: Ancient Anguish <support@ancientanguish.org>
Homepage: https://github.com/samilton/ancient-anguish-client
Description: A cross-platform MUD client for Ancient Anguish
 Ancient Anguish Client is a desktop MUD client with RPG theming,
 area-based audio, and background images for connecting to the
 Ancient Anguish MUD server.
CTRL

# Set permissions
chmod 755 "${PKG_DIR}/${INSTALL_DIR}/ancient_anguish_client"
find "${PKG_DIR}/${INSTALL_DIR}/lib" -name "*.so" -exec chmod 644 {} \;
chmod 755 "${PKG_DIR}/DEBIAN"

# Build the .deb
dpkg-deb --build --root-owner-group "${PKG_DIR}"

# Rename to standard artifact naming
mv "${PKG_DIR}.deb" "${PKG_NAME}-linux-x64-${VERSION}.deb"

echo "Built: ${PKG_NAME}-linux-x64-${VERSION}.deb"
