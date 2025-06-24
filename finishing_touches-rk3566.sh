#!/bin/bash

# Create extlinux.conf
sudo mkdir -p ${mountpoint}/extlinux
cat <<EOF | sudo tee ${mountpoint}/extlinux/extlinux.conf
LABEL ArkOS
  LINUX /Image
  FDT /${UNIT_DTB}.dtb
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
if [[ "$UNIT" == *"353"* ]] || [[ "$UNIT" == *"503"* ]]; then
  NAME="rg${UNIT}"
fi
echo "$NAME" | sudo tee Arkbuild/etc/hostname
sudo sed -i "/localhost/s//localhost ${NAME}/" Arkbuild/etc/hosts

# Copy the necessary .asoundrc file for proper audio in emulationstation and emulators
sudo cp audio/.asoundrc.${CHIPSET} Arkbuild/home/ark/.asoundrc
sudo cp audio/.asoundrcbak.${CHIPSET} Arkbuild/home/ark/.asoundrcbak
sudo cp audio/.asoundrcbt.${CHIPSET} Arkbuild/home/ark/.asoundrcbt
sudo chown ark:ark Arkbuild/home/ark/.asoundrc*

# Sleep script
sudo mkdir -p Arkbuild/usr/lib/systemd/system-sleep
sudo cp scripts/sleep.${CHIPSET} Arkbuild/usr/lib/systemd/system-sleep/sleep
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
#sudo cp scripts/fstab.exfat.${CHIPSET} ${mountpoint}/fstab.exfat
sudo cp scripts/firstboot.service Arkbuild/etc/systemd/system/firstboot.service
sudo chroot Arkbuild/ bash -c "systemctl enable firstboot"

# Add hotkeydaemon service and python script
sudo cp hotkeydaemon/killer_daemon.service Arkbuild/etc/systemd/system/killer_daemon.service
sudo cp hotkeydaemon/killer_daemon.py Arkbuild/usr/local/bin/killer_daemon.py
sudo chmod 777 Arkbuild/usr/local/bin/killer_daemon.py

#Generate fstab to be used after EASYROMS expansion
cat <<EOF | sudo tee ${mountpoint}/fstab.exfat
/dev/mmcblk1p4  /  ${ROOT_FILESYSTEM_FORMAT}  defaults,noatime  0 0

/dev/mmcblk1p3 /boot vfat defaults,noatime 0 0
/dev/mmcblk1p5 /roms exfat defaults,auto,umask=000,uid=1002,gid=1002,noatime 0 0
/roms/tools /opt/system/Tools none nofail,x-systemd.device-timeout=7,bind
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
sudo cp global/* Arkbuild/usr/local/bin/
sudo cp device/rk3566/uboot.img.anbernic Arkbuild/usr/local/bin/
sudo mv device/rk3566/uboot.img.jelos Arkbuild/usr/local/bin/uboot.img.jelos

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
echo "$NAME" | sudo tee Arkbuild/home/ark/.config/.DEVICE

# Set the locale

sudo umount ${mountpoint}

fat32_mountpoint=mnt/roms
mkdir -p ${fat32_mountpoint}
sudo mkdir -p Arkbuild/roms
while read GAME_SYSTEM; do
  if [[ ! "$GAME_SYSTEM" =~ ^# ]]; then
    echo -e "Creating ${fat32_mountpoint}/${GAME_SYSTEM}\n"
    sudo mkdir -p ${fat32_mountpoint}/${GAME_SYSTEM}
  fi
done <game_systems.txt

# Copy default game launch images
sudo cp launchimages/loading.ascii.${UNIT} ${fat32_mountpoint}/launchimages/loading.ascii
sudo cp launchimages/loading.jpg.${UNIT} ${fat32_mountpoint}/launchimages/loading.jpg

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

sudo rm -rf ${fat32_mountpoint}
