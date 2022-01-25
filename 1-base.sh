#!/bin/sh

# ParallelDownloads = 15 and enable multilib in pacman.conf
sed -i 's/^#ParallelDownloads = 5$/ParallelDownloads = 15/' /etc/pacman.conf
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf

# Use all cores for compilation and compression
sed -i "s/-j2/-j$(nproc)/;s/^#MAKEFLAGS/MAKEFLAGS/" /etc/makepkg.conf
sed -i "s/COMPRESSXZ=(xz -c -z -)/COMPRESSXZ=(xz -c -T $(nproc) -z -)/g" /etc/makepkg.conf

# Make a 2GB swapfile and set swappiness to 1
dd if=/dev/zero of=/etc/swapfile bs=1M count=2048 status=progress
chmod 600 /etc/swapfile
mkswap /etc/swapfile
swapon /etc/swapfile
echo "/etc/swapfile none swap defaults 0 0" >> /etc/fstab
echo "vm.swappiness=1" >> /etc/sysctl.d/99-swappiness.conf

# Locale, Host, Root password
ln -sf /usr/share/zoneinfo/Asia/Singapore /etc/localtime
hwclock --systohc
sed -i '177s/.//' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" >> /etc/locale.conf
read -p "Enter desired hostname: " hsn
echo "$hsn" >> /etc/hostname
{
    echo "127.0.0.1    localhost"
    echo "::1          localhost"
    echo "127.0.1.1    $hsn.localdomain    $hsn"
} >> /etc/hosts
echo "Enter new password for root"
passwd

# Install some packages
pacman -Sy grub efibootmgr networkmanager mtools dosfstools ntfs-3g ufw dash \
    pipewire pipewire-pulse pipewire-jack neovim wget man-db

# Relink dash to /bin/sh
ln -sfT dash /usr/bin/sh
printf "[Trigger]\nType = Package\nOperation = Install\nOperation = Upgrade\nTarget = bash\n\n[Action]\nDescription = Re-pointing /bin/sh symlink to dash...\nWhen = PostTransaction\nExec = /usr/bin/ln -sfT dash /usr/bin/sh\nDepends = dash" > /usr/share/libalpm/hooks/binsh2dash.hook

# Install grub
sed -i '4s/5/-1/' /etc/default/grub
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=arch
grub-mkconfig -o /boot/grub/grub.cfg

# Enable services
systemctl enable NetworkManager
systemctl enable fstrim.timer
systemctl enable ufw.service

# Add user
read -p "Enter desired username: " usn
useradd -m -G wheel "$usn"
echo "Enter password for $usn"
passwd "$usn"
sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers

# Done
echo "All done. You can now exit, unmount, and reboot :)"
