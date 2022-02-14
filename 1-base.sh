#!/bin/sh

# set ParallellDownloads to 15 and enable multilib repositories
sed -i 's/^#ParallelDownloads = 5/ParallelDownloads = 15/' /etc/pacman.conf
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf

# use all cores for compilation and compression
sed -i "s/-j2/-j$(nproc)/;s/^#MAKEFLAGS/MAKEFLAGS/" /etc/makepkg.conf
sed -i "s/COMPRESSXZ=(xz -c -z -)/COMPRESSXZ=(xz -c -T $(nproc) -z -)/g" /etc/makepkg.conf

# make a 10GB swapfile and set swappiness to 1
dd if=/dev/zero of=/etc/swapfile bs=1M count=10240 status=progress
chmod 600 /etc/swapfile
mkswap /etc/swapfile
swapon /etc/swapfile
printf "/etc/swapfile none swap defaults 0 0" >> /etc/fstab
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
pacman -Sy --noconfirm grub efibootmgr networkmanager mtools dosfstools ntfs-3g \
    ufw dash pipewire pipewire-alsa pipewire-pulse pipewire-jack linux-headers \
    reflector git wget neovim man-db polkit

# relink dash to /bin/sh and create hook to relink dash to /bin/sh everytime bash gets updated
ln -sfT dash /usr/bin/sh
printf "[Trigger]\nType = Package\nOperation = Install\nOperation = Upgrade\nTarget = bash\n\n[Action]\nDescription = Re-pointing /bin/sh symlink to dash...\nWhen = PostTransaction\nExec = /usr/bin/ln -sfT dash /usr/bin/sh\nDepends = dash" > /usr/share/libalpm/hooks/binsh2dash.hook

# install grub
sed -i 's/GRUB_TIMEOUT=5/GRUB_TIMEOUT=-1/' /etc/default/grub
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=arch
grub-mkconfig -o /boot/grub/grub.cfg

# enable services
systemctl enable NetworkManager
systemctl enable fstrim.timer
systemctl enable reflector.timer
systemctl enable ufw.service

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
    y|Y) mkdir -p /home/"$usn"/files/repos
        mv /my-arch-install /home/"$usn"/files/repos/my-arch-install
        chown -R "$usn":"$usn" /home/"$usn"/files
        printf "You answered Yes. Run \"cd ~/files/repos/my-arch-install && ./2-postinstall.sh\" after rebooting." ;;
    n|N) printf "You answered No." ;;
    *) printf "Answered neither. Assuming your answer is No." ;;
esac

# done
printf "\nBase installation done! Run \"exit\", then \"umount -a\", and \"reboot now\" :)\n"
