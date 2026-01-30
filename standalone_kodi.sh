#!/bin/bash

# Build Kodi package
DEBIAN_CODE_NAME="trixie"
KODI_VERSION_TAG="21.3-Omega"
KODI_DEVENV="Ark_devenv"
CHIPSET="rk3566"

if [ ! -d "${KODI_DEVENV}" ]; then
  echo -e "${KODI_DEVENV} environment doesn't seem to exist.  Please do make devenv first to create it then run this script again\n\n"
  sleep 3
  exit 1
fi

# Ensure libmali is installed for rk3566 in devenv
if test -z "$(ls -l ${KODI_DEVENV}/usr/lib/aarch64-linux-gnu/libMali.so | grep g52- | tr -d '\0')"
then
  $(grep g52 utils.sh)
  sudo wget -t 3 -T 60 --no-check-certificate https://github.com/christianhaitian/${CORE_BUILDS_CHIPSET:-${CHIPSET}}_core_builds/raw/refs/heads/master/mali/aarch64/${whichmali} -O ${KODI_DEVENV}/usr/lib/aarch64-linux-gnu/${whichmali}
  cd ${KODI_DEVENV}/usr/lib/aarch64-linux-gnu
  sudo ln -sf ${whichmali} libMali.so
  for LIB in libEGL.so libEGL.so.1 libEGL.so.1.1.0 libGLES_CM.so libGLES_CM.so.1 libGLESv1_CM.so libGLESv1_CM.so.1 libGLESv1_CM.so.1.1.0 libGLESv2.so libGLESv2.so.2 libGLESv2.so.2.0.0 libGLESv2.so.2.1.0 libGLESv3.so libGLESv3.so.3 libgbm.so libgbm.so.1 libgbm.so.1.0.0 libmali.so libmali.so.1 libMaliOpenCL.so libOpenCL.so libwayland-egl.so libwayland-egl.so.1 libwayland-egl.so.1.0.0
  do
    sudo rm -fv ${LIB}
    sudo ln -sfv libMali.so ${LIB}
  done
  cd ../../../../
fi

# Install additional Kodi build dependencies
if test -z "$(cat ${KODI_DEVENV}/etc/apt/sources.list | grep ${DEBIAN_CODE_NAME}-backports)"
then
    echo "deb http://deb.debian.org/debian ${DEBIAN_CODE_NAME}-backports main" | sudo tee -a ${KODI_DEVENV}/etc/apt/sources.list
    sudo chroot ${KODI_DEVENV} bash -c "apt -y update"
else
    sudo chroot ${KODI_DEVENV} bash -c "apt -y update"
fi

while read KODI_NEEDED_DEV_PACKAGE; do
  if [[ ! "$KODI_NEEDED_DEV_PACKAGE" =~ ^# ]]; then
    sudo chroot ${KODI_DEVENV} bash -c "apt -y install ${KODI_NEEDED_DEV_PACKAGE}"
  fi
done <kodi_needed_dev_packages.txt

sudo chroot ${KODI_DEVENV} bash -c "cd /home/ark &&
  [ -d kodi ] && rm -rf kodi || echo \"ok\" &&
  mkdir -p kodi &&
  cd kodi &&
  git clone --recursive https://github.com/christianhaitian/kodi-install &&
  cd kodi-install &&
  sed -i '/\/home\/kodi/s//\/home\/ark\/kodi/' configuration.sh &&
  chmod 777 ArkOS-Kodi-Build-alt.sh &&
  ./ArkOS-Kodi-Build-alt.sh ${KODI_VERSION_TAG}
  "

if [[ "$?" -ne "0" ]]; then
  echo "The build failed.  Check the build log for kodi in ${KODI_DEVENV}/home/ark/kodi/ to see what the issue may be."
  echo "" 	
  exit 1
fi

sudo rm -rf ${KODI_DEVENV}/home/ark/kodi
sudo cp -R kodi/userdata/ ${KODI_DEVENV}/opt/kodi/
sudo cp kodi_needed_dev_packages.txt ${KODI_DEVENV}/opt/kodi/kodi_needed_packages.txt
sudo chroot ${KODI_DEVENV} bash -c "chown -R ark:ark /opt/kodi/"
sudo cp kodi/scripts/Kodi.sh ${KODI_DEVENV}/usr/local/bin/
sudo chmod 777 ${KODI_DEVENV}/usr/local/bin/Kodi.sh

# Create the compressed tar of the setup
sudo chroot ${KODI_DEVENV} bash -c "tar -cJvf Kodi-${KODI_VERSION_TAG}.tar.xz /opt/kodi/* /usr/local/bin/Kodi.sh"

cat <<EOF | tee Kodi-${KODI_VERSION_TAG}-install.sh
#!/bin/bash
. /usr/local/bin/buttonmon.sh

if test ! -z "\$(cat /home/ark/.config/.DEVICE | grep RGB20PRO | tr -d '\0')"
then
  sudo setfont /usr/share/consolefonts/Lat7-TerminusBold32x16.psf.gz
else
  sudo setfont /usr/share/consolefonts/Lat7-TerminusBold22x11.psf.gz
fi

GW=\`ip route | awk '/default/ { print \$3 }'\`
if [ -z "\$GW" ]; then
  printf "\n\n\n\e[91mInternet connectivity is required for this process to complete successfully.  Please check your internet connection and try again.\n"
  sleep 5
  exit 1
fi

printf "\nAre you sure you want to install Kodi ${KODI_VERSION_TAG}?\n" >> /dev/tty1
printf "\nPress A to continue.  Press B to exit.\n" >> /dev/tty1
while true
do
    Test_Button_A
	if [ "\$?" -eq "10" ]; then
	  break
	fi
	Test_Button_B
	if [ "\$?" -eq "10" ]; then
	  clear >> /dev/tty1
	  if [[ ! -e "/dev/input/by-path/platform-odroidgo2-joypad-event-joystick" ]]; then
        sudo setfont /usr/share/consolefonts/Lat7-Terminus20x10.psf.gz
	  fi
	  exit 0
	fi
done

process_tar() {
	printf "\nRemoving existing Kodi version, if installed, but keeping existing addons and settings in place.  Please wait..." >> /dev/tty1
	rm -rf /opt/kodi/lib/kodi/addons/* /opt/kodi/share/kodi/addons/*
	printf "\nInstalling Kodi ${KODI_VERSION_TAG} version.  Please wait...\n" >> /dev/tty1
	tail -n +\${PAYLOAD_LINE} \$0 | sudo tar xJ -C \$WORK_DIR
	sudo chown -R ark:ark /opt/kodi/
	if [ "\$(cat ~/.config/.DEVICE)" != "RG503" ]; then
	  sed -i '/<res width\="1920" height\="1440" aspect\="4:3"/s//<res width\="1623" height\="1180" aspect\="4:3"/g' /opt/kodi/share/kodi/addons/skin.estuary/addon.xml
	fi
}

if test ! -z \$(tr -d '\0' < /proc/device-tree/compatible | grep rk3566)
then
  PAYLOAD_LINE=\$(awk '/^__PAYLOAD_BEGINS__/ { print NR + 1; exit 0; }' \$0)
  WORK_DIR=/
  printf "\nStarting the process.  Please wait..." >> /dev/tty1
  process_tar
  if test -z "\$(cat /etc/apt/sources.list | grep ${DEBIAN_CODE_NAME}-backports)"
  then
    echo "deb http://deb.debian.org/debian ${DEBIAN_CODE_NAME}-backports main" | sudo tee -a /etc/apt/sources.list
  fi
  sudo apt -y update
  while read KODI_NEEDED_PACKAGE; do
    if [[ ! "\$KODI_NEEDED_PACKAGE" =~ ^# ]] && [[ ! "\$KODI_NEEDED_PACKAGE" == *"-dev"* ]]; then
      sudo apt -y install \${KODI_NEEDED_PACKAGE}
    fi
  done </opt/kodi/kodi_needed_packages.txt

  sudo rm /opt/kodi/kodi_needed_packages.txt
  printf "\nThis process has completed.  Kodi ${KODI_VERSION_TAG} should now been installed." >> /dev/tty1
  sleep 5
  clear
  if [[ ! -e "/dev/input/by-path/platform-odroidgo2-joypad-event-joystick" ]]; then
    sudo setfont /usr/share/consolefonts/Lat7-Terminus20x10.psf.gz
  fi
  exit 0
else
  printf "This is not a supported RK3566 device.  The script is exiting and will self destruct." >> /dev/tty1
  sleep 5
  rm -v -- "\$0"
  clear
  if [[ ! -e "/dev/input/by-path/platform-odroidgo2-joypad-event-joystick" ]]; then
    sudo setfont /usr/share/consolefonts/Lat7-Terminus20x10.psf.gz
  fi
  exit 0
fi

__PAYLOAD_BEGINS__
EOF

cat ${KODI_DEVENV}/Kodi-${KODI_VERSION_TAG}.tar.xz >> Kodi-${KODI_VERSION_TAG}-install.sh

echo "Done creating Kodi-${KODI_VERSION_TAG}-install.sh"
