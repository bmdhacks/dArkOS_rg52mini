#!/bin/bash
#
# DRM connector setup and HDMI detection for RK3562 (RG56 Pro)
# Creates /var/run/drmConn (required by EmulationStation for Display Settings menu)
# and /var/run/drmMode (used by RetroArch for display mode selection).
# Runs at boot via @reboot crontab.
#

# Default: internal DSI panel (connector 0, mode 0)
echo 0 | sudo tee /var/run/drmConn > /dev/null
echo 0 | sudo tee /var/run/drmMode > /dev/null

# Check if HDMI is connected via RK628 bridge
HDMI_STATUS=$(cat /sys/class/drm/card0-HDMI-A-1/status 2>/dev/null)

if [ "$HDMI_STATUS" == "connected" ]; then
    echo 1 | sudo tee /var/run/drmConn > /dev/null
fi
