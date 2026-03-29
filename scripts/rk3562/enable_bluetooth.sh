#!/bin/bash
#
# Enable Bluetooth for RK3562 (RG52 Mini)
#

sudo systemctl start bluetooth
sudo systemctl start bluealsa 2>/dev/null
bluetoothctl power on 2>/dev/null
