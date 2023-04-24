# my-arch-install
Shell script I made to automate my Arch Linux install.  

## Who should use this?
Mainly for me but others are free to use this script.

## HEADS UP!
This script:
- will wipe your selected drive and will only have Arch Linux on it. Dualbooting is not supported in this script.
- only makes 2 partitions: root and boot.
- uses btrfs as the filesystem with 5 subvolumes: @, @.snapshots, @home, @log, @cache, and @tmp.
- encryption type used is LUKS on partition.
- mounts boot partition in /mnt/boot.
- uses zramd.
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
