#!/bin/sh

# Enable ufw
sudo ufw enable

# Making directories at home
mkdir ~/.config
mkdir -p ~/.local/src ~/.local/share
cd ~/.local/share && mkdir cargo go virtualbox wallpapers 
cd ~/files && mkdir android code documents downloads games

# Make mount directories, mount flashdrive and copy files
cd /mnt && sudo mkdir sanicfast slowboi usb
sudo chown mai: sanicfast slowboi usb
sudo chmod 750 sanicfast slowboi usb
sudo mount /dev/sdc1 /mnt/usb
sudo cp /mnt/usb/.a/navi /etc/navi
cp /mnt/usb/yes-man.jpg ~/.local/share/wallpapers/yes-man.jpg
ln -s ~/.local/share/wallpapers/yes-man.jpg ~/.local/share/bg
sudo umount /mnt/usb

# Exports
export CARGO_HOME="$HOME/.local/share/cargo"
export GOPATH="$HOME/.local/share/go"
export LESSHISTFILE="-"

# Clone and symlink dotfiles
git clone https://github.com/DefinitelyNotMai/dotfiles ~/files/repos/dotfiles
ln -s ~/files/repos/dotfiles/config/dunst ~/.config/dunst
ln -s ~/files/repos/dotfiles/config/gtk-2.0 ~/.config/gtk-2.0
ln -s ~/files/repos/dotfiles/config/gtk-3.0 ~/.config/gtk-3.0
ln -s ~/files/repos/dotfiles/config/lf ~/.config/lf
ln -s ~/files/repos/dotfiles/config/mpd ~/.config/mpd
ln -s ~/files/repos/dotfiles/config/mpv ~/.config/mpv
ln -s ~/files/repos/dotfiles/config/ncmpcpp ~/.config/ncmpcpp
ln -s ~/files/repos/dotfiles/config/newsboat ~/.config/newsboat
ln -s ~/files/repos/dotfiles/config/nvim ~/.config/nvim
ln -s ~/files/repos/dotfiles/config/shell ~/.config/shell
ln -s ~/files/repos/dotfiles/config/x11 ~/.config/x11
ln -s ~/files/repos/dotfiles/config/zathura ~/.config/zathura
ln -s ~/files/repos/dotfiles/config/zsh ~/.config/zsh
ln -s ~/files/repos/dotfiles/local/bin ~/.local/bin
ln -s ~/.config/shell/profile ~/.zprofile

# Install vim-plug
sh -c 'curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'

# Install my needed packages
sudo pacman -Sy xorg-server xorg-xinit wmname libnotify mpd mpv \
    ncmpcpp unclutter sxiv libreoffice-fresh dunst gimp lxappearance htop bc \
    keepassxc pcmanfm zathura zathura-pdf-mupdf newsboat scrot obs-studio \
    pulsemixer jdk-openjdk jre-openjdk jre-openjdk-headless xwallpaper p7zip \
    unzip unrar rust go ttf-liberation ttf-nerd-fonts-symbols ueberzug zsh \
    zsh-syntax-highlighting fzf youtube-dl ffmpegthumbnailer highlight odt2txt \
    catdoc docx2txt perl-image-exiftool python-pdftotext android-tools \
    noto-fonts-emoji adobe-source-han-sans-jp-fonts arc-icon-theme \
    adobe-source-han-sans-kr-fonts adobe-source-han-sans-cn-fonts virtualbox \
    virtualbox-host-modules-arch virtualbox-guest-iso tor torbrowser-launcher

# Install AUR helper and AUR packages
git clone https://aur.archlinux.org/paru.git ~/.local/src/paru
cd ~/.local/src/paru || exit
makepkg -si
sudo sed -i '17s/.//' /etc/paru.conf
paru brave-bin
paru freetube-bin
paru gtk-theme-arc-gruvbox-git
paru lf-git
paru otpclient
paru simple-mtpfs
paru ttf-scientifica
sudo sed -i '35s/.//' /etc/paru.conf
sudo sed -i '36s/.*/FileManager = lfrun/' /etc/paru.conf

# Install my suckless tools
cd ~/files/repos || exit
git clone https://github.com/DefinitelyNotMai/dmenu.git
git clone https://github.com/DefinitelyNotMai/dwm.git
git clone https://github.com/DefinitelyNotMai/scroll.git
git clone https://github.com/DefinitelyNotMai/slock.git
git clone https://github.com/DefinitelyNotMai/slstatus.git
git clone https://github.com/DefinitelyNotMai/st.git
cd dmenu && sudo make install
cd ../dwm && sudo make install
cd ../scroll && sudo make install
cd ../slock && sudo make install
cd ../slstatus && sudo make install
cd ../st && sudo make install

# Automount my drives
echo "crypt-hdd /dev/sda1 /etc/navi" | sudo tee -a /etc/crypttab
echo "/dev/mapper/crypt-hdd /mnt/slowboi ext4 defaults 0 0" | sudo tee -a /etc/fstab

# Remove orphan packages
sudo pacman -Rns $(pacman -Qtdq)

# Change my shell to zsh
chsh -s /usr/bin/zsh

# Done
echo "Done."
