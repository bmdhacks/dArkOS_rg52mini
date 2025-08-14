#!/bin/bash

# Create boot.ini
if [ "$UNIT" == "rg351mp" ]; then
  INITRD_LOADERADDRESS="0x01100000"
else
  INITRD_LOADERADDRESS="0x04000000"
fi
cat <<EOF | sudo tee ${mountpoint}/boot.ini
odroidgoa-uboot-config

setenv bootargs "root=/dev/mmcblk0p2 rootwait rw fsck.repair=yes net.ifnames=0 fbcon=rotate:${SCREEN_ROTATION} console=/dev/ttyFIQ0 quiet splash consoleblank=0 vt.global_cursor_default=0"

# Booting
setenv loadaddr "0x02000000"
setenv initrd_loadaddr "${INITRD_LOADERADDRESS}"
setenv dtb_loadaddr "0x01f00000"

load mmc 1:1 \${loadaddr} Image
load mmc 1:1 \${initrd_loadaddr} uInitrd

load mmc 1:1 \${dtb_loadaddr} ${KERNEL_DTB}

booti \${loadaddr} \${initrd_loadaddr} \${dtb_loadaddr}
EOF

if [ "$UNIT" == "rgb10" ] || [ "$UNIT" == "rk2020" ]; then
  sudo cp logos/rotated/logo.bmp ${mountpoint}/
else
  sudo cp logos/unrotated/logo.bmp ${mountpoint}/
fi

if [ -d "optional" ]; then
  if [ ! -z "$(find optional/ -mindepth 1 -maxdepth 1)" ]; then
    sudo cp optional/* ${mountpoint}/
  fi
fi

# Tell systemd to ignore PowerKey presses.  Let the Global Hotkey daemon handle that
echo "HandlePowerKey=ignore" | sudo tee -a Arkbuild/etc/systemd/logind.conf

# Add some important exports to .bashrc for user ark
echo "export PATH=\"\$PATH:/usr/sbin\"" | sudo tee -a Arkbuild/home/ark/.bashrc
sudo chroot Arkbuild/ bash -c "chown ark:ark /home/ark/.bashrc"

# Set the name in the hostname and add it to the hosts file
if [[ "$UNIT" == *"353"* ]] || [[ "$UNIT" == *"503"* ]]; then
  NAME="rg${UNIT}"
else
  NAME="${UNIT}"
fi
echo "$NAME" | sudo tee Arkbuild/etc/hostname
echo -e "# This host address\n127.0.1.1\t${NAME}" | sudo tee -a Arkbuild/etc/hosts
#sudo sed -i '0,/localhost/s//localhost rgb10/' Arkbuild/etc/hosts

# Copy the necessary .asoundrc file for proper audio in emulationstation and emulators
sudo cp audio/.asoundrc* Arkbuild/home/ark/
sudo chroot Arkbuild/ bash -c "chown ark:ark /home/ark/.asoundrc*"

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
#sudo chroot Arkbuild/ bash -c "(crontab -l 2>/dev/null; echo \"@reboot /usr/local/bin/spktoggle.sh &\") | crontab -"
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
sudo chroot Arkbuild/ bash -c "systemctl disable killer_daemon"

# Add amiga script
sudo cp amiga/amiga.sh Arkbuild/usr/local/bin/

#Generate fstab to be used after EASYROMS expansion
cat <<EOF | sudo tee ${mountpoint}/fstab.exfat
LABEL=ROOTFS / ${ROOT_FILESYSTEM_FORMAT} ${ROOT_FILESYSTEM_MOUNT_OPTIONS} 0 0

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
sudo cp dArkOS_Tools/*.sh Arkbuild/opt/system/
sudo cp dArkOS_Tools/${CHIPSET}/*.sh Arkbuild/opt/system/Advanced/
sudo cp dArkOS_Tools/Advanced/*.sh Arkbuild/opt/system/Advanced/
if [[ "$UNIT" == *"rgb10"* ]] || [[ "$UNIT" == "rk2020" ]] || [[ "$UNIT" == *"oga"* ]]; then
  sudo cp dArkOS_Tools/OGA/*.sh Arkbuild/opt/system/Advanced/
fi
sudo chroot Arkbuild/ bash -c "chown -R ark:ark /opt"
sudo chmod -R 777 Arkbuild/opt/system/

# Copy performance scripts
sudo cp scripts/perf* Arkbuild/usr/local/bin/

# Add USB DAC Support
echo -e "Generating 20-usb-alsa.rules udev for usb dac support"
echo -e "KERNEL==\"controlC[0-9]*\", DRIVERS==\"usb\", SYMLINK=\"snd/controlC7\"" | sudo tee Arkbuild/etc/udev/rules.d/20-usb-alsa.rules
sudo chroot Arkbuild/ bash -c "(crontab -l 2>/dev/null; echo \"@reboot /usr/local/bin/checknswitchforusbdac.sh &\") | crontab -"

# Copy various other backend tools
sudo cp scripts/checkbrightonboot Arkbuild/usr/local/bin/
sudo cp scripts/current_* Arkbuild/usr/local/bin/
sudo cp scripts/finish.sh Arkbuild/usr/local/bin/
sudo cp scripts/pause.sh Arkbuild/usr/local/bin/
sudo cp scripts/speak_bat_life.sh Arkbuild/usr/local/bin/
sudo cp scripts/spktoggle.sh Arkbuild/usr/local/bin/
sudo cp scripts/timezones Arkbuild/usr/local/bin/
sudo cp global/* Arkbuild/usr/local/bin/
if [[ "$UNIT" == "rgb10" ]]; then
  sudo cp device/rgb10/* Arkbuild/usr/local/bin/
elif [[ "$UNIT" == "rg351mp" ]]; then
  sudo cp device/rg351mp/*.sh Arkbuild/usr/local/bin/
  sudo cp device/rg351mp/*.py Arkbuild/usr/local/bin/
  sudo cp device/rg351mp/*.green Arkbuild/usr/local/bin/
  sudo cp device/rg351mp/*.red Arkbuild/usr/local/bin/
  sudo cp device/rg351mp/fix_power_led Arkbuild/usr/local/bin/
  sudo cp device/rg351mp/checkbrightonboot Arkbuild/usr/local/bin/
  sudo cp device/rg351mp/"Change LED to Red.sh" Arkbuild/opt/system/
  sudo chroot Arkbuild/ bash -c "chown -R ark:ark /opt"
  sudo chmod 777 Arkbuild/opt/system/"Change LED to Red.sh"
  sudo cp device/rg351mp/*.service Arkbuild/etc/systemd/system/
  sudo chroot Arkbuild/ bash -c "systemctl enable 351mp batt_led"
fi

# Make all scripts in /usr/local/bin executable, world style
sudo chmod 777 Arkbuild/usr/local/bin/*

# Link themes folder to /roms/themes and clone some themes to the folder
sudo rm -rf Arkbuild/etc/emulationstation/themes/
sudo chroot Arkbuild/ bash -c "ln -sfv /roms/themes/ /etc/emulationstation/themes"

# Link music folder to /roms/bgmusic
sudo rm -rf Arkbuild/etc/emulationstation/music/
sudo chroot Arkbuild/ bash -c "ln -sfv /roms/bgmusic/ /etc/emulationstation/music"

# Set launchimage to PIC mode
sudo chroot Arkbuild/ touch /home/ark/.config/.GameLoadingIModePIC

# Set default volume
sudo cp audio/asound.state.${CHIPSET} Arkbuild/var/local/asound.state

# Set SDL Video Driver for bash
echo "export SDL_VIDEO_EGL_DRIVER=libEGL.so" | sudo tee Arkbuild/etc/profile.d/SDL_VIDEO.sh

# Set device name 
if [ "$CHIPSET" == "rk3326" ]; then
  echo "rgb10" | sudo tee Arkbuild/home/ark/.config/.DEVICE
fi

# Configure default samba share setup
cat <<EOF | sudo tee -a Arkbuild/etc/samba/smb.conf
[roms]
   comment = ROMS
   path = /roms
   browsable = yes
   read only = no
   map archive = no
   map system = no
   map hidden = no
   guest ok = yes
   read list = guest

[opt]
   comment = OPT
   path = /opt
   browsable = yes
   read only = no
   map archive = no
   map system = no
   map hidden = no
   guest ok = yes
   read list = guest

[ark]
   comment = ark
   path = /home/ark
   browsable = yes
   read only = no
   map archive = no
   map system = no
   map hidden = no
   guest ok = yes
   read list = guest
EOF
sudo chroot Arkbuild/ bash -c "systemctl disable smbd"
sudo chroot Arkbuild/ bash -c "systemctl disable nmbd"

# Set distro identification and version
sudo mkdir -p Arkbuild/usr/share/plymouth/themes/
cat <<EOF | sudo tee Arkbuild/usr/share/plymouth/themes/text.plymouth
title=dArkOS (${BUILD_DATE})
EOF
echo "${BUILD_DATE}" | sudo tee Arkbuild/home/ark/.config/.VERSION

# Set boot up welcome text with distro and version
sudo cp scripts/boot_text.sh Arkbuild/usr/local/bin/
sudo chmod 777 Arkbuild/usr/local/bin/boot_text.sh
sudo cp scripts/welcome-message.service Arkbuild/etc/systemd/system/welcome-message.service
sudo chroot Arkbuild/ bash -c "systemctl enable welcome-message"

# Set the ownver of the ark folder and all sub content to ark
sudo chroot Arkbuild/ bash -c "chown -R ark:ark /home/ark"

# Clone some themes to the tempthemes folder
sudo mkdir Arkbuild/tempthemes
if [[ "$UNIT" == *"rgb10"* ]] || [[ "$UNIT" == "rk2020" ]] || [[ "$UNIT" == *"oga"* ]]; then
  sudo git clone --depth=1 https://github.com/pix33l/es-theme-pixui.git Arkbuild/tempthemes/es-theme-pixui
fi
sudo git clone --depth=1 https://github.com/Jetup13/es-theme-freeplay.git Arkbuild/tempthemes/es-theme-freeplay
sudo git clone --depth=1 https://github.com/Jetup13/es-theme-minimal-arkos.git Arkbuild/tempthemes/es-theme-minimal-arkos
sudo git clone --depth=1 https://github.com/Jetup13/es-theme-nes-box.git Arkbuild/tempthemes/es-theme-nes-box
sudo git clone --depth=1 https://github.com/Jetup13/es-theme-switch.git Arkbuild/tempthemes/es-theme-switch
sudo git clone --depth=1 https://github.com/dani7959/es-theme-replica.git Arkbuild/tempthemes/es-theme-replica

sync
sudo umount -l ${mountpoint}
#while true; do
  #sleep 1
  #if [[ -z "$(fuser -c ${mountpoint})" ]]; then
    #break
  #fi
  #echo "${mountpoint} is still in use.  Attempting to force close processes using it..."
  #sudo fuser -ckv -9 ${mountpoint}
#done
sudo losetup -d ${LOOP_BOOT}

# Format rootfs partition in final image
ROOTFS_PART_OFFSET=$((STORAGE_PART_START * 512))
LOOP_ROOTFS=$(sudo losetup --find --show --offset ${ROOTFS_PART_OFFSET} ${DISK})
sudo mkfs.${ROOT_FILESYSTEM_FORMAT} ${ROOT_FILESYSTEM_FORMAT_PARAMETERS} ${LOOP_ROOTFS}
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
sudo cp -a scummvm/scripts/Scan* ${fat32_mountpoint}/scummvm/
sudo cp -a hypseus-singe/scripts/Scan* ${fat32_mountpoint}/scummvm/
sudo cp -a scummvm/scripts/menu.scummvm ${fat32_mountpoint}/scummvm/

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
