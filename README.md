# my-arch-install
Shell script I made to install Arch Linux.  
0-preinstall.sh should be ran at the start.
1-base.sh should be ran after chrooting into /mnt.
2-postInstall.sh is for MY personal use but feel free to use it, be ready to make some edits in the script though.

## Who should use this?
People who just want a kinda minimal installation of Arch going.

## HEADS UP!
This script:
- only makes only 2 partitions: root and efi
- mounts efi partition in /mnt/boot/efi
- makes a 10GB swapfile, delete/comment it out before executing if not desired.
- makes "dash" your "/bin/sh", delete/comment it out before executing if not desired.

## Installation
After Live ISO loads up, run the following commands:
```
git clone https://github.com/DefinitelyNotMai/my-arch-install.git
cd my-arch-install
chmod +x *.sh
./0-preinstall.sh
```
