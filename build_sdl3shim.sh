#!/bin/bash
#
# Build the SDL3-on-SDL2 shim (libSDL3.so.0) and install it under
# /opt/sdl3-shim/.  The shim exposes the SDL3 API but dlopens the system
# libSDL2-2.0.so.0 at runtime for actual video/audio/joystick work — so
# any SDL3-using app (PCSX2 fork, in particular) gets the same
# RGA-rotated KMSDRM display path SDL2 already provides on dArkOS.
#
# Source: https://github.com/bmdhacks/SDL.git branch sdl2-backend
#         (the same fork referenced as a submodule from /home/bmd/sdl3forsdl2;
#          we clone it directly so HTTPS users without the wrapper repo can build)
#
# RK3562-only — skip on other chipsets.

if [ "$CHIPSET" != "rk3562" ]; then
    return 0
fi

SDL3_REMOTE="https://github.com/bmdhacks/SDL.git"
SDL3_BRANCH="sdl2-backend"
SDL3_SRC="Arkbuild/home/ark/sdl3"
SDL3_BUILD="/home/ark/sdl3/build"

if [ ! -d "Arkbuild_package_cache/${CHIPSET}" ]; then
  mkdir -p "Arkbuild_package_cache/${CHIPSET}"
fi

# Host-side fetch (uses host's git config — HTTPS so no auth required)
if [ ! -d "${SDL3_SRC}/.git" ]; then
    sudo rm -rf "${SDL3_SRC}"
    sudo mkdir -p "$(dirname "${SDL3_SRC}")"
    git clone -b "${SDL3_BRANCH}" "${SDL3_REMOTE}" "${SDL3_SRC}"
    verify_action
    sudo chown -R 1000:1000 "${SDL3_SRC}"
else
    git -C "${SDL3_SRC}" fetch origin "${SDL3_BRANCH}"
    git -C "${SDL3_SRC}" checkout "${SDL3_BRANCH}"
    git -C "${SDL3_SRC}" reset --hard "origin/${SDL3_BRANCH}"
fi

SDL3_SHA=$(git -C "${SDL3_SRC}" rev-parse HEAD)

# Cache check.  Single-component key (no submodules; the fork is self-contained
# on this branch).  UNIT-independent — same .so works on RG52 Mini and RG43H.
if [ -f "Arkbuild_package_cache/${CHIPSET}/sdl3-shim.tar.gz" ] && \
   [ "$(cat Arkbuild_package_cache/${CHIPSET}/sdl3-shim.commit 2>/dev/null)" == "${SDL3_SHA}" ]; then
    sudo tar -xvzpf "Arkbuild_package_cache/${CHIPSET}/sdl3-shim.tar.gz"
    if [ ! -f "Arkbuild/opt/sdl3-shim/lib/libSDL3.so.0" ]; then
        echo "WARNING: sdl3-shim cache tarball is incomplete, rebuilding from source..."
        sudo rm -f "Arkbuild_package_cache/${CHIPSET}/sdl3-shim.tar.gz"
    fi
fi

if [ ! -f "Arkbuild/opt/sdl3-shim/lib/libSDL3.so.0" ]; then
    # SDL_GPU is OFF so we don't need SPIRV-Cross — PCSX2 talks to Vulkan
    # directly via VK_KHR_display, and never calls SDL_CreateRenderer or the
    # SDL_GPU API.  All SDL3 video backends are OFF too: the SDL2 backend
    # dlopens the system libSDL2-2.0.so.0 whose own KMSDRM+RGA path handles
    # display.  We're effectively building an input/audio/event-loop shim.
    call_chroot "set -e &&
        rm -rf ${SDL3_BUILD} &&
        mkdir -p ${SDL3_BUILD} &&
        cd ${SDL3_BUILD} &&
        cmake .. \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX=/opt/sdl3-shim \
            -DCMAKE_C_FLAGS='-mcpu=cortex-a53 -O2' \
            -DCMAKE_CXX_FLAGS='-mcpu=cortex-a53 -O2' \
            -DSDL_SDL2_BACKEND=ON \
            -DSDL_VULKAN=OFF \
            -DSDL_GPU=OFF -DSDL_RENDER_GPU=OFF \
            -DSDL_X11=OFF -DSDL_WAYLAND=OFF -DSDL_KMSDRM=OFF \
            -DSDL_OFFSCREEN=OFF -DSDL_DUMMYVIDEO=OFF \
            -DSDL_PIPEWIRE=ON -DSDL_PULSEAUDIO=ON -DSDL_ALSA=ON \
            -DSDL_DUMMYAUDIO=OFF -DSDL_DISKAUDIO=OFF \
            -DSDL_TESTS=OFF -DSDL_UNIX_CONSOLE_BUILD=ON &&
        make -j\$(nproc) &&
        make install &&
        strip /opt/sdl3-shim/lib/libSDL3.so.0.* 2>/dev/null || true
    "
    verify_action

    if [ -f "Arkbuild_package_cache/${CHIPSET}/sdl3-shim.tar.gz" ]; then
      sudo rm -f "Arkbuild_package_cache/${CHIPSET}/sdl3-shim.tar.gz"
    fi
    if [ -f "Arkbuild_package_cache/${CHIPSET}/sdl3-shim.commit" ]; then
      sudo rm -f "Arkbuild_package_cache/${CHIPSET}/sdl3-shim.commit"
    fi
    sudo tar -czpf "Arkbuild_package_cache/${CHIPSET}/sdl3-shim.tar.gz" Arkbuild/opt/sdl3-shim/
    echo "${SDL3_SHA}" > "Arkbuild_package_cache/${CHIPSET}/sdl3-shim.commit"
fi

call_chroot "chown -R root:root /opt/sdl3-shim"
