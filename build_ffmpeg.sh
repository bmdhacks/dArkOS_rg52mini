#!/bin/bash

# Build and install custom ffmpeg-rockchip with hardware video decode/encode
# via Rockchip MPP (RKVDEC/RKVENC) and RGA. Replaces the apt-installed ffmpeg.
#
# Hand-port of upstream commits db1ecc5, 9db5ccd, a3436db, 983f727, b72a9ad,
# 13f35ca. Triggered by BUILD_RKMPP_FFMPEG=y. The cached tarball lives at
# Arkbuild_package_cache/${CHIPSET}/ffmpeg.tar.gz; first build is slow.

if [ -f "Arkbuild_package_cache/${CHIPSET}/ffmpeg.tar.gz" ]; then
    sudo tar -xvzpf Arkbuild_package_cache/${CHIPSET}/ffmpeg.tar.gz
else
	call_chroot "cd /home/ark &&
	  cd ${CHIPSET}_core_builds &&
	  git clone -b jellyfin-mpp --depth=1 https://github.com/nyanmisaka/mpp.git rkmpp &&
	  cd rkmpp &&
	  mkdir rkmpp_build &&
	  cd rkmpp_build &&
	  cmake \
	  -DCMAKE_INSTALL_PREFIX=/usr \
	  -DCMAKE_BUILD_TYPE=Release \
	  -DBUILD_SHARED_LIBS=ON \
	  -DBUILD_TEST=OFF \
	  .. &&
	  make -j \$(nproc) &&
	  make install &&
	  cd ../.. &&
	  git clone -b jellyfin-rga --depth=1 https://github.com/nyanmisaka/rk-mirrors.git rkrga &&
	  meson setup rkrga rkrga_build \
	  --prefix=/usr \
	  --libdir=lib \
	  --buildtype=release \
	  --default-library=shared \
	  -Dcpp_args=-fpermissive \
	  -Dlibdrm=false \
	  -Dlibrga_demo=false &&
	  ninja -C rkrga_build install &&
	  cp -av rkrga_build/librga.so* /usr/lib/aarch64-linux-gnu/ &&
	  git clone --depth=1 https://github.com/nyanmisaka/ffmpeg-rockchip.git -b 7.1 ffmpeg &&
	  cd ffmpeg &&
	  rm -f /usr/lib/aarch64-linux-gnu/librga.so.2.0.0 /usr/lib/aarch64-linux-gnu/librga.so.2 /usr/lib/aarch64-linux-gnu/librga.so &&
	  rm -rf /usr/local/include/rga &&
	  ./configure --prefix=/usr --libdir=/usr/lib/aarch64-linux-gnu --shlibdir=/usr/lib/aarch64-linux-gnu --enable-gpl --enable-version3 --enable-libdrm --enable-rkmpp --enable-rkrga --disable-vulkan --disable-autodetect --enable-shared --disable-static --enable-sdl &&
	  make -j \$(nproc) &&
	  make install
	  "
	verify_action
	mkdir -p Arkbuild_package_cache/${CHIPSET}
	if [ -f "Arkbuild_package_cache/${CHIPSET}/ffmpeg.tar.gz" ]; then
	  sudo rm -f Arkbuild_package_cache/${CHIPSET}/ffmpeg.tar.gz
	fi
	sudo tar -czpf Arkbuild_package_cache/${CHIPSET}/ffmpeg.tar.gz \
	  Arkbuild/usr/bin/ffmpeg \
	  Arkbuild/usr/bin/ffplay \
	  Arkbuild/usr/bin/ffprobe \
	  Arkbuild/usr/lib/aarch64-linux-gnu/librockchip_mpp.* \
	  Arkbuild/usr/lib/aarch64-linux-gnu/librockchip_vpu.* \
	  Arkbuild/usr/lib/librga.so* \
	  Arkbuild/usr/lib/aarch64-linux-gnu/librga.so* \
	  Arkbuild/usr/lib/aarch64-linux-gnu/libavutil* \
	  Arkbuild/usr/lib/aarch64-linux-gnu/libavcodec* \
	  Arkbuild/usr/lib/aarch64-linux-gnu/libavformat* \
	  Arkbuild/usr/lib/aarch64-linux-gnu/libavdevice* \
	  Arkbuild/usr/lib/aarch64-linux-gnu/libavfilter* \
	  Arkbuild/usr/lib/aarch64-linux-gnu/libswscale* \
	  Arkbuild/usr/lib/aarch64-linux-gnu/libswresample* \
	  Arkbuild/usr/lib/aarch64-linux-gnu/libpostproc*
fi

# udev rules to allow the `video` group access to the MPP service, RGA, and
# the dma-heap nodes that ffmpeg-rockchip uses for zero-copy buffer handling.
cat <<EOF | sudo tee Arkbuild/etc/udev/rules.d/50-mpp-permission.rules
KERNEL=="mpp_service", MODE="0660", GROUP="video"
KERNEL=="rga", MODE="0660", GROUP="video"
KERNEL=="system", MODE="0660", GROUP="video"
KERNEL=="system-dma32", MODE="0660", GROUP="video"
KERNEL=="system-uncached", MODE="0660", GROUP="video"
KERNEL=="system-uncached-dma32", MODE="0660", GROUP="video"
EOF
