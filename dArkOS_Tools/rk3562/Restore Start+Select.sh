#!/bin/bash
printf "\033c" >> /dev/tty1
echo 0 | sudo tee /sys/devices/platform/play_joystick/swap_start_home > /dev/null
rm -f /home/ark/.config/.SWAP_START_HOME
printf "\n\n\n\e[32mStart+Select restored to normal.\n" > /dev/tty1
sudo cp "/usr/local/bin/Swap Start+Select with FN+Back.sh" "/opt/system/Advanced/"
sudo rm "/opt/system/Advanced/Restore Start+Select.sh"
sleep 2
printf "\033c" >> /dev/tty1
sudo systemctl restart emulationstation
