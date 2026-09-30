#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright (C) 2026 Gabriel Ángel Montoya Rico
#
# Arma el AppImage y el .deb de Lockspire (x86_64) a partir del build release
# de Linux, que ya tiene que llevar lockspire-native-host junto al ejecutable
# (native-host/README.md). Lo usa .github/workflows/linux-packages.yml.
#
#   packaging/linux/build_packages.sh 1.0.0
#
# Requiere dpkg-deb y, para el AppImage, appimagetool en el PATH (o en
# $APPIMAGETOOL). Deja los paquetes en build/linux-packages/.
set -euo pipefail

VERSION="${1:?Uso: build_packages.sh <versión>}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HERE="$ROOT/packaging/linux"
BUNDLE="$ROOT/app/build/linux/x64/release/bundle"
OUT="$ROOT/build/linux-packages"
APP_ID="com.lockspire.lockspire"

for file in lockspire lockspire-native-host; do
  if [[ ! -x "$BUNDLE/$file" ]]; then
    echo "Falta $BUNDLE/$file (flutter build linux --release y el native host)" >&2
    exit 1
  fi
done

rm -rf "$OUT"
mkdir -p "$OUT"

# --- .deb: la app en /opt/lockspire, con lanzador e íconos del sistema. ---
DEB="$OUT/deb"
mkdir -p "$DEB/DEBIAN" "$DEB/opt/lockspire" "$DEB/usr/bin" \
  "$DEB/usr/share/applications"
cp -a "$BUNDLE/." "$DEB/opt/lockspire/"
ln -s /opt/lockspire/lockspire "$DEB/usr/bin/lockspire"
install -m 644 "$HERE/$APP_ID.desktop" "$DEB/usr/share/applications/"
for size in 48 128 256 512; do
  dir="$DEB/usr/share/icons/hicolor/${size}x${size}/apps"
  mkdir -p "$dir"
  install -m 644 "$HERE/icons/${size}x${size}.png" "$dir/$APP_ID.png"
done
INSTALLED_KB="$(du -sk "$DEB/opt" "$DEB/usr" | awk '{s += $1} END {print s}')"
# t64: nombre de GTK desde Ubuntu 24.04 / Mint 22. libsecret: almacenamiento
# seguro (flutter_secure_storage). appindicator: ícono de la bandeja.
cat > "$DEB/DEBIAN/control" <<CONTROL
Package: lockspire
Version: $VERSION
Architecture: amd64
Maintainer: Gaanmori <gaanmori@users.noreply.github.com>
Installed-Size: $INSTALLED_KB
Depends: libgtk-3-0t64 | libgtk-3-0, libsecret-1-0, libayatana-appindicator3-1
Section: utils
Priority: optional
Homepage: https://github.com/Gaanmori/lockspire
Description: Open-source, local-first password manager
 Lockspire keeps passwords, cards, documents and notes in a vault encrypted
 with your master password (Argon2id + XChaCha20-Poly1305). Optional sync
 with Google Drive, OneDrive or WebDAV, and a Chrome/Edge extension.
CONTROL
dpkg-deb --build --root-owner-group "$DEB" "$OUT/lockspire_${VERSION}_amd64.deb"
rm -rf "$DEB"

# --- AppImage: el bundle tal cual, con AppRun, el .desktop y el ícono. ---
APPDIR="$OUT/Lockspire.AppDir"
mkdir -p "$APPDIR"
cp -a "$BUNDLE/." "$APPDIR/"
cat > "$APPDIR/AppRun" <<'APPRUN'
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
exec "$HERE/lockspire" "$@"
APPRUN
chmod 755 "$APPDIR/AppRun"
install -m 644 "$HERE/$APP_ID.desktop" "$APPDIR/"
install -m 644 "$HERE/icons/256x256.png" "$APPDIR/$APP_ID.png"
ln -s "$APP_ID.png" "$APPDIR/.DirIcon"
ARCH=x86_64 "${APPIMAGETOOL:-appimagetool}" --no-appstream "$APPDIR" \
  "$OUT/Lockspire-${VERSION}-x86_64.AppImage"
rm -rf "$APPDIR"

ls -lh "$OUT"
