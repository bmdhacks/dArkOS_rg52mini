#!/bin/bash

if test ! -z "$(dmesg | grep -Eo 'cpu[0-9] policy NULL' | head -n 1 | tr -d '\0')"
then
  if [ ! -f "/home/ark/.config/.V2DTBLOADED" ]; then
    sudo cp -f /usr/local/bin/rgb30dtbs/rk3566-rgb30.dtb.v2 /boot/rk3566-rgb30.dtb
    touch /home/ark/.config/.V2DTBLOADED
  else
    sudo cp -f /usr/local/bin/rgb30dtbs/rk3566-rgb30.dtb.v1 /boot/rk3566-rgb30.dtb
    rm -f /home/ark/.config/.V2DTBLOADED
  fi
fi
