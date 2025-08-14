#!/bin/bash

# Build and install DinguxCommander
if [ "$UNIT" == "rgb10" ]; then
  BRANCH="master"
  DEVICE_CONFIG="rk3326"
elif [ "$UNIT" == "rg351mp" ]; then
  BRANCH="rg351mp"
  DEVICE_CONFIG="rg351mp"
elif [ "$UNIT" == "rg351v" ]; then
  BRANCH="rg351mp"
  DEVICE_CONFIG="rg351v"
elif [[ "$UNIT" == *"353"* ]]; then
  BRANCH="rg351mp"
  DEVICE_CONFIG="rk3566"
elif [[ "$UNIT" == *"503"* ]]; then
  BRANCH="ogs"
  DEVICE_CONFIG="rk3566"
fi
call_chroot "cd /home/ark &&
  git clone --recursive https://github.com/christianhaitian/rs97-commander-sdl2.git -b ${BRANCH} &&
  cd rs97-commander-sdl2 &&
  make -j$(nproc) &&
  strip DinguxCommander
  "
sudo mkdir -p Arkbuild/opt/dingux
sudo cp Arkbuild/home/ark/rs97-commander-sdl2/DinguxCommander Arkbuild/opt/dingux/
sudo chmod 777 Arkbuild/opt/dingux/DinguxCommander
sudo cp -R Arkbuild/home/ark/rs97-commander-sdl2/res/ Arkbuild/opt/dingux/
if [[ -f "filecommander/configs/oshgamepad.cfg.${DEVICE_CONFIG}" ]]; then
  sudo cp filecommander/configs/oshgamepad.cfg.${DEVICE_CONFIG} Arkbuild/opt/dingux/oshgamepad.cfg
fi
call_chroot "chown -R ark:ark /opt"
sudo rm -rf Arkbuild/home/ark/rs97-commander-sdl2
