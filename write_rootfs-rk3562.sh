#!/bin/bash
#
# Write rootfs to disk for RK3562 (RG56 Pro)
#

echo "Writing rootfs to disk image..."

sync Arkbuild
if [ "${ROOT_FILESYSTEM_FORMAT}" == "xfs" ]; then
  mkdir Arkbuild-final
  sudo mount -o loop ${LOOP_DEV}p4 Arkbuild-final/
  sudo rsync -aHAXv --exclude={'home/ark/Arkbuild_ccache','proc','dev','sys'} Arkbuild/ Arkbuild-final/
  sudo umount Arkbuild-final/
  sudo rm -rf Arkbuild-final/
elif [[ "${ROOT_FILESYSTEM_FORMAT}" == *"ext"* ]]; then
  # Unmount the rootfs — kill any processes holding it open first
  sudo fuser -km Arkbuild/ 2>/dev/null || true
  sudo umount -l Arkbuild/ 2>/dev/null || true
  sleep 1
  if mountpoint -q Arkbuild/ 2>/dev/null; then
    echo "ERROR: Failed to unmount Arkbuild/. Cannot proceed."
    exit 1
  fi
  sudo e2fsck -p -f ${FILESYSTEM}
  sudo resize2fs -M ${FILESYSTEM}
  sudo e2fsck -p -f ${FILESYSTEM}
  sudo dd if="${FILESYSTEM}" of="${LOOP_DEV}p4" bs=4M conv=fsync,notrunc
  # Expand filesystem to fill the partition
  sudo e2fsck -p -f "${LOOP_DEV}p4"
  sudo resize2fs "${LOOP_DEV}p4"
elif [ "${ROOT_FILESYSTEM_FORMAT}" == "btrfs" ]; then
  sudo btrfs balance start --full-balance Arkbuild
  sync Arkbuild
  sudo btrfs filesystem resize 7300M Arkbuild/
  verify_action
  sync Arkbuild
  sudo truncate -s 7650MB ${FILESYSTEM}
  sync Arkbuild
  sudo dd if="${FILESYSTEM}" of="${LOOP_DEV}p4" bs=512 conv=fsync,notrunc
fi
sync ${DISK}

echo "Rootfs written successfully"
