#!/usr/bin/env bash
# Author: cipherodio
# Description: Run on fresh installed Arch Linux

set -Eeuo pipefail

REPO_BASE="https://gitlab.com/cipherodio/"
PACKAGE_URL="${REPO_BASE}archstrap/-/raw/main/temppkg.csv"

msg() { printf "==> %s\n" "$1"; }

die() {
    printf "error: %s\n" "$1" >&2
    exit 1
}

need() { command -v "$1" >/dev/null 2>&1 || die "missing dependency: $1"; }

install_packages() {
    local package_file
    local category='' package='' description=''
    local -a packages=()

    package_file=$(mktemp)

    msg "Fetching package list"
    if ! curl -fsSL "$PACKAGE_URL" -o "$package_file"; then
        rm -f "$package_file"
        die "failed to fetch temppkg.csv"
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
        die "no packages found in temppkg.csv"

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
