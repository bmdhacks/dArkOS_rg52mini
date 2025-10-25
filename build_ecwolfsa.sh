#!/bin/bash

# Build and install ECWolf standalone emulator
if [ -f "Arkbuild_package_cache/${CHIPSET}/ecwolfsa.tar.gz" ] && [ "$(cat Arkbuild_package_cache/${CHIPSET}/ecwolfsa.commit)" == "$(curl -s https:/api.bitbucket.org/2.0/repositories/ecwolf/ecwolf/commits/master | jq -r '.values[0].hash')" ]; then
    sudo tar -xvzpf Arkbuild_package_cache/${CHIPSET}/ecwolfsa.tar.gz
else
	call_chroot "cd /home/ark &&
	  cd ${CHIPSET}_core_builds &&
	  chmod 777 builds-alt.sh &&
	  eatmydata ./builds-alt.sh ecwolfsa
	  "
	sudo mkdir -p Arkbuild/opt/ecwolf
	sudo mkdir -p Arkbuild/home/ark/.config/ecwolf
	sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/ecwolf-64/* Arkbuild/opt/ecwolf/
	if [ -f "Arkbuild_package_cache/${CHIPSET}/ecwolfsa.tar.gz" ]; then
	  sudo rm -f Arkbuild_package_cache/${CHIPSET}/ecwolfsa.tar.gz
	fi
	if [ -f "Arkbuild_package_cache/${CHIPSET}/ecwolfsa.commit" ]; then
	  sudo rm -f Arkbuild_package_cache/${CHIPSET}/ecwolfsa.commit
	fi
	sudo tar -czpf Arkbuild_package_cache/${CHIPSET}/ecwolfsa.tar.gz Arkbuild/opt/ecwolf/ Arkbuild/home/ark/.config/ecwolf/
	sudo git --git-dir=Arkbuild/home/ark/${CHIPSET}_core_builds/ecwolf/.git --work-tree=Arkbuild/home/ark/${CHIPSET}_core_builds/ecwolf rev-parse HEAD > Arkbuild_package_cache/${CHIPSET}/ecwolfsa.commit
fi
sudo cp ecwolf/config/ecwolf.cfg.${UNIT} Arkbuild/home/ark/.config/ecwolf/ecwolf.cfg
sudo cp -a ecwolf/ecwolf* Arkbuild/usr/local/bin/

call_chroot "chown -R ark:ark /home/ark/.config/"
call_chroot "chown -R ark:ark /opt/"
sudo chmod 777 Arkbuild/opt/ecwolf/*
sudo chmod 777 Arkbuild/usr/local/bin/ecwolf*
