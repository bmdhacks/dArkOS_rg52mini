#!/bin/bash
printf "\033c" >> /dev/tty1
echo 1 | sudo tee /sys/devices/platform/play_joystick/swap_start_home > /dev/null
touch /home/ark/.config/.SWAP_START_HOME
printf "\n\n\n\e[32mStart+Select swapped with FN+Back.\n" > /dev/tty1
sudo cp "/usr/local/bin/Restore Start+Select.sh" "/opt/system/Advanced/"
sudo rm "/opt/system/Advanced/Swap Start+Select with FN+Back.sh"
sleep 2
printf "\033c" >> /dev/tty1
sudo systemctl restart emulationstation
