#!/bin/bash

# Build and install mvem for various dArkOS menus from christianhaitian/mvem
if [ -f "Arkbuild_package_cache/${CHIPSET}/mvem.tar.gz" ] && [ "$(cat Arkbuild_package_cache/${CHIPSET}/mvem.commit)" == "$(curl -s https:/api.github.com/repos/christianhaitian/Paul-Robson-s-Microvision-Emulation/commits/master | jq -r '.sha')" ]; then
    sudo tar -xvzpf Arkbuild_package_cache/${CHIPSET}/mvem.tar.gz
else
	call_chroot "cd /home/ark &&
	  cd ${CHIPSET}_core_builds &&
	  git clone --recursive --depth=1 https://github.com/christianhaitian/Paul-Robson-s-Microvision-Emulation.git &&
	  cd Paul-Robson-s-Microvision-Emulation/ &&
	  make -j$(nproc) &&
	  strip mvem &&
	  mkdir -p /opt/mvem &&
	  cp *.bmp /opt/mvem/ &&
	  cp mvem /opt/mvem/ &&
	  chmod 777 /opt/mvem/mvem
	  "
	sudo cp -R mvem/controls/ Arkbuild/opt/mvem/
	if [ -f "Arkbuild_package_cache/${CHIPSET}/mvem.tar.gz" ]; then
	  sudo rm -f Arkbuild_package_cache/${CHIPSET}/mvem.tar.gz
	fi
	if [ -f "Arkbuild_package_cache/${CHIPSET}/mvem.commit" ]; then
	  sudo rm -f Arkbuild_package_cache/${CHIPSET}/mvem.commit
	fi
	sudo tar -czpf Arkbuild_package_cache/${CHIPSET}/mvem.tar.gz Arkbuild/opt/mvem/
	sudo git --git-dir=Arkbuild/home/ark/${CHIPSET}_core_builds/Paul-Robson-s-Microvision-Emulation/.git --work-tree=Arkbuild/home/ark/${CHIPSET}_core_builds/Paul-Robson-s-Microvision-Emulation rev-parse HEAD > Arkbuild_package_cache/${CHIPSET}/mvem.commit
fi

call_chroot "chown -R ark:ark /opt"
sudo cp mvem/scripts/mvem.sh Arkbuild/usr/local/bin/
sudo chmod 777 Arkbuild/usr/local/bin/mvem.sh
