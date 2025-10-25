#!/bin/bash

# Build and install EmulationStation-fcamod
if [ -f ../exports.sh ];
then
  source ../exports.sh
fi
echo "export devid=$(printenv DEV_ID)" | sudo tee Arkbuild/home/ark/ES_VARIABLES.txt
echo "export devpass=$(printenv DEV_PASS)" | sudo tee -a Arkbuild/home/ark/ES_VARIABLES.txt
echo "export apikey=$(printenv TGDB_APIKEY)" | sudo tee -a Arkbuild/home/ark/ES_VARIABLES.txt
if [[ "$UNIT" == *"353"* ]] || [[ "$UNIT" == *"503"* ]]; then
  NAME="RG${UNIT}"
  ES_BRANCH="503noTTS"
elif [[ "$UNIT" == "rgb10" ]] || [[ "$UNIT" == "rk2020" ]]; then
  NAME="${UNIT}"
  ES_BRANCH="master"
else
  NAME="${UNIT}"
  ES_BRANCH="351v"
fi
NAME=`echo ${NAME} | tr '[:lower:]' '[:upper:]'`
echo "export softname=\"dArkOS-${NAME}\"" | sudo tee -a Arkbuild/home/ark/ES_VARIABLES.txt

if [ -f "Arkbuild_package_cache/${CHIPSET}/emulationstation_${ES-BRANCH}.tar.gz" ] && [ "$(cat Arkbuild_package_cache/${CHIPSET}/emulationstation_${ES-BRANCH}.commit)" == "$(curl -s https:/api.github.com/repos/christianhaitian/EmulationStation-fcamod/commits/${ES-BRANCH} | jq -r '.sha')" ]; then
    sudo tar -xvzpf Arkbuild_package_cache/${CHIPSET}/emulationstation_${ES-BRANCH}.tar.gz
else
	call_chroot "apt-get -y update && eatmydata apt-get -y install libfreeimage3 fonts-droid-fallback libfreetype6 curl vlc-bin libsdl2-mixer-2.0-0"
	call_chroot "cd /home/ark &&
	  source ES_VARIABLES.txt &&
	  rm ES_VARIABLES.txt &&
	  git clone --recursive --depth=1 https://github.com/christianhaitian/EmulationStation-fcamod -b ${ES_BRANCH} &&
	  cd EmulationStation-fcamod &&
	  git submodule update --init &&
	  for f in \$(find . -type f \( -name '*.cpp' -o -name '*.h' \) -exec grep -L '<string>' {} \;); do
		sed -i '1i#include <string>' \"\$f\";
	  done &&
	  sed -i '1i#include <ctime>' es-core/src/utils/TimeUtil.h &&
	  cmake -DSCREENSCRAPER_DEV_LOGIN=\"devid=\$devid&devpassword=\$devpass\" -DGAMESDB_APIKEY=\"\$apikey\" -DSCREENSCRAPER_SOFTNAME=\"\$softname\" . &&
	  make -j\$(nproc) &&
	  mkdir -pv /usr/bin/emulationstation &&
	  cp -a emulationstation /usr/bin/emulationstation &&
	  chmod 777 /usr/bin/emulationstation &&
	  cp -a resources /usr/bin/emulationstation/
	  "
	  sudo tar -czpf Arkbuild_package_cache/${CHIPSET}/emulationstation_${ES-BRANCH}.tar.gz Arkbuild/usr/bin/emulationstation/
	  sudo git --git-dir=Arkbuild/home/ark/${CHIPSET}_core_builds/EmulationStation-fcamod/.git --work-tree=Arkbuild/home/ark/${CHIPSET}_core_builds/EmulationStation-fcamod rev-parse HEAD > Arkbuild_package_cache/${CHIPSET}/emulationstation_${ES-BRANCH}.commit
fi
sudo rm -rf Arkbuild/home/ark/EmulationStation-fcamod
sudo mkdir -p Arkbuild/etc/emulationstation/themes
if [[ "${BUILD_ARMHF}" == "y" ]]; then
  sudo cp Emulationstation/es_systems.cfg.${CHIPSET} Arkbuild/etc/emulationstation/es_systems.cfg
else
  sudo cp Emulationstation/es_systems.cfg.${CHIPSET}-64bit_Only Arkbuild/etc/emulationstation/es_systems.cfg
fi
sudo cp Emulationstation/es_input.cfg.${UNIT} Arkbuild/etc/emulationstation/es_input.cfg
sudo cp Emulationstation/es_settings.cfg.${UNIT} Arkbuild/home/ark/.emulationstation/es_settings.cfg
sudo cp Emulationstation/emulationstation.sh.${UNIT} Arkbuild/usr/bin/emulationstation/emulationstation.sh
sudo cp Emulationstation/fonts/* Arkbuild/usr/bin/emulationstation/resources/
sudo cp -R Emulationstation/scripts/ Arkbuild/home/ark/.emulationstation/
sudo chmod -R 777 Arkbuild/home/ark/.emulationstation/scripts/*
call_chroot "chown -R ark:ark /etc/emulationstation/"
call_chroot "chown -R ark:ark /home/ark/"
sudo chmod 777 Arkbuild/usr/bin/emulationstation/emulationstation.sh
sudo cp Emulationstation/emulationstation.service Arkbuild/etc/systemd/system/emulationstation.service
call_chroot "systemctl enable emulationstation"

