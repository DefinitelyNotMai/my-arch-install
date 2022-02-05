#!/bin/bash

# set mirrorlist
reflector --latest 5 --sort rate --protocol https --country Germany --save /etc/pacman.d/mirrorlist --download-timeout 10

# set ParallelDownloads to 15
sed -i "s/^#ParallelDownloads = 5/ParallelDownloads = 15/" /etc/pacman.conf

# install keyring
pacman -Sy --noconfirm archlinux-keyring

# update system clock
timedatectl set-ntp true

# partition and format drives
lsblk
read -p "Enter your drive to format(Ex. \"/dev/sda\"): " dr
gdisk "$dr"
clear
lsblk
read -p "Enter your EFI partition(Ex. \"/dev/sda1\"): " ep
read -p "Enter your root partition(Ex. \"/dev/sda2\"): " rp
mkfs.vfat "$ep"
mkfs.ext4 "$rp"

# drive mounting
mount "$rp" /mnt
mkdir -p /mnt/boot/efi
mount "$ep" /mnt/boot/efi

# install essential packages
pacstrap /mnt base base-devel linux linux-firmware reflector git wget neovim \
    man-db intel-ucode

# generate fstab file
genfstab -U /mnt >> /mnt/etc/fstab

# move cloned repo to /mnt/tmp
mv /my-arch-install /mnt/tmp/my-arch-install

# done
printf "Pre-installation done! Run \"arch-chroot /mnt\", then run \"cd /tmp/my-arch-install && ./1-base.sh\""
