#!/bin/bash

# Build and install lzdoom standalone emulator
if [ -f "Arkbuild_package_cache/${CHIPSET}/emulationstation.tar.gz" ] && [ "$(cat Arkbuild_package_cache/${CHIPSET}/emulationstation.commit)" == "$(curl -s https:/api.github.com/repos/christianhaitian/lzdoom/commits/master | jq -r '.sha')" ]; then
    sudo tar -xvzpf Arkbuild_package_cache/${CHIPSET}/emulationstation.tar.gz
else
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
	if [ -f "Arkbuild_package_cache/${CHIPSET}/lzdoom.tar.gz" ]; then
	  sudo rm -f Arkbuild_package_cache/${CHIPSET}/lzdoom.tar.gz
	fi
	if [ -f "Arkbuild_package_cache/${CHIPSET}/lzdoom.commit" ]; then
	  sudo rm -f Arkbuild_package_cache/${CHIPSET}/lzdoom.commit
	fi
	sudo git --git-dir=Arkbuild/home/ark/${CHIPSET}_core_builds/lzdoom/.git --work-tree=Arkbuild/home/ark/${CHIPSET}_core_builds/lzdoom rev-parse HEAD > Arkbuild_package_cache/${CHIPSET}/lzdoom.commit
	sudo tar -czpf Arkbuild_package_cache/${CHIPSET}/lzdoom.tar.gz Arkbuild/opt/lzdoom/ Arkbuild/home/ark/.config/lzdoom/
fi
sudo cp lzdoom/configs/${UNIT}/lzdoom.ini Arkbuild/home/ark/.config/lzdoom/
sudo cp -R lzdoom/backup/ Arkbuild/home/ark/.config/lzdoom/
call_chroot "chown -R ark:ark /home/ark/.config/"
call_chroot "chown -R ark:ark /opt/"
sudo chmod 777 Arkbuild/opt/lzdoom/*
