#!/bin/bash

# Build and install ogage (Global Hotkey Daemon)
if [ "$UNIT" == "chi" ]; then
  branch="gameforce-chi"
elif [ "$UNIT" == "g350" ]; then
  branch="g350"
elif [ "$UNIT" == "rgb10" ]; then
  branch="master"
elif [ "$UNIT" == "a10mini" ]; then
  branch="a10mini"
elif [ "$UNIT" == "rk2020" ]; then
  branch="rk2020"
elif [ "$UNIT" == "rg351mp" ]; then
  branch="rg351mp"
elif [ "$UNIT" == "rg351v" ]; then
  branch="rg351v"
elif [[ "$UNIT" == *"353"* ]]; then
  branch="rg353v"
elif [[ "$UNIT" == "503" ]] || [[ "$UNIT" == "rg56pro" ]]; then
  branch="rg503"
elif [ "$UNIT" == "rk2023" ] || [ "$UNIT" == "rgb30" ] || [ "$UNIT" == "rgb20pro" ]; then
  branch="rk2023"
fi

if [ -f "Arkbuild_package_cache/${CHIPSET}/ogage_${branch}.tar.gz" ] && [ "$(cat Arkbuild_package_cache/${CHIPSET}/ogage_${branch}.commit)" == "$(curl -s https://api.github.com/repos/christianhaitian/ogage/commits/${branch} | jq -r '.sha')" ]; then
    sudo tar -xvzpf Arkbuild_package_cache/${CHIPSET}/ogage_${branch}.tar.gz
else
	call_chroot "cd /home/ark &&
	  git clone https://github.com/christianhaitian/ogage.git -b ${branch} &&
	  cd ogage &&
	  export CARGO_NET_GIT_FETCH_WITH_CLI=true &&
	  cargo build --release &&
	  strip target/release/ogage &&
	  cp target/release/ogage /usr/local/bin/ &&
	  chmod 777 /usr/local/bin/ogage
	  "
	if [ -f "Arkbuild_package_cache/${CHIPSET}/ogage.tar.gz" ]; then
	  sudo rm -f Arkbuild_package_cache/${CHIPSET}/ogage_${branch}.tar.gz
	fi
	if [ -f "Arkbuild_package_cache/${CHIPSET}/ogage.commit" ]; then
	  sudo rm -f Arkbuild_package_cache/${CHIPSET}/ogage_${branch}.commit
	fi
	sudo tar -czpf Arkbuild_package_cache/${CHIPSET}/ogage_${branch}.tar.gz Arkbuild/usr/local/bin/ogage
	sudo git --git-dir=Arkbuild/home/ark/ogage/.git --work-tree=Arkbuild/home/ark/ogage rev-parse HEAD > Arkbuild_package_cache/${CHIPSET}/ogage_${branch}.commit
	sudo rm -rf Arkbuild/home/ark/ogage
fi

sudo cp scripts/ogage.service Arkbuild/etc/systemd/system/ogage.service
call_chroot "systemctl enable ogage"
