#!/usr/bin/env bash
# Author: cipherodio
# Description: Run on fresh installed Arch Linux

set -Eeuo pipefail

# Helpers
msg() { printf "==> %s\n" "$1"; }
die() {
    printf "error: %s\n" "$1" >&2
    exit 1
}

need() { command -v "$1" >/dev/null 2>&1 || die "missing dependency: $1"; }

clone_if_missing() {
    repo="$1"
    dest="$2"

    msg "Processing $dest"
    if [[ -d "$dest/.git" ]]; then
        git -C "$dest" pull --ff-only
        msg "Updated $dest"
    else
        git clone "$repo" "$dest"
        msg "Cloned $dest"
    fi
}

# Variables
REPO_BASE="https://gitlab.com/cipherodio"
DOTS_REPO="$REPO_BASE/archdots.git"
HOME_DIR="$HOME"
DOTS_DIR="$HOME_DIR/.config/.dots"

HOME_DATA="$HOME_DIR/.local/share"
DATA_DIR="/data"

HUB_DIR="$HOME_DIR/hub"
HUB2_DIR="$DATA_DIR/hub2"

SRC_DIR="$HOME_DIR/hub/src"
DWM_REPO="${REPO_BASE}dwm.git"
ST_REPO="${REPO_BASE}st.git"
DMENU_REPO="${REPO_BASE}dmenu.git"
DWMBLOCKS_REPO="${REPO_BASE}dwmblocks.git"
SLOCK_REPO="${REPO_BASE}slock.git"

# Preconditions
need sudo
need git
sudo -v

msg "Starting Arch one-shot bootstrap"
msg "Done checking prerequisites"
# System packages
PKGS=(
    # X11
    xcape xclip xdg-utils xdo xdotool
    xorg-xdpyinfo xorg-xev xorg-xinit xorg-xinput xorg-xprop
    xorg-xset xorg-xsetroot xorg-xwininfo xterm
    # Drivers
    lib32-vulkan-radeon mesa-utils vulkan-tools
    # Audio
    pipewire pipewire-alsa pipewire-pulse pulsemixer alsa-utils
    # Fonts
    libertinus-font noto-fonts noto-fonts-emoji
    ttc-iosevka ttc-iosevka-aile ttf-iosevka-nerd
    ttf-dejavu ttf-liberation ttf-jetbrains-mono-nerd
    # System
    acpi dunst libnotify npm picom unclutter nim
    # System tools
    btop brightnessctl dosfstools evtest exfatprogs
    htop nvtop ntfs-3g pacutils upower reflector
    # Utilities
    bc fd fzf rofi highlight man-db maim moreutils rsync task jq
    pass psutils openssh ripgrep tmux tree unrar unzip wget zip
    # Media
    feh ffmpeg ffmpegthumbnailer imagemagick mediainfo
    mpc mpd mpv ncmpcpp nsxiv yt-dlp
    # Lf preview
    gnome-epub-thumbnailer lynx atool ueberzugpp
    # Programs
    audacity blender emacs firefox firefox-dark-reader
    firefox-extension-passff firefox-tridactyl
    firefox-ublock-origin gimp inkscape poppler spotify-launcher
    tesseract tesseract-data-eng tesseract-data-osd
    signal-desktop zathura zathura-pdf-mupdf
    # Needed for shotcut to work, uncomment below if using shotcut
    # shotcut qt6-svg qt6-5compat hip-runtime-amd
    # Cli
    lf calcurse newsboat transmission-cli taskwarrior-tui trash-cli
    # i3wm
    # i3-wm i3blocks autotiling snixembed alacritty
    # Qtile
    # qtile python-dbus-next python-iwlib python-mpd2 alacritty
    # python-pip python-psutil python-setproctitle
    # Dev
    bash-language-server lua-language-server rumdl tombi xmlstarlet
    python-debugpy python-lsp-server ruff shfmt shellcheck stylua
    tree-sitter-cli vscode-json-languageserver yaml-language-server
)
msg "Installing ${#PKGS[@]} system packages"
sudo pacman -Syu --needed --noconfirm "${PKGS[@]}"
msg "Done installing ${#PKGS[@]} system packages"

# Dotfiles (bare repo)
msg "Installing dotfiles"
if [[ ! -d "$DOTS_DIR" ]]; then
    git clone --bare "$DOTS_REPO" "$DOTS_DIR"
fi
git --git-dir="$DOTS_DIR" config \
    remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
git --git-dir="$DOTS_DIR" fetch origin
git --git-dir="$DOTS_DIR" --work-tree="$HOME_DIR" checkout -f
git --git-dir="$DOTS_DIR" \
    branch --set-upstream-to=origin/main main 2>/dev/null || true
msg "Done installing dotfiles"

# User directories
msg "Creating hub directory structure"
mkdir -p \
    "$HUB_DIR"/{downloads,review,screencapture,screenshot,src} \
    "$HUB_DIR/data"/{documents,music,videos,wallpapers} \
    "$HUB_DIR/projects"/{main,audacity,blender,shotcut,gimp} \
    "$HUB_DIR/projects/audacity"/{output,raw,save} \
    "$HUB_DIR/projects/blender"/{output,raw,save} \
    "$HUB_DIR/projects/gimp"/{output,raw,save} \
    "$HOME_DIR/.config/mpd/playlists" \
    "$HOME_DATA/fonts"
msg "Done creating hub directory structure"

msg "Creating hub2 directory structure"
mkdir -p \
    "$HUB2_DIR/files"/{documents,music,videos,wallpapers} \
    "$HUB2_DIR/projects"/{main,audacity,blender,shotcut,gimp} \
    "$HUB2_DIR/projects/audacity"/{output,raw,save} \
    "$HUB2_DIR/projects/blender"/{output,raw,save} \
    "$HUB2_DIR/projects/gimp"/{output,raw,save} \
    "$DATA_DIR/games"
msg "Done creating hub2 directory structure"

# Suckless
msg "Building suckless WM stack"

msg "Building DWM"
clone_if_missing "$DWM_REPO" "$SRC_DIR/dwm"
(
    cd "$SRC_DIR/dwm"
    make clean >/dev/null 2>&1 || true
    make
    sudo make install
)
msg "Done installing DWM"

msg "Building St Terminal"
clone_if_missing "$ST_REPO" "$SRC_DIR/st"
(
    cd "$SRC_DIR/st"
    make clean >/dev/null 2>&1 || true
    make
    sudo make install
)
msg "Done installing St Terminal"

msg "Building Dmenu"
clone_if_missing "$DMENU_REPO" "$SRC_DIR/dmenu"
(
    cd "$SRC_DIR/dmenu"
    make clean >/dev/null 2>&1 || true
    make
    sudo make install
)
msg "Done installing Dmenu"

msg "Building Dwmblocks"
clone_if_missing "$DWMBLOCKS_REPO" "$SRC_DIR/dwmblocks"
(
    cd "$SRC_DIR/dwmblocks"
    make clean >/dev/null 2>&1 || true
    make
    sudo make install
)
msg "Done installing Dwmblocks"

msg "Building slock"
clone_if_missing "$SLOCK_REPO" "$SRC_DIR/slock"
(
    cd "$SRC_DIR/slock"
    make clean >/dev/null 2>&1 || true
    make
    sudo make install
)
msg "Done installing slock"
msg "Done building all suckless WM stack"

# Cleanup legacy files
msg "Removing unused legacy shell configs"
rm -f "$HOME_DIR"/.{bash_logout,bash_profile,bashrc,zshrc}
rm -rf "$HOME_DIR/.nimble"
msg "Done cleaning legacy files"

# User services
msg "Enabling user services"
systemctl --user enable --now pipewire pipewire-pulse wireplumber || true
msg "Done enabling user services"

# SSH key
msg "Ensuring SSH key exists"
if [[ ! -f "$HOME_DIR/.ssh/gitlabkey" ]]; then
    mkdir -p "$HOME_DIR/.ssh"
    ssh-keygen -t ed25519 \
        -f "$HOME_DIR/.ssh/gitlabkey" \
        -C "cipherodio@gmail.com" \
        -N ""
fi
msg "Done ensuring SSH key"

# Done
msg "Bootstrap complete"
msg "Reboot recommended"
