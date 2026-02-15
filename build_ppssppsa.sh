#!/bin/bash

# Build and install PPSSPP standalone emulator
# For rk3562, the core_builds repo is a local submodule (bmdhacks fork)
if [ "$CHIPSET" == "rk3562" ]; then
  PPSSPP_TAG=$(grep -oP '(?<=TAG=").*?(?=")' rk3562_core_builds/scripts/ppsspp.sh)
else
  PPSSPP_TAG=$(curl -s https://raw.githubusercontent.com/christianhaitian/${CORE_BUILDS_CHIPSET}_core_builds/refs/heads/master/scripts/ppsspp.sh | grep -oP '(?<=TAG=").*?(?=")')
fi
if [ -f "Arkbuild_package_cache/${CHIPSET}/ppsspp.tar.gz" ] && [ "$(cat Arkbuild_package_cache/${CHIPSET}/ppsspp.commit)" == "${PPSSPP_TAG}" ]; then
    sudo tar -xvzpf Arkbuild_package_cache/${CHIPSET}/ppsspp.tar.gz
else
	# Remove libvulkan-dev dependency for rk3562 to avoid pulling in Mesa's loader
	# (we use Rockchip's proprietary Vulkan loader; PPSSPP bundles its own headers)
	if [ "$CHIPSET" == "rk3562" ]; then
	  sed -i 's/ libvulkan-dev//' Arkbuild/home/ark/${CHIPSET}_core_builds/scripts/ppsspp.sh
	fi
	call_chroot "cd /home/ark &&
	  cd ${CHIPSET}_core_builds &&
	  chmod 777 builds-alt.sh &&
	  eatmydata ./builds-alt.sh ppsspp
	  "
	sudo mkdir -p Arkbuild/opt/ppsspp/backupforromsfolder/ppsspp/PSP/SYSTEM
	sudo cp -Ra Arkbuild/home/ark/${CHIPSET}_core_builds/ppsspp/build/assets/ Arkbuild/opt/ppsspp/
	sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/ppsspp/LICENSE.TXT Arkbuild/opt/ppsspp/
	sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/ppsspp/build/PPSSPPSDL Arkbuild/opt/ppsspp/
	if [ -f "Arkbuild_package_cache/${CHIPSET}/ppsspp.tar.gz" ]; then
	  sudo rm -f Arkbuild_package_cache/${CHIPSET}/ppsspp.tar.gz
	fi
	if [ -f "Arkbuild_package_cache/${CHIPSET}/ppsspp.commit" ]; then
	  sudo rm -f Arkbuild_package_cache/${CHIPSET}/ppsspp.commit
	fi
	sudo tar -czpf Arkbuild_package_cache/${CHIPSET}/ppsspp.tar.gz Arkbuild/opt/ppsspp/
	echo "${PPSSPP_TAG}" > Arkbuild_package_cache/${CHIPSET}/ppsspp.commit
fi
sudo cp ppsspp/gamecontrollerdb.txt.${UNIT} Arkbuild/opt/ppsspp/assets/gamecontrollerdb.txt
sudo cp ppsspp/ppsspp.sh Arkbuild/usr/local/bin/
sudo cp -R ppsspp/configs/backupforromsfolder/ppsspp/PSP/SYSTEM/ppsspp.ini.go.${UNIT} Arkbuild/opt/ppsspp/backupforromsfolder/ppsspp/PSP/SYSTEM/ppsspp.ini.go
sudo cp -R ppsspp/configs/backupforromsfolder/ppsspp/PSP/SYSTEM/ppsspp.ini.sdl.${UNIT} Arkbuild/opt/ppsspp/backupforromsfolder/ppsspp/PSP/SYSTEM/ppsspp.ini.sdl
sudo cp ppsspp/controls.ini.${UNIT} Arkbuild/opt/ppsspp/backupforromsfolder/ppsspp/PSP/SYSTEM/controls.ini
sudo cp ppsspp/ppsspp.ini.${UNIT} Arkbuild/opt/ppsspp/backupforromsfolder/ppsspp/PSP/SYSTEM/ppsspp.ini
call_chroot "chown -R ark:ark /opt/"
sudo chmod 777 Arkbuild/opt/ppsspp/PPSSPPSDL
sudo chmod 777 Arkbuild/usr/local/bin/ppsspp.sh
