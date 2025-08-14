#!/bin/bash

# Build and install linapple standalone emulator along with sdl2-compat
call_chroot "export CCACHE_DISABLE=1 &&
  cd /home/ark &&
  cd ${CHIPSET}_core_builds &&
  chmod 777 builds-alt.sh &&
  eatmydata ./builds-alt.sh linapplesa &&
  cd linapple/sdl12-compat/build &&
  make install &&
  cp /usr/lib/aarch64-linux-gnu/libSDL_image-1.2.so.0* /usr/lib/.
  "
sudo mkdir -p Arkbuild/opt/linapple
sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/linapplesa-64/linapple Arkbuild/opt/linapple/
sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/linapple/res/Master.dsk Arkbuild/opt/linapple/
sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/linapple/res/A2_BASIC.SYM Arkbuild/opt/linapple/
sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/linapple/res/APPLE2E.SYM Arkbuild/opt/linapple/
sudo cp -a linapple/gamecontrollerdb.txt Arkbuild/opt/linapple/
sudo cp -R -a linapple/configs/* Arkbuild/opt/linapple/
sudo cp linapple/apple2.sh Arkbuild/usr/local/bin/
call_chroot "chown -R ark:ark /opt/"
sudo chmod 777 Arkbuild/opt/linapple/linapple
sudo chmod 777 Arkbuild/usr/local/bin/apple2.sh