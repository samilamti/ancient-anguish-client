#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-0.1.0-local}"

echo "=== Building Linux Release ==="
flutter build linux --release

echo "=== Building .deb Package ==="
chmod +x installers/linux/build-deb.sh
./installers/linux/build-deb.sh "v${VERSION}"

echo "=== Package built ==="
ls -la ancient-anguish-client-linux-x64-*.deb
