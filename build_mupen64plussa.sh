#!/bin/bash

# Build and install Mupen64Plus standalone emulator
if [ -f "Arkbuild_package_cache/${CHIPSET}/mupen64plussa.tar.gz" ] && [ "$(cat Arkbuild_package_cache/${CHIPSET}/mupen64plussa.commit)" == "$(curl -s https:/api.github.com/repos/mupen64plus/mupen64plus-core/commits/master | jq -r '.sha')" ]; then
    sudo tar -xvzpf Arkbuild_package_cache/${CHIPSET}/mupen64plussa.tar.gz
else
	call_chroot "cd /home/ark &&
	  cd ${CHIPSET}_core_builds &&
	  chmod 777 builds-alt.sh &&
	  eatmydata ./builds-alt.sh mupen64plussa
	  "
	sudo mkdir -p Arkbuild/opt/mupen64plus
	sudo mkdir -p Arkbuild/home/ark/.config/mupen64plus
	sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/mupen64plussa-64/* Arkbuild/opt/mupen64plus/
	sudo cp mupen64plus/configs/${UNIT}/mupen64plus.cfg Arkbuild/home/ark/.config/mupen64plus/
	sudo rm -f Arkbuild/opt/mupen64plus/*.gz
	sudo cp mupen64plus/*.ini Arkbuild/opt/mupen64plus/
	sudo cp mupen64plus/scripts/n64.sh Arkbuild/usr/local/bin/
	cd Arkbuild/opt/mupen64plus
	sudo ln -s libmupen64plus.so.2.0.0 libmupen64plus.so.2
	cd ../../../
	if [ -f "Arkbuild_package_cache/${CHIPSET}/mupen64plussa.tar.gz" ]; then
	  sudo rm -f Arkbuild_package_cache/${CHIPSET}/mupen64plussa.tar.gz
	fi
	if [ -f "Arkbuild_package_cache/${CHIPSET}/mupen64plussa.commit" ]; then
	  sudo rm -f Arkbuild_package_cache/${CHIPSET}/mupen64plussa.commit
	fi
	sudo tar -czpf Arkbuild_package_cache/${CHIPSET}/mupen64plussa.tar.gz Arkbuild/opt/mupen64plus/ Arkbuild/home/ark/.config/mupen64plus/
	sudo git --git-dir=Arkbuild/home/ark/${CHIPSET}_core_builds/mupen64plus-core/.git --work-tree=Arkbuild/home/ark/${CHIPSET}_core_builds/mupen64plus_core rev-parse HEAD > Arkbuild_package_cache/${CHIPSET}/mupen64plussa.commit
fi
call_chroot "chown -R ark:ark /home/ark/.config/"
call_chroot "chown -R ark:ark /opt/"
sudo chmod 777 Arkbuild/opt/mupen64plus/*
sudo chmod 777 Arkbuild/usr/local/bin/n64.sh
