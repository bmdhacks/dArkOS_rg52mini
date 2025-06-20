#!/bin/bash

echo -e "Creating partitions...\n\n"
# Partition setup
ROOT_FILESYSTEM_FORMAT="xfs"
SYSTEM_SIZE=100      # FAT32 boot partition size in MB
STORAGE_SIZE=7168    # Root filesystem size in MB
ROM_PART_SIZE=512    # FAT32 ROMS/shared partition size in MB
BUILD_SIZE=54579     # Initial file system size in MB during the build.  Then will be reduced to the DISK_SIZE or below upon completion

SYSTEM_PART_START=32768
SYSTEM_PART_END=$(( SYSTEM_PART_START + (SYSTEM_SIZE * 1024 * 1024 / 512) - 1 ))
STORAGE_PART_START=$(( SYSTEM_PART_END + 1 ))
STORAGE_PART_END=$(( STORAGE_PART_START + (STORAGE_SIZE * 1024 * 1024 / 512) - 1 ))
ROM_PART_START=$(( STORAGE_PART_END + 1 ))
ROM_PART_END=$(( ROM_PART_START + (ROM_PART_SIZE * 1024 * 1024 / 512) - 1 ))

DISK_START_PADDING=$(( (SYSTEM_PART_START + 2048 - 1) / 2048 ))
DISK_SIZE=$(( DISK_START_PADDING + SYSTEM_SIZE + STORAGE_SIZE + ROM_PART_SIZE + 1 ))
FILESYSTEM="ArkOS_File_System.img"

# Create filesystem image
if [ -f "ArkOS_RGB10.img" ]; then
  sudo rm -f ArkOS_RGB10.img
fi

dd if=/dev/zero of="${FILESYSTEM}" bs=1M count=0 seek="${BUILD_SIZE}" conv=fsync
sudo mkfs.${ROOT_FILESYSTEM_FORMAT} -F -L ROOTFS "${FILESYSTEM}"
mkdir -p Arkbuild/
sudo mount -t ${ROOT_FILESYSTEM_FORMAT} -o loop ${FILESYSTEM} Arkbuild/

