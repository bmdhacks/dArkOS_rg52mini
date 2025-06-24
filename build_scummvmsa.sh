#!/bin/bash

# Build and install SCUMMVM standalone emulator
call_chroot "source /root/.bashrc && cd /home/ark &&
  cd ${CHIPSET}_core_builds &&
  chmod 777 builds-alt.sh &&
  eatmydata ./builds-alt.sh scummvm
  "
sudo mkdir -p Arkbuild/opt/scummvm
sudo mkdir -p Arkbuild/home/ark/.config/scummvm
sudo cp -Ra Arkbuild/home/ark/${CHIPSET}_core_builds/scummvm/extra/ Arkbuild/opt/scummvm/
sudo cp -Ra Arkbuild/home/ark/${CHIPSET}_core_builds/scummvm/themes/ Arkbuild/opt/scummvm/
sudo cp -Ra Arkbuild/home/ark/${CHIPSET}_core_builds/scummvm/LICENSES/ Arkbuild/opt/scummvm/
sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/scummvm/scummvm Arkbuild/opt/scummvm/
sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/scummvm/AUTHORS Arkbuild/opt/scummvm/
sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/scummvm/COPYING Arkbuild/opt/scummvm/
sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/scummvm/COPYRIGHT Arkbuild/opt/scummvm/
sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/scummvm/NEWS.md Arkbuild/opt/scummvm/
sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/scummvm/README.md Arkbuild/opt/scummvm/
call_chroot "chown -R ark:ark /opt/"
sudo chmod 777 Arkbuild/opt/scummvm/scummvm
call_chroot "chown -R ark:ark /home/ark/.config/"
sudo cp scummvm/scummvm.sh Arkbuild/usr/local/bin/scummvm.sh
sudo chmod 777 Arkbuild/usr/local/bin/scummvm.sh
