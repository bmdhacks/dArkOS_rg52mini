#!/bin/bash

export SDL_GAMECONTROLLERCONFIG_FILE="/opt/inttools/gamecontrollerdb.txt"
cd /opt/351Files
./351Files 2>&1 1>351Files.log
printf "\033c" >> /dev/tty1
