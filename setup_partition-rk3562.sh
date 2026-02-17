#!/bin/bash
#
# Partition setup for RK3562 (RG56 Pro)
#
# Partition layout matches the EmuELEC bootloader expectations:
# - Raw area (0-16383): idbloader at sector 64
# - uboot (16384-24575): U-Boot FIT image (ATF + OP-TEE + U-Boot + MCU)
# - resource (24576-32767): DTB resource image
# - dArkOS_Fat (32768-235519): FAT32 boot partition (~100MB)
# - rootfs (237568+): ext4 root filesystem
# - ROMS partition: FAT32 for game storage
#

ROOT_FILESYSTEM_FORMAT="ext4"
if [ "$ROOT_FILESYSTEM_FORMAT" == "xfs" ] || [ "$ROOT_FILESYSTEM_FORMAT" == "btrfs" ]; then
  ROOT_FILESYSTEM_FORMAT_PARAMETERS="-f -L ROOTFS"
  if [ "$ROOT_FILESYSTEM_FORMAT" != "btrfs" ]; then
    ROOT_FILESYSTEM_MOUNT_OPTIONS="defaults,noatime"
  else
    ROOT_FILESYSTEM_MOUNT_OPTIONS="defaults,noatime,compress=zstd"
  fi
elif [[ "$ROOT_FILESYSTEM_FORMAT" == *"ext"* ]]; then
  # Disable ext4 features not supported by the BSP kernel (5.10.226):
  # metadata_csum_seed (5.15+), orphan_file (5.15+)
  ROOT_FILESYSTEM_FORMAT_PARAMETERS="-F -L ROOTFS -O ^metadata_csum_seed,^orphan_file"
  ROOT_FILESYSTEM_MOUNT_OPTIONS="defaults,noatime"
fi

# Image naming
DISK="dArkOS_${UNIT}_${DEBIAN_CODE_NAME}_${BUILD_DATE}.img"
IMAGE_SIZE=12G
SECTOR_SIZE=512
BUILD_SIZE=52000     # Initial file system size in MB during build
FILESYSTEM="ArkOS_File_System.img"

# Create blank image
fallocate -l $IMAGE_SIZE $DISK
LOOP_DEV=$(sudo losetup --show -f $DISK)

# Create GPT label
sudo parted -s $LOOP_DEV mklabel gpt

# Define GUIDs (same as EmuELEC for compatibility)
GUID_UBOOT="A60B0000-0000-4C7E-8000-015E00004DB7"
GUID_RESOURCE="D46E0000-0000-457F-8000-220D000030DB"
GUID_BASIC_DATA="EBD0A0A2-B9E5-4433-87C0-68B6B72699C7"

# Partition layout (sector = 512B)
# name, start_sector, end_sector, guid
declare -a PARTS=(
  "uboot 16384 24575 $GUID_UBOOT"             # 4MB - U-Boot FIT
  "resource 24576 32767 $GUID_RESOURCE"       # 4MB - DTB resource (may be unused)
  "dArkOS_Fat 32768 235519 $GUID_BASIC_DATA"  # ~100MB - Boot partition
  "rootfs 237568 24903679 $GUID_BASIC_DATA"   # ~11.8GB - Root filesystem
  "5 24903680 25066111 $GUID_BASIC_DATA"      # ~79MB - ROMS partition (expands on first boot)
)

# Create partitions with sgdisk
for i in "${!PARTS[@]}"; do
  IFS=' ' read -r name start end guid <<< "${PARTS[$i]}"
  sudo sgdisk --new=$((i+1)):$start:$end --change-name=$((i+1)):$name --typecode=$((i+1)):$guid $LOOP_DEV
done

# Set legacy BIOS bootable attribute on boot partition so U-Boot finds it
sudo sgdisk --attributes=3:set:2 $LOOP_DEV

# Refresh partitions
sudo partprobe $LOOP_DEV
sleep 2

# Format partitions where needed
sudo mkfs.vfat -F 32 -n dArkOS_Fat "${LOOP_DEV}p3"
sudo mkfs.${ROOT_FILESYSTEM_FORMAT} ${ROOT_FILESYSTEM_FORMAT_PARAMETERS} "${LOOP_DEV}p4"
sudo mkfs.vfat -n ROMS "${LOOP_DEV}p5"

# Create build filesystem
dd if=/dev/zero of="${FILESYSTEM}" bs=1M count=0 seek="${BUILD_SIZE}" conv=fsync
sudo mkfs.${ROOT_FILESYSTEM_FORMAT} ${ROOT_FILESYSTEM_FORMAT_PARAMETERS} "${FILESYSTEM}"
mkdir -p Arkbuild/
sudo mount -t ${ROOT_FILESYSTEM_FORMAT} -o ${ROOT_FILESYSTEM_MOUNT_OPTIONS},loop ${FILESYSTEM} Arkbuild/

echo "Partition setup complete for RK3562"
