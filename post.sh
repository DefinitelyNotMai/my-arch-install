#!/bin/sh

# ============================== #
# =====  POST INSTALLATION ===== #
# ============================== #

# enable ufw
sudo ufw enable

# making directories
mkdir -p ~/documents ~/downloads ~/music ~/videos ~/pictures/screenshots ~/projects \
    ~/.config ~/.local/bin ~/.local/share/cargo ~/.local/share/go ~/.local/share/rustup \
    ~/.local/share/wallpapers ~/.local/share/zsh_history

# make mount directories. I personally separate mount dirs for my flashdrive and hdd
sudo mkdir /mnt/usb /mnt/hdd
sudo chown "$(whoami)": /mnt/usb && sudo chmod 750 /mnt/usb
sudo chown "$(whoami)": /mnt/hdd && sudo chmod 750 /mnt/hdd

# wget and set wallpaper
wget https://wallpaperaccess.com/full/419326.jpg -O ~/.local/share/wallpapers/statue.jpg
ln -s ~/.local/share/wallpapers/statue.jpg ~/.local/share/bg

# clone and symlink my dotfiles
git clone https://github.com/DefinitelyNotMai/dotfiles ~/.local/src/DefinitelyNotMai/dotfiles
dirs="alacritty dunst foot gtk-2.0 gtk-3.0 hypr lf mpd mpv ncmpcpp neofetch newsboat npm nvim qt5ct shell swaylock tmux tofi transmission-daemon waybar zathura zsh electron-flags.conf mimeapps.list user-dirs.dirs wgetrc"
for dir in $dirs; do
    ln -sf ~/.local/src/DefinitelyNotMai/dotfiles/config/"$dir" ~/.config/"$dir"
done
ln -sf ~/.config/shell/profile ~/.zprofile
ln -sf ~/.local/src/DefinitelyNotMai/dotfiles/local/share/applications ~/.local/applications
scpt="lfrun sauce setbg tofi-pass tofi-sys tordone transadd vimv"
for scp in $scpt; do
    ln -sf ~/.local/src/DefinitelyNotMai/dotfiles/local/bin/"$scp" ~/.local/bin/"$scp"
done

# exports
export CARGO_HOME="$HOME/.local/share/cargo"
export RUSTUP_HOME="$HOME/.local/share/rustup"
export GOPATH="$HOME/.local/share/go"
export LESSHISTFILE="-"

# rename a directory and readjust some config files to line up with username
sed -i "s/user/$(whoami)/" ~/.local/src/DefinitelyNotMai/dotfiles/config/gtk-2.0/gtkrc
sed -i "s/user/$(whoami)/" ~/.local/src/DefinitelyNotMai/dotfiles/config/gtk-3.0/bookmarks
sed -i "s/user/$(whoami)/" ~/.local/src/DefinitelyNotMai/dotfiles/config/transmission-daemon/settings.json

# install packages I use
eval sudo pacman -S wayland-protocols swaybg swaylock grim slurp foot wl-clipboard \
    imv xdg-desktop-portal-gtk xdg-desktop-portal-hyprland hyprland chafa libnotify \
    dunst pacman-contrib dkms cmake openssh rustup go jdk-openjdk jre-openjdk \
    jre-openjdk-headless zsh zsh-syntax-highlighting tmux time tree bc p7zip unzip \
    zip unrar transmission-cli glow odt2txt catdoc docx2txt perl-image-exiftool \
    ffmpegthumbnailer imagemagick ripgrep android-tools yt-dlp mpd mpv ncmpcpp htop \
    neofetch newsboat asciiquarium zathura zathura-pdf-mupdf zathura-cb alacritty \
    libreoffice-fresh keepassxc obs-studio firefox qt5-wayland qt5ct brightnessctl \
    ttf-nerd-fonts-symbols-mono ttf-dejavu ttf-liberation otf-comicshanns-nerd \
    wqy-zenhei qemu-base qemu-audio-jack libvirt virt-manager edk2-ovmf dnsmasq \
    iptables-nft dmidecode spice-protocol power-profiles-daemon pass

# create a hook that cleans up pacman's package cache after every package install, uninstall, or update. Keeps current and last cache.
sudo sh -c '{
    printf "[Trigger]\n"
    printf "Operation = Remove\n"
    printf "Operation = Install\n"
    printf "Operation = Upgrade\n"
    printf "Type = Package\n"
    printf "Target = *\n\n"
    printf "[Action]\n"
    printf "Description = Keep the last cache and currently installed.\n"
    printf "When = PostTransaction\n"
    printf "Exec = /usr/bin/paccache -rvk2\n"
} > /usr/share/libalpm/hooks/pacman-cache-cleanup.hook'

# install paru, an AUR helper and AUR packages I use
rustup default stable
git clone https://aur.archlinux.org/paru-git ~/.local/src/morganamilo/paru-git
cd ~/.local/src/morganamilo/paru-git || exit
makepkg -si

# install AUR packages I use
eval paru -S hyprpicker-git nwg-look-bin lf-sixel-git brave-bin mullvad-browser-bin freetube-bin \
    catppuccin-gtk-theme-mocha otpclient tremc-git tofi-git neovim-git zramd waybar-hyprland-git nvm
paru -Rns xdg-desktop-portal-gtk

# change some paru settings
sudo sed -i "s/#BottomUp/BottomUp/" /etc/paru.conf
sudo sed -i "/\[bin\]/,/FileManager = vifm/"'s/^#//' /etc/paru.conf
sudo sed -i 's/vifm/lfrun/' /etc/paru.conf

# enable services
sudo systemctl enable power-profiles-daemon
sudo systemctl enable --now zramd.service

# disable copy-on-write for /var/lib/libvirt/images
sudo chattr +C /var/lib/libvirt/images/

# add user to groups
sudo usermod -aG libvirt,kvm,input "$(whoami)"

# change shell to zsh
chsh -s /usr/bin/zsh

# done
clear
printf "Post installation done! Run \"systemctl reboot\" and after logging in, open a terminal and run \"npm install -g typescript\" for the neovim config to fully work :)\n"
