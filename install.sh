#!/usr/bin/env -S bash -e

# Cleaning the TTY
clear

# Cosmetics (colours for text).
BOLD='\e[1m'
BRED='\e[91m'
BBLUE='\e[34m'
BGREEN='\e[92m'
BYELLOW='\e[93m'
RESET='\e[0m'

# Pretty print (function).
info_print() {
    echo -e "${BOLD}${BGREEN}[ ${BYELLOW}•${BGREEN} ] $1${RESET}"
}

# Pretty print for input (function).
input_print() {
    echo -ne "${BOLD}${BYELLOW}[ ${BGREEN}•${BYELLOW} ] $1${RESET}"
}

# Alert user of bad input (function).
error_print() {
    echo -e "${BOLD}${BRED}[ ${BBLUE}•${BRED} ] $1${RESET}"
}

# Virtualization check (function).
virt_check() {
    hypervisor=$(systemd-detect-virt)
    case $hypervisor in
    kvm)
        info_print "KVM has been detected, setting up guest tools."
        pacstrap /mnt qemu-guest-agent &>/dev/null
        systemctl enable qemu-guest-agent --root=/mnt &>/dev/null
        ;;
    vmware)
        info_print "VMWare Workstation/ESXi has been detected, setting up guest tools."
        pacstrap /mnt open-vm-tools >/dev/null
        systemctl enable vmtoolsd --root=/mnt &>/dev/null
        systemctl enable vmware-vmblock-fuse --root=/mnt &>/dev/null
        ;;
    oracle)
        info_print "VirtualBox has been detected, setting up guest tools."
        pacstrap /mnt virtualbox-guest-utils &>/dev/null
        systemctl enable vboxservice --root=/mnt &>/dev/null
        ;;
    microsoft)
        info_print "Hyper-V has been detected, setting up guest tools."
        pacstrap /mnt hyperv &>/dev/null
        systemctl enable hv_fcopy_daemon --root=/mnt &>/dev/null
        systemctl enable hv_kvp_daemon --root=/mnt &>/dev/null
        systemctl enable hv_vss_daemon --root=/mnt &>/dev/null
        ;;
    esac
}

# Setting up a password for the user account (function).
userpass_selector() {
    input_print "Please enter name for a user account (enter empty to not create one): "
    read -r username
    if [[ -z "$username" ]]; then
        return 0
    fi
    input_print "Please enter a password for $username (you're not going to see the password): "
    read -r -s userpass
    if [[ -z "$userpass" ]]; then
        echo
        error_print "You need to enter a password for $username, please try again."
        return 1
    fi
    echo
    input_print "Please enter the password again (you're not going to see it): "
    read -r -s userpass2
    echo
    if [[ "$userpass" != "$userpass2" ]]; then
        echo
        error_print "Passwords don't match, please try again."
        return 1
    fi
    return 0
}

# Setting up a password for the root account (function).
rootpass_selector() {
    input_print "Please enter a password for the root user (you're not going to see it): "
    read -r -s rootpass
    if [[ -z "$rootpass" ]]; then
        echo
        error_print "You need to enter a password for the root user, please try again."
        return 1
    fi
    echo
    input_print "Please enter the password again (you're not going to see it): "
    read -r -s rootpass2
    echo
    if [[ "$rootpass" != "$rootpass2" ]]; then
        error_print "Passwords don't match, please try again."
        return 1
    fi
    return 0
}

# Microcode detector (function).
microcode_detector() {
    CPU=$(grep vendor_id /proc/cpuinfo)
    if [[ "$CPU" == *"AuthenticAMD"* ]]; then
        info_print "An AMD CPU has been detected, the AMD microcode will be installed."
        microcode="amd-ucode"
    else
        info_print "An Intel CPU has been detected, the Intel microcode will be installed."
        microcode="intel-ucode"
    fi
}

# User enters a hostname (function).
hostname_selector() {
    input_print "Please enter the hostname: "
    read -r hostname
    if [[ -z "$hostname" ]]; then
        error_print "You need to enter a hostname in order to continue."
        return 1
    fi
    return 0
}

# User chooses the console keyboard layout (function).
keyboard_selector() {
    input_print "Please insert the keyboard layout to use in console (enter empty to use US, or \"/\" to look up for keyboard layouts): "
    read -r kblayout
    case "$kblayout" in
    '')
        kblayout="us"
        info_print "The standard US keyboard layout will be used."
        return 0
        ;;
    '/')
        localectl list-keymaps
        clear
        return 1
        ;;
    *)
        if ! localectl list-keymaps | grep -Fxq "$kblayout"; then
            error_print "The specified keymap doesn't exist."
            return 1
        fi
        info_print "Changing console layout to $kblayout."
        loadkeys "$kblayout"
        return 0
        ;;
    esac
}

# Checking the device type
dev_type=$(hostnamectl chassis)

# Welcome screen.
echo -ne "${BOLD}${BYELLOW}
==========================================================
   █████████   █████       █████   █████████    █████████ 
  ███░░░░░███ ░░███       ░░███   ███░░░░░███  ███░░░░░███
 ░███    ░███  ░███        ░███  ░███    ░███ ░███    ░░░ 
 ░███████████  ░███        ░███  ░███████████ ░░█████████ 
 ░███░░░░░███  ░███        ░███  ░███░░░░░███  ░░░░░░░░███
 ░███    ░███  ░███      █ ░███  ░███    ░███  ███    ░███
 █████   █████ ███████████ █████ █████   █████░░█████████ 
░░░░░   ░░░░░ ░░░░░░░░░░░ ░░░░░ ░░░░░   ░░░░░  ░░░░░░░░░  
==========================================================
${RESET}"
info_print "Welcome to ALIAS."

# Setting up keyboard layout.
until keyboard_selector; do :; done

# Choosing the target for the installation.
info_print "Available disks for the installation:"
PS3="Please select the number of the corresponding disk (e.g. 1): "
IFS=$'\n' read -rd '' -a aval_disks < <(lsblk -dpnoNAME | grep -P "/dev/sd|nvme|vd" && printf '\0')
select ENTRY in "${aval_disks[@]}"; do
    DISK="$ENTRY"
    info_print "Arch Linux will be installed on the following disk: $DISK"
    break
done

# User choses the hostname.
until hostname_selector; do :; done

# User sets up the user/root passwords.
until userpass_selector; do :; done
until rootpass_selector; do :; done

# Warn user about deletion of old partition scheme.
input_print "This will delete the current partition table on $DISK once installation starts. Do you agree [y/N]?: "
read -r disk_response
if ! [[ "${disk_response,,}" =~ ^(yes|y)$ ]]; then
    error_print "Quitting."
    exit
fi
info_print "Wiping $DISK."
wipefs -af "$DISK" &>/dev/null
sgdisk -Zo "$DISK" &>/dev/null

# Calculations for size of swap
ram_total=$(free -h | awk '/Mem:/{print $2}')
ram_total=${ram_total//[^0-9.0-9]/}
ram_total=$(printf "%1.f" "$ram_total")
sswap=$(echo "$sswap" | awk '{print sqrt($0)}')
sswap=$(printf "%1.f" "$sswap")
if [[ "$dev_type" == "laptop" ]]; then
    ((sswap += "$ram_total"))
fi

# Creating a new partition scheme.
info_print "Creating the partitions on $DISK."
sgdisk -n 0:0:+1GiB -t 0:ef00 -c 0:boot "$DISK"
sgdisk -n 0:0:+"${sswap}"GiB -t 0:8200 -c 0:swap "$DISK"
sgdisk -n 0:0:+32GiB -t 0:8304 -c 0:root "$DISK"
sgdisk -n 0:0:0 -t 0:8302 -c 0:home "$DISK"

pefi="/dev/disk/by-partlabel/boot"
pswap="/dev/disk/by-partlabel/swap"
proot="/dev/by-partlabel/root"
phome="/dev/by-partlabel/home"

# Informing the Kernel of the changes.
info_print "Informing the Kernel about the disk changes."
partprobe "$DISK"

# Formatting the EFI as FAT32.
info_print "Formatting the EFI Partition as FAT32."
mkfs.fat -F 32 "$pefi" &>/dev/null

# Swap
info_print "Making swap partition."
mkswap "$pswap" &>/dev/null

# Root and home
info_print "Making root partition."
mkfs.ext4 "$proot" &>/dev/null
info_print "Making home partition."
mkfs.ext4 "$phome" &>/dev/null

# Mounting the system
mount "$proot" /mnt
swapon "$pswap"
mount --mkdir "$pefi" /mnt/boot
mount --mkdir "$phome" /mnt/home

# Checking the microcode to install.
microcode_detector

main_pkgs=(atool base base-devel bash-completion bat eza fd linux linux-firmware linux-headers man-db man-pages texinfo openssh pacman-contrib ripgrep sudo rsync zoxide wget "$microcode" grub reflector efibootmgr exfatprogs lostfiles namcap)
apps=(xdg-user-dirs feh lf git htop hledger nano neovim npm perl-image-exiftool python-pip python-pipx python-pynvim trash-cli tree unzip unrar exiv2 odt2txt yt-dlp)
if [[ "$dev_type" == "laptop" ]]; then
    apps+=(upower acpi)
fi

# Pacstrap (setting up a base sytem onto the new root).
info_print "Installing the base system (it may take a while)."
pacstrap -K /mnt "${main_pkgs[@]}" "${apps[@]}" &>/dev/null

# Setting up the hostname.
echo "$hostname" >/mnt/etc/hostname

# Generating /etc/fstab.
info_print "Generating a new fstab."
genfstab -U /mnt >>/mnt/etc/fstab

# Configure selected locale and console keymap
sed -i "/^#en_US.UTF-8/s/^#//" /mnt/etc/locale.gen
sed -i "/^#es_MX.UTF-8/s/^#//" /mnt/etc/locale.gen
sed -i "/^#ja_JP.UTF-8/s/^#//" /mnt/etc/locale.gen
echo "LANG=en_US.UTF-8" >/mnt/etc/locale.conf
echo "KEYMAP=$kblayout" >/mnt/etc/vconsole.conf

# Virtualization check.
virt_check

# Setting up the network.
info_print "Installing and enabling NetworkManager with iwd backend."
pacstrap /mnt networkmanager iwd &>/dev/null
cat >/mnt/etc/NetworkManager/conf.d/wifi_backend.conf <<EOF
[device]
wifi.backend=iwd
EOF
systemctl enable NetworkManager --root=/mnt &>/dev/null

wifi_chip=$(lspci -v | grep -A1 -E "Network")
if [[ "$wifi_chip" == *"RTL8723BE"* ]]; then
    echo "options rtl8723be swenc=1 fwlps=0 ips=0" >/mnt/etc/modprobe.d/rtl8723be.conf
fi

# Configuring the system.
info_print "Configuring the system (timezone, locales, system clock, GRUB)."
arch-chroot /mnt /bin/bash -e <<EOF

    # Setting up timezone.
    ln -sf /usr/share/zoneinfo/$(curl -s http://ip-api.com/line?fields=timezone) /etc/localtime &>/dev/null

    # Setting up clock.
    hwclock --systohc

    # Generating locales.
    locale-gen &>/dev/null

    # Installing GRUB.
    grub-install --target=x86_64-efi --efi-directory=/boot/ --bootloader-id=GRUB &>/dev/null

    # Creating grub config file.
    grub-mkconfig -o /boot/grub/grub.cfg &>/dev/null

EOF

# Setting root password.
info_print "Setting root password."
echo "root:$rootpass" | arch-chroot /mnt chpasswd

# Setting user password.
if [[ -n "$username" ]]; then
    echo "%wheel ALL=(ALL:ALL) ALL" >/mnt/etc/sudoers.d/wheel
    info_print "Adding the user $username to the system with root privilege."
    arch-chroot /mnt useradd -m -G wheel -s /bin/bash "$username"
    info_print "Setting user password for $username."
    echo "$username:$userpass" | arch-chroot /mnt chpasswd
fi

# Pacman eye-candy features.
info_print "Enabling colors, multilib, animations, and parallel downloads for pacman."
sed -Ei 's/^#(Color)$/\1\nILoveCandy/;s/^#(ParallelDownloads).*/\1 = 10/' /mnt/etc/pacman.conf
sed -i "/\[multilib\]/,/Include/"'s/^#//' /mnt/etc/pacman.conf
arch-chroot /mnt /bin/bash -e <<EOF
    pacman -Sy &>/dev/null
EOF

# Disabling debug packages for yay
info_print "Disabling makepkg debug packages and activating parallel compilation"
sed -Ei 's/ (debug lto)/ !\1/;s/^#(MAKEFLAGS=).*/\1\"--jobs=\$(nproc)\"/' /mnt/etc/makepkg.conf # ignore

# Better history
info_print "Enabling better history search"
cat >/mnt/etc/profile.d/bash_history.sh <<EOF
# Save 10,000 lines of history in memory
export HISTSIZE=10000
# Save 200,000 lines of history to disk (will have to grep ~/.bash_history for full listing)
export HISTFILESIZE=200000
# Append to history instead of overwrite
shopt -s histappend
# Ignore redundant or space commands
export HISTCONTROL=ignoreboth
# Ignore more
export HISTIGNORE='ls:ll:la:pwd:clear:history'
# Set time format
export HISTTIMEFORMAT='%F %T '
# Multiple commands on one line show up as a single line
shopt -s cmdhist
# Append new history lines, clear the history list, re-read the history list, print prompt.
export PROMPT_COMMAND="history -a; history -c; history -r; \$PROMPT_COMMAND"
EOF

# Enabling various services.
info_print "Enabling Reflector and systemd-oomd."
services=(reflector.timer systemd-oomd)
for service in "${services[@]}"; do
    systemctl enable "$service" --root=/mnt &>/dev/null
done

# Finishing up.
info_print "Done, you may now wish to reboot (further changes can be done by chrooting into /mnt)."
exit
