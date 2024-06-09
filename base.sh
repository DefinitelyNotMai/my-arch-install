#!/bin/sh

# formatting
error() {
	printf "[\033[1;31mERROR\033[0m] %s\n" "$1"
}

input() {
	printf "[\033[1;34mINPUT\033[0m] %s" "$1"
}

success() {
	printf "[\033[1;32mSUCCESS\033[0m] %s\n" "$1"
}

# source vars file
. /vars

# makepkg optimizations
sed -i "s/-march=x86-64 -mtune=generic/-march=native -mtune=native" /etc/makepkg.conf
sed -i "s/-j2/-j$(nproc)/;s/^#MAKEFLAGS/MAKEFLAGS/" /etc/makepkg.conf
sed -i "s/^#BUILDDIR/BUILDDIR/" /etc/makepkg.conf
sed -i "s/^COMPRESSGZ=(gzip -c -f -n)/COMPRESSGZ=(pigz -c -f -n)/" /etc/makepkg.conf
sed -i "s/^COMPRESSBZ2=(bzip2 -c -f)/COMPRESSBZ2=(pbzip2 -c -f)/" /etc/makepkg.conf
sed -i "s/^COMPRESSXZ=(xz -c -z -)/COMPRESSXZ=(xz -c -z --threads=0 -)" /etc/makepkg.conf

# set swappiness to 1
printf "vm.swappiness=1\n" >> /etc/sysctl.d/99-swappiness.conf

# set locale, hostname and hosts, and set root password
ln -sf /usr/share/zoneinfo/Asia/Singapore /etc/localtime
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
printf "root:%s" "$rpass" | chpasswd

# install some packages
pacman -S --noconfirm networkmanager ntfs-3g ufw dash git wget man-db pipewire \
	pipewire-alsa pipewire-pulse pipewire-jack wireplumber linux-headers \
	reflector polkit

# modify hooks and modules for mkinitcpio
sed -i "s/HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block filesystems fsck)/HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block encrypt filesystems fsck)" /etc/mkinitcpio.conf
sed -i "s/MODULES=()/MODULES=(btrfs)/" /etc/mkinitcpio.conf
# uncomment if you want to load modules for hijacking the graphics card for GPU passthrough
#sed -i "s/MODULES=(btrfs)/MODULES=(btrfs vfio_pci vfio vfio_iommu_type1)/" /etc/mkinitcpio.conf
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
	printf "options cryptdevice=UUID=%s:crypt-root root=UUID=%s zswap.enabled=0 rootflags=subvol=@ rw rootfstype=btrfs\n" "$root_uuid" "$crypt_uuid"
} > /boot/loader/entries/arch.conf
{
	printf "title Arch Linux (fallback initramfs)\n"
	printf "linux /vmlinuz-linux\n"
	printf "initrd /%s.img\n" "$microcode"
	printf "initrd /initramfs-linux-fallback.img\n"
	printf "options cryptdevice=UUID=%s:crypt-root root=UUID=%s zswap.enabled=0 rootflags=subvol=@ rw rootfstype=btrfs\n" "$root_uuid" "$crypt_uuid"
} > /boot/loader/entries/arch-fallback.conf

# look for NVidia Card and output it to /tmp for reference to be used in setting kernel parameter for hijacking. Uncomment if planning to do NVidia GPU passthrough
#lspci -nnk | grep NVIDIA >> /tmp/blkid.txt
#nvim /boot/loader/entries/arch.conf
# amd_iommu=on iommu=pt vfio-pci.ids=<1>,<2>

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
printf "%s:%s" "$usn" "$upass" | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# ask if user wants to use my personal post-install script
while true; do
	input "Would you like to use my personal post-install script after restarting? [y/n] " && read -r ans
	case "$ans" in
		[yY]) cp /post.sh /home/"$usn"/post.sh
			chown "$usn":"$usn" /home/"$usn"/post.sh
			chmod +x /home/"$usn"/post.sh
			success "You answered Yes. Script has been copied to /home/$usn/post.sh\nRun \"./post.sh\" after rebooting."
			break ;;
		[nN]) success "You answered no. Goodluck with the rest of your installation :)"
			break ;;
		*) error "Invalid input. Please enter \"y\" or \"n\"."
			break ;;
	esac
done
success "Base Installation done! Run \"umount -a\", and \"reboot now\" :)\n"
shred -uz /base.sh /post.sh /vars
exit
