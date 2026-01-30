#!/bin/bash
#
# dArkOS Build Script for RG56 Pro (RK3562)
#
# Kernel is compiled from source (../kernel_rk3562/) with fbdev emulation
# and rk915 WiFi driver. Mali GPU libraries and firmware are from the
# EmuELEC BSP extract.
#

if [ -f "build.log" ]; then
  ext=1
  while true
  do
    if [ -f "build.log.${ext}" ]; then
      let ext=ext+1
      continue
    else
      mv build.log build.log.${ext}
      break
    fi
  done
fi
(
# Set chipset and unit in environment variables
export CHIPSET=rk3562
export UNIT=rg56pro
export UNIT_DTB=${CHIPSET}-${UNIT}

# Enable apt-cacher-ng for faster rebuilds
export ENABLE_CACHE=y

# WORKAROUND: No rk3562_core_builds repo exists yet.
# RK3562 and RK3566 are binary compatible (both ARM64 Cortex-A53/A55, Mali Bifrost).
# We'll use rk3566 pre-built binaries by modifying CHIPSET for core builds.
# After bootstrap, create symlink: rk3562_core_builds -> rk3566_core_builds
CORE_BUILDS_SYMLINK_NEEDED=y

# BSP path - points to extracted EmuELEC components
export BSP_PATH="${PWD}/BSP"

# Enable armhf (32-bit) support for RetroArch32 and other 32-bit emulators
export BUILD_ARMHF=y

# Debian codename to use
export DEBIAN_CODE_NAME=bookworm

# Load shared utilities
source ./utils.sh

# Let's make sure necessary tools are available
source ./prepare.sh

# Step-by-step build process
source ./setup_partition-rk3562.sh
source ./bootstrap_rootfs-rk3562.sh
source ./build_kernel-rk3562.sh

# Pre-clone rk3566_core_builds as rk3562_core_builds (they're binary compatible)
if [[ "${CORE_BUILDS_SYMLINK_NEEDED}" == "y" ]]; then
  echo "Cloning rk3566_core_builds as rk3562_core_builds..."
  sudo mkdir -p Arkbuild/home/ark
  if [ ! -d "Arkbuild/home/ark/rk3562_core_builds" ]; then
    sudo git clone --depth=1 https://github.com/christianhaitian/rk3566_core_builds.git Arkbuild/home/ark/rk3562_core_builds
  fi
  sudo chown -R 1000:1000 Arkbuild/home/ark/rk3562_core_builds
fi

source ./build_deps.sh
source ./build_sdl2.sh
source ./build_ppssppsa.sh
source ./build_ppsspp-2021sa.sh
source ./build_duckstationsa.sh
source ./build_mupen64plussa.sh
source ./build_gzdoom.sh
source ./build_lzdoom.sh
source ./build_retroarch.sh
source ./build_retrorun.sh
source ./build_yabasanshirosa.sh
source ./build_mednafen.sh
source ./build_ecwolfsa.sh
source ./build_hypseus-singe.sh
source ./build_openbor.sh
source ./build_solarus.sh
source ./build_scummvmsa.sh
source ./build_fake08.sh
source ./build_xroar.sh
source ./build_mvem.sh
source ./build_bigpemu.sh
source ./build_ogage.sh
source ./build_ogacontrols.sh
source ./build_351files.sh
source ./build_filemanager.sh
source ./build_filebrowser.sh
source ./build_gptokeyb.sh
source ./build_drmtool.sh
source ./build_image-viewer.sh
source ./build_emulationstation-rk3562.sh
source ./build_linapple.sh
source ./build_applewinsa.sh
source ./build_piemu.sh
source ./build_ti99sim.sh
source ./build_gametank.sh
source ./build_openmsxsa.sh
source ./build_flycastsa.sh
source ./build_dolphinsa.sh
source ./build_sdljoytest.sh
source ./build_controllertester.sh
source ./build_drastic.sh
if [[ "${BUILD_KODI}" == "y" ]]; then
  source ./build_kodi.sh
fi
source ./finishing_touches-rk3562.sh
source ./cleanup_filesystem.sh
source ./write_rootfs-rk3562.sh
source ./clean_mounts.sh
source ./create_image.sh
) 2>&1 | tee -a build.log

echo "RG56 Pro build completed. Final image is ready."
