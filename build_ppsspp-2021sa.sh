#!/bin/bash

# Build and install PPSSPP standalone emulator
call_chroot "cd /home/ark &&
  cd ${CHIPSET}_core_builds &&
  chmod 777 builds-alt.sh &&
  eatmydata ./builds-alt.sh ppsspp-2021
  "
sudo mkdir -p Arkbuild/opt/ppsspp-2021
sudo cp -Ra Arkbuild/home/ark/${CHIPSET}_core_builds/ppsspp-2021/build/assets/ Arkbuild/opt/ppsspp-2021/
sudo cp ppsspp/gamecontrollerdb.txt.${UNIT} Arkbuild/opt/ppsspp-2021/assets/gamecontrollerdb.txt
sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/ppsspp-2021/LICENSE.TXT Arkbuild/opt/ppsspp-2021/
sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/ppsspp-2021/build/PPSSPPSDL Arkbuild/opt/ppsspp-2021/
call_chroot "chown -R ark:ark /opt/"
sudo chmod 777 Arkbuild/opt/ppsspp-2021/PPSSPPSDL
