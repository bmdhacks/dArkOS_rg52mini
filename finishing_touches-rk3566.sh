#!/bin/bash

# Create extlinux.conf
sudo mkdir -p ${mountpoint}/extlinux
cat <<EOF | sudo tee ${mountpoint}/extlinux/extlinux.conf
LABEL ArkOS
  LINUX /Image
  FDT /rk3566-353m.dtb
  APPEND root=/dev/mmcblk1p4 initrd=/uInitrd rootwait rw fsck.repair=yes quiet splash net.ifnames=0 console=tty1 plymouth.ignore-serial-consoles consoleblank=0 loglevel=0 video=HDMI-A-1:1280x720@60
EOF

#sudo cp logo.bmp ${mountpoint}/
sudo cp optional/* ${mountpoint}/

# Tell systemd to ignore PowerKey presses.  Let the Global Hotkey daemon handle that
echo "HandlePowerKey=ignore" | sudo tee -a Arkbuild/etc/systemd/logind.conf

# Add some important exports to .bashrc for user ark
echo "export PATH=\"\$PATH:/usr/sbin\"" | sudo tee -a Arkbuild/home/ark/.bashrc
sudo chroot Arkbuild/ chown ark:ark /home/ark/.bashrc

# Set the name in the hostname and add it to the hosts file
echo "rg353m" | sudo tee Arkbuild/etc/hostname
sudo sed -i '/localhost/s//localhost rg353m/' Arkbuild/etc/hosts

# Copy the necessary .asoundrc file for proper audio in emulationstation and emulators
sudo cp audio/.asoundrc.${CHIPSET} Arkbuild/home/ark/.asoundrc
sudo cp audio/.asoundrcbak.${CHIPSET} Arkbuild/home/ark/.asoundrcbak
sudo cp audio/.asoundrcbt.${CHIPSET} Arkbuild/home/ark/.asoundrcbt
sudo chown ark:ark Arkbuild/home/ark/.asoundrc*

# Sleep script
sudo mkdir -p Arkbuild/usr/lib/systemd/system-sleep
sudo cp scripts/sleep Arkbuild/usr/lib/systemd/system-sleep/
sudo chmod 777 Arkbuild/usr/lib/systemd/system-sleep/sleep

# Set performance governor to ondemand on boot
sudo chroot Arkbuild/ bash -c "(crontab -l 2>/dev/null; echo \"@reboot /usr/local/bin/perfnorm quiet &\") | crontab -"

# Set DRM on boot
sudo chroot Arkbuild/ bash -c "(crontab -l 2>/dev/null; echo \"@reboot /usr/local/bin/hdmi-test.sh &\") | crontab -"

# Restore screen colors, saturation and such on boot
#sudo chroot Arkbuild/ bash -c "(crontab -l 2>/dev/null; echo \"@reboot /usr/local/bin/panel_set.sh RestoreSettings &\") | crontab -"

# Find and record panel id on boot
sudo chroot Arkbuild/ bash -c "(crontab -l 2>/dev/null; echo \"@reboot dmesg | grep 'panel id' > /home/ark/.config/.panel_info &\") | crontab -"

# Speaker Toggle to set audio output to SPK on boot
sudo mkdir -p Arkbuild/usr/local/bin
sudo cp scripts/spktoggle.sh Arkbuild/usr/local/bin/
sudo chmod 777 Arkbuild/usr/local/bin/spktoggle.sh
sudo chroot Arkbuild/ bash -c "(crontab -l 2>/dev/null; echo \"@reboot /usr/local/bin/spktoggle.sh &\") | crontab -"
#sudo cp scripts/audiopath.service Arkbuild/etc/systemd/system/audiopath.service
sudo cp scripts/audiostate.service Arkbuild/etc/systemd/system/audiostate.service
#sudo chroot Arkbuild/ bash -c "systemctl enable audiopath"
sudo chroot Arkbuild/ bash -c "systemctl enable audiostate"

# Copy necessary tools for expansion of ROOTFS and convert fat32 games partition to exfat on initial boot
sudo cp scripts/expandtoexfat.sh.${CHIPSET} ${mountpoint}/expandtoexfat.sh
sudo cp scripts/firstboot.sh ${mountpoint}/firstboot.sh
sudo cp scripts/fstab.exfat.${CHIPSET} ${mountpoint}/fstab.exfat
sudo cp scripts/firstboot.service Arkbuild/etc/systemd/system/firstboot.service
sudo chroot Arkbuild/ bash -c "systemctl enable firstboot"

# Disable getty on tty0 and tty1
sudo chroot Arkbuild/ bash -c "systemctl disable getty@tty0.service getty@tty1.service"

# Disable some other unneeded services
sudo chroot Arkbuild/ bash -c "systemctl disable ModemManager polkit"

# Disable ssh service from automatically starting
sudo chroot Arkbuild/ bash -c "systemctl disable ssh"

# Update Messaage of the Day
sudo cp -f scripts/00-header Arkbuild/etc/update-motd.d/00-header
sudo cp -f scripts/10-help-text Arkbuild/etc/update-motd.d/10-help-text
sudo rm -f Arkbuild/etc/motd
sudo chmod 777 Arkbuild/etc/update-motd.d/*

# Disable some unneeded interfaces in NetworkManager
cat <<EOF | sudo tee -a Arkbuild/etc/NetworkManager/NetworkManager.conf

[device]
wifi.scan-rand-mac-address=no

[keyfile]
unmanaged-devices=interface-name:p2p0;interface-name:ap0
EOF

# Default set timezone to New York
sudo chroot Arkbuild/ bash -c "ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime"

# Various tools available through Options added here
sudo mkdir -p Arkbuild/opt/system/Advanced
sudo cp -R dArkOS_Tools/* Arkbuild/opt/system/
sudo chroot Arkbuild/ bash -c "chown -R ark:ark /opt"
sudo chmod -R 777 Arkbuild/opt/system/

# Copy performance scripts
sudo cp scripts/perf* Arkbuild/usr/local/bin/

# Disable power saving for 8821cs wifi chip
cat <<EOF | sudo tee Arkbuild/etc/modprobe.d/8821cs.conf
# Disable power saving
options 8821cs rtw_power_mgnt=0 rtw_enusbss=0 rtw_ips_mode=0
EOF

# Copy various other backend tools
sudo cp scripts/checkbrightonboot Arkbuild/usr/local/bin/
sudo cp scripts/current_* Arkbuild/usr/local/bin/
sudo cp scripts/finish.sh Arkbuild/usr/local/bin/
sudo cp scripts/pause.sh Arkbuild/usr/local/bin/
sudo cp scripts/speak_bat_life.sh Arkbuild/usr/local/bin/
sudo cp scripts/spktoggle.sh Arkbuild/usr/local/bin/
sudo cp scripts/volume.sh Arkbuild/usr/local/bin/
sudo cp scripts/hdmi-test.sh Arkbuild/usr/local/bin/
sudo cp scripts/panel_set.sh Arkbuild/usr/local/bin/
sudo cp scripts/panel_id.sh Arkbuild/usr/local/bin/
sudo cp scripts/timezones Arkbuild/usr/local/bin/
sudo cp scripts/Sleep* Arkbuild/usr/local/bin/
sudo cp scripts/Switch* Arkbuild/usr/local/bin/
sudo cp scripts/Fix* Arkbuild/usr/local/bin/
sudo cp -R mbrola Arkbuild/usr/share/
sudo cp global/* Arkbuild/usr/local/bin/
sudo cp device/rk3566/uboot.img.anbernic Arkbuild/usr/local/bin/
sudo cp device/rk3566/uboot.img Arkbuild/usr/local/bin/uboot.img.jelos
#sudo cp device/rgb10/* Arkbuild/usr/local/bin/

# Make all scripts in /usr/local/bin executable, world style
sudo chmod 777 Arkbuild/usr/local/bin/*

# Link themes folder to /roms/themes and clone some themes to the folder
sudo rm -rf Arkbuild/etc/emulationstation/themes/
sudo chroot Arkbuild/ bash -c "ln -sfv /roms/themes/ /etc/emulationstation/themes"

# Set launchimage to PIC mode
sudo chroot Arkbuild/ touch /home/ark/.config/.GameLoadingIModePIC
sudo chroot Arkbuild/ bash -c "chown -R ark:ark /home/ark"

# Set default volume
sudo cp audio/asound.state.${CHIPSET} Arkbuild/var/local/asound.state

# Set SDL Video Driver for bash
echo "export SDL_VIDEO_EGL_DRIVER=libEGL.so" | sudo tee Arkbuild/etc/profile.d/SDL_VIDEO.sh

# Set the locale

sudo umount ${mountpoint}
#sudo losetup -d ${LOOP_BOOT}

# Format rootfs partition in final image
#ROOTFS_PART_OFFSET=$((237569 * 512))
#LOOP_ROOTFS=$(sudo losetup --find --show --offset ${ROOTFS_PART_OFFSET} ${DISK})
#sudo mkfs.ext4 -F -L ROOTFS ${LOOP_ROOTFS}
#sudo losetup -d ${LOOP_ROOTFS}

# Format ROMS partition in final image
#ROM_PART_OFFSET=$((ROM_PART_START * 512))
#ROM_PART_SIZE_BYTES=$(( (ROM_PART_END - ROM_PART_START + 1) * 512 ))
#LOOP_ROM=$(sudo losetup --find --show --offset ${ROM_PART_OFFSET} --sizelimit ${ROM_PART_SIZE_BYTES} ${DISK})
#if [ -z "$LOOP_ROM" ]; then
  #echo "❌ Failed to create loop device for ROMS partition!"
  #echo "ROM_PART_START: $ROM_PART_START"
  #echo "ROM_PART_END: $ROM_PART_END"
  #echo "ROM_PART_OFFSET: $ROM_PART_OFFSET"
  #echo "ROM_PART_SIZE_BYTES: $ROM_PART_SIZE_BYTES"
  #exit 1
#fi
#sudo mkfs.vfat -F 32 -n EASYROMS ${LOOP_ROM}
fat32_mountpoint=mnt/roms
mkdir -p ${fat32_mountpoint}
#sudo mount ${LOOP_DEV}p5 ${fat32_mountpoint}
sudo mkdir -p Arkbuild/roms
while read GAME_SYSTEM; do
  if [[ ! "$GAME_SYSTEM" =~ ^# ]]; then
    echo -e "Creating ${fat32_mountpoint}/${GAME_SYSTEM}\n"
    sudo mkdir -p ${fat32_mountpoint}/${GAME_SYSTEM}
  fi
done <game_systems.txt

# Copy default game launch images
sudo cp launchimages/loading.ascii.rg353m ${fat32_mountpoint}/launchimages/loading.ascii
sudo cp launchimages/loading.jpg.rg353m ${fat32_mountpoint}/launchimages/loading.jpg

# Copy various tools to roms folders
sudo cp -a ecwolf/Scan* ${fat32_mountpoint}/wolf/
sudo cp -a scummvm/Scan* ${fat32_mountpoint}/scummvm/
sudo cp -a scummvm/menu.scummvm ${fat32_mountpoint}/scummvm/

# Clone some themes to the roms/themes folder
sudo git clone https://github.com/Jetup13/es-theme-nes-box.git ${fat32_mountpoint}/themes/es-theme-nes-box
sync

# Create roms.tar for use after exfat partition creation
sudo tar -C mnt/ -cvf Arkbuild/roms.tar roms

# Remove and cleanup fat32 roms mountpoint
sudo chmod -R 755 ${fat32_mountpoint}
sync
#sudo umount ${fat32_mountpoint}
#sudo losetup -d ${LOOP_ROM}
sudo rm -rf ${fat32_mountpoint}
