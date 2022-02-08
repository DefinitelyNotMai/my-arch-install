#!/bin/sh

# set mirrorlist
reflector --latest 10 --sort rate --save /etc/pacman.d/mirrorlist --protocol https --download-timeout 10

# enable ParallelDownloads and set it to 15
sed -i "s/^#ParallelDownloads = 5/ParallelDownloads = 15/" /etc/pacman.conf

# sync mirrors and install keyring
pacman -Sy --noconfirm archlinux-keyring

# disk partitioning
clear
lsblk
read -p "Enter your drive to format(Ex. \"/dev/sda\"): " dr
gdisk "$dr"

# partition formatting
clear
lsblk
read -p "Enter your EFI partition(Ex. \"/dev/sda1\"): " ep
read -p "Enter your root partition(Ex. \"/dev/sda2\"): " rp
mkfs.vfat -F32 "$ep"
mkfs.ext4 "$rp"
mount "$rp" /mnt
mkdir -p /mnt/boot/efi
mount "$ep" /mnt/boot/efi

# install essential packages
pacstrap /mnt base base-devel linux linux-firmware intel-ucode

# generate fstab file
genfstab -U /mnt >> /mnt/etc/fstab

# copy current mirrorlist to mounted root
cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist

# done
clear
printf "Pre-installation done! Run \"arch-chroot /mnt\", then run \"cd /tmp/my-arch-install && ./1-base.sh\"\n"
