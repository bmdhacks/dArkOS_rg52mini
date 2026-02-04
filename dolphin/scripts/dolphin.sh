#!/bin/bash

directory=$(dirname "$1" | cut -d "/" -f2)

for d in GC StateSaves ScreenShots Wii; do
  if [[ -d "/home/ark/.local/share/dolphin-emu/${d}" && ! -L "/home/ark/.local/share/dolphin-emu/${d}" ]]; then
    rm -rf /home/ark/.local/share/dolphin-emu/${d}
  fi
  if [[ ! -d "/$directory/gc/$d" ]]; then
    mkdir /$directory/gc/${d}
  fi
  ln -sf /$directory/gc/${d} /home/ark/.local/share/dolphin-emu/
done

export DOLPHIN_EMU_USERPATH="${HOME}/.local/share/dolphin-emu/"

/opt/dolphin/dolphin-emu-nogui -p drm -a HLE -e "${1}"

