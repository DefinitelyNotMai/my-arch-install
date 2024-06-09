#!/bin/sh

# enable ufw
sudo ufw enable

# make directories
mkdir -p "$HOME"/documents "$HOME"/downloads "$HOME"/music "$HOME"/videos \
	"$HOME"/pictures/screenshots "$HOME"/projects "$HOME"/.config "$HOME"/.local/bin \
	"$HOME"/.local/share/cargo "$HOME"/.local/share/go "$HOME"/.local/share/rustup \
	"$HOME"/.local/share/shell-history

# make mount directories
sudo mkdir /mnt/usb
sudo chown "$(whoami)":"$(whoami)" && sudo chmod 750 /mnt/usb

# clone and symlink my dotfiles
git clone https://github.com/DefinitelyNotMai/dotfiles "$HOME"/.local/src/DefinitelyNotMai/dotfiles
dirs="alacritty dunst foot git gtk-2.0 gtk-3.0 hypr imv lf mpd mpv ncmpcpp newsboat npm nvim nwg-look qt5ct qt6ct shell swaylock tmux tofi transmission-daemon VSCodium waybar wget xsettingsd zathura brave-flags.conf mimeapps.list user-dirs.dirs"
for dir in $dirs; do
	ln -sf "$HOME"/.local/src/DefinitelyNotMai/dotfiles/config/"$dir" "$HOME"/.config/"$dir"
done
ln -sf "$HOME"/.config/shell/profile "$HOME"/.profile
ln -sf "$HOME"/.config/shell/mksh/.mkshrc "$HOME"/.mkshrc
ln -sf "$HOME"/.local/src/DefinitelyNotMai/dotfiles/local/share/applications "$HOME"/.local/share/applications
scpt="bookmark diceroll tofi-pass tofi-sys tordone transadd"
for scp in $scpt; do
	ln -sf "$HOME"/.local/src/DefinitelyNotMai/dotfiles/local/bin/"$scp" "$HOME"/.local/bin/"$scp"
done

# variables
export BUN_INSTALL="$HOME"/.local/share/bun
export CARGO_HOME="$HOME"/.local/share/cargo
export GOPATH="$HOME"/.local/share/go
export NPM_CONFIG_USERCONFIG="$HOME"/.config/npm/npmrc
export PNPM_HOME="$HOME"/.local/share/pnpm
export RUSTUP_HOME="$HOME"/.local/share/rustup
export LESSHISTFILE="-"

# readjust some config files with current username
sed -i "s/user/$(whoami)/" "$HOME"/.local/src/DefinitelyNotMai/dotfiles/config/gtk-2.0/gtkrc
sed -i "s/user/$(whoami)/" "$HOME"/.local/src/DefinitelyNotMai/dotfiles/config/gtk-3.0/bookmarks
sed -i "s/user/$(whoami)/" "$HOME"/.local/src/DefinitelyNotMai/dotfiles/config/transmission-daemon/settings.json

# install packages
eval sudo pacman -S wayland-protocols swaylock grim slurp foot wl-clipboard \
	imv xdg-desktop-portal-gtk xdg-desktop-portal-hyprland hyprland waybar chafa libnotify \
	dunst pacman-contrib dkms cmake openssh rustup go lf jdk-openjdk jre-openjdk nwg-look \
	jre-openjdk-headless tmux time tree bc p7zip unzip zip unrar transmission-cli nodejs npm \
	glow ripgrep fd android-tools yt-dlp mpd mpv ncmpcpp htop newsboat zathura zathura-pdf-mupdf \
	zathura-cb alacritty libreoffice-fresh obs-studio firefox keepassxc qt5-wayland qt5ct \
	qt6-wayland qt6ct brightnessctl ttf-nerd-fonts-symbols-mono ttf-dejavu ttf-liberation \
	wqy-zenhei noto-fonts-emoji qemu-base qemu-audio-jack libvirt virt-manager edk2-ovmf \
	dnsmasq iptables-nft dmidecode spice-protocol power-profiles-daemon ninja curl

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

# install neovim
git clone --depth=1 https://github.com/neovim/neovim "$HOME"/.local/src/neovim/neovim
cd "$HOME"/.local/src/neovim/neovim || exit
make CMAKE_BUILD_TYPE=Release
sudo make install

# install rustup, sccache, and pfetch
rustup default nightly
cargo install sccache
export RUSTC_WRAPPER="$CARGO_HOME"/bin/sccache
cargo install pfetch

# install paru
git clone https://aur.archlinux.org/paru-git "$HOME"/.local/src/morganamilo/paru-git
cd "$HOME"/.local/src/morganamilo/paru-git || exit
makepkg -si

# install aur packages
eval paru -S hyprpicker-git brave-bin mullvad-browser-bin freetube-bin \
	catppuccin-gtk-theme-mocha otpclient tremc-git tofi-git zramd mksh
paru -Rns xdg-desktop-portal-gtk

# change some paru settings
sudo sed -i "s/#BottomUp/BottomUp/" /etc/paru.conf
sudo sed -i "/\[bin\]/,/FileManager = vifm/"'s/^#//' /etc/paru.conf
sudo sed -i 's/vifm/lf/' /etc/paru.conf

# enable services
sudo systemctl enable power-profiles-daemon
sudo systemctl enable --now zramd.service

# disable copy-on-write for /var/lib/libvirt/images
sudo chattr +C /var/lib/libvirt/images/

# add user to groups
sudo usermod -aG libvirt,kvm,input "$(whoami)"

# change shell to zsh
chsh -s /usr/bin/mksh

# done
clear
printf "Post installation done! Run \"systemctl reboot\" :)\n"
