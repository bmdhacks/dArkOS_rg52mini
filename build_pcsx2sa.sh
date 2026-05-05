#!/bin/bash
#
# Build the bmdhacks PCSX2 fork's SDL3 frontend (binary "pcsx2-sdl") and
# install it under /opt/pcsx2/.  Source:
#
#   https://git.sr.ht/~bmdhacks/pcsx2  branch feature/sdl-frontend
#
# Replaces the abandoned binary AetherSX2 path (commit 0c660f1 on
# branch aethersx2-attempt) — see /home/bmd/.claude/plans/ok-so-i-ve-been-giggly-lagoon.md
# for the full design rationale.
#
# Depends on /opt/sdl3-shim (built by build_sdl3shim.sh) for SDL3 headers
# and libSDL3.so.0.  RK3562-only.

if [ "$CHIPSET" != "rk3562" ]; then
    return 0
fi

PCSX2_REMOTE="https://git.sr.ht/~bmdhacks/pcsx2"
PCSX2_BRANCH="feature/sdl-frontend"
PCSX2_SRC="Arkbuild/home/ark/pcsx2"
PCSX2_BUILD="/home/ark/pcsx2/build-${UNIT}"

if [ ! -d "Arkbuild_package_cache/${CHIPSET}" ]; then
  mkdir -p "Arkbuild_package_cache/${CHIPSET}"
fi

# Host-side fetch (HTTPS — no auth)
if [ ! -d "${PCSX2_SRC}/.git" ]; then
    sudo rm -rf "${PCSX2_SRC}"
    sudo mkdir -p "$(dirname "${PCSX2_SRC}")"
    git clone -b "${PCSX2_BRANCH}" "${PCSX2_REMOTE}" "${PCSX2_SRC}"
    verify_action
    sudo chown -R 1000:1000 "${PCSX2_SRC}"
else
    git -C "${PCSX2_SRC}" fetch origin "${PCSX2_BRANCH}"
    git -C "${PCSX2_SRC}" checkout "${PCSX2_BRANCH}"
    git -C "${PCSX2_SRC}" reset --hard "origin/${PCSX2_BRANCH}"
fi

PCSX2_SHA=$(git -C "${PCSX2_SRC}" rev-parse HEAD)
SDL3_SHA=$(cat "Arkbuild_package_cache/${CHIPSET}/sdl3-shim.commit" 2>/dev/null || echo "no-shim")
CACHE_KEY="${PCSX2_SHA}_${SDL3_SHA}_${UNIT}"

if [ -f "Arkbuild_package_cache/${CHIPSET}/pcsx2sa_${UNIT}.tar.gz" ] && \
   [ "$(cat Arkbuild_package_cache/${CHIPSET}/pcsx2sa_${UNIT}.commit 2>/dev/null)" == "${CACHE_KEY}" ]; then
    sudo tar -xvzpf "Arkbuild_package_cache/${CHIPSET}/pcsx2sa_${UNIT}.tar.gz"
    if [ ! -f "Arkbuild/opt/pcsx2/bin/pcsx2-sdl" ]; then
        echo "WARNING: pcsx2sa cache tarball is incomplete, rebuilding from source..."
        sudo rm -f "Arkbuild_package_cache/${CHIPSET}/pcsx2sa_${UNIT}.tar.gz"
    fi
fi

if [ ! -f "Arkbuild/opt/pcsx2/bin/pcsx2-sdl" ]; then
    # PCSX2's BuildParameters.cmake hardcodes -march=armv8.1-a for arm64,
    # but Cortex-A53 is ARMv8.0-A (no LSE atomics).  Patch that line down
    # to armv8-a and rely on -moutline-atomics to handle locked operations
    # via runtime-dispatched libgcc helpers.
    sed -i 's/"-march=armv8.1-a"/"-march=armv8-a"/' "${PCSX2_SRC}/cmake/BuildParameters.cmake"

    # Build plutovg/plutosvg as prereqs — Trixie doesn't ship them and the
    # fork doesn't vendor them.
    call_chroot "set -e &&
        cd /home/ark &&
        if [ ! -d plutovg ]; then
            git clone --depth=1 https://github.com/sammycage/plutovg.git
        fi &&
        cd plutovg && mkdir -p build && cd build &&
        cmake .. -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX=/usr/local \
            -DBUILD_SHARED_LIBS=ON \
            -DCMAKE_C_FLAGS='-mcpu=cortex-a53 -O2' &&
        make -j\$(nproc) install &&
        cd /home/ark &&
        if [ ! -d plutosvg ]; then
            git clone --depth=1 https://github.com/sammycage/plutosvg.git
        fi &&
        cd plutosvg && mkdir -p build && cd build &&
        cmake .. -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX=/usr/local \
            -DBUILD_SHARED_LIBS=ON \
            -DPLUTOSVG_ENABLE_FREETYPE=ON \
            -DCMAKE_C_FLAGS='-mcpu=cortex-a53 -O2' &&
        make -j\$(nproc) install &&
        ldconfig
    "
    verify_action

    # Configure + build PCSX2 SDL frontend.
    # - SDL3 from /opt/sdl3-shim via PKG_CONFIG_PATH.
    # - OVERRIDE_HOST_PAGE_SIZE=4096: configure-time detection picks up the
    #   build host's kernel, not the target.
    # - X11_API/WAYLAND_API OFF: VK_KHR_display direct-to-monitor is the
    #   only display path PCSX2 needs — no compositor, no SDL_Vulkan_CreateSurface.
    # - RPATH: SDL3 shim and PCSX2's own lib dir.
    call_chroot "set -e &&
        export PKG_CONFIG_PATH=/opt/sdl3-shim/lib/pkgconfig:/usr/local/lib/pkgconfig:\${PKG_CONFIG_PATH} &&
        export LD_LIBRARY_PATH=/opt/sdl3-shim/lib:/usr/local/lib:\${LD_LIBRARY_PATH} &&
        rm -rf ${PCSX2_BUILD} &&
        mkdir -p ${PCSX2_BUILD} &&
        cd ${PCSX2_BUILD} &&
        cmake /home/ark/pcsx2 -G Ninja \
            -DCMAKE_BUILD_TYPE=Release \
            -DPACKAGE_MODE=ON \
            -DCMAKE_INSTALL_PREFIX=/opt/pcsx2 \
            -DENABLE_SDL_FRONTEND=ON \
            -DENABLE_QT_UI=OFF \
            -DUSE_VULKAN=ON -DUSE_OPENGL=ON \
            -DX11_API=OFF -DWAYLAND_API=OFF \
            -DOVERRIDE_HOST_PAGE_SIZE=4096 \
            -DCMAKE_C_FLAGS='-march=armv8-a -moutline-atomics -O3' \
            -DCMAKE_CXX_FLAGS='-march=armv8-a -moutline-atomics -O3' \
            -DCMAKE_BUILD_RPATH='/opt/sdl3-shim/lib;/opt/pcsx2/lib' \
            -DCMAKE_INSTALL_RPATH='/opt/sdl3-shim/lib;/opt/pcsx2/lib' &&
        ninja -j\$(nproc) &&
        ninja install &&
        strip /opt/pcsx2/bin/pcsx2-sdl 2>/dev/null || true
    "
    verify_action

    if [ -f "Arkbuild_package_cache/${CHIPSET}/pcsx2sa_${UNIT}.tar.gz" ]; then
      sudo rm -f "Arkbuild_package_cache/${CHIPSET}/pcsx2sa_${UNIT}.tar.gz"
    fi
    if [ -f "Arkbuild_package_cache/${CHIPSET}/pcsx2sa_${UNIT}.commit" ]; then
      sudo rm -f "Arkbuild_package_cache/${CHIPSET}/pcsx2sa_${UNIT}.commit"
    fi
    sudo tar -czpf "Arkbuild_package_cache/${CHIPSET}/pcsx2sa_${UNIT}.tar.gz" Arkbuild/opt/pcsx2/
    echo "${CACHE_KEY}" > "Arkbuild_package_cache/${CHIPSET}/pcsx2sa_${UNIT}.commit"
fi

# Seed the per-UNIT PCSX2.ini template (controls DisplayRotation among
# other things) and the launcher wrapper.
sudo mkdir -p Arkbuild/opt/pcsx2/templates
sudo cp "pcsx2/configs/PCSX2.ini.${UNIT}" Arkbuild/opt/pcsx2/templates/PCSX2.ini

sudo mkdir -p Arkbuild/home/ark/.config/pcsx2/inis
sudo cp "pcsx2/configs/PCSX2.ini.${UNIT}" Arkbuild/home/ark/.config/pcsx2/inis/PCSX2.ini

sudo cp pcsx2/scripts/standalone-pcsx2sa Arkbuild/usr/local/bin/standalone-pcsx2sa
sudo chmod 755 Arkbuild/usr/local/bin/standalone-pcsx2sa

call_chroot "chown -R ark:ark /opt/pcsx2"
call_chroot "chown -R ark:ark /home/ark/.config/pcsx2"
sudo chmod 755 Arkbuild/opt/pcsx2/bin/pcsx2-sdl
