#!/bin/bash

DEVICE=""
CONFIG=""

if [ -f "/boot/rk3326-rg351mp-linux.dtb" ] || [ -f "/boot/rk3326-g350-linux.dtb" ]; then
  DEVICE="RG351MP/G350"
  CONFIG="BigPEmuConfig.bigpcfg.rg351mp"
elif [ -f "/boot/rk3326-odroidgo2-linux.dtb" ] || [ -f "/boot/rk3326-odroidgo2-linux-v11.dtb" ]; then
  if [[ ! -z $(cat /etc/emulationstation/es_input.cfg | grep "190000004b4800000010000001010000") ]]; then
    DEVICE="RGB10/OGA 1.1 (BE)"
    CONFIG="BigPEmuConfig.bigpcfg.rgb10"
  else
    DEVICE="RK2020/OGA 1.0"
    CONFIG="BigPEmuConfig.bigpcfg.rk2020"
  fi
else
    DEVICE="RK3566"
    CONFIG="BigPEmuConfig.bigpcfg.rk3566"
fi

. /usr/local/bin/buttonmon.sh

if compgen -G "/boot/rk3566*" > /dev/null; then
  if test ! -z "$(cat /home/ark/.config/.DEVICE | grep RGB20PRO | tr -d '\0')"
  then
    sudo setfont /usr/share/consolefonts/Lat7-TerminusBold32x16.psf.gz
  else
    sudo setfont /usr/share/consolefonts/Lat7-TerminusBold28x14.psf.gz
  fi
  height="20"
  width="60"
fi

printf "\nAre you sure you want to default your BigPEmu configuration?\n"
printf "\nPress A to continue.  Press B to exit.\n"
while true
do
    Test_Button_A
    if [ "$?" -eq "10" ]; then
      cp -f /opt/bigpemu/defaultconfig/${CONFIG} /home/ark/.bigpemu_userdata/BigPEmuConfig.bigpcfg
      if [ $? == 0 ]; then
        printf "\nRestored the default BigPEmu emulator configuration for the\n"
        printf "$DEVICE"
        sleep 5
      else
        printf "\nFailed to restore the default BigPEmu emulator configuration for $DEVICE"
        sleep 5
      fi
      exit 0
	fi

    Test_Button_B
    if [ "$?" -eq "10" ]; then
	  printf "\nExiting without defaulting the BigPEmu emulator configuration."
	  sleep 1
      exit 0
	fi
done
