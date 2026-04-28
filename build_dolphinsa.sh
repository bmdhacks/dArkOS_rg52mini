#!/bin/bash

# Build and install Dolphin standalone emulator
# Cache key: SHA of scripts/dolphinsa.sh in our rk3562_core_builds submodule.
# If the recipe changes, the old tarball is discarded and we rebuild.
DOLPHINSA_RECIPE_SHA=$(git -C rk3562_core_builds ls-tree HEAD scripts/dolphinsa.sh 2>/dev/null | awk '{print $3}')
if [ -f "Arkbuild_package_cache/${CHIPSET}/dolphinsa.tar.gz" ] && \
   [ "$(cat Arkbuild_package_cache/${CHIPSET}/dolphinsa.commit 2>/dev/null)" == "${DOLPHINSA_RECIPE_SHA}" ]; then
    sudo tar -xvzpf Arkbuild_package_cache/${CHIPSET}/dolphinsa.tar.gz
    # Validate cache extraction produced the expected binary
    if [ ! -f "Arkbuild/opt/dolphin/dolphin-emu-nogui" ]; then
        echo "WARNING: Dolphin cache tarball is corrupt, rebuilding from source..."
        sudo rm -f Arkbuild_package_cache/${CHIPSET}/dolphinsa.tar.gz
    fi
fi
if [ ! -f "Arkbuild/opt/dolphin/dolphin-emu-nogui" ]; then
	call_chroot "cd /home/ark &&
	  cd ${CHIPSET}_core_builds &&
	  chmod 777 builds-alt.sh &&
	  eatmydata ./builds-alt.sh dolphinsa
	  "
	sudo mkdir -p Arkbuild/opt/dolphin
	sudo mkdir -p Arkbuild/home/ark/.local/share/dolphin-emu
	sudo cp -Ra Arkbuild/home/ark/${CHIPSET}_core_builds/dolphinsa64/dolphin-emu-nogui Arkbuild/opt/dolphin/
	sudo cp -Ra Arkbuild/home/ark/${CHIPSET}_core_builds/dolphin/Data/Sys/* Arkbuild/home/ark/.local/share/dolphin-emu/
	sudo rm -f Arkbuild_package_cache/${CHIPSET}/dolphinsa.tar.gz Arkbuild_package_cache/${CHIPSET}/dolphinsa.commit
	sudo tar -czpf Arkbuild_package_cache/${CHIPSET}/dolphinsa.tar.gz Arkbuild/opt/dolphin/ Arkbuild/home/ark/.local/share/dolphin-emu/
	echo "${DOLPHINSA_RECIPE_SHA}" | sudo tee Arkbuild_package_cache/${CHIPSET}/dolphinsa.commit > /dev/null
fi
sudo cp -R dolphin/Config/ Arkbuild/home/ark/.local/share/dolphin-emu/
sudo cp dolphin/scripts/dolphin.sh Arkbuild/usr/local/bin/
call_chroot "chown -R ark:ark /opt/"
call_chroot "chown -R ark:ark /home/ark/"
sudo chmod 777 Arkbuild/opt/dolphin/dolphin-emu-nogui
sudo chmod 777 Arkbuild/usr/local/bin/dolphin.sh
