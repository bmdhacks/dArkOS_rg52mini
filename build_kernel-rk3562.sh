#!/bin/bash
#
# Kernel Build and Installation for RK3562 (RG56 Pro)
#
# Builds the kernel from source (kernel_rk3562/) with fbdev emulation
# enabled, and installs BSP components (firmware, bootloader) from the
# EmuELEC BSP extract. Mali GPU libraries are handled by build_deps.sh
# (downloaded from rk3566_core_builds, g13p0 DDK).
#
# Kernel source required at: ${KERNEL_SRC_PATH}
#   - Must have .config already prepared (use proc.config from device)
#   - Must have rk915 WiFi driver patched in
#
# BSP components required in ${BSP_PATH}:
#   - librga/ (BSP librga.so.2.1.0 + headers for RGA3 ABI)
#   - mali/libmali-hook.so.1.9.0 (optional - Mali hook library)
#   - firmware/ (WiFi, Bluetooth, etc.)
#   - uboot.img (optional - U-Boot FIT image)
#   - bootloader_area.img (raw bootloader including idbloader)
#

# Kernel source tree lives alongside the dArkOS build directory
KERNEL_SRC_PATH="${PWD}/kernel_rk3562"

# Patched DTB (VOP2 plane-mask + rockchip-suspend enabled). This is the single
# source of truth for the device tree. Decompile with dtc to edit, recompile back.
DTB_FILE="${PWD}/BSP/${UNIT_DTB}.dtb"

echo "Building and installing kernel for RK3562..."

# Verify kernel source exists
if [ ! -d "${KERNEL_SRC_PATH}" ]; then
  echo "ERROR: Kernel source not found at ${KERNEL_SRC_PATH}"
  exit 1
fi

# Verify BSP path exists
if [ ! -d "${BSP_PATH}" ]; then
  echo "ERROR: BSP_PATH (${BSP_PATH}) not found!"
  echo "Please extract EmuELEC SYSTEM first using unsquashfs"
  exit 1
fi

# Extract compressed BSP Mali tarballs if not already extracted
if [ ! -d "${BSP_PATH}/mali" ] && [ -f "${BSP_PATH}/mali.tar.gz" ]; then
  echo "Extracting Mali 64-bit libraries..."
  tar xzf "${BSP_PATH}/mali.tar.gz" -C "${BSP_PATH}"
fi
if [ ! -d "${BSP_PATH}/mali32" ] && [ -f "${BSP_PATH}/mali32.tar.gz" ]; then
  echo "Extracting Mali 32-bit libraries..."
  tar xzf "${BSP_PATH}/mali32.tar.gz" -C "${BSP_PATH}"
fi

# Verify required BSP components
# Mali GPU blob is downloaded by build_deps.sh (g13p0 from rk3566_core_builds)
# Only the DTB and firmware are required from BSP

# Verify patched DTB exists
if [ ! -f "${DTB_FILE}" ]; then
  echo "ERROR: Patched DTB not found at ${DTB_FILE}"
  echo "This compiled DTB is the source of truth. To edit: dtc -I dtb -O dts ${DTB_FILE} > /tmp/rg56pro.dts"
  exit 1
fi

# Ensure kernel .config exists
if [ ! -f "${KERNEL_SRC_PATH}/.config" ]; then
  echo "Generating kernel .config from ${UNIT}_defconfig..."
  make -C "${KERNEL_SRC_PATH}" ${UNIT}_defconfig
fi

# Build kernel Image
echo "Building kernel Image..."
make -C "${KERNEL_SRC_PATH}" -j$(nproc) Image
if [ $? -ne 0 ]; then
  echo "ERROR: Kernel build failed"
  exit 1
fi

# Get kernel version from the build system (not strings, which also matches
# the "Linux version %s" format string in the kernel binary)
KERNEL_VERSION=$(make -C "${KERNEL_SRC_PATH}" -s kernelrelease)
echo "Built kernel version: ${KERNEL_VERSION}"

# Build kernel modules
echo "Building kernel modules..."
make -C "${KERNEL_SRC_PATH}" -j$(nproc) modules
# Module build failures are non-fatal — we have BSP modules as fallback

# Mount boot partition
mountpoint=mnt/boot
mkdir -p ${mountpoint}
sudo mount ${LOOP_DEV}p3 ${mountpoint}

# Copy compiled kernel Image and patched DTB to boot partition
echo "Copying kernel and DTB..."
sudo cp "${KERNEL_SRC_PATH}/arch/arm64/boot/Image" ${mountpoint}/
sudo cp "${DTB_FILE}" ${mountpoint}/${UNIT_DTB}.dtb

# Copy battery charge animation BMPs for U-Boot charge display
echo "Copying charge animation BMPs..."
sudo cp ${BSP_PATH}/battery_*.bmp ${mountpoint}/ 2>/dev/null || true

# Install kernel modules from source build
echo "Installing kernel modules..."
sudo make -C "${KERNEL_SRC_PATH}" INSTALL_MOD_PATH="${PWD}/Arkbuild" modules_install

# Copy firmware blobs (follow symlinks, ignore dangling ones)
echo "Installing firmware..."
sudo mkdir -p Arkbuild/lib/firmware/
if [ -d "${BSP_PATH}/firmware" ]; then
  # Use rsync to handle symlinks gracefully
  sudo rsync -aL --ignore-errors ${BSP_PATH}/firmware/ Arkbuild/lib/firmware/ 2>/dev/null || \
    sudo cp -rL ${BSP_PATH}/firmware/* Arkbuild/lib/firmware/ 2>/dev/null || true
fi

# Mali GPU libraries are downloaded and installed by build_deps.sh (same as RK3566).
# The RK3562 uses g13p0 (set in utils.sh) — the BSP g24p0 has a broken GLES 1.0.
# Install libmali-hook from BSP if available.
sudo mkdir -p Arkbuild/usr/lib/aarch64-linux-gnu/
sudo cp ${BSP_PATH}/mali/libmali-hook.so.1.9.0 Arkbuild/usr/lib/aarch64-linux-gnu/ 2>/dev/null || true
(
  cd Arkbuild/usr/lib/aarch64-linux-gnu
  sudo ln -sf libmali-hook.so.1.9.0 libmali-hook.so.1 2>/dev/null || true
  sudo ln -sf libmali-hook.so.1 libmali-hook.so 2>/dev/null || true
)

# Run ldconfig to update library cache
sudo chroot Arkbuild/ ldconfig

# Create kernel config for initramfs-tools
echo "Creating kernel config for initramfs-tools..."
sudo cp "${KERNEL_SRC_PATH}/.config" Arkbuild/boot/config-${KERNEL_VERSION}

# Create uInitrd
echo "Creating uInitrd..."
call_chroot "depmod ${KERNEL_VERSION}; update-initramfs -c -k ${KERNEL_VERSION}"
sudo cp Arkbuild/boot/initrd.img-${KERNEL_VERSION} ${mountpoint}/initrd.img

if ! command -v mkimage &> /dev/null; then
  sudo apt -y update
  sudo apt -y install u-boot-tools
fi

# Update uInitrd to force booting from mmcblk1p4 (SD card rootfs)
# Use subshell to preserve cwd
(
  mkdir -p initrd
  sudo mv ${mountpoint}/initrd.img initrd/.
  cd initrd
  zstd -d -c initrd.img | cpio -idmv
  rm -f initrd.img
  sed -i '/local dev_id\=/c\\tlocal dev_id\=\"/dev/mmcblk1p4\"' scripts/local

  # Add regulatory.db for WiFi
  mkdir -p lib/firmware
  wget -t 3 -T 60 https://github.com/CaffeeLake/wireless-regdb/raw/refs/heads/master/regulatory.db -O lib/firmware/regulatory.db 2>/dev/null || true

  # Fix: fsck hook fails to detect root fstype during chroot build because
  # /dev/mmcblk1p4 doesn't exist, so it skips copying fsck/logsave entirely.
  # The initramfs scripts/functions still calls logsave unconditionally, and
  # the missing binary causes exit code 127 -> panic at boot.
  for bin in /sbin/fsck /sbin/logsave /sbin/e2fsck /sbin/fsck.ext4; do
    src="../../Arkbuild${bin}"
    if [ -f "$src" ]; then
      cp "$src" ".${bin}"
      # Copy required shared libraries
      for lib in $(ldd "$src" 2>/dev/null | grep -o '/lib[^ ]*'); do
        mkdir -p ".$(dirname "$lib")"
        cp -n "$lib" ".$lib" 2>/dev/null || true
      done
    fi
  done

  find . | cpio -H newc -o | gzip -c > ../uInitrd
  sudo mv ../uInitrd ../${mountpoint}/uInitrd
  cd ..
  rm -rf initrd
)
sudo rm -f ${mountpoint}/initrd.img

# Flash bootloader components
echo "Flashing bootloader components..."

# Flash the idbloader (first 8MB contains idbloader at sector 64)
if [ -f "${BSP_PATH}/bootloader_area.img" ]; then
  echo "Flashing bootloader area (idbloader)..."
  # Only flash the idbloader portion (sectors 64-16383)
  sudo dd if=${BSP_PATH}/bootloader_area.img of=$LOOP_DEV bs=$SECTOR_SIZE skip=64 seek=64 count=16320 conv=notrunc
fi

# Flash U-Boot FIT image to uboot partition
if [ -f "${BSP_PATH}/uboot.img" ]; then
  echo "Flashing U-Boot FIT image..."
  sudo dd if=${BSP_PATH}/uboot.img of=$LOOP_DEV bs=$SECTOR_SIZE seek=16384 conv=notrunc
fi

# Copy U-Boot image for potential recovery
sudo mkdir -p Arkbuild/usr/local/bin/
if [ -f "${BSP_PATH}/uboot.img" ]; then
  sudo cp ${BSP_PATH}/uboot.img Arkbuild/usr/local/bin/uboot.img.emuelec
fi

# Create config directory for kernel version info
sudo mkdir -p Arkbuild/boot/
echo "${KERNEL_VERSION}" | sudo tee Arkbuild/boot/kernel_version

echo "Kernel build and installation complete"
echo "  Kernel: ${KERNEL_VERSION}"
echo "  Mali: handled by build_deps.sh (${whichmali})"
echo "  DTB: ${UNIT_DTB}.dtb"

# Note: No cd needed - we should still be in the original directory
