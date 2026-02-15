#!/bin/bash
#
# Fix Audio for RK3562 (RG56 Pro)
# Resets audio configuration for RK817 codec
#

# Kill any audio-using processes
sudo killall -9 retroarch 2>/dev/null
sudo killall -9 emulationstation 2>/dev/null

# Restore default audio config
cp /home/ark/.asoundrcbak /home/ark/.asoundrc

# Restore ALSA state
sudo /usr/sbin/alsactl restore -f /var/local/asound.state 2>/dev/null

# Set playback path to speaker
amixer -q sset 'Playback Path' HP 2>/dev/null

echo "Audio configuration reset for RK817 codec"
sleep 2
