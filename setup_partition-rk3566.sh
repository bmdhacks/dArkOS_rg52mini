#!/bin/bash
#set -e

ROOT_FILESYSTEM_FORMAT="btrfs"
if [ "$ROOT_FILESYSTEM_FORMAT" == "xfs" ] || [ "$ROOT_FILESYSTEM_FORMAT" == "btrfs" ]; then
  ROOT_FILESYSTEM_FORMAT_PARAMETERS="-f -L ROOTFS"
  if [ "$ROOT_FILESYSTEM_FORMAT" != "btrfs" ]; then
    ROOT_FILESYSTEM_MOUNT_OPTIONS="defaults,noatime"
  else
    ROOT_FILESYSTEM_MOUNT_OPTIONS="defaults,noatime,compress=zstd"
  fi
elif [[ "$ROOT_FILESYSTEM_FORMAT" == *"ext"* ]]; then
  ROOT_FILESYSTEM_FORMAT_PARAMETERS="-F -L ROOTFS"
  ROOT_FILESYSTEM_MOUNT_OPTIONS="defaults,noatime"
fi
if [[ "$UNIT" == *"353"* ]] || [[ "$UNIT" == *"503"* ]]; then
  DISK="dArkOS_RG${UNIT}_${DEBIAN_CODE_NAME}_${BUILD_DATE}.img"
else
  DISK="dArkOS_${UNIT}_${DEBIAN_CODE_NAME}_${BUILD_DATE}.img"
fi
IMAGE_SIZE=7.5G
SECTOR_SIZE=512
BUILD_SIZE=54579     # Initial file system size in MB during the build.  Then will be reduced to the DISK_SIZE or below upon completion
FILESYSTEM="ArkOS_File_System.img"

# Create blank image
fallocate -l $IMAGE_SIZE $DISK
LOOP_DEV=$(sudo losetup --show -f $DISK)

# Create GPT label
sudo parted -s $LOOP_DEV mklabel gpt

# Define GUIDs
GUID_UBOOT="A60B0000-0000-4C7E-8000-015E00004DB7"
GUID_RESOURCE="D46E0000-0000-457F-8000-220D000030DB"
GUID_BASIC_DATA="EBD0A0A2-B9E5-4433-87C0-68B6B72699C7"

# Partition layout (sector = 512B)
# name, start_sector, end_sector, guid
declare -a PARTS=(
  "uboot 16384 24575 $GUID_UBOOT"          # 4MB
  "resource 24576 32767 $GUID_RESOURCE"    # 4MB
  "dArkOS_Fat 32768 235519 $GUID_BASIC_DATA" # 104MB
  "rootfs 237568 15445614 $GUID_BASIC_DATA" # ~7.7GB
  "4 15445615 15608046 $GUID_BASIC_DATA"   # 79MB
)

# Create partitions with sgdisk
for i in "${!PARTS[@]}"; do
  IFS=' ' read -r name start end guid <<< "${PARTS[$i]}"
  sudo sgdisk --new=$((i+1)):$start:$end --change-name=$((i+1)):$name --typecode=$((i+1)):$guid $LOOP_DEV
done

# Refresh partitions
sudo partprobe $LOOP_DEV
sleep 2

# Format partitions where needed
sudo mkfs.vfat -F 32 -n dArkOS_Fat "${LOOP_DEV}p3"
sudo mkfs.${ROOT_FILESYSTEM_FORMAT} ${ROOT_FILESYSTEM_FORMAT_PARAMETERS} "${LOOP_DEV}p4"
sudo mkfs.vfat -n ROMS "${LOOP_DEV}p5"

dd if=/dev/zero of="${FILESYSTEM}" bs=1M count=0 seek="${BUILD_SIZE}" conv=fsync
sudo mkfs.${ROOT_FILESYSTEM_FORMAT} ${ROOT_FILESYSTEM_FORMAT_PARAMETERS} "${FILESYSTEM}"
mkdir -p Arkbuild/
sudo mount -t ${ROOT_FILESYSTEM_FORMAT} -o ${ROOT_FILESYSTEM_MOUNT_OPTIONS},loop ${FILESYSTEM} Arkbuild/
