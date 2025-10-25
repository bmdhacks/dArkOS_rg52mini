#!/bin/bash

# Build and install Mednafen
if [ -f "Arkbuild_package_cache/${CHIPSET}/mednafen.tar.gz" ] && [ "$(cat Arkbuild_package_cache/${CHIPSET}/mednafen.commit)" == "$(curl -s https://raw.githubusercontent.com/christianhaitian/${CHIPSET}_core_builds/refs/heads/master/scripts/mednafen.sh | grep -oP '(?<=tarname=").*?(?=")')" ]; then
    sudo tar -xvzpf Arkbuild_package_cache/${CHIPSET}/mednafen.tar.gz
else
	call_chroot "cd /home/ark &&
	  cd ${CHIPSET}_core_builds &&
	  chmod 777 builds-alt.sh &&
	  ./builds-alt.sh mednafen
	  "
	sudo mkdir -p Arkbuild/opt/mednafen
	sudo mkdir -p Arkbuild/home/ark/.mednafen
	sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/mednafen64/mednafen Arkbuild/opt/mednafen/
	if [ -f "Arkbuild_package_cache/${CHIPSET}/mednafen.tar.gz" ]; then
	  sudo rm -f Arkbuild_package_cache/${CHIPSET}/mednafen.tar.gz
	fi
	if [ -f "Arkbuild_package_cache/${CHIPSET}/mednafen.commit" ]; then
	  sudo rm -f Arkbuild_package_cache/${CHIPSET}/mednafen.commit
	fi
	sudo tar -czpf Arkbuild_package_cache/${CHIPSET}/mednafen.tar.gz Arkbuild/opt/mednafen/
	sudo curl -s https://raw.githubusercontent.com/christianhaitian/${CHIPSET}_core_builds/refs/heads/master/scripts/mednafen.sh | grep -oP '(?<=tarname=").*?(?=")' > Arkbuild_package_cache/${CHIPSET}/mednafen.commit
fi
sudo cp mednafen/configs/mednafen.cfg.${UNIT} Arkbuild/home/ark/.mednafen/mednafen.cfg
sudo cp mednafen/mednafen Arkbuild/usr/local/bin/

call_chroot "chown -R ark:ark /home/ark/.mednafen/"
call_chroot "chown -R ark:ark /opt/"
sudo chmod 777 Arkbuild/opt/mednafen/mednafen
sudo chmod 777 Arkbuild/usr/local/bin/mednafen

