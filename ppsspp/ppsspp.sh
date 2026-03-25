#!/bin/bash

directory=$(dirname "$2" | cut -d "/" -f2)

ln -sf /$directory/psp/ppsspp/ /home/ark/.config/

if  [[ $1 == "standalone" ]]; then
  if  [[ ! -d "/$directory/psp/ppsspp" ]]; then
    cp -rf /opt/ppsspp/backupforromsfolder/ppsspp /$directory/psp
  fi
  if  [[ ! -f "/$directory/psp/ppsspp/PSP/SYSTEM/controls.ini" ]]; then
    cp -rf /opt/ppsspp/backupforromsfolder/ppsspp/PSP/SYSTEM/controls.ini /$directory/psp/ppsspp/PSP/SYSTEM/controls.ini
  fi
  if  [[ ! -f "/$directory/psp/ppsspp/PSP/SYSTEM/ppsspp.ini.sdl" ]]; then
    cp -rf /opt/ppsspp/backupforromsfolder/ppsspp/PSP/SYSTEM/ppsspp.ini.sdl /$directory/psp/ppsspp/PSP/SYSTEM/ppsspp.ini.sdl
  fi
  echo "VAR=PPSSPPSDL" > /home/ark/.config/KILLIT
  sudo systemctl restart killer_daemon.service
  cp -f /$directory/psp/ppsspp/PSP/SYSTEM/ppsspp.ini.sdl /$directory/psp/ppsspp/PSP/SYSTEM/ppsspp.ini
  xres="$(cat /sys/class/graphics/fb0/modes | grep -o -P '(?<=:).*(?=p-)' | cut -dx -f1)"
  if [ $xres -ge "1280" ]; then
    HDMI="/usr/lib/aarch64-linux-gnu/libSDL2-2.0.so.0.10.0"
  fi
  LD_PRELOAD="$HDMI" /opt/ppsspp/PPSSPPSDL --fullscreen "$2"
  cp -f /$directory/psp/ppsspp/PSP/SYSTEM/ppsspp.ini /$directory/psp/ppsspp/PSP/SYSTEM/ppsspp.ini.sdl
  sudo systemctl stop killer_daemon.service
elif [[ $1 == "standalone-2021" ]]; then
  if  [[ ! -d "/$directory/psp/ppsspp" ]]; then
    cp -rf /opt/ppsspp/backupforromsfolder/ppsspp /$directory/psp
  fi
  if  [[ ! -f "/$directory/psp/ppsspp/PSP/SYSTEM/controls.ini" ]]; then
    cp -rf /opt/ppsspp/backupforromsfolder/ppsspp/PSP/SYSTEM/controls.ini /$directory/psp/ppsspp/PSP/SYSTEM/controls.ini
  fi
  if  [[ ! -f "/$directory/psp/ppsspp/PSP/SYSTEM/ppsspp.ini.sdl" ]]; then
    cp -rf /opt/ppsspp/backupforromsfolder/ppsspp/PSP/SYSTEM/ppsspp.ini.sdl /$directory/psp/ppsspp/PSP/SYSTEM/ppsspp.ini.sdl
  fi
  export SDL_AUDIODRIVER=alsa
  echo "VAR=PPSSPPSDL" > /home/ark/.config/KILLIT
  sudo systemctl restart killer_daemon.service
  cp -f /$directory/psp/ppsspp/PSP/SYSTEM/ppsspp.ini.sdl /$directory/psp/ppsspp/PSP/SYSTEM/ppsspp.ini
  /opt/ppsspp-2021/PPSSPPSDL --fullscreen "$2"
  cp -f /$directory/psp/ppsspp/PSP/SYSTEM/ppsspp.ini /$directory/psp/ppsspp/PSP/SYSTEM/ppsspp.ini.sdl
  sudo systemctl stop killer_daemon.service
  unset SDL_AUDIODRIVER
else
  if [[ ! -d "/$directory/psp/PSP" ]]; then
    mkdir /$directory/psp/PSP
  fi
  if [[ ! -d "/$directory/psp/PSP/SAVEDATA" ]]; then
    mkdir /$directory/psp/PSP/SAVEDATA
  fi
  if [[ ! -d "/$directory/psp/SAVEDATA" ]]; then
    mkdir /$directory/psp/SAVEDATA
  fi
  /usr/local/bin/watchpsp.sh $directory &
  /usr/local/bin/retroarch -L /home/ark/.config/retroarch/cores/ppsspp_libretro.so "$2"
  sudo kill -9 $(pidof watchpsp.sh)
fi

# Restore RK817 codec state after emulator exit (RK3562 devices only) —
# PPSSPP can leave the audio path in a bad state.
if [ "$(cat /home/ark/.config/.DEVICE)" == "RG56PRO" ] || [ "$(cat /home/ark/.config/.DEVICE)" == "RG43H" ]; then
  amixer -q sset 'Playback Path' HP 2>/dev/null
  amixer -q sset 'Resume Path' ON 2>/dev/null
fi
