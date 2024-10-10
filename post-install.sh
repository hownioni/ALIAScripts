#!/usr/bin/env -S bash -e

if [ "$(id -u)" -eq 0 ]; then
    error_print "Please run this script without sudo."
    exit 1
fi

# Cleaning the TTY.
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

exists() {
    command -v "$1" &>/dev/null
}

dotfiles() {
    /usr/bin/git --git-dir="$HOME/.dotfiles/" --work-tree="$HOME" "$@"
}

get_repo() {
    input_print "Please enter the url of your dotfiles repo: "
    read -r dotfiles_repo
    if [[ -z "$dotfiles_repo" ]]; then
        echo
        error_print "URL can't be empty."
        return 1
    fi
}

gpu_detector() {
    GPU=$(lspci -v | grep -A1 -E "(VGA|3D)")
    if [[ "$GPU" == *"Intel"* ]]; then
        info_print "An Intel GPU has been detected, installing appropiate video drivers."
        video_drivers=(vulkan-intel lib32-vulkan-intel mesa lib32-mesa)
    elif [[ "$GPU" == *"AMD"* ]]; then
        info_print "An AMD GPU has been detected, installing appropiate video drivers."
        video_drivers=(xf86-video-amdgpu vulkan-radeon lib32-vulkan-radeon mesa lib32-mesa)
    else
        info_print "An NVIDIA GPU has been detected, this currently needs more testing."
        exit 0
    fi
}
graphic_server_install() {
    main_pkgs=(xorg qtile ly xclip picom papirus-icon-theme playerctl udisks2 dunst bluez bluez-utils brightnessctl)
    audio_server=(pipewire-alsa wireplumber pipewire-audio pipewire-pulse pipewire-jack alsa-utils pavucontrol pamixer)
    fonts=(noto-fonts noto-fonts-emoji ttf-liberation gnu-free-fonts ttf-nerd-fonts-symbols ttf-firacode-nerd)
    apps=(cups-pdf ffmpegthumbnailer libreoffice-fresh blueman bitwarden kitty firefox nsxiv rofi rofi-calc flameshot dwarffortress rofi-emoji udiskie syncthing mpv mpv-mpris feh copyq)
    yay_pkgs=(dragon-drop syncthingtray rofi-nerdy kitty-xterm-symlinks python-pulsectl-asyncio python-pywalfox zapzap)

    # Detect gpu for video driver installation
    gpu_detector

    # Install packages
    info_print "Installing the graphics server, display and window manager, along with some useful tools (this may take a while)."
    sudo pacman -S --noconfirm "${main_pkgs[@]}" "${apps[@]}" "${fonts[@]}" "${video_drivers[@]}" "${audio_server[@]}" 2>/dev/null
    exists yay && yay -S --noconfirm "${yay_pkgs[@]}" 2>/dev/null

    info_print "Enabling the display manager (ly) and CUPS."
    services=(ly.service cups.service)
    for service in "${services[@]}"; do
        sudo systemctl enable "$service" &>/dev/null
    done
}

yay_install() {
    info_print "Installing the yay AUR manager."
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si
    cd .. && rm -rf yay
}

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
                       Post-Install
==========================================================
${RESET}"
info_print "Welcome to ALIAS 2: Electric Boogaloo."

# Install yay
if ! exists yay; then
    input_print "Do you want to install yay for simpler AUR management [y/N]?: "
    read -r yay_response
    if ! [[ "${yay_response,,}" =~ ^(yes|y)$ ]]; then
        error_print "Continuing."
        return 0
    else
        yay_install
    fi
fi

# Clone config
info_print "Cloning config and tracking it."
if [[ ! -d "${HOME}/.dotfiles" ]]; then
    until get_repo; do :; done
    git clone --bare "$dotfiles_repo" "$HOME"/.dotfiles
    dotfiles checkout -f
    dotfiles config --local status.showUntrackedFiles no
    if [[ "$dotfiles_repo" == *"hownioni/dotfiles"* ]]; then
        info_print "Installing some AUR packages required for my config."
        yay -S --noconfirm bash-complete-alias pistol-git vimv python-pywal16 &>/dev/null
    fi
else
    info_print "There already exists a \"~/.dotfiles\" directory. Continuing."
fi

# Install graphics server
input_print "Do you want to install the graphics server [y/N]?: "
read -r graphics_response
if ! [[ "${graphics_response,,}" =~ ^(yes|y)$ ]]; then
    info_print "All done! You can reboot now."
    exit 0
fi
graphic_server_install
info_print "All done! You can reboot now."
