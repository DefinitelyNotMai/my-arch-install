# my-arch-install
Shell script I made to automate my Arch Linux install.  

## Who should use this?
Mainly for me but others are free to use this script.

## HEADS UP!
This script:
- will wipe your selected drive and will only have Arch Linux on it. Dualbooting is not supported in this script.
- only makes 2 partitions: root and boot.
- uses ext4 only, no btrfs or other filesystems.
- encryption type used is LUKS on partition.
- mounts boot partition in /mnt/boot.
- makes an 8GB swapfile.
- makes "dash" your "/bin/sh".
- uses PipeWire as audio.
- uses systemd-boot as the bootloader.
- uses Wayland as the display server with Hyprland as the compositor.

## Installation
After Live ISO loads up, run the following commands:
```
timedatectl set-ntp true
pacman -Sy git
git clone https://github.com/DefinitelyNotMai/my-arch-install.git
cd my-arch-install
chmod +x pre.sh
./pre.sh
```
