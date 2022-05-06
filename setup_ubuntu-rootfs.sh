#!/usr/bin/env bash

set -eou pipefail

WLAN_SSID="100ASK"
WLAN_SECRET="100ask"
#read -p "Type in WLAN SSID: " WLAN_SSID
#read -s -p "Type in WLAN secret key: " WLAN_SECRET
echo ""


if sudo debootstrap --arch=riscv64  --include=ca-certificates,pciutils,autoconf,automake,autotools-dev,curl,python3,libmpc-dev,libmpfr-dev,libgmp-dev,gawk,build-essential,bison,flex,libtool,patchutils,bc,zlib1g-dev,wpasupplicant,htop,net-tools,openssh-server,sudo,e2fsprogs,git,man-db,lshw,dbus,wireless-regdb,libsensors5,libssl-dev,uuid-dev,libudev-dev  --foreign hirsute  rootfs http://cn.archive.ubuntu.com/ubuntu/


then
	echo "Created rootfs"
else
	echo "Failed to create rootfs using debootstrap."
	echo "If the error is that the keyring is missing or out-of-date,"
	echo "this command can be re-run with the --no-check-gpg option."
fi

pushd linux-build
sudo make modules_install ARCH=riscv INSTALL_MOD_PATH=../rootfs KERNELRELEASE=5.17.0-rc2-379425-g06b026a8b714
popd


sudo rm rootfs/lib/modules/5.17.0-rc2-379425-g06b026a8b714/build
sudo rm rootfs/lib/modules/5.17.0-rc2-379425-g06b026a8b714/source
sudo depmod -a -b rootfs 5.17.0-rc2-379425-g06b026a8b714


#echo "Set root user password to: 100ask"
#sudo sed  's%^root:[^:]*:%root:$6$QkgMDDAP$qSmQAFBZTsFXCDFxK.Rwsy4Ik.J\/bSzsI6fW.fSX5kzEW4YRWTgJpzo8c9YTMm3XTkjsNgcudaUN7ha624PHh0:%' rootfs/etc/shadow
sudo sed -i -e 's%^root:[^:]*:%root:$6$QkgMDDAP$qSmQAFBZTsFXCDFxK.Rwsy4Ik.J\/bSzsI6fW.fSX5kzEW4YRWTgJpzo8c9YTMm3XTkjsNgcudaUN7ha624PHh0:%' rootfs/etc/shadow

sudo cp fstab rootfs/etc/

sudo rm -f /tmp/wlan0_contents
cat > /tmp/wlan0_contents << EOF
allow-hotplug wlan0
iface wlan0 inet dhcp
	wpa-ssid ${WLAN_SSID}
	wpa-psk ${WLAN_SECRET}
EOF
sudo cp /tmp/wlan0_contents rootfs/etc/network/interfaces.d/
sudo rm /tmp/wlan0_contents

echo "Set host name to 'NezhaSTU'"
sudo sh -c 'echo nezhastu > rootfs/etc/hostname'
sudo sh -c 'echo "@reboot for i in 1 2 3 4 5; do /usr/sbin/ntpdate 0.europe.pool.ntp.org && break || sleep 15; done" >> rootfs/var/spool/cron/crontabs/root'
sudo chmod 600 rootfs/var/spool/cron/crontabs/root

