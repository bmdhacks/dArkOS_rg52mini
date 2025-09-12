#!/bin/bash

if [ -f "/boot/logo.bmp" ]; then
  export SDL_VIDEO_EGL_DRIVER="libEGL.so"
  image-viewer /boot/logo.bmp &
  sleep 5s
  sudo pkill image-viewer
fi
