#!/bin/bash

# Build and install PPSSPP standalone emulator
if [ -f "Arkbuild_package_cache/${CHIPSET}/ppsspp-2021.tar.gz" ]; then
    sudo tar -xvzpf Arkbuild_package_cache/${CHIPSET}/ppsspp-2021.tar.gz
    if [ ! -f "Arkbuild/opt/ppsspp-2021/PPSSPPSDL" ]; then
        echo "WARNING: PPSSPP-2021 cache tarball is incomplete, rebuilding from source..."
        sudo rm -f Arkbuild_package_cache/${CHIPSET}/ppsspp-2021.tar.gz
    fi
fi
if [ ! -f "Arkbuild/opt/ppsspp-2021/PPSSPPSDL" ] && [ ! -f "Arkbuild_package_cache/${CHIPSET}/ppsspp-2021.tar.gz" ]; then
	call_chroot "cd /home/ark &&
	  cd ${CHIPSET}_core_builds &&
	  chmod 777 builds-alt.sh &&
	  eatmydata ./builds-alt.sh ppsspp-2021
	  "
	sudo mkdir -p Arkbuild/opt/ppsspp-2021
	sudo cp -Ra Arkbuild/home/ark/${CHIPSET}_core_builds/ppsspp-2021/build/assets/ Arkbuild/opt/ppsspp-2021/
	sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/ppsspp-2021/LICENSE.TXT Arkbuild/opt/ppsspp-2021/
	sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/ppsspp-2021/build/PPSSPPSDL Arkbuild/opt/ppsspp-2021/
	if [ -f "Arkbuild_package_cache/${CHIPSET}/ppsspp-2021.tar.gz" ]; then
	  sudo rm -f Arkbuild_package_cache/${CHIPSET}/ppsspp-2021.tar.gz
	fi
	sudo tar -czpf Arkbuild_package_cache/${CHIPSET}/ppsspp-2021.tar.gz Arkbuild/opt/ppsspp-2021/
fi
sudo cp ppsspp/gamecontrollerdb.txt.${UNIT} Arkbuild/opt/ppsspp-2021/assets/gamecontrollerdb.txt
call_chroot "chown -R ark:ark /opt/"
sudo chmod 777 Arkbuild/opt/ppsspp-2021/PPSSPPSDL
