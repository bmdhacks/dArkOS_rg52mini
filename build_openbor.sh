#!/bin/bash

# Build and install OpenBOR standalone emulator
if [ -f "Arkbuild_package_cache/${CHIPSET}/openbor.tar.gz" ] && [ "$(cat Arkbuild_package_cache/${CHIPSET}/openbor.commit)" == "$(curl -s https://raw.githubusercontent.com/christianhaitian/${CHIPSET}_core_builds/refs/heads/master/scripts/openbor.sh | grep -oP '(?<=git checkout ).*')" ]; then
    sudo tar -xvzpf Arkbuild_package_cache/${CHIPSET}/openbor.tar.gz
else
	call_chroot "cd /home/ark &&
	  cd ${CHIPSET}_core_builds &&
	  chmod 777 builds-alt.sh &&
	  eatmydata ./builds-alt.sh openbor
	  "
	sudo mkdir -p Arkbuild/opt/OpenBor
	sudo mkdir -p Arkbuild/opt/OpenBor/Paks
	sudo mkdir -p Arkbuild/opt/OpenBor/Saves
	sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/openbor-64/OpenBOR Arkbuild/opt/OpenBor/
	if [ -f "Arkbuild_package_cache/${CHIPSET}/openbor.tar.gz" ]; then
	  sudo rm -f Arkbuild_package_cache/${CHIPSET}/openbor.tar.gz
	fi
	if [ -f "Arkbuild_package_cache/${CHIPSET}/openbor.commit" ]; then
	  sudo rm -f Arkbuild_package_cache/${CHIPSET}/openbor.commit
	fi
	sudo tar -czpf Arkbuild_package_cache/${CHIPSET}/openbor.tar.gz Arkbuild/opt/OpenBor/ 
	sudo git --git-dir=Arkbuild/home/ark/${CHIPSET}_core_builds/openbor/.git --work-tree=Arkbuild/home/ark/${CHIPSET}_core_builds/openbor rev-parse HEAD > Arkbuild_package_cache/${CHIPSET}/openbor.commit
fi
sudo cp openbor/configs/master.cfg.${UNIT} Arkbuild/opt/OpenBor/Saves/master.cfg
sudo cp openbor/OpenBor.sh Arkbuild/opt/OpenBor/OpenBor.sh
call_chroot "chown -R ark:ark /opt/"
sudo chmod 777 Arkbuild/opt/OpenBor/OpenBor.sh
