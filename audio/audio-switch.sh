#!/bin/bash
# Switch ~/.asoundrc to HDMI when an HDMI display is connected, restore the
# default config when it's disconnected. Triggered by 99-hdmi-audio.rules on
# any DRM card add/change event.

HDMI_STATUS=$(cat /sys/class/drm/card0-HDMI-A-1/status 2>/dev/null)

if [ "$HDMI_STATUS" = "connected" ]; then
    cp /home/ark/.asoundrchdmi /home/ark/.asoundrc
else
    cp /home/ark/.asoundrcbak /home/ark/.asoundrc
fi
