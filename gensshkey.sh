#!/usr/bin/env bash
# Author: cipherodio
# Description: Run on fresh installed Arch Linux

set -Eeuo pipefail

HOME_DIR="$HOME"

msg() { printf "==> %s\n" "$1"; }

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
