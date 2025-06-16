#!/bin/bash
sudo sed -i "/SuspendState\=/c\SuspendState\=freeze" /etc/systemd/sleep.conf
cp -f /usr/local/bin/"Sleep - Switch to Deep sleep support.sh" /opt/system/Advanced/.
sudo dd if=/usr/local/bin/uboot.img.jelos of=/dev/mmcblk1 conv=notrunc bs=512 seek=16384
sudo rm /opt/system/Advanced/"Sleep - Switch to Light sleep support.sh"
printf "\n\n\e[32mSleep mode has been switch to light mode.  Restarting OS now...\n"
printf "\033[0m"
sleep 3
sudo reboot
