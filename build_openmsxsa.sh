#!/bin/bash

# Build and install openmsx standalone emulator
if [ -f "Arkbuild_package_cache/${CHIPSET}/openmsx.tar.gz" ] && [ "$(cat Arkbuild_package_cache/${CHIPSET}/openmsx.commit)" == "$(curl -s https://raw.githubusercontent.com/christianhaitian/${CORE_BUILDS_CHIPSET}_core_builds/refs/heads/master/scripts/openmsx.sh | grep -oP '(?<=TAG=").*?(?=")')" ]; then
    sudo tar -xvzpf Arkbuild_package_cache/${CHIPSET}/openmsx.tar.gz
else
	call_chroot "cd /home/ark &&
	  cd ${CHIPSET}_core_builds &&
	  chmod 777 builds-alt.sh &&
	  eatmydata ./builds-alt.sh openmsx
	  "
	sudo mkdir -p Arkbuild/opt/openmsx/backupconfig/openmsx
	sudo cp -Ra Arkbuild/home/ark/${CHIPSET}_core_builds/openMSX/share Arkbuild/opt/openmsx/backupconfig/openmsx/
	sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/openMSX/README Arkbuild/opt/openmsx/
	sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/openmsx64/openmsx Arkbuild/opt/openmsx/
	sudo cp Arkbuild/home/ark/${CHIPSET}_core_builds/openMSX/Contrib/cbios/* Arkbuild/opt/openmsx/backupconfig/openmsx/share/machines/
	if [ -f "Arkbuild_package_cache/${CHIPSET}/openmsx.tar.gz" ]; then
	  sudo rm -f Arkbuild_package_cache/${CHIPSET}/openmsx.tar.gz
	fi
	if [ -f "Arkbuild_package_cache/${CHIPSET}/openmsx.commit" ]; then
	  sudo rm -f Arkbuild_package_cache/${CHIPSET}/openmsx.commit
	fi
	sudo tar -czpf Arkbuild_package_cache/${CHIPSET}/openmsx.tar.gz Arkbuild/opt/openmsx/ 
	sudo curl -s https://raw.githubusercontent.com/christianhaitian/${CORE_BUILDS_CHIPSET}_core_builds/refs/heads/master/scripts/openmsx.sh | grep -oP '(?<=TAG=").*?(?=")' > Arkbuild_package_cache/${CHIPSET}/openmsx.commit
fi

sudo cp openmsx/configs/openmsx.gptk Arkbuild/opt/openmsx/backupconfig/openmsx/
sudo cp openmsx/configs/commands.txt Arkbuild/opt/openmsx/backupconfig/openmsx/
sudo cp openmsx/configs/gamecontrollerdb.txt Arkbuild/opt/openmsx/
sudo cp openmsx/scripts/openmsx Arkbuild/usr/local/bin/
call_chroot "chown -R ark:ark /opt/"
sudo chmod 777 Arkbuild/opt/openmsx/openmsx
sudo chmod 777 Arkbuild/usr/local/bin/openmsx
