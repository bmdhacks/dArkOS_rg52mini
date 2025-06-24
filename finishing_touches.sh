#!/bin/bash

# Create boot.ini
cat <<EOF | sudo tee ${mountpoint}/boot.ini
odroidgoa-uboot-config

setenv bootargs "root=/dev/mmcblk0p2 rootwait rw fsck.repair=yes net.ifnames=0 fbcon=rotate:3 console=/dev/ttyFIQ0 quiet splash consoleblank=0 vt.global_cursor_default=0"

# Booting
setenv loadaddr "0x02000000"
setenv initrd_loadaddr "0x04000000"
setenv dtb_loadaddr "0x01f00000"

load mmc 1:1 \${loadaddr} Image
load mmc 1:1 \${initrd_loadaddr} uInitrd

if test \${hwrev} = 'v11'; then
load mmc 1:1 \${dtb_loadaddr} ${CHIPSET}-odroidgo2-linux-v11.dtb
elif test \${hwrev} = 'v10-go3'; then
load mmc 1:1 \${dtb_loadaddr} ${CHIPSET}-odroidgo3-linux.dtb
else
load mmc 1:1 \${dtb_loadaddr} ${CHIPSET}-odroidgo2-linux.dtb
fi

booti \${loadaddr} \${initrd_loadaddr} \${dtb_loadaddr}
EOF

sudo cp logo.bmp ${mountpoint}/
sudo cp optional/* ${mountpoint}/

# Tell systemd to ignore PowerKey presses.  Let the Global Hotkey daemon handle that
echo "HandlePowerKey=ignore" | sudo tee -a Arkbuild/etc/systemd/logind.conf

# Add some important exports to .bashrc for user ark
echo "export PATH=\"\$PATH:/usr/sbin\"" | sudo tee -a Arkbuild/home/ark/.bashrc
sudo chroot Arkbuild/ chown ark:ark /home/ark/.bashrc

# Set the name in the hostname and add it to the hosts file
echo "rgb10" | sudo tee Arkbuild/etc/hostname
sudo sed -i '/localhost/s//localhost rgb10/' Arkbuild/etc/hosts

# Copy the necessary .asoundrc file for proper audio in emulationstation and emulators
sudo cp audio/.asoundrc* Arkbuild/home/ark/
sudo chown ark:ark Arkbuild/home/ark/.asoundrc*

# Sleep script
sudo mkdir -p Arkbuild/usr/lib/systemd/system-sleep
sudo cp scripts/sleep.${CHIPSET} Arkbuild/usr/lib/systemd/system-sleep/sleep
sudo chmod 777 Arkbuild/usr/lib/systemd/system-sleep/sleep

# Set performance governor to ondemand on boot
sudo chroot Arkbuild/ bash -c "(crontab -l 2>/dev/null; echo \"@reboot /usr/local/bin/perfnorm quiet &\") | crontab -"

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
#sudo cp scripts/fstab.exfat.${CHIPSET} ${mountpoint}/fstab.exfat
sudo cp scripts/firstboot.service Arkbuild/etc/systemd/system/firstboot.service
sudo chroot Arkbuild/ bash -c "systemctl enable firstboot"

# Add hotkeydaemon service and python script
sudo cp hotkeydaemon/killer_daemon.service Arkbuild/etc/systemd/system/killer_daemon.service
sudo cp hotkeydaemon/killer_daemon.py Arkbuild/usr/local/bin/killer_daemon.py
sudo chmod 777 Arkbuild/usr/local/bin/killer_daemon.py

#Generate fstab to be used after EASYROMS expansion
cat <<EOF | sudo tee ${mountpoint}/fstab.exfat
LABEL=ROOTFS / ${ROOT_FILESYSTEM_FORMAT} defaults,noatime 0 0

LABEL=BOOT /boot vfat defaults 0 2
LABEL=EASYROMS /roms exfat defaults,auto,umask=000,uid=1000,gid=1000,noatime 0 0
/roms/tools /opt/system/Tools none bind
EOF

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

# Copy various other backend tools
sudo cp scripts/checkbrightonboot Arkbuild/usr/local/bin/
sudo cp scripts/current_* Arkbuild/usr/local/bin/
sudo cp scripts/finish.sh Arkbuild/usr/local/bin/
sudo cp scripts/pause.sh Arkbuild/usr/local/bin/
sudo cp scripts/speak_bat_life.sh Arkbuild/usr/local/bin/
sudo cp scripts/spktoggle.sh Arkbuild/usr/local/bin/
sudo cp scripts/timezones Arkbuild/usr/local/bin/
sudo cp global/* Arkbuild/usr/local/bin/
sudo cp device/rgb10/* Arkbuild/usr/local/bin/

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

# Set device name 
if [ "$CHIPSET" == "rk3326" ]; then
  echo "rgb10" | sudo tee Arkbuild/home/ark/.config/.DEVICE
fi

# Set the locale

sudo umount ${mountpoint}
sudo losetup -d ${LOOP_BOOT}

# Format rootfs partition in final image
ROOTFS_PART_OFFSET=$((STORAGE_PART_START * 512))
LOOP_ROOTFS=$(sudo losetup --find --show --offset ${ROOTFS_PART_OFFSET} ${DISK})
sudo mkfs.${ROOT_FILESYSTEM_FORMAT} -F -L ROOTFS ${LOOP_ROOTFS}
sudo losetup -d ${LOOP_ROOTFS}

# Format ROMS partition in final image
ROM_PART_OFFSET=$((ROM_PART_START * 512))
ROM_PART_SIZE_BYTES=$(( (ROM_PART_END - ROM_PART_START + 1) * 512 ))
LOOP_ROM=$(sudo losetup --find --show --offset ${ROM_PART_OFFSET} --sizelimit ${ROM_PART_SIZE_BYTES} ${DISK})
if [ -z "$LOOP_ROM" ]; then
  echo "❌ Failed to create loop device for ROMS partition!"
  echo "ROM_PART_START: $ROM_PART_START"
  echo "ROM_PART_END: $ROM_PART_END"
  echo "ROM_PART_OFFSET: $ROM_PART_OFFSET"
  echo "ROM_PART_SIZE_BYTES: $ROM_PART_SIZE_BYTES"
  exit 1
fi
sudo mkfs.vfat -F 32 -n EASYROMS ${LOOP_ROM}
fat32_mountpoint=mnt/roms
mkdir -p ${fat32_mountpoint}
sudo mount ${LOOP_ROM} ${fat32_mountpoint}
sudo mkdir -p Arkbuild/roms
while read GAME_SYSTEM; do
  if [[ ! "$GAME_SYSTEM" =~ ^# ]]; then
    echo -e "Creating ${fat32_mountpoint}/${GAME_SYSTEM}\n"
    sudo mkdir -p ${fat32_mountpoint}/${GAME_SYSTEM}
  fi
done <game_systems.txt

# Copy default game launch images
sudo cp launchimages/loading.ascii.rgb10 ${fat32_mountpoint}/launchimages/loading.ascii
sudo cp launchimages/loading.jpg.rgb10 ${fat32_mountpoint}/launchimages/loading.jpg

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
sudo umount ${fat32_mountpoint}
sudo losetup -d ${LOOP_ROM}
sudo rm -rf ${fat32_mountpoint}
