#!/bin/bash

URL="https://www.richwhitehouse.com/jaguar/index.php?content=download"
html=$(curl -s "$URL")

if [ -f "Arkbuild_package_cache/${CHIPSET}/bigpemu.tar.gz" ] && [ "$(cat Arkbuild_package_cache/${CHIPSET}/bigpemu.commit)" == "$(echo "$html" | grep -oE 'https://www.richwhitehouse.com/jaguar/builds/BigPEmu_LinuxARM64_v[0-9]+\.tar\.gz' | tail -n 1)" ]; then
    sudo tar -xvzpf Arkbuild_package_cache/${CHIPSET}/bigpemu.tar.gz
else
	arm64_link=$(echo "$html" | grep -oE 'https://www.richwhitehouse.com/jaguar/builds/BigPEmu_LinuxARM64_v[0-9]+\.tar\.gz' | tail -n 1)
	wget -t 3 -T 60 --no-check-certificate "$arm64_link"
	sudo tar -xvzf BigPEmu* -C Arkbuild/opt/
	sudo chmod 777 Arkbuild/opt/bigpemu/bigpemu
	call_chroot "chown -R ark:ark /opt/bigpemu/"
	rm -f BigPEmu*
	call_chroot "cd /home/ark &&
		  cd ${CHIPSET}_core_builds &&
		  git clone --recursive --depth=1 https://github.com/ptitSeb/gl4es.git &&
		  cd gl4es &&
		  mk build &&
		  cd build &&
		  cmake .. -DODROID=1 -DNOX11=1 -DNOEGL=1 -DCMAKE_BUILD_TYPE=RelWithDebInfo; make -j$(nproc) &&
		  strip ../lib/* &&
		  mkdir -p /opt/bigpemu/
		  cp ../lib/libGL.so.1 /opt/bigpemu/ &&
		  cd /opt/bigpemu &&
		  ln -sf libGL.so.1 libOpenGL.so &&
		  ln -sf libOpenGL.so libOpenGL.so.0 &&
		  "
	if [ -f "Arkbuild_package_cache/${CHIPSET}/bigpemu.tar.gz" ]; then
	  sudo rm -f Arkbuild_package_cache/${CHIPSET}/bigpemu.tar.gz
	fi
	if [ -f "Arkbuild_package_cache/${CHIPSET}/bigpemu.commit" ]; then
	  sudo rm -f Arkbuild_package_cache/${CHIPSET}/bigpemu.commit
	fi
	sudo tar -czpf Arkbuild_package_cache/${CHIPSET}/bigpemu.tar.gz Arkbuild/opt/bigpemu/
	echo "$arm64_link" > Arkbuild_package_cache/${CHIPSET}/bigpemu.commit
fi
call_chroot "chown -R ark:ark /opt/bigpemu/"
sudo cp bigpemu/scripts/bigpemu.sh Arkbuild/usr/local/bin/
sudo cp -R bigpemu/defaultconfigs/ Arkbuild/opt/bigpemu/
sudo chmod 777 Arkbuild/usr/local/bin/bigpemu.sh