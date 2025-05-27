#!/bin/bash

function verify_action() {
  code=$?
  if [ $code != 0 ]; then
    echo -e "Exiting build with return code ${code}"
    exit 1
  fi
}

function setup_ark_user() {
  if [ "$1" == "32" ]; then
    CHROOT_DIR="Arkbuild32"
  else
    CHROOT_DIR="Arkbuild"
  fi
  sudo chroot ${CHROOT_DIR}/ useradd ark -k /etc/skel -d /home/ark -m -s /bin/bash
  sudo chroot ${CHROOT_DIR}/ bash -c "echo ark:ark | chpasswd"
  sudo chroot ${CHROOT_DIR}/ chage -I -1 -m 0 -M 99999 -E -1 ark
  sudo mkdir -p ${CHROOT_DIR}/etc/sudoers.d
  echo "ark     ALL= NOPASSWD: ALL" | sudo tee ${CHROOT_DIR}/etc/sudoers.d/ark-no-sudo-password
  echo "Defaults        !secure_path" | sudo tee ${CHROOT_DIR}/etc/sudoers.d/ark-no-secure-path
  sudo chmod 0440 ${CHROOT_DIR}/etc/sudoers.d/ark-no-sudo-password
  sudo chmod 0440 ${CHROOT_DIR}/etc/sudoers.d/ark-no-secure-path
  sudo chroot ${CHROOT_DIR}/ usermod -G video,sudo,netdev,input,audio,adm,ark ark
  directories=(".config" ".emulationstation")
  for dir in "${directories[@]}"; do
    sudo mkdir -p "${CHROOT_DIR}/home/ark/${dir}"
  done
  sudo chroot ${CHROOT_DIR}/ chown -R ark:ark /home/ark/
}

function setup_arkbuild32() {
  if [ ! -d Arkbuild32 ]; then
    # Bootstrap base system
    sudo debootstrap --no-check-gpg --include=eatmydata --resolve-deps --arch=armhf --foreign bookworm Arkbuild32 http://deb.debian.org/debian/
    sudo cp /usr/bin/qemu-arm-static Arkbuild32/usr/bin/
    sudo chroot Arkbuild32/ apt-get -y install eatmydata
    sudo chroot Arkbuild32/ eatmydata /debootstrap/debootstrap --second-stage

    # Bind essential host filesystems into chroot for networking
    sudo mount --bind /dev Arkbuild32/dev
    sudo mount -t devpts none Arkbuild32/dev/pts -o newinstance,ptmxmode=0666
    #sudo mount --bind /dev/pts Arkbuild32/dev/pts
    sudo mount --bind /proc Arkbuild32/proc
    sudo mount --bind /sys Arkbuild32/sys
    echo -e "nameserver 8.8.8.8\nnameserver 1.1.1.1" | sudo tee Arkbuild32/etc/resolv.conf > /dev/null
    # Install libmali, DRM, and GBM libraries for rk3326
    sudo chroot Arkbuild32/ apt-get install -y libdrm-dev libgbm1
    setup_ark_user 32
    sudo mkdir -p Arkbuild32/home/ark
    sudo chroot Arkbuild32/ umount /proc
    source build_deps.sh 32
    source build_sdl2.sh 32
    sudo cp -a Arkbuild32/usr/lib/arm-linux-gnueabihf/libSDL2-2.0.so.0.${extension} Arkbuild/usr/lib/arm-linux-gnueabihf/libSDL2-2.0.so.0.${extension}
    sudo chroot Arkbuild/ bash -c "ln -sfv /usr/lib/arm-linux-gnueabihf/libSDL2.so /usr/lib/arm-linux-gnueabihf/libSDL2-2.0.so.0"
    sudo chroot Arkbuild/ bash -c "ln -sfv /usr/lib/arm-linux-gnueabihf/libSDL2-2.0.so.0.${extension} /usr/lib/arm-linux-gnueabihf/libSDL2.so"
    sudo cp -a Arkbuild32/home/ark/linux-rga/build/librga.so* Arkbuild/usr/lib/arm-linux-gnueabihf/
    sudo cp -a Arkbuild32/home/ark/libgo2/libgo2.so* Arkbuild/usr/lib/arm-linux-gnueabihf/
    # Place libmali manually (assumes you have libmali.so or mali drivers ready)
    sudo mkdir -p Arkbuild32/usr/lib/arm-linux-gnueabihf/
    wget -t 3 -T 60 --no-check-certificate https://github.com/christianhaitian/rk3326_core_builds/raw/refs/heads/rk3326/mali/armhf/libmali-bifrost-g31-rxp0-gbm.so
    sudo mv libmali-bifrost-g31-rxp0-gbm.so Arkbuild32/usr/lib/arm-linux-gnueabihf/.
    whichmali="libmali-bifrost-g31-rxp0-gbm.so"
    cd Arkbuild32/usr/lib/arm-linux-gnueabihf
    sudo ln -sf ${whichmali} libMali.so
    for LIB in libEGL.so libEGL.so.1 libEGL.so.1.1.0 libGLES_CM.so libGLES_CM.so.1 libGLESv1_CM.so libGLESv1_CM.so.1 libGLESv1_CM.so.1.1.0 libGLESv2.so libGLESv2.so.2 libGLESv2.so.2.0.0 libGLESv2.so.2.1.0 libGLESv3.so libGLESv3.so.3 libgbm.so libgbm.so.1 libgbm.so.1.0.0 libmali.so libmali.so.1 libMaliOpenCL.so libOpenCL.so libwayland-egl.so libwayland-egl.so.1 libwayland-egl.so.1.0.0
    do
      sudo rm -fv ${LIB}
      sudo ln -sfv libMali.so ${LIB}
    done
    cd ../../../../
	sudo chroot Arkbuild32/ ldconfig
  fi
}

function remove_arkbuild() {
  for m in home/ark/Arkbuild_ccache proc dev/pts dev dev sys
  do
    if grep -qs "Arkbuild/${m} " /proc/mounts; then
      sudo umount -l Arkbuild/${m}
      verify_action
      sync
      sleep 1
    fi
  done
  sudo rm -rf Arkbuild/home/ark/Arkbuild_ccache
  [ -d "Arkbuild" ] && sudo umount -l Arkbuild
  return 0
}

function remove_arkbuild32() {
  for m in home/ark/Arkbuild_ccache proc dev/pts dev sys
  do
    if grep -qs "Arkbuild32/${m} " /proc/mounts; then
      sudo umount -l Arkbuild32/${m}
      verify_action
      sync
      sleep 1
    fi
  done
  [ -d "Arkbuild32" ] && sudo umount -l Arkbuild32
  return 0
}

updateapt="N"
function install_package() {
  if [ "$1" == "32" ]; then
    NEEDED_ARCH=""
    CHROOT_DIR="Arkbuild32"
  elif [ "$1" == "armhf" ]; then
    NEEDED_ARCH=":armhf"
    CHROOT_DIR="Arkbuild"
  else
    NEEDED_ARCH=":arm64"
    CHROOT_DIR="Arkbuild"
  fi
  neededlibs=( ${@:2} )
  for libs in "${neededlibs[@]}"
  do
     sudo chroot ${CHROOT_DIR}/ dpkg -s "${libs}${NEEDED_ARCH}" &>/dev/null
     if [[ $? != "0" ]]; then
       if [[ "$updateapt" == "N" ]]; then
         sudo chroot ${CHROOT_DIR}/ apt-get -y update
         updateapt="Y"
       fi
       sudo chroot ${CHROOT_DIR}/ bash -c "DEBIAN_FRONTEND=noninteractive eatmydata apt-get -y install ${libs}${NEEDED_ARCH}"
       if [[ $? != "0" ]]; then
         echo " "
         echo "Could not install needed library ${libs}${NEEDED_ARCH}."
       else
	     echo "${libs}${NEEDED_ARCH} was successfully installed."
       fi
     fi
  done
}

function protect_package() {
  if [ "$1" == "32" ]; then
    CHROOT_DIR="Arkbuild32"
  else
    CHROOT_DIR="Arkbuild"
  fi
  protectlibs=( ${@:2} )
  for protectedlib in "${protectlibs[@]}"
  do
     sudo chroot ${CHROOT_DIR}/ apt-mark manual "${protectedlib}"
     if [[ $? != "0" ]]; then
       echo "${protectedlib} could not mark as manually installed."
     else
	   echo "$${protectedlib} has been marked as manually installed."
     fi
  done
}
