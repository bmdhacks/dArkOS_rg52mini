#!/bin/bash

echo -e "Installing build dependencies and needed packages...\n\n"

if [ "$1" == "32" ]; then
  BIT="32"
  ARCH="arm-linux-gnueabihf"
  CHROOT_DIR="Arkbuild32"
else
  BIT="64"
  ARCH="aarch64-linux-gnu"
  CHROOT_DIR="Arkbuild"
fi

# Install additional needed packages and protect them from autoremove
while read NEEDED_PACKAGE; do
  if [[ ! "$NEEDED_PACKAGE" =~ ^# ]]; then
    install_package $BIT "${NEEDED_PACKAGE}"
    protect_package $BIT "${NEEDED_PACKAGE}"
  fi
done <needed_packages.txt

# Install build dependencies
while read NEEDED_DEV_PACKAGE; do
  if [[ ! "$NEEDED_DEV_PACKAGE" =~ ^# ]]; then
    install_package $BIT "${NEEDED_DEV_PACKAGE}"
    #protect_package $BIT "${NEEDED_DEV_PACKAGE}"
  fi
done <needed_dev_packages.txt

# Default gcc and g++ to version 12 if gcc is newer than 12
GCC_VERSION=`sudo chroot ${CHROOT_DIR}/ bash -c "gcc --version | head -n 1 | awk '{print $3}' | cut -d' ' -f3 | cut -d'.' -f1"`
if (( GCC_VERSION > 12 )); then
  install_package $BIT gcc-12
  install_package $BIT g++-12
  sudo chroot ${CHROOT_DIR}/ bash -c "update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-12 10"
  sudo chroot ${CHROOT_DIR}/ bash -c "update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-12 20"
  sudo chroot ${CHROOT_DIR}/ bash -c "update-alternatives --set gcc /usr/bin/gcc-12"
  sudo chroot ${CHROOT_DIR}/ bash -c "update-alternatives --set g++ /usr/bin/g++-12"
fi

# Bind ccache to chroot to speed up consecutive builds
[ ! -d "${CHROOT_DIR}/home/ark/Arkbuild_ccache" ] && sudo mkdir -p ${CHROOT_DIR}/home/ark/Arkbuild_ccache
sudo mount --bind ${PWD}/Arkbuild_ccache ${CHROOT_DIR}/home/ark/Arkbuild_ccache
sudo chroot ${CHROOT_DIR}/ bash -c "[ -z \$(echo \$CCACHE_DIR | grep ccache) ]" && echo -e "export CCACHE_DIR=/home/ark/Arkbuild_ccache" | sudo tee -a ${CHROOT_DIR}/root/.bashrc > /dev/null
sudo chroot ${CHROOT_DIR}/ bash -c "[ -z \$(echo \$PATH | grep ccache) ]" && echo -e "export PATH=/usr/lib/ccache:\$PATH" | sudo tee -a ${CHROOT_DIR}/root/.bashrc > /dev/null
sudo chroot ${CHROOT_DIR}/ bash -c "/usr/sbin/update-ccache-symlinks"

# Symlink fix for DRM headers
sudo chroot ${CHROOT_DIR}/ bash -c "ln -s /usr/include/libdrm/ /usr/include/drm"

# Place libmali manually (assumes you have libmali.so or mali drivers ready)
# For rk3562, Mali libs are pre-installed from BSP in build_kernel-rk3562.sh
ARCHITECTURE_ARRAY=("aarch64-linux-gnu")
if [[ "${BUILD_ARMHF}" == "y" ]]; then
  ARCHITECTURE_ARRAY+=("arm-linux-gnueabihf")
fi
for ARCHITECTURE in "${ARCHITECTURE_ARRAY[@]}"
do
  if [ "$ARCHITECTURE" == "aarch64-linux-gnu" ]; then
    FOLDER="aarch64"
  else
    FOLDER="armhf"
  fi
  sudo mkdir -p Arkbuild/usr/lib/${ARCHITECTURE}/

  # For BSP Mali (rk3562), 32-bit armhf still uses g13p0 from core_builds
  if [ "${whichmali_bsp}" == "true" ] && [ "$FOLDER" == "armhf" ]; then
    MALI_BLOB=libmali-bifrost-g52-g13p0-gbm.so
  else
    MALI_BLOB=${whichmali}
  fi

  # Install Mali blob
  if [ "${whichmali_bsp}" == "true" ] && [ "$FOLDER" == "aarch64" ]; then
    # RK3562 64-bit: extract g24p0 from BSP tarball (Vulkan 1.3 + GLES 2.0/3.0)
    echo "Installing BSP Mali g24p0 (${whichmali}) from BSP/mali.tar.gz..."
    tar xzf BSP/mali.tar.gz -C /tmp mali/${whichmali}
    sudo cp /tmp/mali/${whichmali} Arkbuild/usr/lib/${ARCHITECTURE}/
    rm -f /tmp/mali/${whichmali}
    (
      cd Arkbuild/usr/lib/${ARCHITECTURE}
      sudo ln -sf ${whichmali} libMali.so
    )
  elif [ -f "Arkbuild/usr/lib/${ARCHITECTURE}/libmali.so.1" ]; then
    # Check if Mali already installed (e.g. from build_kernel step)
    echo "Mali libraries already installed, creating symlinks..."
    (
      cd Arkbuild/usr/lib/${ARCHITECTURE}
      sudo ln -sf libmali.so.1 libMali.so
    )
  else
    # Download Mali from core_builds repo (rk3566, rk3326, etc.)
    wget -t 3 -T 60 --no-check-certificate https://github.com/christianhaitian/${CORE_BUILDS_CHIPSET}_core_builds/raw/refs/heads/master/mali/${FOLDER}/${MALI_BLOB}
    sudo mv ${MALI_BLOB} Arkbuild/usr/lib/${ARCHITECTURE}/.
    (
      cd Arkbuild/usr/lib/${ARCHITECTURE}
      sudo ln -sf ${MALI_BLOB} libMali.so
    )
  fi

  # Create EGL/GLES/GBM/Vulkan symlinks - use subshell to preserve cwd
  (
    cd Arkbuild/usr/lib/${ARCHITECTURE}
    for LIB in libEGL.so libEGL.so.1 libEGL.so.1.1.0 libGLES_CM.so libGLES_CM.so.1 libGLESv1_CM.so libGLESv1_CM.so.1 libGLESv1_CM.so.1.1.0 libGLESv2.so libGLESv2.so.2 libGLESv2.so.2.0.0 libGLESv2.so.2.1.0 libGLESv3.so libGLESv3.so.3 libgbm.so libgbm.so.1 libgbm.so.1.0.0 libmali.so libmali.so.1 libMaliOpenCL.so libOpenCL.so libwayland-egl.so libwayland-egl.so.1 libwayland-egl.so.1.0.0 libvulkan.so libvulkan.so.1
    do
      sudo rm -fv ${LIB}
      sudo ln -sfv libMali.so ${LIB}
    done
  )
done
sudo chroot Arkbuild/ ldconfig

# Bundle g13p0 Mali for EmulationStation (rk3562 only)
# g24p0 has broken GLES 1.0 glDrawArrays — ES uses GLES 1.0 for its loading screen.
# ES gets g13p0 via LD_PRELOAD so the rest of the system can use g24p0 Vulkan.
if [ "$CHIPSET" == "rk3562" ]; then
  sudo mkdir -p Arkbuild/opt/emulationstation/lib
  wget -t 3 -T 60 --no-check-certificate \
    https://github.com/christianhaitian/rk3566_core_builds/raw/refs/heads/master/mali/aarch64/libmali-bifrost-g52-g13p0-gbm.so
  sudo mv libmali-bifrost-g52-g13p0-gbm.so Arkbuild/opt/emulationstation/lib/libmali.so
fi

# Install meson
sudo chroot ${CHROOT_DIR}/ bash -c "git clone https://github.com/mesonbuild/meson.git && ln -s /meson/meson.py /usr/bin/meson"

# Install librga
if [ "$CHIPSET" == "rk3562" ] && [ "$BIT" == "64" ]; then
  # RK3562 64-bit uses BSP librga (matches RGA3 kernel driver ABI).
  # The christianhaitian/linux-rga build has struct layout mismatches with the RGA3
  # kernel framework, causing "Cannot get src1 channel buffer" errors.
  sudo cp BSP/librga/librga.so.2.1.0 ${CHROOT_DIR}/usr/lib/${ARCH}/
  sudo ln -sf librga.so.2.1.0 ${CHROOT_DIR}/usr/lib/${ARCH}/librga.so.2
  sudo ln -sf librga.so.2 ${CHROOT_DIR}/usr/lib/${ARCH}/librga.so
  sudo mkdir -p ${CHROOT_DIR}/usr/local/include/rga
  sudo cp BSP/librga/include/RgaApi.h BSP/librga/include/drmrga.h BSP/librga/include/rga.h \
         BSP/librga/include/im2d.h BSP/librga/include/im2d_type.h BSP/librga/include/im2d_version.h \
         BSP/librga/include/im2d_common.h BSP/librga/include/im2d_buffer.h \
         BSP/librga/include/im2d_expand.h BSP/librga/include/im2d_single.h \
         BSP/librga/include/RgaUtils.h BSP/librga/include/RockchipRga.h \
         BSP/librga/include/RgaMutex.h BSP/librga/include/RgaSingleton.h \
         BSP/librga/include/GrallocOps.h \
         ${CHROOT_DIR}/usr/local/include/rga/
else
  # Build and install christianhaitian's librga (works for RK3326/RK3566)
  sudo chroot ${CHROOT_DIR}/ bash -c "cd /home/ark &&
    git clone https://github.com/christianhaitian/linux-rga.git &&
    cd linux-rga &&
    meson build && cd build &&
    meson compile &&
    cp -r librga.so* /usr/lib/${ARCH}/ &&
    cd .. &&
    mkdir -p /usr/local/include/rga &&
    cp -f drmrga.h rga.h RgaApi.h RockchipRgaMacro.h /usr/local/include/rga/
    "
fi

# Build and install libgo2
sudo chroot ${CHROOT_DIR}/ bash -c "cd /home/ark &&
  git clone https://github.com/OtherCrashOverride/libgo2.git &&
  cd libgo2 &&
  premake4 gmake &&
  make -j$(nproc) &&
  cp libgo2.so* /usr/lib/${ARCH}/ &&
  mkdir -p /usr/include/go2 &&
  cp -L src/*.h /usr/include/go2/
  "
