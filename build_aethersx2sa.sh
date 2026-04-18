#!/bin/bash
#
# Install AetherSX2 standalone PS2 emulator into the chroot.
#
# AetherSX2 was discontinued in early 2023 and never open-sourced; the
# v1.5-3606 (Dec 27 2022) aarch64 binary at BSP/aethersx2.tar.gz is the
# final Linux build. ROCKNIX still ships the same binary. We bundle Qt6 +
# SDL2 from the same tarball (no system Qt6 needed).
#
# RK3562-only — skip on other chipsets.

if [ "$CHIPSET" != "rk3562" ]; then
    return 0
fi

if [ ! -f "${BSP_PATH}/aethersx2.tar.gz" ]; then
    echo "ERROR: ${BSP_PATH}/aethersx2.tar.gz missing — cannot build aethersx2sa"
    return 1
fi

# Untar binary + bundled libs into /opt/aethersx2/.
# Tarball layout is aethersx2/usr/share/{aethersx2,libs,resources,qt.conf};
# we flatten so the binary sits at /opt/aethersx2/aethersx2 with libs/
# beside it.
sudo rm -rf Arkbuild/opt/aethersx2
sudo mkdir -p Arkbuild/opt/aethersx2
sudo tar -xzf "${BSP_PATH}/aethersx2.tar.gz" -C Arkbuild/opt/aethersx2 --strip-components=3

# Strip the bundled Wayland/xcb QPA plugins so Qt cannot accidentally pick
# them at runtime — we only support the eglfs / vkkhrdisplay path on dArkOS.
sudo rm -f Arkbuild/opt/aethersx2/libs/plugins/platforms/libqxcb.so
sudo rm -f Arkbuild/opt/aethersx2/libs/plugins/platforms/libqwayland-egl.so
sudo rm -f Arkbuild/opt/aethersx2/libs/plugins/platforms/libqwayland-generic.so
sudo rm -rf Arkbuild/opt/aethersx2/libs/plugins/wayland-decoration-client
sudo rm -rf Arkbuild/opt/aethersx2/libs/plugins/wayland-graphics-integration-client
sudo rm -rf Arkbuild/opt/aethersx2/libs/plugins/wayland-graphics-integration-server
sudo rm -rf Arkbuild/opt/aethersx2/libs/plugins/wayland-shell-integration
sudo rm -rf Arkbuild/opt/aethersx2/libs/plugins/xcbglintegrations

# Replace the broken bundled libqeglfs.so (which NEEDs libQt6EglFSDeviceIntegration.so.6,
# a support lib ROCKNIX never shipped because they use Wayland) with ours — built
# from matching Qt 6.4.1 qtbase source via build_qt6_eglfs.sh in the parent tree.
# Also install the support lib + symlinks into libs/.
if [ ! -f "${BSP_PATH}/qt6-eglfs/libqeglfs.so" ] || \
   [ ! -f "${BSP_PATH}/qt6-eglfs/libQt6EglFSDeviceIntegration.so.6.4.1" ]; then
    echo "ERROR: ${BSP_PATH}/qt6-eglfs/ missing the custom eglfs QPA bits."
    echo "       Run ../build_qt6_eglfs.sh from the project root to produce them."
    return 1
fi
sudo cp "${BSP_PATH}/qt6-eglfs/libqeglfs.so" \
    Arkbuild/opt/aethersx2/libs/plugins/platforms/libqeglfs.so
sudo cp -a "${BSP_PATH}/qt6-eglfs/"libQt6EglFSDeviceIntegration.so* \
    Arkbuild/opt/aethersx2/libs/
# KMS support libs linked by libqeglfs-kms-integration.so.
sudo cp -a "${BSP_PATH}/qt6-eglfs/"libQt6EglFsKmsSupport.so* \
    Arkbuild/opt/aethersx2/libs/
sudo cp -a "${BSP_PATH}/qt6-eglfs/"libQt6EglFsKmsGbmSupport.so* \
    Arkbuild/opt/aethersx2/libs/

# egldeviceintegrations plugins are what libqeglfs.so dlopens at runtime for
# the actual hardware backend (kms-gbm on our target). Without these, eglfs
# silently falls back to the "base" (X11-only) path and fails on KMSDRM.
if [ -d "${BSP_PATH}/qt6-eglfs/egldeviceintegrations" ]; then
    sudo mkdir -p Arkbuild/opt/aethersx2/libs/plugins/egldeviceintegrations
    sudo cp -a "${BSP_PATH}/qt6-eglfs/egldeviceintegrations/"*.so \
        Arkbuild/opt/aethersx2/libs/plugins/egldeviceintegrations/
fi

# Build empty-stub glvnd libs so the main binary's NEEDED entries for
# libGLX.so.0, libOpenGL.so.0, and libGLdispatch.so.0 resolve without
# pulling in Mesa/libglvnd (which would clash with the Mali GPU stack).
# AetherSX2 uses Vulkan at runtime and never actually calls into these
# symbols, so empty SONAME-only stubs are enough.
call_chroot "cd /tmp && : > empty.c && \
    for soname in libGLX.so.0 libOpenGL.so.0 libGLdispatch.so.0; do \
        gcc -shared -fPIC -Wl,-soname,\$soname -o /opt/aethersx2/libs/\$soname empty.c; \
    done && \
    rm -f empty.c"

# Debian Trixie renamed libaio1 -> libaio1t64 (time_t transition), so the
# binary's NEEDED "libaio.so.1" has no matching file. Drop in a symlink.
call_chroot "if [ -f /usr/lib/aarch64-linux-gnu/libaio.so.1t64 ] && \
                [ ! -e /usr/lib/aarch64-linux-gnu/libaio.so.1 ]; then \
                 ln -sf libaio.so.1t64 /usr/lib/aarch64-linux-gnu/libaio.so.1; \
             fi"

# Stash the PCSX2.ini template alongside the binary; the launcher seeds
# /home/ark/.config/aethersx2/inis/PCSX2.ini from this on first run.
sudo mkdir -p Arkbuild/opt/aethersx2/templates
sudo cp aethersx2/configs/PCSX2.ini Arkbuild/opt/aethersx2/templates/PCSX2.ini

# Pre-seed the user config dir so first launch doesn't race the mkdir.
sudo mkdir -p Arkbuild/home/ark/.config/aethersx2/inis
sudo cp aethersx2/configs/PCSX2.ini Arkbuild/home/ark/.config/aethersx2/inis/PCSX2.ini

# Install launcher wrapper.
sudo cp aethersx2/scripts/standalone-aethersx2 Arkbuild/usr/local/bin/standalone-aethersx2
sudo chmod 755 Arkbuild/usr/local/bin/standalone-aethersx2

sudo chmod 755 Arkbuild/opt/aethersx2/aethersx2
call_chroot "chown -R ark:ark /opt/aethersx2"
call_chroot "chown -R ark:ark /home/ark/.config/aethersx2"
