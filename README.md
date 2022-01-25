# my-arch-install
Shell script I made to install Arch Linux.  
1-base.sh should be ran after chrooting into /mnt.
2-postInstall.sh is for MY personal use but feel free to use it, be ready to make some edits in the script though.

## Who should use this?
People who just want a minimal installation of Arch going.

## HEADS UP!
This script assumes:
- you only made 2 partitions: root and efi
- you mounted your efi partition in /mnt/boot/efi
- you didn't create a swap partition and it makes a 2GB swapfile for you, delete/comment out before executing if not desired.
- you want "dash" as your "/bin/sh", comment it out before executing if not desired.

## Installation
Base install, run after chrooting into /mnt.
```
git clone https://github.com/DefinitelyNotMai/my-arch-install.git
cd my-arch-install
chmod +x 1-base.sh
./1-base.sh
```
Post install, run after rebooting and logging in.
```
mkdir -p ~/files/repos
cd ~/files/repos
git clone https://github.com/DefinitelyNotMai/my-arch-install.git
cd my-arch-install
chmod +x 2-postInstall.sh
./2-postInstall.sh
```
