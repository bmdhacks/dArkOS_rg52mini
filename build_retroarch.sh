#!/bin/bash

# Build and install Retroarch
while true
do
  call_chroot "cd /home/ark &&
    cd ${CHIPSET}_core_builds &&
    chmod 777 builds-alt.sh &&
    [ -d retroarch ] && rm -rf retroarch* || echo \"Cloning into retroarch\" &&
    eatmydata ./builds-alt.sh retroarch
    "
  if [[ "$?" -ne "0" ]]; then
    sleep 30
    continue
  else
    break
  fi
done

sudo mkdir -p Arkbuild/opt/retroarch/bin
sudo mkdir -p Arkbuild/home/ark/.config/retroarch/filters/video
sudo mkdir -p Arkbuild/home/ark/.config/retroarch/filters/audio
sudo mkdir -p Arkbuild/home/ark/.config/retroarch/autoconfig/udev
sudo mkdir -p Arkbuild/opt/cmds
if [ "$UNIT" == "rgb10" ] || [ "$UNIT" == "rk2020" ]; then
  sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/retroarch64/retroarch.${CHIPSET}.rot Arkbuild/opt/retroarch/bin/retroarch
elif [ "$CHIPSET" == "rk3566" ]; then
  sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/retroarch64/retroarch Arkbuild/opt/retroarch/bin/retroarch
else
  sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/retroarch64/retroarch.${CHIPSET}.unrot Arkbuild/opt/retroarch/bin/retroarch
fi
sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/retroarch/gfx/video_filters/*.so Arkbuild/home/ark/.config/retroarch/filters/video/
sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/retroarch/gfx/video_filters/*.filt Arkbuild/home/ark/.config/retroarch/filters/video/
sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/retroarch/libretro-common/audio/dsp_filters/*.so Arkbuild/home/ark/.config/retroarch/filters/audio/
sudo cp -a Arkbuild/home/ark/${CHIPSET}_core_builds/retroarch/libretro-common/audio/dsp_filters/*.dsp Arkbuild/home/ark/.config/retroarch/filters/audio/
sudo rm -rf Arkbuild/home/ark/${CHIPSET}_core_builds/retroarch/
sudo cp -a retroarch/configs/retroarch.cfg.${UNIT} Arkbuild/home/ark/.config/retroarch/retroarch.cfg
sudo cp -a retroarch/configs/retroarch.cfg.bak.${UNIT} Arkbuild/home/ark/.config/retroarch/retroarch.cfg.bak
sudo cp -a retroarch/configs/retroarch-core-options.cfg.${UNIT} Arkbuild/home/ark/.config/retroarch/retroarch-core-options.cfg
sudo cp -a retroarch/configs/retroarch-core-options.cfg.bak.${UNIT} Arkbuild/home/ark/.config/retroarch/retroarch-core-options.cfg.bak
sudo cp -a retroarch/configs/controller/*.cfg Arkbuild/home/ark/.config/retroarch/autoconfig/udev/
sudo cp retroarch/scripts/retroarch Arkbuild/usr/local/bin/
sudo cp retroarch/scripts/retroarch.sh Arkbuild/opt/cmds
#sudo cp retroarch/scripts/retroarch32.sh Arkbuild/opt/cmds
call_chroot "chown -R ark:ark /opt/"
sudo chmod 777 Arkbuild/opt/cmds/*
sudo chmod 777 Arkbuild/usr/local/bin/retroarch
sudo chmod 777 Arkbuild/opt/retroarch/bin/*
# Add cores requested from retroarch_cores
if [ "$CHIPSET" == "rk3326" ]; then
  CORE_REPO="master"
else
  CORE_REPO="rg503"
fi
ARCH="aarch64"
sudo mkdir -p Arkbuild/home/ark/.config/retroarch/cores
while read RETROARCH_CORE; do
  if [[ ! "$RETROARCH_CORE" =~ ^# ]]; then
    echo -e "Adding ${RETROARCH_CORE} libretro core\n"
    wget -t 5 -T 30 --no-check-certificate https://github.com/christianhaitian/retroarch-cores/raw/"$CORE_REPO"/"$ARCH"/"$RETROARCH_CORE"_libretro.so.zip -O /dev/shm/"$RETROARCH_CORE"_libretro.so.zip
    if [ $? -eq 0 ]; then
      sudo unzip -o /dev/shm/"$RETROARCH_CORE"_libretro.so.zip -d Arkbuild/home/ark/.config/retroarch/cores/
      rm -f /dev/shm/"$RETROARCH_CORE"_libretro.so.zip
      printf "\n  ${RETROARCH_CORE} libretro has now been added!\n"
    else
      printf "\n  ${RETROARCH_CORE} libretro was not added!\n"
    fi
    sudo wget -t 5 -T 30 --no-check-certificate https://github.com/libretro/libretro-core-info/raw/refs/heads/master/"$RETROARCH_CORE"_libretro.info -O Arkbuild/home/ark/.config/retroarch/cores/"$RETROARCH_CORE"_libretro.info
    if [ $? -ne 0 ]; then
      if [ -f "core_info_files/${RETROARCH_CORE}_libretro.info" ]; then
	    sudo cp core_info_files/"$RETROARCH_CORE"_libretro.info Arkbuild/home/ark/.config/retroarch/cores/"$RETROARCH_CORE"_libretro.info
      fi
    fi
  fi
done <retroarch_cores.txt

# Copy other core info files not available from libretro's repo
#sudo cp core_info_files/* Arkbuild/home/ark/.config/retroarch/cores/
#sudo cp core_info_files/* Arkbuild/home/ark/.config/retroarch32/cores/

# Download and add retroarch assets
sudo git clone --depth=1 https://github.com/libretro/retroarch-assets.git Arkbuild/home/ark/.config/retroarch/assets/
sudo find Arkbuild/home/ark/.config/retroarch/assets/ -maxdepth 1 ! -name assets \
                                                                  ! -name glui \
                                                                  ! -name nxrgui \
                                                                  ! -name ozone \
                                                                  ! -name pkg \
                                                                  ! -name rgui \
                                                                  ! -name sounds \
                                                                  ! -name switch \
                                                                  ! -name xmb \
                                                                  ! -name COPYING -type d,f -not -path '.' -exec rm -rf {} +

setup_arkbuild32
sudo chroot Arkbuild32/ mkdir -p /home/ark
while true
do
  call_chroot32 "cd /home/ark &&
    if [ ! -d ${CHIPSET}_core_builds ]; then git clone https://github.com/christianhaitian/${CHIPSET}_core_builds.git; fi &&
    cd ${CHIPSET}_core_builds &&
    chmod 777 builds-alt.sh &&
    [ -d retroarch ] && rm -rf retroarch* || echo \"Cloning into retroarch\" &&
    ./builds-alt.sh retroarch
    "
  if [[ "$?" -ne "0" ]]; then
    sleep 30
    continue
  else
    break
  fi
done
sudo mkdir -p Arkbuild/home/ark/.config/retroarch32/filters/video
sudo mkdir -p Arkbuild/home/ark/.config/retroarch32/filters/audio
sudo mkdir -p Arkbuild/home/ark/.config/retroarch32/autoconfig/udev
if [ "$UNIT" == "rgb10" ] || [ "$UNIT" == "rk2020" ]; then
  sudo cp -a Arkbuild32/home/ark/${CHIPSET}_core_builds/retroarch32/retroarch32.${CHIPSET}.rot Arkbuild/opt/retroarch/bin/retroarch32
elif [ "$CHIPSET" == "rk3566" ]; then
  sudo cp -a Arkbuild32/home/ark/${CHIPSET}_core_builds/retroarch32/retroarch32 Arkbuild/opt/retroarch/bin/retroarch32
else
  sudo cp -a Arkbuild32/home/ark/${CHIPSET}_core_builds/retroarch32/retroarch32.${CHIPSET}.unrot Arkbuild/opt/retroarch/bin/retroarch32
fi
sudo cp -a Arkbuild32/home/ark/${CHIPSET}_core_builds/retroarch/gfx/video_filters/*.so Arkbuild/home/ark/.config/retroarch32/filters/video/
sudo cp -a Arkbuild32/home/ark/${CHIPSET}_core_builds/retroarch/gfx/video_filters/*.filt Arkbuild/home/ark/.config/retroarch32/filters/video/
sudo cp -a Arkbuild32/home/ark/${CHIPSET}_core_builds/retroarch/libretro-common/audio/dsp_filters/*.so Arkbuild/home/ark/.config/retroarch32/filters/audio/
sudo cp -a Arkbuild32/home/ark/${CHIPSET}_core_builds/retroarch/libretro-common/audio/dsp_filters/*.dsp Arkbuild/home/ark/.config/retroarch32/filters/audio/
sudo cp -a retroarch32/configs/retroarch.cfg.${UNIT} Arkbuild/home/ark/.config/retroarch32/retroarch.cfg
sudo cp -a retroarch32/configs/retroarch.cfg.bak.${UNIT} Arkbuild/home/ark/.config/retroarch32/retroarch.cfg.bak
sudo cp -a retroarch32/configs/retroarch-core-options.cfg.${UNIT} Arkbuild/home/ark/.config/retroarch32/retroarch-core-options.cfg
sudo cp -a retroarch32/configs/retroarch-core-options.cfg.bak.${UNIT} Arkbuild/home/ark/.config/retroarch32/retroarch-core-options.cfg.bak
sudo cp -a retroarch32/configs/controller/*.cfg Arkbuild/home/ark/.config/retroarch32/autoconfig/udev/
sudo cp retroarch32/scripts/retroarch32 Arkbuild/usr/local/bin/
sudo cp retroarch32/scripts/retroarch32.sh Arkbuild/opt/cmds
call_chroot "chown -R ark:ark /opt/"
sudo chmod 777 Arkbuild/opt/cmds/*
sudo chmod 777 Arkbuild/usr/local/bin/retroarch32
sudo chmod 777 Arkbuild/opt/retroarch/bin/*
# Add cores requested from retroarch_cores32
if [ "$CHIPSET" == "rk3326" ]; then
  CORE_REPO="master"
else
  CORE_REPO="rg503"
fi
ARCH="arm7hf"
sudo mkdir -p Arkbuild/home/ark/.config/retroarch32/cores
while read RETROARCH_CORE32; do
  if [[ ! "$RETROARCH_CORE32" =~ ^# ]]; then
    echo -e "Adding ${RETROARCH_CORE32} libretro core\n"
    wget -t 5 -T 30 --no-check-certificate https://github.com/christianhaitian/retroarch-cores/raw/"$CORE_REPO"/"$ARCH"/"$RETROARCH_CORE32"_libretro.so.zip -O /dev/shm/"$RETROARCH_CORE32"_libretro.so.zip
    if [ $? -eq 0 ]; then
      sudo unzip -o /dev/shm/"$RETROARCH_CORE32"_libretro.so.zip -d Arkbuild/home/ark/.config/retroarch32/cores/
      rm -f /dev/shm/"$RETROARCH_CORE32"_libretro.so.zip
      printf "\n  ${RETROARCH_CORE32} libretro has now been added!\n"
    else
      printf "\n  ${RETROARCH_CORE32} libretro was not added!\n"
    fi
    sudo wget -t 5 -T 30 --no-check-certificate https://github.com/libretro/libretro-core-info/raw/refs/heads/master/"$RETROARCH_CORE32"_libretro.info -O Arkbuild/home/ark/.config/retroarch32/cores/"$RETROARCH_CORE32"_libretro.info
    if [ $? -ne 0 ]; then
      if [ -f "core_info_files/${RETROARCH_CORE32}_libretro.info" ]; then
	    sudo cp core_info_files/"$RETROARCH_CORE32"_libretro.info Arkbuild/home/ark/.config/retroarch32/cores/"$RETROARCH_CORE32"_libretro.info
      fi
    fi
  fi
done <retroarch_cores32.txt

# Download and add retroarch assets
sudo git clone --depth=1 https://github.com/libretro/retroarch-assets.git Arkbuild/home/ark/.config/retroarch32/assets/
sudo find Arkbuild/home/ark/.config/retroarch32/assets/ -maxdepth 1 ! -name assets \
                                                                  ! -name glui \
                                                                  ! -name nxrgui \
                                                                  ! -name ozone \
                                                                  ! -name pkg \
                                                                  ! -name rgui \
                                                                  ! -name sounds \
                                                                  ! -name switch \
                                                                  ! -name xmb \
                                                                  ! -name COPYING -type d,f -not -path '.' -exec rm -rf {} +
call_chroot "chown -R ark:ark /home/ark/.config/"
