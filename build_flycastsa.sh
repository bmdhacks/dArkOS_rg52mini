#!/bin/bash

# Build and install flycast standalone emulator
# Cache key: SHA of scripts/flycastsa.sh in our rk3562_core_builds submodule.
FLYCASTSA_RECIPE_SHA=$(git -C rk3562_core_builds ls-tree HEAD scripts/flycastsa.sh 2>/dev/null | awk '{print $3}')
if [ -f "Arkbuild_package_cache/${CHIPSET}/flycastsa.tar.gz" ] && \
   [ "$(cat Arkbuild_package_cache/${CHIPSET}/flycastsa.commit 2>/dev/null)" == "${FLYCASTSA_RECIPE_SHA}" ]; then
    sudo tar -xvzpf Arkbuild_package_cache/${CHIPSET}/flycastsa.tar.gz
else
	call_chroot "cd /home/ark &&
	  cd ${CHIPSET}_core_builds &&
	  chmod 777 builds-alt.sh &&
	  eatmydata ./builds-alt.sh flycastsa
	  "
	sudo mkdir -p Arkbuild/opt/flycastsa
	if [[ "$CHIPSET" = "rk3326" ]]; then
	  ext="-rk3326"
	else
	  ext=""
	fi
	sudo cp -R Arkbuild/home/ark/${CHIPSET}_core_builds/flycastsa-64/flycast${ext} Arkbuild/opt/flycastsa/flycast
	sudo rm -f Arkbuild_package_cache/${CHIPSET}/flycastsa.tar.gz Arkbuild_package_cache/${CHIPSET}/flycastsa.commit
	sudo tar -czpf Arkbuild_package_cache/${CHIPSET}/flycastsa.tar.gz Arkbuild/opt/flycastsa/
	echo "${FLYCASTSA_RECIPE_SHA}" | sudo tee Arkbuild_package_cache/${CHIPSET}/flycastsa.commit > /dev/null
fi

sudo mkdir -p Arkbuild/home/ark/.config/flycast
sudo cp flycast/config/emu.cfg Arkbuild/home/ark/.config/flycast/
call_chroot "chown -R ark:ark /opt/"
call_chroot "chown -R ark:ark /home/ark/.config/flycast/"
sudo chmod 777 Arkbuild/opt/flycastsa/flycast
