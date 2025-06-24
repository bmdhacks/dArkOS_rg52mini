#!/bin/bash

# Build and install PPSSPP standalone emulator
call_chroot "cd /home/ark &&
  cd ${CHIPSET}_core_builds &&
  chmod 777 builds-alt.sh &&
  eatmydata ./builds-alt.sh ppsspp
  "
sudo mkdir -p Arkbuild/opt/ppsspp
sudo cp -Ra Arkbuild/home/ark/${CHIPSET}_core_builds/ppsspp/build/assets/ Arkbuild/opt/ppsspp/
sudo cp ppsspp/gamecontrollerdb.txt.${UNIT} Arkbuild/opt/ppsspp/assets/gamecontrollerdb.txt
sudo cp ppsspp/ppsspp.sh Arkbuild/usr/local/bin/
sudo mkdir -p Arkbuild/opt/ppsspp/backupforromsfolder/ppsspp/PSP/SYSTEM
sudo cp -R ppsspp/configs/backupforromsfolder/ppsspp/PSP/SYSTEM/ppsspp.ini.go.${UNIT} Arkbuild/opt/ppsspp/backupforromsfolder/ppsspp/PSP/SYSTEM/ppsspp.ini.go
sudo cp -R ppsspp/configs/backupforromsfolder/ppsspp/PSP/SYSTEM/ppsspp.ini.sdl.${UNIT} Arkbuild/opt/ppsspp/backupforromsfolder/ppsspp/PSP/SYSTEM/ppsspp.ini.sdl
sudo cp ppsspp/controls.ini.${UNIT} Arkbuild/opt/ppsspp/backupforromsfolder/ppsspp/PSP/SYSTEM/controls.ini
sudo cp ppsspp/ppsspp.ini.${UNIT} Arkbuild/opt/ppsspp/backupforromsfolder/ppsspp/PSP/SYSTEM/ppsspp.ini
sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/ppsspp/LICENSE.TXT Arkbuild/opt/ppsspp/
sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/ppsspp/build/PPSSPPSDL Arkbuild/opt/ppsspp/
call_chroot "chown -R ark:ark /opt/"
sudo chmod 777 Arkbuild/opt/ppsspp/PPSSPPSDL
sudo chmod 777 Arkbuild/usr/local/bin/ppsspp.sh
