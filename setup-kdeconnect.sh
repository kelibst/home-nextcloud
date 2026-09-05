#!/bin/bash
# OPTIONAL: build KDE Connect from source for Deepin 25.
#
# Read this before running it.
#
# Deepin 25 ships KDE Frameworks 6.6 and Qt 6.8 but does not package
# kdeconnect, and three of its required components are missing from the repos
# too: KContacts, KPeople and Kirigami Addons. So this builds four things in
# dependency order and installs them into /usr/local.
#
# What it costs: roughly 1 GB of build dependencies from apt and 20-45 minutes
# of compiling, depending on the machine.
#
# What you actually gain over ./setup-phone-link.sh: native desktop
# notification popups, and a dedicated SMS window. Screen mirroring, full
# control of the phone, and two-way clipboard sync are already covered by
# scrcpy, and file transfer is already covered by the Nextcloud instance in
# this repo. Consider whether that gap is worth the build before starting.
#
# Honest status: every download URL, checksum and apt package name in here has
# been verified against upstream, but the compile itself has not been run
# end-to-end on this machine. Treat the first run as an experiment. It installs
# only into /usr/local, and the "Uninstalling" section of PHONE-LINK.md
# explains how to back it out.
#
# Safe to re-run; completed stages are skipped.

set -euo pipefail
cd "$(dirname "$0")"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; NC='\033[0m'
step() { echo -e "\n${BLUE}==>${NC} $1"; }
ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
warn() { echo -e "  ${YELLOW}!${NC} $1"; }
die()  { echo -e "  ${RED}✗${NC} $1" >&2; exit 1; }

PREFIX="/usr/local"
LIBDIR="lib/x86_64-linux-gnu"
BUILD_ROOT="$HOME/.cache/kdeconnect-build"
JOBS="$(nproc)"

# Pinned sources. Checksums are upstream's own, from the .sha256 sidecars on
# download.kde.org. Versions are chosen to match Deepin's KF6 6.6 / Qt 6.8.
# Format: name|version|url|sha256
SOURCES=(
"kcontacts|6.6.0|https://download.kde.org/stable/frameworks/6.6/kcontacts-6.6.0.tar.xz|99f0527d49bc6b3fbdc91c4b7edb67c86936e7a4c8cd881bd9da2eedf5666d6c"
"kpeople|6.6.0|https://download.kde.org/stable/frameworks/6.6/kpeople-6.6.0.tar.xz|a0f100a325190859c7754f6a94c38d07ce60f89f30e0d58ddf99641f1f16e2b0"
"kirigami-addons|1.6.0|https://download.kde.org/stable/kirigami-addons/kirigami-addons-1.6.0.tar.xz|376dae6fc5acac7d0905ce9fef3211be0705c6e2df52bb80dfde1eaa20fe1bfa"
"kdeconnect-kde|24.12.3|https://download.kde.org/stable/release-service/24.12.3/src/kdeconnect-kde-24.12.3.tar.xz|48d0eb908539a21f36e1784c2e782a4dca1c90402fe24a631ed2aff43aebab17"
)

BUILD_DEPS=(
build-essential cmake extra-cmake-modules ninja-build
qt6-base-dev qt6-declarative-dev qt6-multimedia-dev qt6-connectivity-dev
qt6-tools-dev qt6-tools-dev-tools
libkf6config-dev libkf6coreaddons-dev libkf6i18n-dev libkf6codecs-dev
libkf6configwidgets-dev libkf6dbusaddons-dev libkf6iconthemes-dev
libkf6notifications-dev libkf6kio-dev libkf6kcmutils-dev libkf6service-dev
libkf6solid-dev libkirigami-dev libkf6windowsystem-dev libkf6guiaddons-dev
libkf6doctools-dev libkf6crash-dev libkf6package-dev libkf6itemviews-dev
libkf6widgetsaddons-dev libkf6pulseaudioqt-dev libkf6statusnotifieritem-dev
libqca-qt6-dev libssl-dev
)

# --- 1. Confirm --------------------------------------------------------------
step "About to build KDE Connect from source"
[ "$EUID" -ne 0 ] || die "do not run as root — it will sudo only where needed"
echo "  prefix       : $PREFIX"
echo "  build dir    : $BUILD_ROOT"
echo "  parallelism  : $JOBS jobs"
echo "  components   : kcontacts, kpeople, kirigami-addons, kdeconnect-kde"
echo
echo "  This installs ~1 GB of build dependencies and compiles for 20-45 minutes."
read -rp "  Continue? [y/N] " reply
[ "$reply" = "y" ] || [ "$reply" = "Y" ] || { echo "  Aborted."; exit 0; }

# --- 2. Build dependencies ---------------------------------------------------
step "Installing build dependencies"
MISSING=()
for p in "${BUILD_DEPS[@]}"; do
    dpkg -s "$p" >/dev/null 2>&1 || MISSING+=("$p")
done
if [ ${#MISSING[@]} -eq 0 ]; then
    ok "all ${#BUILD_DEPS[@]} build dependencies already present"
else
    echo "  installing ${#MISSING[@]} package(s) — this needs sudo"
    sudo apt-get update
    sudo apt-get install -y "${MISSING[@]}" || die "dependency installation failed"
    ok "build dependencies installed"
fi

# --- 3. Build each component -------------------------------------------------
mkdir -p "$BUILD_ROOT"

for entry in "${SOURCES[@]}"; do
    IFS='|' read -r NAME VERSION URL SHA <<< "$entry"
    SRC_DIR="$BUILD_ROOT/${NAME}-${VERSION}"
    STAMP="$BUILD_ROOT/.${NAME}-${VERSION}.installed"
    TARBALL="$BUILD_ROOT/$(basename "$URL")"

    step "Building $NAME $VERSION"

    if [ -f "$STAMP" ]; then
        ok "already built and installed (delete $STAMP to force a rebuild)"
        continue
    fi

    if [ ! -f "$TARBALL" ]; then
        echo "  downloading ..."
        curl -sSL --fail -o "$TARBALL.part" "$URL" || die "download failed: $URL"
        mv "$TARBALL.part" "$TARBALL"
    fi

    echo "$SHA  $TARBALL" | sha256sum -c --quiet - \
        || die "SHA-256 mismatch for $NAME — refusing to build"
    ok "checksum verified"

    rm -rf "$SRC_DIR"
    tar xf "$TARBALL" -C "$BUILD_ROOT"
    [ -d "$SRC_DIR" ] || die "unexpected archive layout for $NAME"

    # Match Debian's multiarch libdir so the result lands where the runtime
    # linker and Qt already look.
    cmake -S "$SRC_DIR" -B "$SRC_DIR/build" -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$PREFIX" \
        -DCMAKE_INSTALL_LIBDIR="$LIBDIR" \
        -DCMAKE_PREFIX_PATH="$PREFIX" \
        -DBUILD_TESTING=OFF \
        || die "cmake configuration failed for $NAME"
    ok "configured"

    cmake --build "$SRC_DIR/build" --parallel "$JOBS" \
        || die "compilation failed for $NAME"
    ok "compiled"

    echo "  installing to $PREFIX (needs sudo)"
    sudo cmake --install "$SRC_DIR/build" || die "install failed for $NAME"
    sudo ldconfig
    touch "$STAMP"
    ok "installed"
done

# --- 4. Runtime paths --------------------------------------------------------
# Qt and KDE do not look under /usr/local by default on Debian-derived systems,
# so the QML modules, plugins and .desktop files need to be pointed at.
step "Configuring runtime paths"
PROFILE_SNIPPET="/etc/profile.d/kdeconnect-local.sh"
SNIPPET_CONTENT="# Installed by setup-kdeconnect.sh — makes the /usr/local KDE build discoverable.
export QML_IMPORT_PATH=\"$PREFIX/$LIBDIR/qt6/qml\${QML_IMPORT_PATH:+:\$QML_IMPORT_PATH}\"
export QML2_IMPORT_PATH=\"$PREFIX/$LIBDIR/qt6/qml\${QML2_IMPORT_PATH:+:\$QML2_IMPORT_PATH}\"
export QT_PLUGIN_PATH=\"$PREFIX/$LIBDIR/qt6/plugins\${QT_PLUGIN_PATH:+:\$QT_PLUGIN_PATH}\"
export XDG_DATA_DIRS=\"$PREFIX/share\${XDG_DATA_DIRS:+:\$XDG_DATA_DIRS}\""

if [ -f "$PROFILE_SNIPPET" ] && [ "$(cat "$PROFILE_SNIPPET")" = "$SNIPPET_CONTENT" ]; then
    ok "runtime paths already configured"
else
    printf '%s\n' "$SNIPPET_CONTENT" | sudo tee "$PROFILE_SNIPPET" >/dev/null
    ok "wrote $PROFILE_SNIPPET"
fi

LDCONF="/etc/ld.so.conf.d/kdeconnect-local.conf"
if [ ! -f "$LDCONF" ]; then
    echo "$PREFIX/$LIBDIR" | sudo tee "$LDCONF" >/dev/null
    sudo ldconfig
    ok "wrote $LDCONF"
else
    ok "library path already registered"
fi

# --- 5. Autostart ------------------------------------------------------------
step "Enabling the KDE Connect daemon at login"
AUTOSTART_DIR="$HOME/.config/autostart"
mkdir -p "$AUTOSTART_DIR"
cat > "$AUTOSTART_DIR/kdeconnectd.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=KDE Connect
Exec=$PREFIX/libexec/kdeconnectd
Terminal=false
X-GNOME-Autostart-enabled=true
EOF
ok "daemon will start at next login"

# --- 6. Verify ---------------------------------------------------------------
step "Verifying"
if [ -x "$PREFIX/bin/kdeconnect-app" ]; then
    ok "kdeconnect-app installed"
else
    warn "kdeconnect-app not found at $PREFIX/bin — check the build output above"
fi

echo
echo -e "${GREEN}Done.${NC}"
echo
echo "  Next:"
echo "    1. Log out and back in, so the runtime paths above take effect."
echo "    2. Start the daemon now without logging out:"
echo "         $PREFIX/libexec/kdeconnectd &"
echo "    3. Install 'KDE Connect' on the phone from F-Droid or Play Store."
echo "    4. Both devices must be on the same network — over USB tethering they"
echo "       are, so pairing should work with the cable in."
echo "    5. If the phone does not appear, add this desktop by IP in the Android"
echo "       app's settings. This machine: $(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K[\d.]+' | head -1)"
