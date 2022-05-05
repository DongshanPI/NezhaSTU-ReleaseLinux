# NezhaSTU-Release-linux
> 自动构建Debian Ubuntu等发行版本系统，主要用于学习研究。

简介
==========
* 此套系统是基于 `debootstrap `配合GUN/linux社区版本实现的自动构建系统，主要是一些列脚本等。
* 由于社区版本目前支持的硬件不够完善。接 下来计划支持使用 Tina-sdk 里的 boot0 opensbi uboot kernel 各个组件来自动生成一个完整系统镜像。


使用步骤
============
1.此构建系统基于 debian类发行版系统，如ubuntu debian mint等，示例使用的是debian 10.
在开始编译前需要先执行 `prepare_debian_host.sh` 脚本来安装编译所需的各项依赖。

2.安装完成依赖环境后，就可以执行 `build.sh`  来开始构建基于社区版本的 boot0_spl opensbi uboot kernel等镜像，开始之前还是会自动编译构建一个 GNU GCC工具链。

3.等待编译完成系统所需的各个阶段，就可以使用 `setup_rootfs.sh` 来生产文件系统镜像了。

4.等待上一步结束后，就可以执行最后一步 `output_images.sh` 生成一个**NezhaSTU-Sdcard.img** 镜像，用于生成一个最终镜像，可以直接使用 dd if命令 或者Windows下的 wind32diskimage进行烧写。

5.烧写完成后，插到开发板TF卡槽上，上电就会启动了，等待提示输入用户名和密码。
**登录用户名root 密码100ask**
**登录用户名root 密码100ask**
**登录用户名root 密码100ask**





Running
=======
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

* 参考资料 https://andreas.welcomes-you.com/boot-sw-debian-risc-v-lichee-rv/
