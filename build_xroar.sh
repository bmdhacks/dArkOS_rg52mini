#!/bin/bash

# Build and install XRoar
if [ -f "Arkbuild_package_cache/${CHIPSET}/xroar.tar.gz" ] && [ "$(cat Arkbuild_package_cache/${CHIPSET}/xroar.commit)" == "$(curl -s https://raw.githubusercontent.com/christianhaitian/${CORE_BUILDS_CHIPSET}_core_builds/refs/heads/master/scripts/xroar.sh | grep -oP '(?<=tarname=").*?(?=")')" ]; then
    sudo tar -xvzpf Arkbuild_package_cache/${CHIPSET}/xroar.tar.gz
else
	call_chroot "cd /home/ark &&
	  cd ${CHIPSET}_core_builds &&
	  chmod 777 builds-alt.sh &&
	  ./builds-alt.sh xroar
	  "
	sudo mkdir -p Arkbuild/opt/xroar
	sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/xroar64/xroar Arkbuild/opt/xroar/
	if [ -f "Arkbuild_package_cache/${CHIPSET}/xroar.tar.gz" ]; then
	  sudo rm -f Arkbuild_package_cache/${CHIPSET}/xroar.tar.gz
	fi
	if [ -f "Arkbuild_package_cache/${CHIPSET}/xroar.commit" ]; then
	  sudo rm -f Arkbuild_package_cache/${CHIPSET}/xroar.commit
	fi
	sudo tar -czpf Arkbuild_package_cache/${CHIPSET}/xroar.tar.gz Arkbuild/opt/xroar/
	sudo curl -s https://raw.githubusercontent.com/christianhaitian/${CORE_BUILDS_CHIPSET}_core_builds/refs/heads/master/scripts/xroar.sh | grep -oP '(?<=tarname=").*?(?=")' > Arkbuild_package_cache/${CHIPSET}/xroar.commit
fi

sudo cp -a xroar/coco.sh Arkbuild/usr/local/bin/
sudo cp -R xroar/controls/ Arkbuild/opt/xroar/
sudo cp -a xroar/xroar.gptk Arkbuild/opt/xroar/

call_chroot "chown -R ark:ark /opt/"
sudo chmod 777 Arkbuild/opt/xroar/xroar
sudo chmod 777 Arkbuild/usr/local/bin/coco.sh

