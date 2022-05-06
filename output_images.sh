#!/bin/sh


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

echo "Write SPL"
sudo dd if=sun20i_d1_spl/nboot/boot0_sdcard_sun20iw1p1.bin of=${SD_CARD} bs=8192 seek=16
echo "Write u-boot table of contents"
sudo dd if=u-boot.toc1 of=${SD_CARD} bs=512 seek=32800


#Creat mount dir.
sudo mkdir -p /mnt/sdcard_boot
sudo mkdir -p /mnt/sdcard_rootfs

#Copy kernel and dtb.
sudo mkfs.ext4 $partBoot
echo "Copy files to /boot partition"
sudo mount -t ext4  $partBoot /mnt/sdcard_boot

sudo cp linux-build/arch/riscv/boot/Image.gz /mnt/sdcard_boot
sudo cp boot.scr /mnt/sdcard_boot
sudo sync
sudo cp linux-build/arch/riscv/boot/Image /mnt/sdcard_boot
sudo cp linux-build/arch/riscv/boot/dts/allwinner/sun20i-d1-nezha.dtb /mnt/sdcard_boot
#sudo cp -rf extlinux/  /mnt/sdcard_boot
sudo sync
sudo umount /mnt/sdcard_boot

#Copy filesystem.
echo "Copy files to root filesystem"
sudo mkfs.ext4 $partRoot
sudo mount -t ext4 $partRoot /mnt/sdcard_rootfs
sudo cp -av rootfs/* /mnt/sdcard_rootfs/
sudo sync
sudo umount /mnt/sdcard_rootfs

sudo rmdir /mnt/sdcard_boot
sudo rmdir /mnt/sdcard_rootfs

sudo mkswap $swapPart

sudo kpartx -d $loopdevice
sudo losetup -d $loopdevice

echo "Successfully finished output RV64 image to ${SD_CARD}"
