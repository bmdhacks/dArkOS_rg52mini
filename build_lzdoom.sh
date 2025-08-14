#!/bin/bash

# Build and install lzdoom standalone emulator
call_chroot "cd /home/ark &&
  cd ${CHIPSET}_core_builds &&
  git clone --recursive https://github.com/christianhaitian/lzdoom.git &&
  cd lzdoom && 
  sed -i '/types.h\"/s//types.h\"\n\#include <limits>/' src/scripting/types.cpp &&
  mkdir build &&
  cd build &&
  cmake -DNO_GTK=ON -DCMAKE_BUILD_TYPE=Release -DCMAKE_RULE_MESSAGES=OFF ../. &&
  eatmydata make -j$(nproc) &&
  strip lzdoom
  "
sudo mkdir -p Arkbuild/opt/lzdoom
sudo mkdir -p Arkbuild/home/ark/.config/lzdoom
sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/lzdoom/build/lzdoom Arkbuild/opt/lzdoom/
sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/lzdoom/build/*.pk3 Arkbuild/home/ark/.config/lzdoom/
sudo cp -R Arkbuild/home/ark/${CHIPSET}_core_builds/lzdoom/build/fm_banks/ Arkbuild/home/ark/.config/lzdoom/
sudo cp -R Arkbuild/home/ark/${CHIPSET}_core_builds/lzdoom/build/soundfonts/ Arkbuild/home/ark/.config/lzdoom/
sudo cp -a lzdoom/configs/${UNIT}/lzdoom.ini Arkbuild/home/ark/.config/lzdoom/
sudo cp -R lzdoom/backup/ Arkbuild/home/ark/.config/lzdoom/
call_chroot "chown -R ark:ark /home/ark/.config/"
call_chroot "chown -R ark:ark /opt/"
sudo chmod 777 Arkbuild/opt/lzdoom/*
