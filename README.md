# my-arch-install
Shell scripts for my Arch Linux install

## Installation
Base install, run after chrooting into "/mnt"
```
cd /tmp
git clone https://github.com/DefinitelyNotMai/my-arch-install.git
cd my-arch-install
chmod +x 1-base.sh
./1-base.sh
```
Post install, run after rebooting and logging in
```
mkdir -p ~/files/repos
cd ~/files/repos
git clone https://github.com/DefinitelyNotMai/my-arch-install.git
cd my-arch-install
chmod +x 2-postInstall.sh
./2-postInstall.sh
```
