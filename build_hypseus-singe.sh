#!/bin/bash

# Build and install Hypseus-singe standalone emulator
call_chroot "source /root/.bashrc && cd /home/ark &&
  cd ${CHIPSET}_core_builds &&
  chmod 777 builds-alt.sh &&
  eatmydata ./builds-alt.sh hypseus-singe
  "
sudo mkdir -p Arkbuild/opt/hypseus-singe
sudo mkdir -p Arkbuild/opt/hypseus-singe/framefile
sudo mkdir -p Arkbuild/opt/hypseus-singe/logs
sudo mkdir -p Arkbuild/opt/hypseus-singe/ram
sudo mkdir -p Arkbuild/opt/hypseus-singe/screenshots
sudo cp -Ra Arkbuild/home/ark/${CHIPSET}_core_builds/hypseus-singe/fonts/ Arkbuild/opt/hypseus-singe/
sudo cp -Ra Arkbuild/home/ark/${CHIPSET}_core_builds/hypseus-singe/midi/ Arkbuild/opt/hypseus-singe/
sudo cp -Ra Arkbuild/home/ark/${CHIPSET}_core_builds/hypseus-singe/pics/ Arkbuild/opt/hypseus-singe/
sudo cp -Ra Arkbuild/home/ark/${CHIPSET}_core_builds/hypseus-singe/sound/ Arkbuild/opt/hypseus-singe/
sudo cp -Ra Arkbuild/home/ark/${CHIPSET}_core_builds/hypseus-singe/LICENSE/ Arkbuild/opt/hypseus-singe/
sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/hypseus-singe/build/hypseus Arkbuild/opt/hypseus-singe/hypseus-singe
sudo cp hypseus-singe/configs/hypinput_gamepad.ini.${UNIT} Arkbuild/opt/hypseus-singe/hypseus-singe/hypinput_gamepad.ini
sudo cp hypseus-singe/configs/gamecontrollerdb.txt Arkbuild/opt/hypseus-singe/hypseus-singe/gamecontrollerdb.txt
call_chroot "chown -R ark:ark /opt/"
sudo cp hypseus-singe/singe.sh Arkbuild/usr/local/bin/singe.sh
sudo cp hypseus-singe/daphne.sh Arkbuild/usr/local/bin/daphne.sh
sudo chmod 777 Arkbuild/opt/hypseus-singe/hypseus-singe
sudo chmod 777 Arkbuild/usr/local/bin/singe.sh
sudo chmod 777 Arkbuild/usr/local/bin/daphne.sh
