[中文](README.md)|[English](README_en.md)

# 东山哪吒STU自动构建Debian ubuntu发行版系统

* 此套系统是基于 `debootstrap `配合GUN/linux社区版本实现的自动构建系统，主要是一些列脚本等。
* 此套系统并非是一步编译所有，需要分多次执行，因为脚本框架等问题，所以不是特别完善。
* 目前构建系统使用的社区大佬 https://github.com/smaeul 提供的源码，硬件支持上并不是特别完整。但是最小系统没有问题。
* 后期计划使用Tina-sdk V2.0内的 spl opensbi  u-boot kernel进行适配构建。
* 欢迎各位爱好者改善此框架，增加更多新的riscv开发板与芯片，助力发展。


## 支持的开发板

* 哪吒D1开发板。

* 东山哪吒STU开发板(主要支持)。

* MQ开发板。


## 编译操作步骤
> 此仓库主要使用的shell脚本来实现自动编译构建并生成打包一个 debian发行版系统，操作步骤可以参考如下。

* 步骤1：配置编译基本环境。
  * 此构建系统基于 debian类发行版系统，如ubuntu debian mint等，示例使用的是debian 10.    在开始编译前需要先执行 `prepare_debian_host.sh` 脚本来安装编译所需的各项依赖。
* 步骤2：使用社区GCC编译生成一个交叉编译工具链并开始编译 spl  opensbi uboot kernel各部分组件。
  * 安装完成依赖环境后，就可以执行 `build.sh`  来开始构建基于社区版本的 boot0_spl opensbi uboot kernel等镜像，开始之前还是会自动编译构建一个 GNU GCC工具链。
* 步骤3：使用`debootstrap`生成一个文件系统，同时初始化一些比较参数。
  * 执行[setup_rootfs.sh](https://github.com/DongshanPI/NezhaSTU-ReleaseLinux/blob/master/setup_rootfs.sh)之前必须要保证上一步执行完成，脚本内会根据之前的内核配置，安装对应的模块驱动等。
* 步骤4：生成一个可以直接烧入TF卡的**NezhaSTU-Sdcard.img** 镜像文件。
  * 等待上一步结束后，就可以执行最后一步 `output_images.sh` 生成一个镜像，用于生成一个最终镜像，可以直接使用 dd if命令 或者Windows下的 wind32diskimage进行烧写。
* 步骤5：将**NezhaSTU-Sdcard.img** 烧录完成后，卡插入开发板内，接通电源上电，即可看到串口打印信息。
  * 串口可以查看启动信息，注意登录信息为 **登录用户名root 密码100ask**




## 过程分析

* 参考资料 https://andreas.welcomes-you.com/boot-sw-debian-risc-v-lichee-rv/

### 源码仓库

* 社区版本:
  * Toolchain:    https://github.com/riscv/riscv-gnu-toolchain/
  * boot0_spl:  https://github.com/smaeul/sun20i_d1_spl
  * opensbi: https://github.com/smaeul/opensbi
  * uboot: https://github.com/smaeul/u-boot/
  * linux: https://github.com/smaeul/linux

* 全志原厂版本：
  * Toolchain： https://gitlab.com/weidongshan/Toolchain/-/raw/master/riscv64-glibc-gcc-thead_20200702.tar.xz
  * opensbi： https://github.com/DongshanPI/DongshanNezhaSTU-opensbi.git
  * u-boot2018： https://github.com/DongshanPI/DongshanNezhaSTU-u-boot.git
  * kernel： https://github.com/DongshanPI/DongshanNezhaSTU-Kernel.git

### 配置过程讲解

#### build.sh

* [build.sh](https://github.com/DongshanPI/NezhaSTU-ReleaseLinux/blob/master/build.sh) 用于编译GCC spl opensbi uboot kernel .

```bash
#!/usr/bin/env bash

set -eou pipefail

echo "Updating all git submodules"
/*拉取同步所有git子模块的仓库源码*/
git submodule update --init --recursive

cwd=`pwd`
/*下面代码主要用于，检查工具链是否存在，如果不存在就自动配置编译生成一个。*/
if ! [ -d riscv64-unknown-linux-gnu -a -x riscv64-unknown-linux-gnu/bin/riscv64-unknown-linux-gnu-gcc ]; then
	echo "Build RISC-V toolchain"
	pushd riscv-gnu-toolchain
	./configure --prefix=$cwd/riscv64-unknown-linux-gnu --with-arch=rv64gc --with-abi=lp64d
	make linux -j `nproc`
	popd
else
	echo "RISC-V toolchain has been built."
fi
```

```bash
/*设置编译好的工具链，加入到系统环境变量中*/
export PATH=$cwd/riscv64-unknown-linux-gnu/bin:$PATH

/*进入到sun20i_d1_spl 目录开始编译 boot0阶段代码*/
echo "Build boot0 binary"
pushd sun20i_d1_spl
make CROSS_COMPILE=$cwd/riscv64-unknown-linux-gnu/bin/riscv64-unknown-linux-gnu- p=sun20iw1p1 mmc
popd

/*进入到opensbi 目录 开始编译opensbi代码*/
echo "Build OpenSBI binary"
pushd opensbi
make CROSS_COMPILE=$cwd/riscv64-unknown-linux-gnu/bin/riscv64-unknown-linux-gnu- PLATFORM=generic FW_PIC=y FW_OPTIONS=0x2
popd

/*进入到u-boot目录下，开始编译uboot源码*/
echo "Build u-boot binary"
pushd u-boot
make CROSS_COMPILE=$cwd/riscv64-unknown-linux-gnu/bin/riscv64-unknown-linux-gnu- nezha_defconfig
make -j `nproc` ARCH=riscv CROSS_COMPILE=$cwd/riscv64-unknown-linux-gnu/bin/riscv64-unknown-linux-gnu- all V=1
popd

/*编译完成后根据nezha_toc1.cfg 配置说明将opensbi uboot镜像与uboot生成的设备树打包到一起*/
echo "Generate u-boot table of contents"
./u-boot/tools/mkimage -T sunxi_toc1 -d nezha_toc1.cfg u-boot.toc1


/*进入内核模块，使用源码目录下的nezhastu_linux_defconfig配置文件进行编译。 */
echo "Build Linux kernel"
pushd  linux
cp ../nezhastu_linux_defconfig arch/riscv/configs/nezhastu_linux_defconfig
make ARCH=riscv CROSS_COMPILE=$cwd/riscv64-unknown-linux-gnu/bin/riscv64-unknown-linux-gnu-  nezhastu_linux_defconfig

make -j `nproc`  ARCH=riscv CROSS_COMPILE=$cwd/riscv64-unknown-linux-gnu/bin/riscv64-unknown-linux-gnu- all V=1

make -j `nproc`  ARCH=riscv CROSS_COMPILE=$cwd/riscv64-unknown-linux-gnu/bin/riscv64-unknown-linux-gnu- dtbs
pushd

/*生成一个boot.scr启动脚本，里面主要是kernel启动参数等信息。*/
echo "Generate u-boot script"
./u-boot/tools/mkimage -T script -O linux -d nezhastu_uboot-bootscr.txt  boot.scr
```



#### setup_rootfs.sh

* [setup_rootfs.sh](https://github.com/DongshanPI/NezhaSTU-ReleaseLinux/blob/master/setup_rootfs.sh) 主要用于生成文件系统并增加配置。

```bash
#!/usr/bin/env bash

set -eou pipefail

/*设置WiFi的用户名和密码*/
WLAN_SSID="100ASK"
WLAN_SECRET="100ask"
#read -p "Type in WLAN SSID: " WLAN_SSID
#read -s -p "Type in WLAN secret key: " WLAN_SECRET
echo ""


/*检查gpg密钥文件。*/
keyring_option="--keyring /usr/share/keyrings/debian-ports-archive-keyring.gpg"
if [ $# -eq 1 ]; then
	if [ $1 = "--no-check-gpg" ]; then
		keyring_option="--no-check-gpg"
	fi
fi

/*生成一个rootfs系统镜像文件*/
if sudo debootstrap --arch=riscv64 ${keyring_option} --components main,contrib,non-free --include=debian-ports-archive-keyring,pciutils,autoconf,automake,autotools-dev,curl,python3,libmpc-dev,libmpfr-dev,libgmp-dev,gawk,build-essential,bison,flex,texinfo,gperf,libtool,patchutils,bc,zlib1g-dev,wpasupplicant,htop,net-tools,wireless-tools,firmware-realtek,ntpdate,openssh-client,openssh-server,sudo,e2fsprogs,git,man-db,lshw,dbus,wireless-regdb,libsensors5,lm-sensors,swig,libssl-dev,python3-distutils,python3-dev,alien,fakeroot,dkms,libblkid-dev,uuid-dev,libudev-dev,libaio-dev,libattr1-dev,libelf-dev,python3-setuptools,python3-cffi,python3-packaging,libffi-dev,libcurl4-openssl-dev,python3-ply,iotop,tmux,psmisc unstable rootfs http://deb.debian.org/debian-ports
then
	echo "Created rootfs"
else
	echo "Failed to create rootfs using debootstrap."
	echo "If the error is that the keyring is missing or out-of-date,"
	echo "this command can be re-run with the --no-check-gpg option."
fi

/*安装内核模块到rootfs*/
pushd linux
sudo make modules_install ARCH=riscv INSTALL_MOD_PATH=../rootfs KERNELRELEASE=5.17.0-rc2-379425-g06b026a8b714
popd

/*删除一些无用的链接文件。*/
sudo rm rootfs/lib/modules/5.17.0-rc2-379425-g06b026a8b714/build
sudo rm rootfs/lib/modules/5.17.0-rc2-379425-g06b026a8b714/source
sudo depmod -a -b rootfs 5.17.0-rc2-379425-g06b026a8b714

/*设置root用户名密码为100ask*/
echo "Set root user password to: 100ask"
sudo sed -i -e 's%^root:[^:]*:%root:$6$QkgMDDAP$qSmQAFBZTsFXCDFxK.Rwsy4Ik.J\/bSzsI6fW.fSX5kzEW4YRWTgJpzo8c9YTMm3XTkjsNgcudaUN7ha624PHh0:%' rootfs/etc/shadow

/*增加fstab启动自动挂载分区脚本*/
sudo cp fstab rootfs/etc/

/*设置wlan0的配置信息*/
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

/*设置主机用户名等信息*/
echo "Set host name to 'NezhaSTU'"
sudo sh -c 'echo nezhastu > rootfs/etc/hostname'
sudo sh -c 'echo "@reboot for i in 1 2 3 4 5; do /usr/sbin/ntpdate 0.europe.pool.ntp.org && break || sleep 15; done" >> rootfs/var/spool/cron/crontabs/root'
sudo chmod 600 rootfs/var/spool/cron/crontabs/root

```



  #### output_images.sh

* [output_images.sh](https://github.com/DongshanPI/NezhaSTU-ReleaseLinux/blob/master/output_images.sh)

```bash
#!/bin/sh

/*设置生成一个NezhaSTU-Sdcard.img 镜像文件，并使用parted进行分区，并自动挂载到虚拟磁盘*/
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

/*写入boot0 spl u-boot.toc1阶段到NezhaSTU-Sdcard.img，注意看写入的偏移地址*/
echo "Write SPL"
sudo dd if=sun20i_d1_spl/nboot/boot0_sdcard_sun20iw1p1.bin of=${SD_CARD} bs=8192 seek=16
echo "Write u-boot table of contents"
sudo dd if=u-boot.toc1 of=${SD_CARD} bs=512 seek=32800


/*创建专门的挂载目录，并拷贝内核镜像设备树 启动脚本*/
#Creat mount dir.
sudo mkdir -p /mnt/sdcard_boot
sudo mkdir -p /mnt/sdcard_rootfs

#Copy kernel and dtb.
sudo mkfs.ext4 $partBoot
echo "Copy files to /boot partition"
sudo mount -t ext4  $partBoot /mnt/sdcard_boot

sudo cp -rfv linux/arch/riscv/boot/Image.gz /mnt/sdcard_boot
sudo cp -rfv boot.scr /mnt/sdcard_boot
sudo cp -rfv linux/arch/riscv/boot/dts/allwinner/sun20i-d1-nezha.dtb /mnt/sdcard_boot
sudo sync
sudo umount /mnt/sdcard_boot

/*创建专门的挂载目录，并拷贝对应的文件系统文件*/
#Copy filesystem.
echo "Copy files to root filesystem"
sudo mkfs.ext4 $partRoot
sudo mount -t ext4 $partRoot /mnt/sdcard_rootfs
sudo cp -av rootfs/* /mnt/sdcard_rootfs/
sudo sync
sudo umount /mnt/sdcard_rootfs

sudo rmdir /mnt/sdcard_boot
sudo rmdir /mnt/sdcard_rootfs

/*格式化一下swap交换分区*
sudo mkswap $swapPart

/*卸载挂载虚拟分区*/
sudo kpartx -d $loopdevice
sudo losetup -d $loopdevice

echo "Successfully finished output RV64 image to ${SD_CARD}"
```











## 启动log

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



## 参与贡献

* 此仓库遵循了GPL-V3开源协议，使用的同学请继续保留该协议。
* 可以fork此仓库并提交您的修改，来帮助此仓库更加完善。
* 欢迎各位爱好者改善此框架，增加更多新的riscv开发板与芯片，助力发展。
