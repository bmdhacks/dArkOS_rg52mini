#!/bin/bash

if [ -f "/boot/logo.bmp" ]; then
  sudo ffplay -x 1280 -y 720 /boot/logo.bmp &
  #PROC=$!
  sleep 5s
  sudo pkill ffplay
  #sudo kill -9 $PROC
fi

