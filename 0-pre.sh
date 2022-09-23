#!/bin/bash

# I. PREINSTALLATION
# set mirrorlist
reflector --latest 10 --sort rate --save /etc/pacman.d/mirrorlist --protocol https --download-timeout 20

# enable and set ParallelDownloads to 15
sed -i "s/^#ParallelDownloads = 5/ParallelDownloads = 15/" /etc/pacman.conf

# sync mirrors and install keyring
pacman -Sy --noconfirm archlinux-keyring

# disk partitioning
clear
lsblk
read -p "Enter drive to format(Ex. \"/dev/sda\"): " dr
gdisk "$dr"

# partition formatting
clear
lsblk
read -p "Enter your boot partition(Ex. \"/dev/sda1\"): " ep
read -p "Enter your root partition(Ex. \"/dev/sda2\"): " rp
mkfs.fat -F 32 "$ep"
cryptsetup -y -v luksFormat "$rp"
cryptsetup open "$rp" crypt-root
mkfs.ext4 /dev/mapper/crypt-root
mount /dev/mapper/crypt-root /mnt
mkdir /mnt/boot
mount "$ep" /mnt/boot

# Check if processor is AMD or Intel
cpu=$(grep vendor_id /proc/cpuinfo)
if [[ "$cpu" ==  *"AuthenticAMD"* ]]; then
  microcode=amd-ucode
else
  microcode=intel-ucode
fi

# install essential packages
pacstrap /mnt base base-devel linux linux-firmware "$microcode"

# generate fstab file
genfstab -U /mnt >> /mnt/etc/fstab

# copy current mirrorlist and cloned repo to mounted root
cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist

# copy base install script to /mnt and execute it
sed '1,/^# II. BASE$/d' 0-pre.sh > /mnt/1-base.sh
chmod +x /mnt/1-base.sh

# pre-installation done
clear
printf "Pre-installation done! Performing Base install now..."
sleep 3
arch-chroot /mnt ./1-base.sh
exit

# II. BASE
#!/bin/bash

# enable and set ParallelDownloads to 15 and enable multilib repositories
sed -i 's/^#ParallelDownloads = 5/ParallelDownloads = 15/' /etc/pacman.conf

# use all cores for compilation and compression
sed -i "s/-j2/-j$(nproc)/;s/^#MAKEFLAGS/MAKEFLAGS/" /etc/makepkg.conf
sed -i "s/COMPRESSXZ=(xz -c -z -)/COMPRESSXZ=(xz -c -T $(nproc) -z -)/g" /etc/makepkg.conf

# make an 8GB encryoted swapfile and set swappiness to 1
cd /opt
dd if=/dev/zero of=swap bs=1M count=8192 status=progress
cryptsetup --type plain -d /dev/urandom open swap swap
chmod 600 swap
mkswap swap
swapon swap
printf "swap /opt/swap /dev/urandom swap" >> /etc/crypttab
printf "/dev/mapper/swap none swap sw 0 0" >> /etc/fstab
printf "vm.swappiness=1" >> /etc/sysctl.d/99-swappiness.conf

# set locale, hostname and hosts, and set root password
ln -sf /usr/share/zoneinfo/Asia/Manila /etc/localtime
hwclock --systohc
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
printf "LANG=en_US.UTF-8" >> /etc/locale.conf
read -p "Enter desired hostname: " hsn
printf "%s" "$hsn" >> /etc/hostname
printf "127.0.0.1    localhost\n::1          localhost\n127.0.1.1    %s.localdomain    %s" "$hsn" "$hsn" >> /etc/hosts
printf "Enter new password for root\n"
passwd

# install some packages
pacman -S --noconfirm grub efibootmgr networkmanager mtools dosfstools ntfs-3g \
  ufw dash pipewire pipewire-alsa pipewire-pulse pipewire-jack linux-headers \
  reflector git wget neovim man-db polkit

# open mkinitcpio.conf
sed -i "s/HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)/HOOKS=(base udev autodetect keyboard modconf block encrypt filesystems fsck)/" /etc/mkinitcpio.conf
sed -i "s/MODULES=()/MODULES=(vfio_pci vfio vfio_iommu_type1 vfio_virqfd)/" /etc/mkinitcpio.conf
mkinitcpio -p linux

# relink dash to /bin/sh and create hook to relink dash to /bin/sh everytime bash gets updated
ln -sfT dash /usr/bin/sh
printf "[Trigger]\nType = Package\nOperation = Install\nOperation = Upgrade\nTarget = bash\n\n[Action]\nDescription = Re-pointing /bin/sh symlink to dash...\nWhen = PostTransaction\nExec = /usr/bin/ln -sfT dash /usr/bin/sh\nDepends = dash" > /usr/share/libalpm/hooks/binsh2dash.hook

# remove grub timeout and install grub
sed -i 's/GRUB_TIMEOUT=5/GRUB_TIMEOUT=-1/' /etc/default/grub
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# run blkid and output file to /tmp for reference to be used in setting kernel parameter
blkid > /tmp/blkid.txt
lspci -nnk >> /tmp/blkid.txt
printf "cryptdevice=UUID=device-UUID:crypt-root root=/dev/mapper/crypt-root" >> /tmp/blkid.txt
nvim /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

# enable services
systemctl enable NetworkManager
systemctl enable fstrim.timer
systemctl enable reflector.timer
systemctl enable ufw.service

# edit reflector's systemd service config file
sed -i 's/--latest 5/--latest 10/' /etc/xdg/reflector/reflector.conf
sed -i 's/--sort age/--sort rate/' /etc/xdg/reflector/reflector.conf

# add user, assign to wheel, and allow any member of wheel group to execute sudo commands
read -p "Enter desired username: " usn
useradd -m "$usn"
printf "Enter password for %s\n" "$usn"
passwd "$usn"
usermod -a -G wheel "$usn"
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# prompt if user wants to use my personal postinstall script
read -p "Would you like to use my personal postinstall script after restarting?(y/n): " ans
case "$ans" in
  y|Y) mkdir -p /home/"$usn"/.local/src/DefinitelyNotMai
    sed '1,/^# III. POSTINSTALLATION$/d' /1-base.sh > /home/"$usn"/.local/src/DefinitelyNotMai/2-post.sh
    rm /1-base.sh
    chown -R "$usn":"$usn" /home/"$usn"/.local
    printf "You answered Yes. Run \"umount -a\" and \"reboot now\", then \"cd ~/.local/src/ && chmod +x 2-post.sh && ./2-post.sh\" after rebooting."
    exit ;;
  *) printf "You answered No."
    printf "\nBase installation done! Run \"umount -a\", and \"reboot now\" :)\n"
    exit ;;
esac

# III. POSTINSTALLATION
#!/bin/sh

# enable ufw
sudo ufw enable

# making directories
mkdir ~/.config
mkdir -p ~/.local/share/cargo ~/.local/share/go ~/.local/share/wallpapers 
mkdir -p ~/documents ~/downloads ~/music ~/pictures/scrot-screenshots ~/videos

# make mount directories, mount flashdrive and copy files
sudo mkdir /mnt/usb /mnt/hdd
sudo chown $(whoami): /mnt/usb
sudo chmod 750 usb
sudo chown $(whoami): /mnt/hdd
sudo chmod 750 hdd
sudo mount /dev/sda1 /mnt/usb
sudo cp /mnt/usb/.a/navi /etc/navi
cp /mnt/usb/yes-man.jpg ~/.local/share/wallpapers/yes-man.jpg
ln -s ~/.local/share/wallpapers/yes-man.jpg ~/.local/share/bg
sudo umount /mnt/usb

# exports
export CARGO_HOME="$HOME/.local/share/cargo"
export GOPATH="$HOME/.local/share/go"
export LESSHISTFILE="-"

# clone and symlink my dotfiles
git clone https://github.com/DefinitelyNotMai/dotfiles ~/.local/src/DefinitelyNotMai/dotfiles
ln -s ~/.local/src/DefinitelyNotMai/dotfiles/config/alacritty ~/.config/alacritty
ln -s ~/.local/src/DefinitelyNotMai/dotfiles/config/dunst ~/.config/dunst
ln -s ~/.local/src/DefinitelyNotMai/dotfiles/config/gtk-2.0 ~/.config/gtk-2.0
ln -s ~/.local/src/DefinitelyNotMai/dotfiles/config/gtk-3.0 ~/.config/gtk-3.0
ln -s ~/.local/src/DefinitelyNotMai/dotfiles/config/lf ~/.config/lf
ln -s ~/.local/src/DefinitelyNotMai/dotfiles/config/mpd ~/.config/mpd
ln -s ~/.local/src/DefinitelyNotMai/dotfiles/config/mpv ~/.config/mpv
ln -s ~/.local/src/DefinitelyNotMai/dotfiles/config/ncmpcpp ~/.config/ncmpcpp
ln -s ~/.local/src/DefinitelyNotMai/dotfiles/config/newsboat ~/.config/newsboat
ln -s ~/.local/src/DefinitelyNotMai/dotfiles/config/nvim ~/.config/nvim
ln -s ~/.local/src/DefinitelyNotMai/dotfiles/config/shell ~/.config/shell
ln -s ~/.local/src/DefinitelyNotMai/dotfiles/config/x11 ~/.config/x11
ln -s ~/.local/src/DefinitelyNotMai/dotfiles/config/user-dirs.dirs ~/.config/user-dirs.dirs
ln -s ~/.local/src/DefinitelyNotMai/dotfiles/config/zathura ~/.config/zathura
ln -s ~/.local/src/DefinitelyNotMai/dotfiles/config/zsh ~/.config/zsh
ln -s ~/.local/src/DefinitelyNotMai/dotfiles/local/bin ~/.local/bin
ln -s ~/.config/shell/profile ~/.zprofile

# install packages I use
sudo pacman -S --noconfirm xorg-server xorg-xinit xorg-xev libnotify mpd mpv \
  ncmpcpp unclutter sxiv libreoffice-fresh dunst gimp lxappearance htop bc \
  keepassxc pcmanfm zathura zathura-pdf-mupdf zathura-cb scrot obs-studio \
  pulsemixer jdk-openjdk jre-openjdk jre-openjdk-headless xwallpaper p7zip \
  unzip unrar rust go ttf-liberation ttf-nerd-fonts-symbols-2048-em-mono ueberzug zsh \
  zsh-syntax-highlighting ffmpegthumbnailer highlight odt2txt file-roller \
  catdoc docx2txt perl-image-exiftool python-pdftotext android-tools xclip \
  noto-fonts-emoji noto-fonts-cjk arc-icon-theme firefox fzf alacritty \
  libappindicator-gtk3 ttf-jetbrains-mono pavucontrol newsboat brightnessctl wmname \
  npm ripgrep time tree libxpresent neofetch openssh spice-protocol cmake qemu \
  libvirt edk2-ovmf virt-manager iptables-nft dnsmasq

# install AUR helper and AUR packages I use
git clone https://aur.archlinux.org/paru.git ~/.local/src/paru
cd ~/.local/src/paru || exit
makepkg -si
sudo sed -i "s/#BottomUp/BottomUp/" /etc/paru.conf
paru freetube-bin
paru gtk-theme-arc-gruvbox-git
paru lf-git
paru otpclient
sudo sed -i "/\[bin\]/,/FileManager = vifm/"'s/^#//' /etc/paru.conf
sudo sed -i 's/vifm/lfrun/' /etc/paru.conf

# install my suckless tools
cd ~/.local/src/DefinitelyNotMai/ || exit
git clone https://github.com/DefinitelyNotMai/dmenu
git clone https://github.com/DefinitelyNotMai/dwm
git clone https://github.com/DefinitelyNotMai/scroll
git clone https://github.com/DefinitelyNotMai/slock
git clone https://github.com/DefinitelyNotMai/slstatus
git clone https://github.com/DefinitelyNotMai/st
cd dmenu && sudo make install
cd ../dwm && sudo make install
cd ../scroll && sudo make install
cd ../slock && sudo make install
cd ../slstatus && sudo make install
cd ../st && sudo make install

# enable services for virt-manager
sudo systemctl enable libvirtd.service
sudo systemctl enable virtlogd.socket
sudo virsh net-autostart default
sudo virsh net-start default

# remove orphan packages
sudo pacman -Rns $(pacman -Qtdq)

# change shell to zsh
chsh -s /usr/bin/zsh

# done
clear
printf "Post installation done! Run \"systemctl reboot\" and login. :)"
