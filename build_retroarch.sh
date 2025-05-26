#!/bin/bash

# Build and install Retroarch
sudo chroot Arkbuild/ bash -c "cd /home/ark &&
  cd rk3326_core_builds &&
  chmod 777 builds-alt.sh &&
  eatmydata ./builds-alt.sh retroarch
  "

sudo mkdir -p Arkbuild/opt/retroarch/bin
sudo mkdir -p Arkbuild/home/ark/.config/retroarch/filters/video
sudo mkdir -p Arkbuild/home/ark/.config/retroarch/filters/audio
sudo mkdir -p Arkbuild/home/ark/.config/retroarch/autoconfig/udev
sudo mkdir -p Arkbuild/opt/cmds
sudo cp -a Arkbuild/home/ark/rk3326_core_builds/retroarch64/retroarch.rk3326.rot Arkbuild/opt/retroarch/bin/retroarch
sudo cp -a Arkbuild/home/ark/rk3326_core_builds/retroarch/gfx/video_filters/*.so Arkbuild/home/ark/.config/retroarch/filters/video/
sudo cp -a Arkbuild/home/ark/rk3326_core_builds/retroarch/gfx/video_filters/*.filt Arkbuild/home/ark/.config/retroarch/filters/video/
sudo cp -a Arkbuild/home/ark/rk3326_core_builds/retroarch/libretro-common/audio/dsp_filters/*.so Arkbuild/home/ark/.config/retroarch/filters/audio/
sudo cp -a Arkbuild/home/ark/rk3326_core_builds/retroarch/libretro-common/audio/dsp_filters/*.dsp Arkbuild/home/ark/.config/retroarch/filters/audio/
sudo rm -rf Arkbuild/home/ark/rk3326_core_builds/retroarch/
sudo cp -a retroarch/configs/retroarch* Arkbuild/home/ark/.config/retroarch/
sudo cp retroarch/configs/controller/* Arkbuild/home/ark/.config/retroarch/autoconfig/udev/
sudo cp retroarch/scripts/retroarch Arkbuild/usr/local/bin/
sudo cp retroarch/scripts/retroarch.sh Arkbuild/opt/cmds
#sudo cp retroarch/scripts/retroarch32.sh Arkbuild/opt/cmds
sudo chroot Arkbuild/ bash -c "chown -R ark:ark /opt/"
sudo chmod 777 Arkbuild/opt/cmds/*
sudo chmod 777 Arkbuild/usr/local/bin/retroarch
sudo chmod 777 Arkbuild/opt/retroarch/bin/*
# Add cores requested from retroarch_cores
CORE_REPO="master"
ARCH="aarch64"
sudo mkdir -p Arkbuild/home/ark/.config/retroarch/cores
while read RETROARCH_CORE; do
  if [[ ! "$RETROARCH_CORE" =~ ^# ]]; then
    echo -e "Adding ${RETROARCH_CORE} libretro core\n"
    for (( ; ; ))
    do
      wget -t 3 -T 30 --no-check-certificate https://github.com/christianhaitian/retroarch-cores/raw/"$CORE_REPO"/"$ARCH"/"$RETROARCH_CORE"_libretro.so.zip -O /dev/shm/"$RETROARCH_CORE"_libretro.so.zip
	  if [ $? == 0 ]; then
	   break
	  fi
	  sleep 10
	done
    if [ $? -eq 0 ]; then
      sudo unzip -o /dev/shm/"$RETROARCH_CORE"_libretro.so.zip -d Arkbuild/home/ark/.config/retroarch/cores/
      rm -f /dev/shm/"$RETROARCH_CORE"_libretro.so.zip
      printf "\n  ${RETROARCH_CORE} libretro has now been added!\n"
    else
      printf "\n  ${RETROARCH_CORE} libretro was not added!\n"
    fi
    sudo wget -t 3 -T 30 --no-check-certificate https://github.com/libretro/libretro-core-info/raw/refs/heads/master/"$RETROARCH_CORE"_libretro.info -O Arkbuild/home/ark/.config/retroarch/cores/"$RETROARCH_CORE"_libretro.info
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
sudo chroot Arkbuild32/ bash -c "cd /home/ark &&
  if [ ! -d rk3326_core_builds ]; then git clone https://github.com/christianhaitian/rk3326_core_builds.git; fi &&
  cd rk3326_core_builds &&
  chmod 777 builds-alt.sh &&
  ./builds-alt.sh retroarch
  "
sudo mkdir -p Arkbuild/home/ark/.config/retroarch32/filters/video
sudo mkdir -p Arkbuild/home/ark/.config/retroarch32/filters/audio
sudo mkdir -p Arkbuild/home/ark/.config/retroarch32/autoconfig/udev
sudo cp -a Arkbuild32/home/ark/rk3326_core_builds/retroarch32/retroarch32.rk3326.rot Arkbuild/opt/retroarch/bin/retroarch32
sudo cp -a Arkbuild32/home/ark/rk3326_core_builds/retroarch/gfx/video_filters/*.so Arkbuild/home/ark/.config/retroarch32/filters/video/
sudo cp -a Arkbuild32/home/ark/rk3326_core_builds/retroarch/gfx/video_filters/*.filt Arkbuild/home/ark/.config/retroarch32/filters/video/
sudo cp -a Arkbuild32/home/ark/rk3326_core_builds/retroarch/libretro-common/audio/dsp_filters/*.so Arkbuild/home/ark/.config/retroarch32/filters/audio/
sudo cp -a Arkbuild32/home/ark/rk3326_core_builds/retroarch/libretro-common/audio/dsp_filters/*.dsp Arkbuild/home/ark/.config/retroarch32/filters/audio/
sudo cp -a retroarch32/configs/retroarch* Arkbuild/home/ark/.config/retroarch32/
sudo cp retroarch32/configs/controller/* Arkbuild/home/ark/.config/retroarch32/autoconfig/udev/
sudo cp retroarch32/scripts/retroarch32 Arkbuild/usr/local/bin/
sudo cp retroarch32/scripts/retroarch32.sh Arkbuild/opt/cmds
sudo chroot Arkbuild/ bash -c "chown -R ark:ark /opt/"
sudo chmod 777 Arkbuild/opt/cmds/*
sudo chmod 777 Arkbuild/usr/local/bin/retroarch
sudo chmod 777 Arkbuild/opt/retroarch/bin/*
# Add cores requested from retroarch_cores32
CORE_REPO="master"
ARCH="arm7hf"
sudo mkdir -p Arkbuild/home/ark/.config/retroarch32/cores
while read RETROARCH_CORE32; do
  if [[ ! "$RETROARCH_CORE32" =~ ^# ]]; then
    echo -e "Adding ${RETROARCH_CORE32} libretro core\n"
    for (( ; ; ))
    do
      wget -t 3 -T 30 --no-check-certificate https://github.com/christianhaitian/retroarch-cores/raw/"$CORE_REPO"/"$ARCH"/"$RETROARCH_CORE32"_libretro.so.zip -O /dev/shm/"$RETROARCH_CORE32"_libretro.so.zip
	  if [ $? == 0 ]; then
	   break
	  fi
	  sleep 10
	done
    if [ $? -eq 0 ]; then
      sudo unzip -o /dev/shm/"$RETROARCH_CORE32"_libretro.so.zip -d Arkbuild/home/ark/.config/retroarch32/cores/
      rm -f /dev/shm/"$RETROARCH_CORE32"_libretro.so.zip
      printf "\n  ${RETROARCH_CORE32} libretro has now been added!\n"
    else
      printf "\n  ${RETROARCH_CORE32} libretro was not added!\n"
    fi
    sudo wget -t 3 -T 30 --no-check-certificate https://github.com/libretro/libretro-core-info/raw/refs/heads/master/"$RETROARCH_CORE32"_libretro.info -O Arkbuild/home/ark/.config/retroarch32/cores/"$RETROARCH_CORE32"_libretro.info
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
sudo chroot Arkbuild/ bash -c "chown -R ark:ark /home/ark/.config/"
