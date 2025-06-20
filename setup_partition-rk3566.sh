#!/bin/bash
#set -e

ROOT_FILESYSTEM_FORMAT="xfs"
DISK="ArkOS_RG353M.img"
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
  "ANBERNIC 32768 235519 $GUID_BASIC_DATA" # 104MB
  "rootfs 237568 15421439 $GUID_BASIC_DATA" # ~7.7GB
  "4 15421440 15583871 $GUID_BASIC_DATA"   # 79MB
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
sudo mkfs.vfat -n ANBERNIC "${LOOP_DEV}p3"
sudo mkfs.${ROOT_FILESYSTEM_FORMAT} -L rootfs "${LOOP_DEV}p4"
sudo mkfs.vfat -n ROMS "${LOOP_DEV}p5"

# Copy content (example only)
#echo "Copying boot files to ANBERNIC..."
#mount "${LOOP_DEV}p3" /mnt
#cp android/Image /mnt/
#cp android/rk3566-anbernic-rg353m.dtb /mnt/
#cp boot/extlinux.conf /mnt/
#umount /mnt

#echo "Extracting rootfs..."
#mount "${LOOP_DEV}p4" /mnt
#tar -xpf rootfs/rootfs.tar.gz -C /mnt
#umount /mnt

#echo "Flashing uboot.img and resource.img..."
#sudo dd if=device/rk3566/uboot.img of=$LOOP_DEV bs=$SECTOR_SIZE seek=16384 conv=notrunc
#sudo dd if=device/rk3566/resource.img of=$LOOP_DEV bs=$SECTOR_SIZE seek=24576 conv=notrunc

dd if=/dev/zero of="${FILESYSTEM}" bs=1M count=0 seek="${BUILD_SIZE}" conv=fsync
sudo mkfs.${ROOT_FILESYSTEM_FORMAT} -F -L ROOTFS "${FILESYSTEM}"
mkdir -p Arkbuild/
sudo mount -t ${ROOT_FILESYSTEM_FORMAT} -o loop ${FILESYSTEM} Arkbuild/

#sudo losetup -d $LOOP_DEV
#echo "✅ ArkOS-like image created: $DISK"
