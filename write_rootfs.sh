#!/bin/bash

# Write rootfs to disk
sync
if [ "${ROOT_FILESYSTEM_FORMAT}" == "xfs" ]; then
  mkdir Arkbuild-final
  sudo mount -o loop ${LOOP_DEV}p4 Arkbuild-final/
  sudo rsync -av --exclude={'home/ark/Arkbuild_ccache','proc','dev','sys'} Arkbuild/ Arkbuild-final/
  sudo umount Arkbuild-final/
  sudo rm -rf Arkbuild-final/
elif [[ "${ROOT_FILESYSTEM_FORMAT}" == *"ext"* ]]; then
  e2fsck -p -f ${FILESYSTEM}
  resize2fs -M ${FILESYSTEM}
  sudo dd if="${FILESYSTEM}" of="${DISK}" bs=512 seek="${STORAGE_PART_START}" conv=fsync,notrunc
elif [ "${ROOT_FILESYSTEM_FORMAT}" == "btrfs" ]; then
  #FILESYSTEM_LOOP=$(cat /proc/mounts | grep "Arkbuild btrfs" | cut -d ' ' -f 1)
  #sudo btrfs check --force --repair ${FILESYSTEM_LOOP}
  sudo btrfs balance start --full-balance Arkbuild
  #BTRFS_MIN_SIZE=$(sudo btrfs filesystem usage -b Arkbuild/ | grep -A 1 Unallocated | awk '!/Unallocated/')
  #BTRFS_MIN_SIZE=$(echo $BTRFS_MIN_SIZE | cut -d ' ' -f 2)
  #BTRFS_MIN_SIZE=$(echo "$BTRFS_MIN_SIZE * 0.9" | bc | cut -d '.' -f 1)
  sudo btrfs filesystem resize 7300M Arkbuild/
  sudo truncate -s 7650MB ${FILESYSTEM}
  #sudo btrfs check --force --repair ${FILESYSTEM_LOOP}
  sudo dd if="${FILESYSTEM}" of="${DISK}" bs=512 seek="${STORAGE_PART_START}" conv=fsync,notrunc
fi
