# my-arch-install
Shell script I made to automate my Arch Linux install.  

## Who should use this?
Mainly for me but others are free to use this script.

## HEADS UP!
This script:
- only makes 2 partitions: root and efi
- uses ext4 only, no btrfs or other filesystems.
- mounts efi partition in /mnt/boot/efi
- makes a 10GB swapfile.
- makes "dash" your "/bin/sh".
- uses PipeWire as audio.
- uses GRUB as the bootloader.

## Installation
After Live ISO loads up, run the following commands:
```
timedatectl set-ntp true
pacman -Sy git
git clone https://github.com/DefinitelyNotMai/my-arch-install.git
cd my-arch-install
chmod +x install.sh
./install.sh
```
