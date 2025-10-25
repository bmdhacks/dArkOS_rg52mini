#!/bin/bash

# Build and install Yabasanshiro standalone emulator
if [ -f "Arkbuild_package_cache/${CHIPSET}/yabasanshirosa.tar.gz" ] && [ "$(cat Arkbuild_package_cache/${CHIPSET}/yabasanshirosa.commit)" == "$(curl -s https://raw.githubusercontent.com/christianhaitian/${CHIPSET}_core_builds/refs/heads/master/scripts/yabasanshirosa.sh | grep -oP '(?<=TAG=").*?(?=")')" ]; then
    sudo tar -xvzpf Arkbuild_package_cache/${CHIPSET}/yabasanshirosa.tar.gz
else
	call_chroot "source /root/.bashrc && cd /home/ark &&
	  cd ${CHIPSET}_core_builds &&
	  chmod 777 builds-alt.sh &&
	  sed -i '/python-pip/s//python3-pip/g' scripts/yabasanshirosa.sh &&
	  eatmydata ./builds-alt.sh yabasanshirosa &&
	  mkdir -p /opt/yabasanshiro &&
	  cp yabasanshirosa64/yabasanshiro /opt/yabasanshiro/
	  "
	if [ -f "Arkbuild_package_cache/${CHIPSET}/yabasanshirosa.tar.gz" ]; then
	  sudo rm -f Arkbuild_package_cache/${CHIPSET}/yabasanshirosa.tar.gz
	fi
	if [ -f "Arkbuild_package_cache/${CHIPSET}/yabasanshirosa.commit" ]; then
	  sudo rm -f Arkbuild_package_cache/${CHIPSET}/yabasanshirosa.commit
	fi
	sudo tar -czpf Arkbuild_package_cache/${CHIPSET}/yabasanshirosa.tar.gz Arkbuild/opt/yabasanshiro/
	sudo curl -s https://raw.githubusercontent.com/christianhaitian/${CHIPSET}_core_builds/refs/heads/master/scripts/yabasanshirosa.sh | grep -oP '(?<=TAG=").*?(?=")' > Arkbuild_package_cache/${CHIPSET}/yabasanshirosa.commit
fi
call_chroot "chown -R ark:ark /opt/"
sudo chmod 777 Arkbuild/opt/yabasanshiro/yabasanshiro
sudo cp yabasanshiro/saturn.sh Arkbuild/usr/local/bin/saturn.sh
sudo chmod 777 Arkbuild/usr/local/bin/saturn.sh
