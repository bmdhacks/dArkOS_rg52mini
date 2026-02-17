#!/bin/bash

# Build and install Duckstation standalone emulator
if [ -f "Arkbuild_package_cache/${CHIPSET}/duckstationsa.tar.gz" ]; then
    sudo tar -xvzpf Arkbuild_package_cache/${CHIPSET}/duckstationsa.tar.gz
    if [ ! -f "Arkbuild/opt/duckstation/duckstation-nogui" ]; then
        echo "WARNING: DuckStation cache tarball is incomplete, rebuilding from source..."
        sudo rm -f Arkbuild_package_cache/${CHIPSET}/duckstationsa.tar.gz
    fi
fi
if [ ! -f "Arkbuild/opt/duckstation/duckstation-nogui" ] && [ ! -f "Arkbuild_package_cache/${CHIPSET}/duckstationsa.tar.gz" ]; then
	# Remove rotation patch for landscape-native devices
	if [ "$CHIPSET" == "rk3562" ] && [ "$UNIT" != "rg56pro" ]; then
	  rm -f Arkbuild/home/ark/${CHIPSET}_core_builds/patches/duckstationsa-patch-004-add-rotation.patch
	fi
	call_chroot "cd /home/ark &&
	  cd ${CHIPSET}_core_builds &&
	  chmod 777 builds-alt.sh &&
	  eatmydata ./builds-alt.sh duckstationsa
	  "
	sudo mkdir -p Arkbuild/opt/duckstation
	sudo mkdir -p Arkbuild/home/ark/.config/duckstation
	sudo cp -Ra Arkbuild/home/ark/${CHIPSET}_core_builds/duckstationsa-64/duckstation-nogui Arkbuild/opt/duckstation/
	sudo cp -Ra Arkbuild/home/ark/${CHIPSET}_core_builds/duckstation/data/database Arkbuild/home/ark/.config/duckstation/
	sudo cp -Ra Arkbuild/home/ark/${CHIPSET}_core_builds/duckstation/data/inputprofiles Arkbuild/home/ark/.config/duckstation/
	sudo cp -Ra Arkbuild/home/ark/${CHIPSET}_core_builds/duckstation/data/resources Arkbuild/home/ark/.config/duckstation/
	sudo cp -Ra Arkbuild/home/ark/${CHIPSET}_core_builds/duckstation/data/shaders Arkbuild/home/ark/.config/duckstation/
	if [ -f "Arkbuild_package_cache/${CHIPSET}/duckstationsa.tar.gz" ]; then
	  sudo rm -f Arkbuild_package_cache/${CHIPSET}/duckstationsa.tar.gz
	fi
	sudo tar -czpf Arkbuild_package_cache/${CHIPSET}/duckstationsa.tar.gz Arkbuild/opt/duckstation/ Arkbuild/home/ark/.config/duckstation/
fi
sudo cp duckstation/scripts/standalone-duckstation Arkbuild/usr/local/bin/
sudo cp duckstation/configs/settings.ini.${UNIT} Arkbuild/home/ark/.config/duckstation/settings.ini
sudo cp duckstation/configs/gamecontrollerdb.txt Arkbuild/home/ark/.config/duckstation/database/gamecontrollerdb.txt
call_chroot "chown -R ark:ark /opt/"
call_chroot "chown -R ark:ark /home/ark/"
sudo chmod 777 Arkbuild/opt/duckstation/duckstation-nogui
sudo chmod 777 Arkbuild/usr/local/bin/standalone-duckstation
