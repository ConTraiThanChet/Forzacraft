#!/usr/bin/env bash
# Reproduce the headless art toolchain in a fresh Kiro sandbox (no root needed).
# Installs into $TOOLS (default /projects/sandbox/.tools, outside the repo):
#   - sysroot/  : X11/GTK3/Xvfb libraries extracted from Amazon Linux 2023 RPMs
#   - bin/Xvfb  : Xvfb patched to call ./xb/xkbcomp and write ./xkbout/ (relative to xkb dir)
#   - blockbench/ : extracted Blockbench AppImage (+ GeckoLib plugin, installed at first start)
#   - aseprite/build/bin/aseprite : Aseprite CLI built from source (no UI, scripting on)
# Idempotent: skips steps whose output already exists.
set -euo pipefail
TOOLS=${TOOLS:-/projects/sandbox/.tools}
mkdir -p "$TOOLS"/{rpms,sysroot,bin,home}
DNF="dnf -q --setopt=logdir=$TOOLS/dnf --setopt=cachedir=$TOOLS/dnf/cache --setopt=persistdir=$TOOLS/dnf/persist"

# 1) Libraries via RPM extraction (root fs is read-only, dnf install is impossible)
if [ ! -x "$TOOLS/sysroot/usr/bin/Xvfb" ]; then
  cd "$TOOLS/rpms"
  ROOTS="gtk3 xorg-x11-server-Xvfb xkbcomp xkeyboard-config libXcursor-devel libXi-devel libXrandr-devel libXfixes-devel libXrender-devel libXext-devel"
  { $DNF repoquery --requires --resolve --recursive --arch x86_64,noarch --qf '%{name}' $ROOTS 2>/dev/null; printf '%s\n' $ROOTS libXcursor libXi libXrandr libXfixes libXrender; } | sort -u \
    | while read -r p; do rpm -q "$p" >/dev/null 2>&1 || echo "$p"; done > need.txt
  $DNF repoquery --location --latest-limit 1 --arch x86_64,noarch $(cat need.txt) 2>/dev/null > urls.txt
  xargs -P8 -n1 curl -sSLO < urls.txt
  cd "$TOOLS/sysroot"
  for f in ../rpms/*.rpm; do
    case $(basename "$f") in glibc-*|coreutils*|amazon-linux-repo*|systemd-[0-9]*|filesystem*|bash-[0-9]*|util-linux-[0-9]*) continue;; esac
    rpm2archive - < "$f" | tar xz 2>/dev/null || true
  done
  rm -rf usr/share/locale usr/share/doc usr/share/man
fi

# 2) Patched Xvfb + private xkb dir
if [ ! -x "$TOOLS/bin/Xvfb" ]; then
  python3 - "$TOOLS" <<'EOF'
import sys
t=sys.argv[1]; b=open(t+'/sysroot/usr/bin/Xvfb','rb').read()
for old,new in [(b'\x00/usr/bin\x00',b'\x00./xb\x00\x00\x00\x00\x00'),(b'\x00/var/lib/xkb/\x00',b'\x00./xkbout/\x00\x00\x00\x00\x00')]:
    assert len(old)==len(new) and b.count(old)==1; b=b.replace(old,new)
open(t+'/bin/Xvfb','wb').write(b)
EOF
  chmod +x "$TOOLS/bin/Xvfb"
fi
mkdir -p "$TOOLS/xvfb-run/xb"
[ -d "$TOOLS/xvfb-run/xkb" ] || cp -rL /usr/share/X11/xkb "$TOOLS/xvfb-run/xkb"
mkdir -p "$TOOLS/xvfb-run/xkb/xkbout"
cat > "$TOOLS/xvfb-run/xb/xkbcomp" <<EOF
#!/bin/sh
exec $TOOLS/sysroot/usr/bin/xkbcomp "\$@"
EOF
chmod +x "$TOOLS/xvfb-run/xb/xkbcomp"

# 3) Blockbench
if [ ! -x "$TOOLS/blockbench/blockbench" ]; then
  cd "$TOOLS"
  URL=$(curl -s https://api.github.com/repos/JannisX11/blockbench/releases/latest | python3 -c "import sys,json;d=json.load(sys.stdin);print([a['browser_download_url'] for a in d['assets'] if a['name'].endswith('.AppImage') and 'arm' not in a['name']][0])")
  curl -sSL -o Blockbench.AppImage "$URL" && chmod +x Blockbench.AppImage
  ./Blockbench.AppImage --appimage-extract >/dev/null && mv squashfs-root blockbench && rm Blockbench.AppImage
fi

# 4) Aseprite (CLI-only build: LAF_BACKEND=none, ENABLE_UI=OFF; no Skia needed)
#    EULA: self-compiled Aseprite is for personal use only; do not redistribute the binary.
if [ ! -x "$TOOLS/aseprite/build/bin/aseprite" ]; then
  cd "$TOOLS"
  [ -d aseprite ] || git clone --depth 1 https://github.com/aseprite/aseprite.git
  cd aseprite
  # The sandbox git gateway needs the .git suffix on submodule URLs.
  fix() { [ -f .gitmodules ] && sed -i -E 's#(url = https://github.com/[^ ]+[^t])$#\1.git#' .gitmodules && git submodule sync -q; }
  fix; git submodule update --init --depth 1 -q || true
  git submodule foreach --quiet --recursive 'if [ -f .gitmodules ]; then sed -i -E "s#(url = https://github.com/[^ ]+[^t])\$#\1.git#" .gitmodules; git submodule sync -q; git submodule update --init --depth 1 -q || true; fi; git checkout -f -q HEAD'
  S=$TOOLS/sysroot/usr
  mkdir -p build && cd build
  cmake -G Ninja -DCMAKE_BUILD_TYPE=Release -DLAF_BACKEND=none -DENABLE_UI=OFF -DENABLE_SCRIPTING=ON \
    -DENABLE_UPDATER=OFF -DENABLE_CCACHE=OFF -DENABLE_TESTS=OFF \
    -DCMAKE_PREFIX_PATH=$S -DCMAKE_INCLUDE_PATH=$S/include -DCMAKE_LIBRARY_PATH=$S/lib64 \
    -DCMAKE_CXX_FLAGS="-I$S/include" -DCMAKE_C_FLAGS="-I$S/include" \
    -DCMAKE_EXE_LINKER_FLAGS="-L$S/lib64 -Wl,-rpath,$S/lib64" ..
  ninja -j"$(nproc)" aseprite
fi
ln -sfn "$TOOLS/aseprite/build/bin/aseprite" "$TOOLS/bin/aseprite"

# 5) env.sh
cat > "$TOOLS/env.sh" <<'EOF'
# Source this file: . /projects/sandbox/.tools/env.sh
export TOOLS=/projects/sandbox/.tools
export SYSROOT=$TOOLS/sysroot/usr
export PATH=$TOOLS/bin:$SYSROOT/bin:$PATH
export LD_LIBRARY_PATH=$SYSROOT/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
export XDG_DATA_DIRS=$SYSROOT/share:/usr/share
export DISPLAY=${DISPLAY:-:99}
export DBUS_SESSION_BUS_ADDRESS=disabled:
# /root is read-only in this sandbox: writable HOME for Electron/Aseprite/Gradle
export HOME=$TOOLS/home
export GRADLE_USER_HOME=$TOOLS/gradle
export JAVA_HOME=/root/.local/share/mise/installs/java/17.0.2
mkdir -p "$HOME"
EOF
echo "art tools installed in $TOOLS"
