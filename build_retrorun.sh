#!/bin/bash

# Build and install Retrorun and Retrorun32
sudo chroot Arkbuild/ bash -c "cd /home/ark &&
  if [ ! -d rk3326_core_builds ]; then git clone https://github.com/christianhaitian/rk3326_core_builds.git; fi &&
  cd rk3326_core_builds &&
  chmod 777 builds-alt.sh &&
  ./builds-alt.sh retrorun
  "
sudo chroot Arkbuild32/ bash -c "cd /home/ark &&
  if [ ! -d rk3326_core_builds ]; then git clone https://github.com/christianhaitian/rk3326_core_builds.git; fi &&
  cd rk3326_core_builds &&
  chmod 777 builds-alt.sh &&
  ./builds-alt.sh retrorun
  "
sudo cp -a Arkbuild/home/ark/rk3326_core_builds/retrorun-64/retrorun-rk3326 Arkbuild/usr/local/bin/retrorun
sudo cp -a Arkbuild32/home/ark/rk3326_core_builds/retrorun-32/retrorun32-rk3326 Arkbuild/usr/local/bin/retrorun32
sudo cp -a retrorun/scripts/*.sh Arkbuild/usr/local/bin/
sudo cp -a retrorun/configs/retrorun.cfg.rk3326 Arkbuild/home/ark/.config/retrorun.cfg

sudo chmod 777 Arkbuild/usr/local/bin/retrorun*
sudo chmod 777 Arkbuild/usr/local/bin/atomiswave.sh
sudo chmod 777 Arkbuild/usr/local/bin/dreamcast.sh
sudo chmod 777 Arkbuild/usr/local/bin/naomi.sh
sudo chmod 777 Arkbuild/usr/local/bin/saturn.sh
