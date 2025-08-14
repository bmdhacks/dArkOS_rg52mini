SHELL := /bin/bash

DEBIAN_CODE_NAME ?= trixie
ENABLE_CACHE ?= y

export DEBIAN_CODE_NAME
export ENABLE_CACHE

ifeq ($(DEBIAN_CODE_NAME),)
  $(error DEBIAN_CODE_NAME is not set. Please run with DEBIAN_CODE_NAME=suite (e.g., trixie))
endif


all:
	@echo "Please specify a valid build target: make rgb10 or make rg353m"

rgb10:
	$(info dArkOS will be built using the $(DEBIAN_CODE_NAME) release of Debian.)
	$(info debian building caching enabled? ${ENABLE_CACHE})
	@sleep 5
	./build_rgb10.sh

rg351mp:
	$(info dArkOS will be built using the $(DEBIAN_CODE_NAME) release of Debian.)
	$(info debian building caching enabled? ${ENABLE_CACHE})
	@sleep 5
	./build_rg351mp.sh

rg353m:
	$(info dArkOS will be built using the $(DEBIAN_CODE_NAME) release of Debian.)
	$(info debian building caching enabled? ${ENABLE_CACHE})
	@sleep 5
	./build_rg353m.sh

rg503:
	$(info dArkOS will be built using the $(DEBIAN_CODE_NAME) release of Debian.)
	$(info debian building caching enabled? ${ENABLE_CACHE})
	@sleep 5
	./build_rg503.sh

devenv:
	$(info dArkOS will be built using the $(DEBIAN_CODE_NAME) release of Debian.)
	$(info debian building caching enabled? ${ENABLE_CACHE})
	@sleep 5
	./build_devenv.sh

devenv32:
	$(info dArkOS will be built using the $(DEBIAN_CODE_NAME) release of Debian.)
	$(info debian building caching enabled? ${ENABLE_CACHE})
	@sleep 5
	./build_devenv.sh 32

clean:
	[ -d "mnt/boot" ] && sudo umount mnt/boot && sudo rm -rf mnt/boot || true
	[ -d "mnt/roms" ] && sudo umount mnt/roms && sudo rm -rf mnt/roms || true
	[ -d "main" ] && sudo rm -rf main || true
	[ -d "initrd" ] && sudo rm -rf initrd || true
	[ -f "wget-log" ] && sudo rm -f wget-log* || true
	source utils.sh && remove_arkbuild && remove_arkbuild32
	sudo rm -rf Arkbuild Arkbuild32 Arkbuild-final arkos_* main mnt odroidgoA-4.4.y ArkOS_* rg351 wget-*
	while losetup -a | grep -m 1 ArkOS; do sudo losetup -d "$$(losetup -a | grep ArkOS | cut -d ':' -f 1)"; done
	@echo "Done!"

clean_complete: clean
	[ -d "$${PWD}/Arkbuild_ccache" ] && sudo umount $${PWD}/Arkbuild_ccache || true
	[ -d "$${PWD}/Arkbuild_ccache" ] && sudo rm -rf Arkbuild_ccache || true
	sudo rm -f build.log*
