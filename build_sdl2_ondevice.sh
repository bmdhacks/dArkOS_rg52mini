#!/bin/bash
# Build SDL2 with RGA rotation patches directly on the RG56 Pro.
# Usage: scp this script + the two patch files to the device, then run it.
#
# Prerequisites (should already be installed from the build):
#   cmake, gcc, make, librga headers, libdrm-dev, libasound2-dev, etc.
#
# After building, it installs the new libSDL2 system-wide.

set -e

SDL_COMMIT="5d249570393f7a37e037abf22cd6012a4cc56a71"  # SDL 2.0.32.10
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="/tmp/sdl2-build"
INSTALL_PREFIX="/usr/lib/aarch64-linux-gnu"

echo "=== SDL2 on-device build ==="

# Clean previous build
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Clone SDL2
echo "--- Cloning SDL2 at $SDL_COMMIT ---"
git clone https://github.com/libsdl-org/SDL
cd SDL
git checkout "$SDL_COMMIT"

# Apply core_builds patches (0001-0004) from the installed tree
CORE_PATCHES_DIR="/home/ark/rk3562_core_builds/patches"
if [ -d "$CORE_PATCHES_DIR" ]; then
  for p in "$CORE_PATCHES_DIR"/sdl2-patch-*.patch; do
    if [ -f "$p" ]; then
      pname="$(basename "$p")"
      # Skip odroidgoa patches (same logic as builds-alt.sh)
      if [[ "$pname" == *"odroidgoa"* ]]; then
        echo "Skipping $pname (odroidgoa)"
        continue
      fi
      echo "Applying $pname"
      patch -Np1 < "$p"
    fi
  done
fi

# Apply our rotation patches from the script directory
echo "Applying RGA rotation patch (kmsdrm)"
patch -Np1 < "$SCRIPT_DIR/sdl2-patch-0004-odroidgoa-kmsdrm.patch"

echo "Applying cursor rotation patch"
patch -Np1 < "$SCRIPT_DIR/sdl2-patch-0005-odroidgoa-rotate-cursor.patch"

# Revert CRC joystick changes (same as build system)
git checkout 528b71284f491bcb6ecfd4ab7e00d37b296bd621 -- src/joystick/SDL_gamecontroller.c
git revert -n e5024fae3decb724e397d3c9dbcb744d8c79aac1

# Build
echo "--- Building SDL2 ---"
mkdir build
cd build
cmake -DCMAKE_INSTALL_PREFIX="$INSTALL_PREFIX" \
      -DCMAKE_INSTALL_LIBDIR="$INSTALL_PREFIX" \
      -DSDL_STATIC=OFF \
      -DSDL_LIBC=ON \
      -DSDL_GCC_ATOMICS=ON \
      -DSDL_ALTIVEC=OFF \
      -DSDL_OSS=OFF \
      -DSDL_ALSA=ON \
      -DSDL_ALSA_SHARED=ON \
      -DSDL_JACK=OFF \
      -DSDL_JACK_SHARED=OFF \
      -DSDL_ESD=OFF \
      -DSDL_ESD_SHARED=OFF \
      -DSDL_ARTS=OFF \
      -DSDL_ARTS_SHARED=OFF \
      -DSDL_NAS=OFF \
      -DSDL_NAS_SHARED=OFF \
      -DSDL_LIBSAMPLERATE=ON \
      -DSDL_LIBSAMPLERATE_SHARED=OFF \
      -DSDL_SNDIO=OFF \
      -DSDL_DISKAUDIO=OFF \
      -DSDL_DUMMYAUDIO=OFF \
      -DSDL_WAYLAND=OFF \
      -DSDL_WAYLAND_QT_TOUCH=OFF \
      -DSDL_WAYLAND_SHARED=OFF \
      -DSDL_COCOA=OFF \
      -DSDL_DIRECTFB=OFF \
      -DSDL_VIVANTE=OFF \
      -DSDL_DIRECTFB_SHARED=OFF \
      -DSDL_FUSIONSOUND=OFF \
      -DSDL_FUSIONSOUND_SHARED=OFF \
      -DSDL_DUMMYVIDEO=OFF \
      -DSDL_PTHREADS=ON \
      -DSDL_PTHREADS_SEM=ON \
      -DSDL_DIRECTX=OFF \
      -DSDL_CLOCK_GETTIME=OFF \
      -DSDL_RPATH=OFF \
      -DSDL_RENDER_D3D=OFF \
      -DSDL_X11=OFF \
      -DSDL_OPENGL=OFF \
      -DSDL_OPENGLES=ON \
      -DSDL_VULKAN=ON \
      -DSDL_KMSDRM=ON \
      -DSDL_PULSEAUDIO=OFF ..

export LDFLAGS="${LDFLAGS} -lrga"
make -j$(nproc)

echo "--- Installing ---"
strip libSDL2-2.0.so.0.*

# Back up the current library
if [ ! -f "$INSTALL_PREFIX/libSDL2-2.0.so.0.3200.10.bak" ]; then
  sudo cp "$INSTALL_PREFIX/libSDL2-2.0.so.0.3200.10" \
          "$INSTALL_PREFIX/libSDL2-2.0.so.0.3200.10.bak"
  echo "Backed up existing libSDL2 to .bak"
fi

# Install the new library
sudo cp libSDL2-2.0.so.0.3200.10 "$INSTALL_PREFIX/"
sudo ln -sf libSDL2-2.0.so.0.3200.10 "$INSTALL_PREFIX/libSDL2-2.0.so.0"
sudo ln -sf libSDL2-2.0.so.0.3200.10 "$INSTALL_PREFIX/libSDL2.so"

echo ""
echo "=== Done! New SDL2 installed to $INSTALL_PREFIX ==="
echo "Test with: /opt/ppsspp/PPSSPPSDL"
