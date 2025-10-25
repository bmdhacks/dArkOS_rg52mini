#!/bin/bash

# Build and install SCUMMVM standalone emulator
if [ -f "Arkbuild_package_cache/${CHIPSET}/scummvm.tar.gz" ] && [ "$(cat Arkbuild_package_cache/${CHIPSET}/scummvm.commit)" == "$(curl -s https://raw.githubusercontent.com/christianhaitian/${CHIPSET}_core_builds/refs/heads/master/scripts/scummvm.sh | grep -oP '(?<=TAG=").*?(?=")')" ]; then
    sudo tar -xvzpf Arkbuild_package_cache/${CHIPSET}/scummvm.tar.gz
else
	call_chroot "cd /home/ark &&
	  cd ${CHIPSET}_core_builds &&
	  chmod 777 builds-alt.sh &&
	  eatmydata ./builds-alt.sh scummvm
	  "
	sudo mkdir -p Arkbuild/opt/scummvm
	sudo cp -Ra Arkbuild/home/ark/${CHIPSET}_core_builds/scummvm/extra/ Arkbuild/opt/scummvm/
	sudo cp -Ra Arkbuild/home/ark/${CHIPSET}_core_builds/scummvm/themes/ Arkbuild/opt/scummvm/
	sudo cp -Ra Arkbuild/home/ark/${CHIPSET}_core_builds/scummvm/LICENSES/ Arkbuild/opt/scummvm/
	sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/scummvm/scummvm Arkbuild/opt/scummvm/
	sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/scummvm/AUTHORS Arkbuild/opt/scummvm/
	sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/scummvm/COPYING Arkbuild/opt/scummvm/
	sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/scummvm/COPYRIGHT Arkbuild/opt/scummvm/
	sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/scummvm/NEWS.md Arkbuild/opt/scummvm/
	sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/scummvm/README.md Arkbuild/opt/scummvm/
	if [ -f "Arkbuild_package_cache/${CHIPSET}/scummvm.tar.gz" ]; then
	  sudo rm -f Arkbuild_package_cache/${CHIPSET}/scummvm.tar.gz
	fi
	if [ -f "Arkbuild_package_cache/${CHIPSET}/scummvm.commit" ]; then
	  sudo rm -f Arkbuild_package_cache/${CHIPSET}/scummvm.commit
	fi
	sudo tar -czpf Arkbuild_package_cache/${CHIPSET}/scummvm.tar.gz Arkbuild/opt/scummvm/
	sudo curl -s https://raw.githubusercontent.com/christianhaitian/${CHIPSET}_core_builds/refs/heads/master/scripts/scummvm.sh | grep -oP '(?<=TAG=").*?(?=")' > Arkbuild_package_cache/${CHIPSET}/scummvm.commit
fi

sudo mkdir -p Arkbuild/home/ark/.config/scummvm
sudo cp scummvm/configs/scummvm.ini.${UNIT} Arkbuild/home/ark/.config/scummvm/scummvm.ini
call_chroot "chown -R ark:ark /opt/"
sudo chmod 777 Arkbuild/opt/scummvm/scummvm
call_chroot "chown -R ark:ark /home/ark/.config/"
sudo cp scummvm/scripts/scummvm.sh Arkbuild/usr/local/bin/scummvm.sh
sudo chmod 777 Arkbuild/usr/local/bin/scummvm.sh
