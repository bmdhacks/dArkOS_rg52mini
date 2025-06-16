#!/bin/bash

# Cleanup to reduce image size and remove build remnants
echo -e "Cleaning up filesystem"
sudo chroot Arkbuild/ bash -c "rm -rf /home/ark/EmulationStation-fcamod"
sudo chroot Arkbuild/ bash -c "rm -rf /home/ark/libgo2"
sudo chroot Arkbuild/ bash -c "rm -rf /home/ark/linux-rga"
sudo chroot Arkbuild/ bash -c "rm -rf /home/ark/${CHIPSET}_core_builds"
sudo chroot Arkbuild/ bash -c "apt-get remove -y autotools-dev \
  build-essential \
  ccache \
  clang \
  cmake \
  g++ \
  liba52-0.7.4-dev \
  libasound2-dev \
  libboost-date-time-dev \
  libboost-filesystem-dev \
  libboost-locale-dev \
  libboost-system-dev \
  libcurl4-openssl-dev \
  libdrm-dev \
  libeigen3-dev \
  libevdev-dev \
  libxext-dev \
  libfaad-dev \
  libflac-dev \
  libfreeimage-dev \
  libfreetype6-dev \
  libfribidi-dev \
  libglew-dev \
  libjpeg62-turbo-dev \
  libmad0-dev \
  libmpeg2-4-dev \
  libnl-3-dev \
  libnl-genl-3-dev \
  libnl-route-3-dev \
  libogg-dev \
  libopenal-dev \
  libpng-dev \
  libsdl2-dev \
  libsdl2-image-dev \
  libsdl2-mixer-dev \
  libsdl2-ttf-dev \
  libsm-dev \
  libsoxr-dev \
  libspeechd-dev \
  libstdc++-12-dev \
  libtheora-dev \
  libudev-dev \
  libvlc-dev \
  libvlccore-dev \
  libvorbis-dev \
  libvpx-dev \
  libx11-dev \
  libx11-xcb1 \
  libxcb-dri2-0 \
  ninja-build \
  pkg-config \
  premake4 \
  rapidjson-dev \
  zlib1g-dev"

sudo chroot Arkbuild/ apt-get -y autoremove
sudo chroot Arkbuild/ apt-get clean

# Ensure additional needed packages are still in place
while read NEEDED_PACKAGE; do
  if [[ ! "$NEEDED_PACKAGE" =~ ^# ]]; then
    install_package armhf ${NEEDED_PACKAGE}
  fi
done <needed_packages32.txt
sync

while read NEEDED_PACKAGE; do
  if [[ ! "$NEEDED_PACKAGE" =~ ^# ]]; then
    install_package 64 ${NEEDED_PACKAGE}
    protect_package 64 ${NEEDED_PACKAGE}
  fi
done <needed_packages.txt
sync

cd Arkbuild/usr/lib/arm-linux-gnueabihf
for LIB in libEGL.so libEGL.so.1 libGLES_CM.so libGLES_CM.so.1 libGLESv1_CM.so libGLESv1_CM.so.1 libGLESv1_CM.so.1.1.0 libGLESv2.so libGLESv2.so.2 libGLESv2.so.2.0.0 libGLESv2.so.2.1.0 libGLESv3.so libGLESv3.so.3 libgbm.so libgbm.so.1 libgbm.so.1.0.0 libmali.so libmali.so.1 libMaliOpenCL.so libOpenCL.so libwayland-egl.so libwayland-egl.so.1 libwayland-egl.so.1.0.0
do
  sudo rm -fv ${LIB}
  sudo ln -sfv libMali.so ${LIB}
done
cd ../../../../

cd Arkbuild/usr/lib/aarch64-linux-gnu
for LIB in libEGL.so libEGL.so.1 libGLES_CM.so libGLES_CM.so.1 libGLESv1_CM.so libGLESv1_CM.so.1 libGLESv1_CM.so.1.1.0 libGLESv2.so libGLESv2.so.2 libGLESv2.so.2.0.0 libGLESv2.so.2.1.0 libGLESv3.so libGLESv3.so.3 libgbm.so libgbm.so.1 libgbm.so.1.0.0 libmali.so libmali.so.1 libMaliOpenCL.so libOpenCL.so libwayland-egl.so libwayland-egl.so.1 libwayland-egl.so.1.0.0
do
  sudo rm -fv ${LIB}
  sudo ln -sfv libMali.so ${LIB}
done
cd ../../../../

sudo chroot Arkbuild/ bash -c "ln -sfv /usr/lib/aarch64-linux-gnu/libSDL2.so /usr/lib/aarch64-linux-gnu/libSDL2-2.0.so.0"
sudo chroot Arkbuild/ bash -c "ln -sfv /usr/lib/aarch64-linux-gnu/libSDL2-2.0.so.0.${extension} /usr/lib/aarch64-linux-gnu/libSDL2.so"
sudo chroot Arkbuild/ bash -c "ln -sfv /usr/lib/arm-linux-gnueabihf/libSDL2.so /usr/lib/arm-linux-gnueabihf/libSDL2-2.0.so.0"
sudo chroot Arkbuild/ bash -c "ln -sfv /usr/lib/arm-linux-gnueabihf/libSDL2-2.0.so.0.${extension} /usr/lib/arm-linux-gnueabihf/libSDL2.so"
sudo chroot Arkbuild/ ldconfig

sudo umount -l Arkbuild/home/ark/Arkbuild_ccache
sudo rm -rf Arkbuild/home/ark/Arkbuild_ccache
sudo rm -rf Arkbuild/var/log/journal
sudo rm Arkbuild/usr/sbin/policy-rc.d
sudo rm -f Arkbuild/etc/resolv.conf
sudo rm -f Arkbuild/etc/network/interfaces
sudo rm -rf Arkbuild/usr/share/man/*
#for i in {1..8}; do sudo mkdir -p Arkbuild/usr/share/man/man"$i"; done
sudo rm -rf Arkbuild/var/lib/apt/lists/*
sudo rm -f Arkbuild/var/log/*.log
sudo rm -f Arkbuild/var/log/apt/*.log
sudo rm -f Arkbuild/tmp/reboot-needed
