#!/bin/bash

# Build and install solarus standalone emulator along with sdl2-compat
if [ -f "Arkbuild_package_cache/${CHIPSET}/solarus.tar.gz" ] && [ "$(cat Arkbuild_package_cache/${CHIPSET}/solarus.commit)" == "$(curl -s https://raw.githubusercontent.com/christianhaitian/${CHIPSET}_core_builds/refs/heads/master/scripts/solarus.sh | grep -oP '(?<=TAG=").*?(?=")')" ]; then
    sudo tar -xvzpf Arkbuild_package_cache/${CHIPSET}/solarus.tar.gz
else
	call_chroot "cd /home/ark &&
	  cd ${CHIPSET}_core_builds &&
	  chmod 777 builds-alt.sh &&
	  eatmydata ./builds-alt.sh solarus
	  "
	sudo mkdir -p Arkbuild/opt/solarus
	sudo cp -R Arkbuild/home/ark/${CHIPSET}_core_builds/solarus64/* Arkbuild/opt/solarus/
	if [ -f "Arkbuild_package_cache/${CHIPSET}/solarus.tar.gz" ]; then
	  sudo rm -f Arkbuild_package_cache/${CHIPSET}/solarus.tar.gz
	fi
	if [ -f "Arkbuild_package_cache/${CHIPSET}/solarus.commit" ]; then
	  sudo rm -f Arkbuild_package_cache/${CHIPSET}/solarus.commit
	fi
	sudo tar -czpf Arkbuild_package_cache/${CHIPSET}/solarus.tar.gz Arkbuild/opt/solarus/
	sudo curl -s https://raw.githubusercontent.com/christianhaitian/${CHIPSET}_core_builds/refs/heads/master/scripts/solarus.sh | grep -oP '(?<=TAG=").*?(?=")' > Arkbuild_package_cache/${CHIPSET}/solarus.commit
fi
sudo cp solarus/configs/${UNIT}/pads.ini Arkbuild/opt/solarus/
sudo cp solarus/scripts/solarus.sh Arkbuild/usr/local/bin/
sudo chmod 777 Arkbuild/usr/local/bin/solarus.sh
call_chroot "chown -R ark:ark /opt/"
sudo chmod 777 Arkbuild/opt/solarus/solarus-run
