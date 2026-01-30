#!/bin/bash
#
# Kernel Build and Installation for RK3562 (RG56 Pro)
#
# Builds the kernel from source (kernel_rk3562/) with fbdev emulation
# enabled, and installs BSP components (Mali GPU, firmware, bootloader)
# from the EmuELEC BSP extract.
#
# Kernel source required at: ${KERNEL_SRC_PATH}
#   - Must have .config already prepared (use proc.config from device)
#   - Must have rk915 WiFi driver patched in
#
# BSP components required in ${BSP_PATH}:
#   - mali/libmali.so.1.9.0 (Mali DDK g25p0, NOT g13p0!)
#   - mali32/libmali.so (32-bit for RetroArch32)
#   - firmware/ (WiFi, Bluetooth, etc.)
#   - uboot.img (optional - U-Boot FIT image)
#   - bootloader_area.img (raw bootloader including idbloader)
#

# Kernel source tree lives alongside the dArkOS build directory
KERNEL_SRC_PATH="${PWD}/kernel_rk3562"

# Patched DTB source (with VOP2 plane-mask fix)
DTB_FILE="${PWD}/BSP/rk3562-rg56pro.dtb"

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

# Verify required BSP components
for component in "mali/libmali.so.1.9.0"; do
  if [ ! -f "${BSP_PATH}/${component}" ]; then
    echo "ERROR: Required BSP component not found: ${BSP_PATH}/${component}"
    exit 1
  fi
done

# Verify patched DTB exists
if [ ! -f "${DTB_FILE}" ]; then
  echo "ERROR: Patched DTB not found at ${DTB_FILE}"
  echo "Build it from rg56pro-patched.dts with: dtc -I dts -O dtb rg56pro-patched.dts -o rk3562-rg56pro.dtb"
  exit 1
fi

# Build kernel Image
echo "Building kernel Image..."
make -C "${KERNEL_SRC_PATH}" -j$(nproc) Image
if [ $? -ne 0 ]; then
  echo "ERROR: Kernel build failed"
  exit 1
fi

# Get kernel version from the built Image
KERNEL_VERSION=$(strings "${KERNEL_SRC_PATH}/arch/arm64/boot/Image" | grep -oP '^Linux version \K[^ ]+')
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

# Extract compressed BSP Mali tarballs if not already extracted
if [ ! -d "${BSP_PATH}/mali" ] && [ -f "${BSP_PATH}/mali.tar.gz" ]; then
  echo "Extracting Mali 64-bit libraries..."
  tar xzf "${BSP_PATH}/mali.tar.gz" -C "${BSP_PATH}"
fi
if [ ! -d "${BSP_PATH}/mali32" ] && [ -f "${BSP_PATH}/mali32.tar.gz" ]; then
  echo "Extracting Mali 32-bit libraries..."
  tar xzf "${BSP_PATH}/mali32.tar.gz" -C "${BSP_PATH}"
fi

# Install Mali g25p0 libraries (64-bit)
# IMPORTANT: RK3562 uses Mali DDK g25p0, NOT g13p0 like RK3566!
echo "Installing Mali g25p0 GPU libraries (64-bit)..."
sudo mkdir -p Arkbuild/usr/lib/aarch64-linux-gnu/
sudo cp ${BSP_PATH}/mali/libmali.so.1.9.0 Arkbuild/usr/lib/aarch64-linux-gnu/
sudo cp ${BSP_PATH}/mali/libmali-hook.so.1.9.0 Arkbuild/usr/lib/aarch64-linux-gnu/

# Create Mali symlinks (64-bit) - use subshell to preserve cwd
(
  cd Arkbuild/usr/lib/aarch64-linux-gnu
  sudo ln -sf libmali.so.1.9.0 libmali.so.1
  sudo ln -sf libmali.so.1 libmali.so
  sudo ln -sf libmali-hook.so.1.9.0 libmali-hook.so.1
  sudo ln -sf libmali-hook.so.1 libmali-hook.so

  # Create EGL/GLES/GBM symlinks pointing to libmali
  for LIB in libEGL.so libEGL.so.1 libEGL.so.1.1.0 \
             libGLES_CM.so libGLES_CM.so.1 \
             libGLESv1_CM.so libGLESv1_CM.so.1 libGLESv1_CM.so.1.1.0 \
             libGLESv2.so libGLESv2.so.2 libGLESv2.so.2.0.0 libGLESv2.so.2.1.0 \
             libGLESv3.so libGLESv3.so.3 \
             libgbm.so libgbm.so.1 libgbm.so.1.0.0 \
             libOpenCL.so libMaliOpenCL.so \
             libwayland-egl.so libwayland-egl.so.1 libwayland-egl.so.1.0.0
  do
    sudo rm -f ${LIB}
    sudo ln -sf libmali.so ${LIB}
  done
)

# Install Mali libraries (32-bit) for RetroArch32 and other armhf apps
if [[ "${BUILD_ARMHF}" == "y" ]] && [ -f "${BSP_PATH}/mali32/libmali.so" ]; then
  echo "Installing Mali g25p0 GPU libraries (32-bit)..."
  sudo mkdir -p Arkbuild/usr/lib/arm-linux-gnueabihf/
  sudo cp ${BSP_PATH}/mali32/libmali.so Arkbuild/usr/lib/arm-linux-gnueabihf/libmali.so.1.9.0

  # Use subshell to preserve cwd
  (
    cd Arkbuild/usr/lib/arm-linux-gnueabihf
    sudo ln -sf libmali.so.1.9.0 libmali.so.1
    sudo ln -sf libmali.so.1 libmali.so
    sudo ln -sf libmali.so libMali.so

    # Create EGL/GLES/GBM symlinks (32-bit)
    for LIB in libEGL.so libEGL.so.1 libEGL.so.1.1.0 \
               libGLES_CM.so libGLES_CM.so.1 \
               libGLESv1_CM.so libGLESv1_CM.so.1 libGLESv1_CM.so.1.1.0 \
               libGLESv2.so libGLESv2.so.2 libGLESv2.so.2.0.0 libGLESv2.so.2.1.0 \
               libGLESv3.so libGLESv3.so.3 \
               libgbm.so libgbm.so.1 libgbm.so.1.0.0 \
               libOpenCL.so libMaliOpenCL.so \
               libwayland-egl.so libwayland-egl.so.1 libwayland-egl.so.1.0.0
    do
      sudo rm -f ${LIB}
      sudo ln -sf libMali.so ${LIB}
    done
  )
fi

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
echo "  Mali: DDK g25p0 (Bifrost G52)"
echo "  DTB: ${UNIT_DTB}.dtb"

# Note: No cd needed - we should still be in the original directory
