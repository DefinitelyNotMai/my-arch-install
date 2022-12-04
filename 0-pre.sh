#!/bin/bash

##### PRE INSTALLATION START #####
# get hostname
printf "Enter desired hostname: "
read -r hsn
while ! printf "%s" "$hsn" | grep -q "^[a-z][a-z0-9-]*$"; do
    printf "ERROR: Invalid hostname. Try again: "
    read -r hsn
done

# get root password
printf "Enter password for root: "
read -rs rpass1
printf "\nRe-enter password: "
read -rs rpass2
while [ "$rpass1" != "$rpass2" ]; do
    unset rpass2
    printf "\nERROR: Passwords don't match. Try again: "
    read -rs rpass1
    printf "\nRe-enter password: "
    read -rs rpass2
done

# get username
printf "\nEnter desired username: "
read -r usn
while ! printf "%s" "$usn" | grep -q "^[a-z_][a-z0-9_-]*$"; do
    printf "ERROR: Invalid username. Try again: "
    read -r usn
done

# get user password
printf "Enter password for %s: " "$usn"
read -rs pass1
printf "\nRe-enter password: "
read -rs pass2
while [ "$pass1" != "$pass2" ]; do
    unset pass2
    printf "\nERROR: Passwords don't match. Try again: "
    read -rs pass1
    printf "\nRe-enter password: "
    read -rs pass2
done

# get drive to format
clear
lsblk
printf "Enter drive to format (Ex. \"/dev/sda\" OR \"/dev/nvme0n1\"): "
read -r dr

# update mirrorlist
printf "\nUpdating mirrorlist with reflector. Please wait...\n"
reflector --latest 10 --sort rate --save /etc/pacman.d/mirrorlist --protocol https --download-timeout 20

# enable and set ParallelDownloads to 15
sed -i "s/^#ParallelDownloads = 5$/ParallelDownloads = 15/" /etc/pacman.conf

# sync mirrors and install keyring
pacman -Sy --noconfirm archlinux-keyring

# format disk
sgdisk -Z "$dr"
sgdisk -a 2048 -o "$dr"

# create partitions
sgdisk -n 1::+300M --typecode=1:ef00 "$dr"
sgdisk -n 2::-0 --typecode=2:8300 "$dr"

# determine if drive is nvme or not
clear
lsblk
case "$dr" in
    *nvme*) bp="$dr"p1 && rp="$dr"p2 ;;
    *) bp="$dr"1 && rp="$dr"2 ;;
esac

# encrypt and format root partition, and format boot partition
cryptsetup -y -v luksFormat "$rp"
cryptsetup open "$rp" crypt-root
mkfs.ext4 /dev/mapper/crypt-root
mkfs.vfat -F32 "$bp"

# mount root and boot partition
mount /dev/mapper/crypt-root /mnt
mkdir /mnt/boot
mount "$bp" /mnt/boot

# determine if processor is AMD or Intel for microcode package
cpu=$(grep vendor_id /proc/cpuinfo)
case "$cpu" in
    *AuthenticAMD) microcode=amd-ucode ;;
    *GenuineIntel) microcode=intel-ucode ;;
esac

# install essential packages
pacstrap /mnt base base-devel linux linux-firmware "$microcode"

# run partprobe to reread partition table, and generate fstab file
partprobe "$dr"
genfstab -U /mnt >> /mnt/etc/fstab

# copy current mirrorlist to mounted root
cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist

# add variables
{
    printf "hsn=%s\n" "$hsn"
    printf "rpass1=%s\n" "$rpass1"
    printf "usn=%s\n" "$usn"
    printf "pass1=%s\n" "$pass1"
    printf "microcode=%s\n" "$microcode"
    printf "enc_dr_uuid="
    blkid -s UUID -o value "$rp"
} > vars

# copy vars to source for variables to be used in Base Installation
cp vars /mnt/vars

# copy base install script to /mnt and make it executable
sed "1,/^##### BASE INSTALLATION START #####$/d" 0-pre.sh > /mnt/1-base.sh
chmod +x /mnt/1-base.sh

# pre-installation done
clear
printf "Pre-installation done! Performing Base install now...\n"
sleep 3
arch-chroot /mnt ./1-base.sh
exit

##### BASE INSTALLATION START #####
#!/bin/sh

# source vars for hostname, username, and kernel parameters
. /vars

# enable and set ParallelDownloads to 15
sed -i 's/^#ParallelDownloads = 5/ParallelDownloads = 15/' /etc/pacman.conf

# use all cores for compilation and compression
sed -i "s/-j2/-j$(nproc)/;s/^#MAKEFLAGS/MAKEFLAGS/" /etc/makepkg.conf
sed -i "s/COMPRESSXZ=(xz -c -z -)/COMPRESSXZ=(xz -c -T $(nproc) -z -)/g" /etc/makepkg.conf

# make an 8GB encryoted swapfile and set swappiness to 1
cd /opt || exit
dd if=/dev/zero of=swap bs=1M count=8192 status=progress
cryptsetup --type plain -d /dev/urandom open swap swap
chmod 600 swap && mkswap swap && swapon swap
printf "swap /opt/swap /dev/urandom swap\n" >> /etc/crypttab
printf "/dev/mapper/swap none swap sw 0 0\n" >> /etc/fstab
printf "vm.swappiness=1\n" >> /etc/sysctl.d/99-swappiness.conf

# set locale, hostname and hosts, and set root password
ln -sf /usr/share/zoneinfo/Asia/Manila /etc/localtime
hwclock --systohc
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
printf "LANG=en_US.UTF-8\n" >> /etc/locale.conf
printf "%s\n" "$hsn" >> /etc/hostname
{
    printf "127.0.0.1    localhost\n"
    printf "::1          localhost\n"
    printf "127.0.1.1    %s.localdomain    %s\n" "$hsn" "$hsn"
} >> /etc/hosts
printf "root:$rpass1" | chpasswd

# install some packages
pacman -S --noconfirm networkmanager ntfs-3g ufw dash git wget man-db pipewire \
    pipewire-alsa pipewire-pulse pipewire-jack wireplumber linux-headers neovim \
    reflector polkit

# open mkinitcpio.conf
sed -i "s/HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)/HOOKS=(base udev autodetect keyboard modconf block encrypt filesystems fsck)/" /etc/mkinitcpio.conf

# uncomment if you want to load modules for hijacking graphics card. For GPU Passthrough
#sed -i "s/MODULES=()/MODULES=(vfio_pci vfio vfio_iommu_type1 vfio_virqfd)/" /etc/mkinitcpio.conf
mkinitcpio -p linux

# relink dash to /bin/sh and create hook to relink dash to /bin/sh everytime bash gets updated
ln -sfT dash /usr/bin/sh
{
    printf "[Trigger]\n"
    printf "Type = Package\n"
    printf "Operation = Install\n"
    printf "Operation = Upgrade\n"
    printf "Target = bash\n\n"
    printf "[Action]\n"
    printf "Description = Re-pointing /bin/sh symlink to dash...\n"
    printf "When = PostTransaction\n"
    printf "Exec = /usr/bin/ln -sfT dash /usr/bin/sh\n"
    printf "Depends = dash\n"
} > /usr/share/libalpm/hooks/binsh2dash.hook

# install and configure systemd-boot
bootctl install
{
    printf "default arch.conf\n"
    printf "timeout 3\n"
} > /boot/loader/loader.conf
{
    printf "title Arch Linux\n"
    printf "linux /vmlinuz-linux\n"
    printf "initrd /%s.img\n" "$microcode"
    printf "initrd /initramfs-linux.img\n"
    printf "options cryptdevice=UUID=%s:crypt-root root=/dev/mapper/crypt-root rw\n" "$enc_dr_uuid"
} > /boot/loader/entries/arch.conf
{
    printf "title Arch Linux (fallback initramfs)\n"
    printf "linux /vmlinuz-linux\n"
    printf "initrd /%s.img\n" "$microcode"
    printf "initrd /initramfs-linux-fallback.img\n"
    printf "options cryptdevice=UUID=%s:crypt-root root=/dev/mapper/crypt-root rw\n" "$enc_dr_uuid"
} > /boot/loader/entries/arch-fallback.conf

# look for NVidia Card and output it to /tmp for reference to be used in setting kernel parameter for hijacking. Uncomment if planning to do NVidia GPU passthrough
#lspci -nnk | grep NVIDIA >> /tmp/blkid.txt
#nvim /boot/loader/entries/arch.conf

# enable services
systemctl enable NetworkManager
systemctl enable fstrim.timer
systemctl enable reflector.timer
systemctl enable ufw.service

# edit reflector's systemd service config file
sed -i 's/--latest 5/--latest 10/' /etc/xdg/reflector/reflector.conf
sed -i 's/--sort age/--sort rate/' /etc/xdg/reflector/reflector.conf

# add user, assign to wheel, and allow any member of wheel group to execute sudo commands
useradd -mG wheel "$usn"
printf "$usn:$pass1" | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# prompt if user wants to use my personal postinstall script
printf "Would you like to use my personal postinstall script after restarting?(y/n): "
read -r ans
case "$ans" in
    y|Y) sed '1,/^##### POST INSTALLATION START #####$/d' /1-base.sh > /home/"$usn"/2-post.sh
        shred -v /1-base.sh /vars && rm /1-base.sh /vars
        chown "$usn":"$usn" /home/"$usn"/2-post.sh
        chmod +x /home/"$usn"/2-post.sh
        printf "You answered Yes. Script has been copied to /home/%s/2-post.sh\nRun \"./2-post.sh\" after rebooting.\n" "$usn"
        exit;;
    *) printf "You answered No. You can reboot now and goodluck with the rest of your installation :)\n"
        exit;;
esac
printf "Base Installation done! Run \"umount -a\", and \"reboot now\" :)\n"

##### POST INSTALLATION START #####
#!/bin/sh

# enable ufw
sudo ufw enable

# making directories
mkdir -p ~/.config ~/.local ~/.local/share/cargo ~/.local/share/go \
    ~/.local/share/wallpapers ~/documents ~/downloads ~/music \
    ~/pictures/mpv-screenshots ~/pictures/scrot-screenshots ~/videos ~/projects

# exports
export CARGO_HOME="$HOME/.local/share/cargo"
export GOPATH="$HOME/.local/share/go"
export LESSHISTFILE="-"

# make mount directories. I personally separate mount dirs for my flashdrive and hdd
sudo mkdir /mnt/usb /mnt/hdd
sudo chown "$(whoami)": /mnt/usb && sudo chmod 750 /mnt/usb
sudo chown "$(whoami)": /mnt/hdd && sudo chmod 750 /mnt/hdd

# wget and set dracula-themed wallpaper
wget https://raw.githubusercontent.com/catppuccin/wallpapers/main/flatppuccin/flatppuccin_4k_macchiato.png -O ~/.local/share/wallpapers/flatppuccin.png
ln -s ~/.local/share/wallpapers/flatppuccin.png ~/.local/share/bg

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
ln -s ~/.local/src/DefinitelyNotMai/dotfiles/config/npm ~/.config/npm
ln -s ~/.local/src/DefinitelyNotMai/dotfiles/config/nvim ~/.config/nvim
ln -s ~/.local/src/DefinitelyNotMai/dotfiles/config/pcmanfm ~/.config/pcmanfm
ln -s ~/.local/src/DefinitelyNotMai/dotfiles/config/shell ~/.config/shell
ln -s ~/.local/src/DefinitelyNotMai/dotfiles/config/sxhkd ~/.config/sxhkd
ln -s ~/.local/src/DefinitelyNotMai/dotfiles/config/x11 ~/.config/x11
ln -s ~/.local/src/DefinitelyNotMai/dotfiles/config/user-dirs.dirs ~/.config/user-dirs.dirs
ln -s ~/.local/src/DefinitelyNotMai/dotfiles/config/zathura ~/.config/zathura
ln -s ~/.local/src/DefinitelyNotMai/dotfiles/config/zsh ~/.config/zsh
ln -s ~/.local/src/DefinitelyNotMai/dotfiles/local/bin ~/.local/bin
ln -s ~/.config/shell/profile ~/.zprofile

# rename a directory and readjust some config files to line up with username 
sed -i "s/user/$(whoami)/" ~/.local/src/DefinitelyNotMai/dotfiles/config/gtk-2.0/gtkrc
sed -i "s/user/$(whoami)/" ~/.local/src/DefinitelyNotMai/dotfiles/config/gtk-3.0/bookmarks

# install packages I use
sudo pacman -S xorg-server xorg-xinit xorg-xev libnotify mpd mpv ncmpcpp htop \
    libreoffice-fresh dunst gimp lxappearance bc keepassxc pcmanfm scrot time \
    zathura zathura-pdf-mupdf zathura-cb obs-studio pulsemixer jdk-openjdk zsh \
    jre-openjdk jre-openjdk-headless xwallpaper p7zip unzip unrar rust go fzf \
    zsh-syntax-highlighting ttf-nerd-fonts-symbols-2048-em-mono highlight xclip \
    ffmpegthumbnailer odt2txt catdoc docx2txt perl-image-exiftool android-tools \
    python-pdftotext android-tools noto-fonts-emoji noto-fonts-cjk firefox cmake \
    alacritty newsboat wmname ueberzug npm ripgrep tree neofetch openssh \
    ttc-iosevka-slab lua-language-server pyright deno rust-analyzer gopls \
    autopep8 qemu-base libvirt virt-manager edk2-ovmf dnsmasq iptables-nft \
    dmidecode libxpresent spice-protocol dkms qemu-audio-jack asciiquarium \
    power-profiles-daemon yt-dlp sxhkd 

# install packer.nvim, a plugin manager for neovim written in Lua
git clone --depth 1 https://github.com/wbthomason/packer.nvim\
 ~/.local/share/nvim/site/pack/packer/start/packer.nvim

# install AUR helper and AUR packages I use
git clone https://aur.archlinux.org/paru.git ~/.local/src/paru
cd ~/.local/src/paru || exit
makepkg -si
sudo sed -i "s/#BottomUp/BottomUp/" /etc/paru.conf
paru brave-bin
paru freetube-bin
paru nsxiv-git
paru lf-git
paru otpclient
paru stylua
sudo sed -i "/\[bin\]/,/FileManager = vifm/"'s/^#//' /etc/paru.conf
sudo sed -i 's/vifm/lfrun/' /etc/paru.conf

# install my suckless tools
cd ~/.local/src/DefinitelyNotMai/ || exit
git clone https://github.com/DefinitelyNotMai/dmenu.git
git clone https://github.com/DefinitelyNotMai/dwm.git
git clone https://github.com/DefinitelyNotMai/scroll.git
git clone https://github.com/DefinitelyNotMai/slock.git
git clone https://github.com/DefinitelyNotMai/slstatus.git
git clone https://github.com/DefinitelyNotMai/st.git
cd dmenu && sudo make clean install
cd ../dwm && sudo make clean install
cd ../scroll && sudo make clean install
cd ../slock && sed -i "s/= \"user\"/= \"$(whoami)\"/" config.h && sudo make clean install
cd ../slstatus && sudo make clean install
cd ../st && sudo make clean install

# enable services
sudo systemctl enable power-profiles-daemon
sudo systemctl enable libvirtd

# add user to groups
sudo usermod -aG libvirt,kvm $(whoami)

# change shell to zsh
chsh -s /usr/bin/zsh

# echo out an npm installation script for neovim config to be ran after restart
printf "#!/bin/sh\n\nnpm i -g typescript typescript-language-server vscode-langservers-extracted vls @tailwindcss/language-server yaml-language-server emmet-ls neovim graphql-language-service-cli @astrojs/language-server prettier" > ~/final.sh

# done
clear
printf "Post installation done! Run \"systemctl reboot\" and after logging in, run \"./final.sh\". :)\n"
