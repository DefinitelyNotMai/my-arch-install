#!/bin/bash

# I. PREINSTALLATION
# set mirrorlist
reflector --latest 10 --sort rate --save /etc/pacman.d/mirrorlist --protocol https --download-timeout 20

# enable and set ParallelDownloads to 15
sed -i "s/^#ParallelDownloads = 5$/ParallelDownloads = 15/" /etc/pacman.conf

# sync mirrors and install keyring
pacman -Sy --noconfirm archlinux-keyring

# format disk
clear
lsblk
read -p "Enter drive to format(Ex. \"/dev/sda\" OR \"/dev/nvme0n1\"): " dr
sgdisk -Z "$dr"
sgdisk -a 2048 -o "$dr"

# create partitions
sgdisk -n 1::+300M --typecode=1:ef00 "$dr"
sgdisk -n 2::-0 --typecode=1:8300 "$dr"

# create filesystems
clear
lsblk
if [[ "$dr" =~ "nvme" ]]; then
    bp="$dr"p1
    rp="$dr"p2
else
    bp="$dr"1
    rp="$dr"2
fi
mkfs.vfat -F32 "$bp"
cryptsetup -y -v luksFormat "$rp"
cryptsetup open "$rp" crypt-root
mkfs.ext4 /dev/mapper/crypt-root
mount /dev/mapper/crypt-root /mnt
mkdir /mnt/boot
mount "$bp" /mnt/boot

# check if processor is AMD or Intel
cpu=$(grep vendor_id /proc/cpuinfo)
if [[ "$cpu" ==  *"AuthenticAMD"* ]]; then
    microcode=amd-ucode
elif [[ "$cpu" == *"GenuineIntel"* ]]; then
    microcode=intel-ucode
fi

# install essential packages
pacstrap /mnt base base-devel linux linux-firmware "$microcode"

# generate fstab file
genfstab -U /mnt >> /mnt/etc/fstab

# copy current mirrorlist to mounted root
cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist

# copy base install script to /mnt and execute it
sed "1,/^# II. BASE$/d" 0-pre.sh > /mnt/1-base.sh
echo enc_dr_uuid=$(blkid -s UUID -o value "$rp") >> /mnt/enc_uuid
chmod +x /mnt/1-base.sh

# pre-installation done
clear
printf "Pre-installation done! Performing Base install now..."
sleep 3
arch-chroot /mnt ./1-base.sh
exit

# II. BASE
#!/bin/bash

# source enc_uuid, for kernel parameters
source /enc_uuid

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
printf "swap /opt/swap /dev/urandom swap\n" >> /etc/crypttab
printf "/dev/mapper/swap none swap sw 0 0\n" >> /etc/fstab
printf "vm.swappiness=1\n" >> /etc/sysctl.d/99-swappiness.conf

# set locale, hostname and hosts, and set root password
ln -sf /usr/share/zoneinfo/Asia/Manila /etc/localtime
hwclock --systohc
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
printf "LANG=en_US.UTF-8\n" >> /etc/locale.conf
read -p "Enter desired hostname: " hsn
printf "%s" "$hsn\n" >> /etc/hostname
printf "127.0.0.1    localhost\n::1          localhost\n127.0.1.1    %s.localdomain    %s\n" "$hsn" "$hsn" >> /etc/hosts
printf "Enter new password for root\n"
passwd

# install some packages
pacman -S --noconfirm grub efibootmgr networkmanager mtools dosfstools ntfs-3g \
  ufw dash pipewire pipewire-alsa pipewire-pulse pipewire-jack linux-headers \
  reflector git wget neovim man-db polkit

# open mkinitcpio.conf
sed -i "s/HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)/HOOKS=(base udev autodetect keyboard modconf block encrypt filesystems fsck)/" /etc/mkinitcpio.conf

# uncomment if you want to load modules for hijacking graphics card. For GPU Passthrough
#sed -i "s/MODULES=()/MODULES=(vfio_pci vfio vfio_iommu_type1 vfio_virqfd)/" /etc/mkinitcpio.conf
mkinitcpio -p linux

# relink dash to /bin/sh and create hook to relink dash to /bin/sh everytime bash gets updated
ln -sfT dash /usr/bin/sh
printf "[Trigger]\nType = Package\nOperation = Install\nOperation = Upgrade\nTarget = bash\n\n[Action]\nDescription = Re-pointing /bin/sh symlink to dash...\nWhen = PostTransaction\nExec = /usr/bin/ln -sfT dash /usr/bin/sh\nDepends = dash\n" > /usr/share/libalpm/hooks/binsh2dash.hook

# remove grub timeout and install grub
sed -i 's/GRUB_TIMEOUT=5/GRUB_TIMEOUT=-1/' /etc/default/grub
sed -i "s%GRUB_CMDLINE_LINUX=\"%GRUB_CMDLINE_LINUX=\"cryptdevice=UUID="$enc_dr_uuid":crypt-root root=/dev/mapper/crypt-root%g" /etc/default/grub
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# look for NVidia Card and output it to /tmp for reference to be used in setting kernel parameter for hijacking. Uncomment if planning to do NVidia GPU passthrough
#lspci -nnk | grep NVIDIA >> /tmp/blkid.txt
#nvim /etc/default/grub
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

sed '1,/^# III. POSTINSTALLATION$/d' /1-base.sh > /home/"$usn"/2-post.sh
rm /1-base.sh && rm /enc_dr_uuid
chown "$usn":"$usn" /home/"$usn"/2-post.sh
chmod +x /home/"$usn"/2-post.sh
su -c /home/"$usn"/2-post.sh -s /bin/sh "$usn"

# III. POSTINSTALLATION
#!/bin/sh

# enable ufw
#sudo ufw enable

# making directories
cd ~
mkdir -p ~/.local/src/DefinitelyNotMai 
mkdir ~/.config
mkdir -p ~/.local/share/cargo ~/.local/share/go ~/.local/share/wallpapers 
mkdir -p ~/documents ~/downloads ~/music ~/pictures/mpv-screenshots ~/pictures/scrot-screenshots ~/videos

# make mount directories, mount flashdrive and copy files
sudo mkdir /mnt/usb /mnt/hdd
sudo chown $(whoami): /mnt/usb
sudo chmod 750 /mnt/usb
sudo chown $(whoami): /mnt/hdd
sudo chmod 750 /mnt/hdd
# sudo mount /dev/sda1 /mnt/usb
# sudo umount /mnt/usb

# wget and set dracula-themed wallpaper
wget https://github.com/aynp/dracula-wallpapers/raw/main/Art/Ghost.png -O ~/.local/share/wallpapers/ghost.png
ln -s ~/.local/share/wallpapers/ghost.png ~/.local/share/bg

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
ln -s ~/.local/src/DefinitelyNotMai/dotfiles/config/pcmanfm ~/.config/pcmanfm
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
  noto-fonts-emoji noto-fonts-cjk firefox fzf alacritty \
  libappindicator-gtk3 ttf-jetbrains-mono pavucontrol newsboat brightnessctl wmname \
  npm ripgrep time tree neofetch openssh cmake

# install AUR helper and AUR packages I use
git clone https://aur.archlinux.org/paru.git ~/.local/src/paru
cd ~/.local/src/paru || exit
makepkg -si
sudo sed -i "s/#BottomUp/BottomUp/" /etc/paru.conf
paru freetube-bin
paru dracula-icons-git
paru dracula-cursors-git
paru dracula-gtk-theme-git
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

# change shell to zsh
chsh -s /usr/bin/zsh

# done
clear
printf "Post installation done! Run \"systemctl reboot\" and login. :)"
