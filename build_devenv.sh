#!/bin/bash
#exec 3>&1 4>&2
#trap 'exec 2>&4 1>&3' 0 1 2 3
#exec 1>build.log 2>&1
#set -e
if [ "$1" == "32" ]; then
  DEV_LOG="builddevenv32.log"
else
  DEV_LOG="builddevenv.log"
fi

if [ -f "${DEV_LOG}" ]; then
  ext=1
  while true
  do
    if [ -f "${DEV_LOG}.${ext}" ]; then
      let ext=ext+1
      continue
    else
      mv "${DEV_LOG}" "${DEV_LOG}.${ext}"
      break
    fi
  done
fi
(
# Setup some functions
function setup_ark_user() {
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
  echo -e "export LC_All=en_US.UTF-8" | sudo tee -a ${CHROOT_DIR}/home/ark/.bashrc > /dev/null
  echo -e "export LC_CTYPE=en_US.UTF-8" | sudo tee -a ${CHROOT_DIR}/home/ark/.bashrc > /dev/null
  sudo chroot ${CHROOT_DIR}/ chown -R ark:ark /home/ark/
}

updateapt="N"
function install_package() {
  neededlibs=( ${@:2} )
  for libs in "${neededlibs[@]}"
  do
     sudo chroot ${CHROOT_DIR}/ dpkg -s "${libs}" &>/dev/null
     if [[ $? != "0" ]]; then
       if [[ "$updateapt" == "N" ]]; then
         if test -z "$(cat ${CHROOT_DIR}/etc/apt/sources.list | grep contrib)"
         then
           sudo sed -i '/main/s//main contrib non-free non-free-firmware/' ${CHROOT_DIR}/etc/apt/sources.list
		 fi
         sudo chroot ${CHROOT_DIR}/ apt -y update
         updateapt="Y"
       fi
       sudo chroot ${CHROOT_DIR}/ bash -c "DEBIAN_FRONTEND=noninteractive eatmydata apt -y install ${libs}"
       if [[ $? != "0" ]]; then
         echo " "
         echo "Could not install needed library ${libs}."
       else
	     echo "${libs} was successfully installed."
       fi
     fi
  done
}

function verify_action() {
  code=$?
  if [ $code != 0 ]; then
    echo -e "Exiting build with return code ${code}"
    exit 1
  fi
}

# Step-by-step build process
if [ "$1" == "32" ]; then
  BIT="32"
  ARCH="arm-linux-gnueabihf"
  CHROOT_DIR="Ark_devenv32"
else
  BIT="64"
  ARCH="aarch64-linux-gnu"
  CHROOT_DIR="Ark_devenv"
fi
if [ -d "${CHROOT_DIR}" ]; then
  echo -e "${CHROOT_DIR} environment already exists.  Please delete it and rerun this make to create this new devenv\n\n"
  sleep 3
  exit 0
fi
mkdir -p ${CHROOT_DIR}/
# Let's make sure necessary tools are available
source ./prepare.sh
echo -e "Boostraping Debian....\n\n"
# Bootstrap base system
if [ "$1" == "32" ]; then
  sudo eatmydata debootstrap --no-check-gpg --include=eatmydata --resolve-deps --arch=armhf --foreign ${DEBIAN_CODE_NAME} ${CHROOT_DIR} http://deb.debian.org/debian/
  sudo cp /usr/bin/qemu-arm-static ${CHROOT_DIR}/usr/bin/
else
  sudo eatmydata debootstrap --no-check-gpg --include=eatmydata --resolve-deps --arch=arm64 --foreign ${DEBIAN_CODE_NAME} ${CHROOT_DIR} http://deb.debian.org/debian/
  sudo cp /usr/bin/qemu-aarch64-static ${CHROOT_DIR}/usr/bin/
fi
sudo chroot ${CHROOT_DIR}/ apt-get -y install ccache eatmydata
sudo chroot ${CHROOT_DIR}/ eatmydata /debootstrap/debootstrap --second-stage

# Bind essential host filesystems into chroot for networking
sudo mount --bind /dev ${CHROOT_DIR}/dev
sudo mount -t devpts none ${CHROOT_DIR}/dev/pts -o newinstance,ptmxmode=0666
sudo mount --bind /proc ${CHROOT_DIR}/proc
sudo mount --bind /sys ${CHROOT_DIR}/sys
echo -e "nameserver 8.8.8.8\nnameserver 1.1.1.1" | sudo tee ${CHROOT_DIR}/etc/resolv.conf > /dev/null

#sudo chroot ${CHROOT_DIR}/ mount -t proc proc /proc

# Install base runtime packages
sudo chroot ${CHROOT_DIR}/ eatmydata apt-get install -y initramfs-tools sudo evtest network-manager systemd-sysv locales locales-all ssh dosfstools fluidsynth
sudo chroot ${CHROOT_DIR}/ eatmydata apt-get install -y python3 python3-pip
sudo sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' ${CHROOT_DIR}/etc/locale.gen
echo 'LANG="en_US.UTF-8"' | sudo tee -a ${CHROOT_DIR}/etc/default/locale > /dev/null
echo -e "export LC_All=en_US.UTF-8" | sudo tee -a ${CHROOT_DIR}/root/.bashrc > /dev/null
echo -e "export LC_CTYPE=en_US.UTF-8" | sudo tee -a ${CHROOT_DIR}/root/.bashrc > /dev/null
sudo chroot ${CHROOT_DIR}/ bash -c "update-locale LANG=en_US.UTF-8"
sudo chroot ${CHROOT_DIR}/ bash -c "locale-gen"

# Install libmali, DRM, and GBM libraries for ${CHIPSET}
sudo chroot ${CHROOT_DIR}/ eatmydata apt-get install -y libdrm-dev libgbm1

setup_ark_user
sleep 10
echo -e "Installing build dependencies and needed packages...\n\n"

# Install additional needed packages and protect them from autoremove
while read NEEDED_PACKAGE; do
  if [[ ! "$NEEDED_PACKAGE" =~ ^# ]]; then
    install_package $BIT "${NEEDED_PACKAGE}"
  fi
done <needed_packages.txt

# Install build dependencies
while read NEEDED_DEV_PACKAGE; do
  if [[ ! "$NEEDED_DEV_PACKAGE" =~ ^# ]]; then
    install_package $BIT "${NEEDED_DEV_PACKAGE}"
  fi
done <needed_dev_packages.txt

# Symlink fix for DRM headers
sudo chroot ${CHROOT_DIR}/ bash -c "ln -s /usr/include/libdrm/ /usr/include/drm"

sudo chroot ${CHROOT_DIR}/ ldconfig

# Install meson
sudo chroot ${CHROOT_DIR}/ bash -c "git clone https://github.com/mesonbuild/meson.git && ln -s /meson/meson.py /usr/bin/meson"

# Build and install librga
sudo chroot ${CHROOT_DIR}/ bash -c "cd /home/ark &&
  git clone https://github.com/christianhaitian/linux-rga.git &&
  cd linux-rga &&
  git checkout 1fc02d56d97041c86f01bc1284b7971c6098c5fb &&
  meson build && cd build &&
  meson compile &&
  cp -r librga.so* /usr/lib/${ARCH}/ &&
  cd .. &&
  mkdir -p /usr/local/include/rga &&
  cp -f drmrga.h rga.h RgaApi.h RockchipRgaMacro.h /usr/local/include/rga/
  "

# Build and install libgo2
sudo chroot ${CHROOT_DIR}/ bash -c "cd /home/ark &&
  git clone https://github.com/OtherCrashOverride/libgo2.git &&
  cd libgo2 &&
  premake4 gmake &&
  make -j$(nproc) &&
  cp libgo2.so* /usr/lib/${ARCH}/ &&
  mkdir -p /usr/include/go2 &&
  cp -L src/*.h /usr/include/go2/
  "

echo "Development environment build completed. It can be entered by issuing command sudo chroot ${CHROOT_DIR}."
) 2>&1 | tee -a builddevenv.log
