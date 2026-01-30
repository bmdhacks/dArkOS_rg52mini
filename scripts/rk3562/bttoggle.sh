#!/bin/bash
#
# Bluetooth toggle for RK3562 (RG56 Pro)
#

if systemctl is-active --quiet bluetooth; then
    # Bluetooth is on, turn it off
    sudo systemctl stop bluetooth
    sudo systemctl stop bluealsa 2>/dev/null
    echo "Bluetooth disabled"
else
    # Bluetooth is off, turn it on
    sudo systemctl start bluetooth
    sudo systemctl start bluealsa 2>/dev/null
    echo "Bluetooth enabled"
fi
