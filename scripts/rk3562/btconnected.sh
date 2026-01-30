#!/bin/bash
#
# Bluetooth connection manager for RK3562 (RG56 Pro)
#

case $1 in
    check)
        # Check if Bluetooth is connected
        if bluetoothctl info 2>/dev/null | grep -q "Connected: yes"; then
            # Save reconnect state for wake
            touch /var/local/btautoreconnect.state
        fi
        ;;
    reconnect)
        # Try to reconnect last Bluetooth device
        LAST_DEVICE=$(bluetoothctl paired-devices 2>/dev/null | head -1 | awk '{print $2}')
        if [ ! -z "$LAST_DEVICE" ]; then
            bluetoothctl connect "$LAST_DEVICE" 2>/dev/null
        fi
        ;;
    *)
        echo "Usage: $0 {check|reconnect}"
        ;;
esac
