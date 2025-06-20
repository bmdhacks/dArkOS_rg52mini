#!/bin/bash

echo -e "Setup the Image file...\n\n"

# Image creation
DISK="ArkOS_RGB10.img"
dd if=/dev/zero of="${DISK}" bs=1M count=0 seek="${DISK_SIZE}" conv=fsync
parted -s "${DISK}" mklabel msdos
parted -s "${DISK}" -a min unit s mkpart primary fat32 ${SYSTEM_PART_START} ${SYSTEM_PART_END}
parted -s "${DISK}" set 1 boot on
parted -s "${DISK}" -a min unit s mkpart primary ${ROOT_FILESYSTEM_FORMAT} ${STORAGE_PART_START} ${STORAGE_PART_END}
parted -s "${DISK}" set 2 lba off
parted -s "${DISK}" -a min unit s mkpart primary fat32 ${ROM_PART_START} ${ROM_PART_END}
sync



# Build uboot and install it to the image
git clone --depth=1 https://github.com/christianhaitian/u-boot-${CHIPSET}
cd u-boot-${CHIPSET}
./make.sh odroidgoa

dd if="sd_fuse/idbloader.img" of="../${DISK}" bs=512 seek=64 conv=sync,noerror,notrunc
dd if="sd_fuse/uboot.img" of="../${DISK}" bs=512 seek=16384 conv=sync,noerror,notrunc
dd if="sd_fuse/trust.img" of="../${DISK}" bs=512 seek=24576 conv=sync,noerror,notrunc

cd ..
rm -rf u-boot-${CHIPSET}
