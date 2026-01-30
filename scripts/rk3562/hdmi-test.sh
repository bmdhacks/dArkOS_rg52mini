#!/bin/bash
#
# HDMI detection and configuration for RK3562 (RG56 Pro)
# Uses RK628 HDMI bridge chip
#

# Check if HDMI is connected
HDMI_STATUS=$(cat /sys/class/drm/card0-HDMI-A-1/status 2>/dev/null)

if [ "$HDMI_STATUS" == "connected" ]; then
    # HDMI is connected - configure for external display
    echo "HDMI connected"

    # Set HDMI audio output if available
    if [ -d "/sys/class/sound/card1" ]; then
        # Card 1 is typically the HDMI audio (rockchiphdmirk628)
        echo "HDMI audio available"
    fi
else
    # HDMI not connected - use internal panel
    echo "HDMI not connected, using internal panel"
fi
