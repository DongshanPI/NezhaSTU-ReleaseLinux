# RISCV64 automatically builds the Debian ubuntu distribution system

* This system is an automatic build system based on `debootstrap` with the GUN/linux community version, mainly a series of scripts, etc.
* This system is not all compiled in one step, it needs to be executed in multiple times, because of the script framework and other issues, it is not particularly perfect.
* The source code provided by the community leader https://github.com/smaeul currently used by the build system is not particularly complete in terms of hardware support. But there is no problem with the minimal system.
* The later plan is to use the spl opensbi u-boot kernel in Tina-sdk V2.0 for adaptive construction.
* Welcome all enthusiasts to improve this framework and add more new riscv development boards and chips to facilitate development.


## Supported boards

* Nezha D1 development board.

* Dongshan Nezha STU development board (mainly supported).

* MQ development board.


## Compilation steps
> This repository mainly uses shell scripts to automatically compile and build and generate and package a debian distribution system. The operation steps can be referred to as follows.

* Step 1: Configure the basic environment for compilation.
  * This build system is based on a debian-like distribution system, such as ubuntu debian mint, etc. The example uses debian 10. Before compiling, you need to execute the `prepare_debian_host.sh` script to install the dependencies required for compilation.
* Step 2: Compile with community GCC to generate a cross-compilation toolchain and start compiling various components of spl opensbi uboot kernel.
  * After installing the dependent environment, you can execute `build.sh` to start building images such as boot0_spl opensbi uboot kernel based on the community version. Before starting, it will automatically compile and build a GNU GCC toolchain.
* Step 3: Use `debootstrap` to generate a filesystem while initializing some comparison parameters.
  * Before executing [setup_rootfs.sh](https://github.com/DongshanPI/NezhaSTU-ReleaseLinux/blob/master/setup_rootfs.sh), you must ensure that the previous step is completed, and the script will install the corresponding module driver, etc.
* Step 4: Generate a **NezhaSTU-Sdcard.img** image file that can be directly burned into the TF card.
  * After the end of the previous step, you can execute the last step `output_images.sh` to generate an image, which is used to generate a final image, which can be programmed directly using the dd if command or wind32diskimage under Windows.
* Step 5: After burning **NezhaSTU-Sdcard.img**, insert the card into the development board, turn on the power supply, and you can see the serial port printing information.
  * The serial port can view the startup information, note that the login information is **login user name root password 100ask**

## Process analysis

* Reference https://andreas.welcomes-you.com/boot-sw-debian-risc-v-lichee-rv/

### Source code repository

* Community version:
   * Toolchain: https://github.com/riscv/riscv-gnu-toolchain/
   * boot0_spl: https://github.com/smaeul/sun20i_d1_spl
   * opensbi: https://github.com/smaeul/opensbi
   * uboot: https://github.com/smaeul/u-boot/
   * linux: https://github.com/smaeul/linux

* Allwinner original factory version:
   * Toolchain: https://gitlab.com/weidongshan/Toolchain/-/raw/master/riscv64-glibc-gcc-thead_20200702.tar.xz
   * opensbi: https://github.com/DongshanPI/DongshanNezhaSTU-opensbi.git
   * u-boot2018: https://github.com/DongshanPI/DongshanNezhaSTU-u-boot.git
   *kernel: https://github.com/DongshanPI/DongshanNezhaSTU-Kernel.git

### Configuration process explanation

#### build.sh

* [build.sh](https://github.com/DongshanPI/NezhaSTU-ReleaseLinux/blob/master/build.sh) for compiling GCC spl opensbi uboot kernel .

```bash
#!/usr/bin/env bash

set -eou pipefail

echo "Updating all git submodules"
/* Pull and synchronize the repository source code of all git submodules */
git submodule update --init --recursive

cwd=`pwd`
/*The following code is mainly used to check whether the toolchain exists, and if it does not exist, it will be automatically configured and compiled to generate one. */
if ! [ -d riscv64-unknown-linux-gnu -a -x riscv64-unknown-linux-gnu/bin/riscv64-unknown-linux-gnu-gcc ]; then
echo "Build RISC-V toolchain"
pushd riscv-gnu-toolchain
./configure --prefix=$cwd/riscv64-unknown-linux-gnu --with-arch=rv64gc --with-abi=lp64d
make linux -j `nproc`
popd
else
echo "RISC-V toolchain has been built."
fi
````

```bash
/*Set the compiled toolchain and add it to the system environment variable*/
export PATH=$cwd/riscv64-unknown-linux-gnu/bin:$PATH

/* Enter the sun20i_d1_spl directory to start compiling the boot0 stage code*/
echo "Build boot0 binary"
pushd sun20i_d1_spl
make CROSS_COMPILE=$cwd/riscv64-unknown-linux-gnu/bin/riscv64-unknown-linux-gnu-p=sun20iw1p1 mmc
popd

/* Enter the opensbi directory to start compiling the opensbi code*/
echo "Build OpenSBI binary"
pushd opensbi
make CROSS_COMPILE=$cwd/riscv64-unknown-linux-gnu/bin/riscv64-unknown-linux-gnu-PLATFORM=generic FW_PIC=y FW_OPTIONS=0x2
popd

/* Enter the u-boot directory and start compiling the uboot source code*/
echo "Build u-boot binary"
pushd u-boot
make CROSS_COMPILE=$cwd/riscv64-unknown-linux-gnu/bin/riscv64-unknown-linux-gnu-nezha_defconfig
make -j `nproc` ARCH=riscv CROSS_COMPILE=$cwd/riscv64-unknown-linux-gnu/bin/riscv64-unknown-linux-gnu-all V=1
popd

/*After the compilation is completed, package the opensbi uboot image and the device tree generated by uboot together according to the configuration instructions of nezha_toc1.cfg*/
echo "Generate u-boot table of contents"
./u-boot/tools/mkimage -T sunxi_toc1 -d nezha_toc1.cfg u-boot.toc1


/* Enter the kernel module and compile it using the nezhastu_linux_defconfig configuration file in the source directory. */
echo "Build Linux kernel"
pushd linux
cp ../nezhastu_linux_defconfig arch/riscv/configs/nezhastu_linux_defconfig
make ARCH=riscv CROSS_COMPILE=$cwd/riscv64-unknown-linux-gnu/bin/riscv64-unknown-linux-gnu-nezhastu_linux_defconfig

make -j `nproc` ARCH=riscv CROSS_COMPILE=$cwd/riscv64-unknown-linux-gnu/bin/riscv64-unknown-linux-gnu-all V=1

make -j `nproc` ARCH=riscv CROSS_COMPILE=$cwd/riscv64-unknown-linux-gnu/bin/riscv64-unknown-linux-gnu-dtbs
pushd

/* Generate a boot.scr startup script, which mainly contains information such as kernel startup parameters. */
echo "Generate u-boot script"
./u-boot/tools/mkimage -T script -O linux -d nezhastu_uboot-bootscr.txt boot.scr
````



#### setup_rootfs.sh

* [setup_rootfs.sh](https://github.com/DongshanPI/NezhaSTU-ReleaseLinux/blob/master/setup_rootfs.sh) is mainly used to generate file system and add configuration.

```bash
#!/usr/bin/env bash

set -eou pipefail

/* Set WiFi username and password */
WLAN_SSID="100ASK"
WLAN_SECRET="100ask"
#read -p "Type in WLAN SSID: " WLAN_SSID
#read -s -p "Type in WLAN secret key: " WLAN_SECRET
echo ""


/* Check the gpg key file. */
keyring_option="--keyring /usr/share/keyrings/debian-ports-archive-keyring.gpg"
if [ $# -eq 1 ]; then
if [ $1 = "--no-check-gpg" ]; then
keyring_option="--no-check-gpg"
fi
fi

/* Generate a rootfs system image file */
if sudo debootstrap --arch=riscv64 ${keyring_option} --components main,contrib,non-free --include=debian-ports-archive-keyring,pciutils,autoconf,automake,autotools-dev,curl,python3,libmpc- dev,libmpfr-dev,libgmp-dev,gawk,build-essential,bison,flex,texinfo,gperf,libtool,patchutils,bc,zlib1g-dev,wpasupplicant,htop,net-tools,wireless-tools,firmware-realtek, ntpdate,openssh-client,openssh-server,sudo,e2fsprogs,git,man-db,lshw,dbus,wireless-regdb,libsensors5,lm-sensors,swig,libssl-dev,python3-distutils,python3-dev,alien, fakeroot,dkms,libblkid-dev,uuid-dev,libudev-dev,libaio-dev,libattr1-dev,libelf-dev,python3-setuptools,python3-cffi,python3-packaging,libffi-dev,libcurl4-openssl-dev, python3-ply, iotop, tmux, psmisc unstable rootfs http://deb.debian.org/debian-ports
then
echo "Created rootfs"
else
echo "Failed to create rootfs using debootstrap."
echo "If the error is that the keyring is missing or out-of-date,"
echo "this command can be re-run with the --no-check-gpg option."
fi

/* Install kernel modules to rootfs*/
pushd linux
sudo make modules_install ARCH=riscv INSTALL_MOD_PATH=../rootfs KERNELRELEASE=5.17.0-rc2-379425-g06b026a8b714
popd

/* Delete some useless link files. */
sudo rm rootfs/lib/modules/5.17.0-rc2-379425-g06b026a8b714/build
sudo rm rootfs/lib/modules/5.17.0-rc2-379425-g06b026a8b714/source
sudo depmod -a -b rootfs 5.17.0-rc2-379425-g06b026a8b714

/*Set the root username and password to 100ask*/
echo "Set root user password to: 100ask"
sudo sed -i -e 's%^root:[^:]*:%root:$6$QkgMDDAP$qSmQAFBZTsFXCDFxK.Rwsy4Ik.J\/bSzsI6fW.fSX5kzEW4YRWTgJpzo8c9YTMm3XTkjsNgcudaUN7ha624PHh0:%' rootfs/etc/shadow

/*Add fstab to start auto mount partition script*/
sudo cp fstab rootfs /etc/

/*Set the configuration information of wlan0*/
sudo rm -f /tmp/wlan0_contents
echo "set wlan0 ssid and secret."
cat > /tmp/wlan0_contents << EOF
allow-hotplug wlan0
iface wlan0 inet dhcp
wpa-ssid ${WLAN_SSID}
wpa-psk ${WLAN_SECRET}
EOF
sudo cp /tmp/wlan0_contents rootfs/etc/network/interfaces.d/
sudo rm /tmp/wlan0_contents

/* Set the host user name and other information */
echo "Set host name to 'NezhaSTU'"
sudo sh -c 'echo nezhastu > rootfs/etc/hostname'
sudo sh -c 'echo "@reboot for i in 1 2 3 4 5; do /usr/sbin/ntpdate 0.europe.pool.ntp.org && break || sleep 15; done" >> rootfs/var/spool /cron
```

#### output_images.sh

* [output_images.sh](https://github.com/DongshanPI/NezhaSTU-ReleaseLinux/blob/master/output_images.sh)

```bash
#!/bin/sh

/*Set to generate a NezhaSTU-Sdcard.img image file, use parted to partition, and automatically mount it to the virtual disk*/
SD_CARD=NezhaSTU-Sdcard.img
sudo dd if=/dev/zero of=${SD_CARD} bs=1M count=4000
echo "Create new GPT parititon table and partitions"
sudo parted -s -a optimal -- ${SD_CARD} mklabel gpt
sudo parted -s -a optimal -- ${SD_CARD} mkpart primary ext2 40MiB 100MiB
sudo parted -s -a optimal -- ${SD_CARD} mkpart primary ext4 100MiB -2GiB
sudo parted -s -a optimal -- ${SD_CARD} mkpart primary linux-swap -1GiB 100%
loopdevice=`sudo losetup -f --show ${SD_CARD}`
device=`sudo kpartx -va $loopdevice | sed -E 's/.*(loop[0-9])p.*/\1/g' | head -1`
device="/dev/mapper/${device}"
partBoot="${device}p1"
partRoot="${device}p2"
swapPart="${device}p3"

/*Write the boot0 spl u-boot.toc1 stage to NezhaSTU-Sdcard.img, pay attention to the written offset address*/
echo "Write SPL"
sudo dd if=sun20i_d1_spl/nboot/boot0_sdcard_sun20iw1p1.bin of=${SD_CARD} bs=8192 seek=16
echo "Write u-boot table of contents"
sudo dd if=u-boot.toc1 of=${SD_CARD} bs=512 seek=32800


/*Create a special mount directory and copy the kernel image device tree startup script*/
#Create mount dir.
sudo mkdir -p /mnt/sdcard_boot
sudo mkdir -p /mnt/sdcard_rootfs

#Copy kernel and dtb.
sudo mkfs.ext4 $partBoot
echo "Copy files to /boot partition"
sudo mount -t ext4 $partBoot /mnt/sdcard_boot

sudo cp -rfv linux/arch/riscv/boot/Image.gz /mnt/sdcard_boot
sudo cp -rfv boot.scr /mnt/sdcard_boot
sudo cp -rfv linux/arch/riscv/boot/dts/allwinner/sun20i-d1-nezha.dtb /mnt/sdcard_boot
sudo sync
sudo umount /mnt/sdcard_boot

/*Create a special mount directory and copy the corresponding file system files*/
#Copy filesystem.
echo "Copy files to root filesystem"
sudo mkfs.ext4 $partRoot
sudo mount -t ext4 $partRoot /mnt/sdcard_rootfs
sudo cp -av rootfs/* /mnt/sdcard_rootfs/
sudo sync
sudo umount /mnt/sdcard_rootfs

sudo rmdir /mnt/sdcard_boot
sudo rmdir /mnt/sdcard_rootfs

/*Format the swap partition*
sudo mkswap $swapPart

/* Unmount and mount virtual partition */
sudo kpartx -d $loopdevice
sudo losetup -d $loopdevice

echo "Successfully finished output RV64 image to ${SD_CARD}"
````
## start log

```bash
U-Boot 2022.04-rc4-33849-ga53389af5e (Apr 23 2022 - 08:29:10 -0400)

CPU:   rv64imafdc
Model: Sipeed Lichee RV Dock
DRAM:  512 MiB
sunxi_set_gate: (CLK#24) unhandled
Core:  43 devices, 18 uclasses, devicetree: board
WDT:   Started watchdog@6011000 with servicing (16s timeout)
MMC:   mmc@4020000: 0, mmc@4021000: 1
Loading Environment from nowhere... OK
In:    serial@2500000
Out:   serial@2500000
Err:   serial@2500000
Net:   No ethernet found.
Hit any key to stop autoboot:  0
switch to partitions #0, OK
mmc0 is current device
Scanning mmc 0:1...
Found U-Boot script /boot.scr
501 bytes read in 1 ms (489.3 KiB/s)
## Executing script at 41900000
Loading kernel from mmc 0:1 to address 0x40080000
8383319 bytes read in 1444 ms (5.5 MiB/s)
Booting kernel with bootargs as earlycon=sbi console=ttyS0,115200n8 root=/dev/mmcblk0p2 delayacct slub_debug; and fdtcontroladdr is 5fb19d70
   Uncompressing Kernel Image
Moving Image from 0x40080000 to 0x40200000, end=41724420
## Flattened Device Tree blob at 5fb19d70
   Booting using the fdt blob at 0x5fb19d70
   Loading Device Tree to 0000000042df6000, end 0000000042dff07e ... OK

Starting kernel ...

[    0.000000] Linux version 5.17.0-rc2-379425-g06b026a8b714 (book@debian) (riscv64-unknown-linux-gnu-gcc (g5964b5cd727) 11.1.0, GNU ld (GNU Binutils) 2.37) #1 PREEMPT Sat Apr 23 08:30:14 EDT 2022
[    0.000000] OF: fdt: Ignoring memory range 0x40000000 - 0x40200000
[    0.000000] Machine model: Sipeed Lichee RV Dock
[    0.000000] earlycon: sbi0 at I/O port 0x0 (options '')
[    0.000000] printk: bootconsole [sbi0] enabled
[    0.000000] Zone ranges:
[    0.000000]   DMA32    [mem 0x0000000040200000-0x000000005fffffff]
[    0.000000]   Normal   empty

   3.590404] Run /sbin/init as init process
[    4.467606] systemd[1]: System time before build time, advancing clock.
[    4.594262] systemd[1]: systemd 250.4-1 running in system mode (+PAM +AUDIT +SELINUX +APPARMOR +IMA +SMACK +SECCOMP +GCRYPT +GNUTLS -OPENSSL +ACL +BLKID +CURL +ELFUTILS +FIDO2 +IDN2 -IDN +IPTC +KMOD +LIBCRYPTSETUP +LIBFDISK +PCRE2 -PWQUALITY -P11KIT -QRENCODE +BZIP2 +LZ4 +XZ +ZLIB +ZSTD -BPF_FRAMEWORK -XKBCOMMON +UTMP +SYSVINIT default-hierarchy=unified)
[    4.626770] systemd[1]: Detected architecture riscv64.

Welcome to Debian GNU/Linux bookworm/sid!

[    4.655627] systemd[1]: Hostname set to <nezhastu>.
[    8.004154] systemd[1]: Queued start job for default target Graphical Interface.

  33.848975] vdd-cpu: disabling
[   33.852054] ldob: disabling
[  OK  ] Finished Raise network interfaces.
[  OK  ] Reached target Network.
         Starting OpenBSD Secure Shell server...
         Starting Permit User Sessions...
[  OK  ] Finished Permit User Sessions.
[  OK  ] Started Serial Getty on hvc0.
[  OK  ] Started Serial Getty on ttyS0.
[  OK  ] Reached target Login Prompts.
[  OK  ] Started User Login Management.
[  OK  ] Started OpenBSD Secure Shell server.

Debian GNU/Linux bookworm/sid nezhastu hvc0

nezhastu login:
Debian GNU/Linux bookworm/sid nezhastu ttyS0

nezhastu login: root
Password:
Linux nezhastu 5.17.0-rc2-379425-g06b026a8b714 #1 PREEMPT Sat Apr 23 08:30:14 EDT 2022 riscv64

The programs included with the Debian GNU/Linux system are free software;
the exact distribution terms for each program are described in the
individual files in /usr/share/doc/*/copyright.

Debian GNU/Linux comes with ABSOLUTELY NO WARRANTY, to the extent
permitted by applicable law.
root@nezhastu:~#
root@nezhastu:~#
root@nezhastu:~# uname -a
Linux nezhastu 5.17.0-rc2-379425-g06b026a8b714 #1 PREEMPT Sat Apr 23 08:30:14 EDT 2022 riscv64 GNU/Linux
root@nezhastu:~#

```

## Participate in contribution

* This repository complies with the GPL-V3 open source agreement, students who use it, please keep this agreement.
* You can fork this repository and submit your changes to help make this repository more complete.
* Welcome all enthusiasts to improve this framework and add more new riscv development boards and chips to facilitate development.