#!/bin/sh

# ============================ #
# ===== PRE INSTALLATION ===== #
# ============================ #

# formatting
error() {
    printf "[\033[1;31mERROR\033[0m] %s" "$1"
}

newline() {
    printf "\n"
}

prompt() {
    printf "[\033[1;34mPROMPT\033[0m] %s" "$1"
}

success() {
    printf "[\033[1;32mSUCCESS\033[0m] %s\n" "$1"
}

# get hostname
prompt "Enter desired hostname: "
read -r hsn
while ! printf "%s" "$hsn" | grep -q "^[a-z][a-z0-9-]*$"; do
    error "Invalid hostname. Try again."
    newline
    prompt "Enter desired hostname: "
    read -r hsn
done
success "Hostname will be set to: $hsn"

# get root password
stty -echo
prompt "Enter password for root: "
read -r rpass1
newline
prompt "Re-enter password: "
read -r rpass2
while [ "$rpass1" != "$rpass2" ]; do
    newline
    error "Passwords don't match. Try again."
    newline
    prompt "Enter password for root: "
    read -r rpass1
    newline
    prompt "Re-enter password: "
    read -r rpass2
done
stty echo
newline
success "Root password has been set successfully."

# get username
prompt "Enter desired username: "
read -r usn
while ! printf "%s" "$usn" | grep -q "^[a-z_][a-z0-9_-]*$"; do
    error "Invalid username. Try again."
    newline
    prompt "Enter desired username: "
    read -r usn
done
success "Username will be set to: $usn"

# get user password
stty -echo
prompt "Enter password for $usn: "
read -r upass1
newline
prompt "Re-enter password: "
read -r upass2
while [ "$upass1" != "$upass2" ]; do
    newline
    error "Passwords don't match. Try again."
    newline
    prompt "Enter password for $usn: "
    read -r upass1
    newline
    prompt "Re-enter password: "
    read -r upass2
done
stty echo
newline
success "User password has been set successfully."
sleep 3

# get drive to format
clear
while true; do
    lsblk
    prompt "Enter drive to format (Ex. \"sda\" OR \"nvme0n1\"): "
    read -r dr
    if lsblk | grep -qw "$dr"; then
        success "Drive /dev/$dr exists."
        case "$dr" in
            *nvme*) bp=/dev/"$dr"p1 && rp=/dev/"$dr"p2 ;;
            *) bp=/dev/"$dr"1 && rp=/dev/"$dr"2 ;;
        esac
        break
    else
        clear
        error "Drive /dev/$dr doesn't exist. Please enter a valid drive."
        newline
    fi
done

# ask if user wants to enable ParallelDownloads and if so, how many?
while true; do
    prompt "Do you want to enable ParallelDownloads for pacman?(y/n): "
    read -r ans
    case "$ans" in
        [yY]) prompt "Enter desired number for ParallelDownloads: "
            read -r num
            [ "$num" -eq "$num" ] 2>/dev/null || { error "Invalid input. Please enter a valid integer."; newline; continue; }
            sed -i "s/^#ParallelDownloads = 5$/ParallelDownloads = $num/" /etc/pacman.conf
            success "ParallelDownloads has been enabled with $num downloads."
            break ;;
        [nN]) success "ParallelDownloads will not be enabled."
            break ;;
        *) error "Invalid input. Please enter \"y\" or \"n\""
            newline ;;
    esac
done

# update mirrorlist
printf "\nUpdating mirrorlist with reflector. Please wait...\n"
reflector --latest 10 --sort rate --save /etc/pacman.d/mirrorlist --protocol https --download-timeout 20

# sync mirrors and install keyring
pacman -Sy --noconfirm archlinux-keyring

# format disk
sgdisk -Z /dev/"$dr"
sgdisk -a 2048 -o /dev/"$dr"

# create partitions
sgdisk -n 1::300M --typecode=1:ef00 /dev/"$dr"
sgdisk -n 2::-0 --typecode=2:8300 /dev/"$dr"

# encrypt and format root partition, and format boot partition
cryptsetup -y -v luksFormat "$rp"
cryptsetup open "$rp" crypt-root
mkfs.ext4 /dev/mapper/crypt-root
mkfs.vfat "$bp"

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

# run partprobe to reload partition table, then generate fstab file
partprobe /dev/"$dr"
genfstab -U /mnt >> /mnt/etc/fstab

# copy current mirrorlist and pacman.conf to mounted root
cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist
cp /etc/pacman.conf /mnt/etc/pacman.conf

# add variables
{
    printf "hsn=%s\n" "$hsn"
    printf "rpass=%s\n" "$rpass1"
    printf "usn=%s\n" "$usn"
    printf "upass=%s\n" "$upass1"
    printf "microcode=%s\n" "$microcode"
    printf "enc_dr_uuid="
    blkid -s UUID -o value "$rp"
} > vars

# copy vars to source for variables to be used in Base Installation
cp vars /mnt/vars

# copy base install and post install script to /mnt and make it "base.sh" executable
cp base.sh /mnt/base.sh
cp post.sh /mnt/post.sh
chmod +x /mnt/base.sh

# pre-installation done
clear
printf "Pre-installation done! Performing Base installation now...\n"
sleep 3
arch-chroot /mnt ./base.sh
exit
