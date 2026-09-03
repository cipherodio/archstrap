#!/usr/bin/env bash
# Author: cipherodio
# Description: Run on fresh installed Arch Linux

set -Eeuo pipefail

# Variables
REPO_BASE="https://gitlab.com/cipherodio/"
PACKAGE_URL="${REPO_BASE}archstrap/-/raw/main/package.csv"
DOTS_REPO="${REPO_BASE}archdots.git"
HOME_DIR="$HOME"

HOME_DATA="$HOME_DIR/.local/share"
DATA_DIR="/data"

HUB_DIR="$HOME_DIR/hub"
HUB2_DIR="$DATA_DIR/hub2"

SRC_DIR="$HOME_DIR/hub/src"
DOTS_DIR="$SRC_DIR/archdots"

DWM_REPO="${REPO_BASE}dwm.git"
ST_REPO="${REPO_BASE}st.git"
DMENU_REPO="${REPO_BASE}dmenu.git"
DWMBLOCKS_REPO="${REPO_BASE}dwmblocks.git"
SLOCK_REPO="${REPO_BASE}slock.git"

# Helpers
msg() { printf "==> %s\n" "$1"; }
die() {
    printf "error: %s\n" "$1" >&2
    exit 1
}

need() { command -v "$1" >/dev/null 2>&1 || die "missing dependency: $1"; }

clone_if_missing() {
    local repo="$1"
    local dest="$2"

    msg "Processing $dest"
    if [[ -d "$dest/.git" ]]; then
        git -C "$dest" pull --ff-only
        msg "Updated $dest"
    else
        git clone "$repo" "$dest"
        msg "Cloned $dest"
    fi
}

install_packages() {
    local package_file
    local category='' package='' description=''
    local -a packages=()

    package_file=$(mktemp)

    msg "Fetching package list"
    if ! curl -fsSL "$PACKAGE_URL" -o "$package_file"; then
        rm -f "$package_file"
        die "failed to fetch package.csv"
    fi

    while IFS=, read -r category package description ||
        [[ -n "$category$package$description" ]]; do
        category=${category%$'\r'}
        package=${package%$'\r'}

        [[ "$category" == \#* ]] && continue
        [[ -n "$package" ]] || continue

        packages+=("$package")
    done <"$package_file"

    rm -f "$package_file"

    ((${#packages[@]} > 0)) ||
        die "no packages found in package.csv"

    msg "Installing ${#packages[@]} system packages"
    sudo pacman -Syu --needed --noconfirm "${packages[@]}"
    msg "Done installing ${#packages[@]} system packages"
}

# Preconditions
need sudo
need git
need curl
sudo -v

# System packages
msg "Starting Arch one-shot bootstrap"
msg "Done checking prerequisites"
install_packages

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
    "$HOME_DATA/fonts" \
    "$HOME_DATA/wineprefixes"
msg "Done creating hub directory structure"

msg "Creating hub2 directory structure"
mkdir -p \
    "$HUB2_DIR/files"/{documents,music,videos,wallpapers} \
    "$HUB2_DIR/projects"/{main,audacity,blender,shotcut,gimp} \
    "$HUB2_DIR/projects/audacity"/{output,raw,save} \
    "$HUB2_DIR/projects/blender"/{output,raw,save} \
    "$HUB2_DIR/projects/gimp"/{output,raw,save} \
    "$DATA_DIR/games" \
    "$DATA_DIR/steam"
msg "Done creating hub2 directory structure"

# Dotfiles
msg "Installing dotfiles"
clone_if_missing "$DOTS_REPO" "$DOTS_DIR"
mapfile -t STOW_PACKAGES < <(
    find "$DOTS_DIR" \
        -mindepth 1 \
        -maxdepth 1 \
        -type d \
        ! -name ".git" \
        ! -name "cipher" \
        -printf "%f\n" |
        sort
)
((${#STOW_PACKAGES[@]} > 0)) || die "no Stow packages found in $DOTS_DIR"
msg "Stowing ${#STOW_PACKAGES[@]} dotfile packages"
stow \
    --dir="$DOTS_DIR" \
    --target="$HOME_DIR" \
    --no-folding \
    "${STOW_PACKAGES[@]}"
msg "Done installing dotfiles"

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
