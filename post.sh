#!/bin/sh

# ==================================== #
# =====  POST INSTALLATION START ===== #
# ==================================== #

# enable ufw
sudo ufw enable

# making directories
mkdir -p ~/documents ~/downloads ~/music ~/videos ~/pictures/screenshots ~/projects \
    ~/.config ~/.local/bin ~/.local/share/cargo ~/.local/share/go ~/.local/share/wallpapers \
    ~/.local/share/zsh_history

# exports
export CARGO_HOME="$HOME/.local/share/cargo"
export GOPATH="$HOME/.local/share/go"
export LESSHISTFILE="-"

# make mount directories. I personally separate mount dirs for my flashdrive and hdd
sudo mkdir /mnt/usb /mnt/hdd
sudo chown "$(whoami)": /mnt/usb && sudo chmod 750 /mnt/usb
sudo chown "$(whoami)": /mnt/hdd && sudo chmod 750 /mnt/hdd

# wget and set wallpaper
wget https://wallpapercave.com/wp/wp11979310.jpg -O pixel.jpg
ln -s ~/.local/share/wallpapers/pixel.jpg ~/.local/share/bg

# clone and symlink my dotfiles
git clone https://github.com/DefinitelyNotMai/dotfiles ~/.local/src/DefinitelyNotMai/dotfiles
dirs="alacritty dunst foot gtk-2.0 gtk-3.0 hypr lf mpd mpv ncmpcpp neofetch newsboat npm nvim shell swaylock tofi transmission-daemon waybar zathura zsh mimeapps.list user-dirs.dirs wgetrc"
for dir in $dirs; do
    ln -sf ~/.local/src/DefinitelyNotMai/dotfiles/config/"$dir" ~/.config/"$dir"
done
ln -sf ~/.config/shell/profile ~/.zprofile
ln -sf ~/.local/src/DefinitelyNotMai/dotfiles/local/share/applications ~/.local/applications
scpt="lfrun sauce tofi-sys tordone transadd vimv"
for scp in $scpt; do
    ln -sf ~/.local/src/DefinitelyNotMai/dotfiles/local/bin/"$scp" ~/.local/bin/"$scp"
done
sudo cp ~/.local/src/DefinitelyNotMai/dotfiles/local/bin/bctl /usr/local/bin/bctl

# rename a directory and readjust some config files to line up with username
sed -i "s/user/$(whoami)/" ~/.local/src/DefinitelyNotMai/dotfiles/config/gtk-2.0/gtkrc
sed -i "s/user/$(whoami)/" ~/.local/src/DefinitelyNotMai/dotfiles/config/gtk-3.0/bookmarks
sed -i "s/user/$(whoami)/" ~/.local/src/DefinitelyNotMai/dotfiles/config/transmission-daemon/settings.json

# install packages I use
eval sudo pacman -S wayland-protocols swaybg swaylock grim slurp foot wl-clipboard \
    imv hyprland chafa libnotify dunst pacman-contrib dkms cmake openssh rust go npm \
    jdk-openjdk jre-openjdk jre-openjdk-headless zsh zsh-syntax-highlighting fzf time \
    tree bc p7zip unzip zip unrar transmission-cli glow odt2txt catdoc docx2txt \
    perl-image-exiftool ffmpegthumbnailer imagemagick ripgrep android-tools yt-dlp \
    mpd mpv ncmpcpp htop neofetch newsboat asciiquarium zathura zathura-pdf-mupdf \
    zathura-cb alacritty libreoffice-fresh gimp keepassxc thunar obs-studio \
    firefox \
    papirus-icon-theme ttf-nerd-fonts-symbols-2048-em-mono noto-fonts-emoji noto-fonts-cjk \
    terminus-font qemu-base qemu-audio-jack libvirt virt-manager edk2-ovmf dnsmasq \
    iptables-nft dmidecode libxpresent spice-protocol power-profiles-daemon

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

# install packer.nvim, a plugin manager for neovim written in Lua
git clone --depth 1 https://github.com/wbthomason/packer.nvim\
 ~/.local/share/nvim/site/pack/packer/start/packer.nvim

# install paru, an AUR helper and AUR packages I use
git clone https://aur.archlinux.org/paru-git ~/.local/src/morganamilo/paru
cd ~/.local/src/morganamilo/paru || exit
makepkg -si

# install AUR packages I use
eval paru -S waybar-hyprland-git xdg-desktop-portal-hyprland-git hyprpicker-git \
    nwg-look-bin lf-sixel-git brave-bin freetube-bin ungoogled-chromium-bin \
    catppuccin-gtk-theme-mocha otpclient
paru -Rns xdg-desktop-portal-gtk

# change some paru settings
sudo sed -i "s/#BottomUp/BottomUp/" /etc/paru.conf
sudo sed -i "/\[bin\]/,/FileManager = vifm/"'s/^#//' /etc/paru.conf
sudo sed -i 's/vifm/lfrun/' /etc/paru.conf

# enable services
sudo systemctl enable power-profiles-daemon
sudo systemctl enable libvirtd

# add user to groups
sudo usermod -aG libvirt,kvm,input "$(whoami)"

# change shell to zsh
chsh -s /usr/bin/zsh

# echo out an npm installation script for neovim config to be ran after restart
printf "#!/bin/sh\n\nnpm i -g typescript typescript-language-server vscode-langservers-extracted @volar/vue-language-server @tailwindcss/language-server yaml-language-server emmet-ls neovim graphql-language-service-cli @astrojs/language-server prettier" > ~/final.sh

# done
clear
printf "Post installation done! Run \"systemctl reboot\" and after logging in, open a terminal and run \"./final.sh\". :)\n"
