#!/bin/bash
#
# Bootstrap Debian rootfs for RK3562 (RG56 Pro)
#

echo -e "Bootstrapping Debian for RK3562....\n\n"

# Set noninteractive frontend to avoid debconf warnings in chroot
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true
if [ -f "Arkbuild_package_cache/debian_${DEBIAN_CODE_NAME}_rootfs.tar.gz" ] && [ "$(cat Arkbuild_package_cache/debian_${DEBIAN_CODE_NAME}_rootfs.commit)" == "$(curl -s https://deb.debian.org/debian/dists/stable/Release | grep "^Version:" | cut -d' ' -f2)" ]; then
    sudo tar -xvzpf Arkbuild_package_cache/debian_${DEBIAN_CODE_NAME}_rootfs.tar.gz
else
    if [[ "${ENABLE_CACHE}" == "y" ]]; then
      export DEBIAN_LOCATION="http://127.0.0.1:3142/deb.debian.org/debian/"
    else
      export DEBIAN_LOCATION="http://deb.debian.org/debian/"
    fi
    # Bootstrap base system
    sudo eatmydata debootstrap --no-check-gpg --include=eatmydata --resolve-deps --arch=arm64 --foreign ${DEBIAN_CODE_NAME} Arkbuild ${DEBIAN_LOCATION}
    sudo cp /usr/bin/qemu-aarch64-static Arkbuild/usr/bin/
    if [[ "${ENABLE_CACHE}" == "y" ]]; then
      echo 'Acquire::http::proxy "http://127.0.0.1:3142";' | sudo tee Arkbuild/etc/apt/apt.conf.d/99proxy
    fi
    # Second stage must run first to make the chroot functional
    sudo chroot Arkbuild/ /debootstrap/debootstrap --second-stage
    # Now we can install additional packages
    sudo chroot Arkbuild/ bash -c "DEBIAN_FRONTEND=noninteractive apt-get -y update"
    sudo chroot Arkbuild/ bash -c "DEBIAN_FRONTEND=noninteractive apt-get -y install ccache eatmydata"

    if [[ "${BUILD_ARMHF}" == "y" ]]; then
      # Enable armhf architecture and update
      sudo chroot Arkbuild/ dpkg --add-architecture armhf
      sudo chroot Arkbuild/ bash -c "DEBIAN_FRONTEND=noninteractive eatmydata apt-get -y update"
      sudo chroot Arkbuild/ bash -c "DEBIAN_FRONTEND=noninteractive eatmydata apt-get -y install libc6:armhf liblzma5:armhf libasound2t64:armhf libfreetype6:armhf libxkbcommon-x11-0:armhf libudev1:armhf libudev0:armhf libgbm1:armhf libstdc++6:armhf"
    fi

    sudo cat Arkbuild/etc/os-release | grep "^DEBIAN_VERSION_FULL=" | cut -d'=' -f2 > Arkbuild_package_cache/debian_${DEBIAN_CODE_NAME}_rootfs.commit
    sudo tar -cvpzf Arkbuild_package_cache/debian_${DEBIAN_CODE_NAME}_rootfs.tar.gz Arkbuild/
fi

# Bind essential host filesystems into chroot for networking
sudo mount --bind /dev Arkbuild/dev
sudo mount -t devpts none Arkbuild/dev/pts -o newinstance,ptmxmode=0666
sudo mount --bind /proc Arkbuild/proc
sudo mount --bind /sys Arkbuild/sys
echo -e "nameserver 8.8.8.8\nnameserver 1.1.1.1" | sudo tee Arkbuild/etc/resolv.conf > /dev/null

# Avoid service autostarts
echo "exit 101" | sudo tee Arkbuild/usr/sbin/policy-rc.d > /dev/null
sudo chmod 0755 Arkbuild/usr/sbin/policy-rc.d
sudo chroot Arkbuild/ mount -t proc proc /proc

# Install base runtime packages (use noninteractive to avoid debconf prompts)
sudo chroot Arkbuild/ bash -c "DEBIAN_FRONTEND=noninteractive eatmydata apt-get -y update"
sudo chroot Arkbuild/ bash -c "DEBIAN_FRONTEND=noninteractive eatmydata apt-get -y upgrade"
sudo chroot Arkbuild/ bash -c "DEBIAN_FRONTEND=noninteractive eatmydata apt-get install -y e2fsprogs initramfs-tools sudo evtest network-manager systemd-sysv locales locales-all ssh dosfstools fluidsynth"
sudo chroot Arkbuild/ bash -c "DEBIAN_FRONTEND=noninteractive eatmydata apt-get install -y python3 python3-pip"
sudo sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' Arkbuild/etc/locale.gen
echo 'LANG="en_US.UTF-8"' | sudo tee -a Arkbuild/etc/default/locale > /dev/null
echo -e "export LC_All=en_US.UTF-8" | sudo tee -a Arkbuild/root/.bashrc > /dev/null
echo -e "export LC_CTYPE=en_US.UTF-8" | sudo tee -a Arkbuild/root/.bashrc > /dev/null
sudo chroot Arkbuild/ bash -c "update-locale LANG=en_US.UTF-8"
sudo chroot Arkbuild/ bash -c "locale-gen"
sudo chroot Arkbuild/ systemctl enable NetworkManager

# Install libdrm and GBM libraries
sudo chroot Arkbuild/ bash -c "DEBIAN_FRONTEND=noninteractive eatmydata apt-get install -y libdrm-dev libgbm1"

setup_ark_user
sleep 10

# Generate /etc/fstab
# Note: RG56 Pro boots from SD card as mmcblk1 (eMMC is mmcblk0)
echo -e "Generating /etc/fstab"
FSTAB="/dev/mmcblk1p4 / ${ROOT_FILESYSTEM_FORMAT} ${ROOT_FILESYSTEM_MOUNT_OPTIONS} 0 0
/dev/mmcblk1p3 /boot vfat defaults,noatime 0 2"
if [ "$UNIT" == "rg43h" ]; then
  # RG43H Pro has only 1GB RAM — use the 256MB swap partition on the eMMC
  FSTAB="${FSTAB}
PARTLABEL=swap none swap sw,pri=10 0 0"
fi
echo -e "${FSTAB}" | sudo tee Arkbuild/etc/fstab

echo -e "Generating 10-standard.rules for udev"
echo -e "# Rules for RK3562 Mali and RGA
KERNEL==\"mali0\", GROUP=\"video\", MODE=\"0660\"
KERNEL==\"rga\", GROUP=\"video\", MODE=\"0660\"
ACTION==\"add\", SUBSYSTEM==\"backlight\", RUN+=\"/bin/chgrp video /sys/class/backlight/%k/brightness\"
ACTION==\"add\", SUBSYSTEM==\"backlight\", RUN+=\"/bin/chmod g+w /sys/class/backlight/%k/brightness\"
ACTION==\"add|change\", KERNEL==\"sd[a-z]*|mmcblk[0-9]*\", ATTR{queue/rotational}==\"0\", ATTR{queue/scheduler}=\"bfq\"" | sudo tee Arkbuild/etc/udev/rules.d/10-standard.rules

echo -e "Generating 40-usb_modeswitch.rules for udev"
echo -e "# Rules
ACTION!=\"add|change\", GOTO=\"end_modeswitch\"

# Atheros Wireless / Netgear WNDA3200
ATTRS{idVendor}==\"0cf3\", ATTRS{idProduct}==\"20ff\", RUN+=\"/usr/bin/eject '/dev/%k'\"

# Realtek RTL8821CU chipset 802.11ac NIC
ATTR{idVendor}==\"0bda\", ATTR{idProduct}==\"1a2b\", RUN+=\"/usr/sbin/usb_modeswitch -K -v 0bda -p 1a2b\"
ATTR{idVendor}==\"0bda\", ATTR{idProduct}==\"c811\", RUN+=\"/usr/sbin/usb_modeswitch -K -v 0bda -p c811\"

LABEL=\"end_modeswitch\"" | sudo tee Arkbuild/etc/udev/rules.d/40-usb_modeswitch.rules

sudo chroot Arkbuild/ sync
sleep 5
sudo chroot Arkbuild/ umount /proc

echo "Bootstrap complete for RK3562"
