#!/usr/bin/env bash
# Author: cipherodio
# Description: systemd-boot loader configuration

set -Eeuo pipefail

# Helpers
msg() { printf "\033[1;92m==>\033[0m %s\n" "$1"; }
die() {
    printf "\033[1;31merror:\033[0m %s\n" "$1" >&2
    exit 1
}

BOOT_DIR="/boot"
LOADER_CONF="$BOOT_DIR/loader/loader.conf"
ENTRY_DIR="$BOOT_DIR/loader/entries"
ENTRY_CONF="$ENTRY_DIR/arch.conf"

# 1. Detect root UUID
ROOT_PART="$(findmnt -n -o SOURCE /)"
ROOT_UUID="$(blkid -s UUID -o value "$ROOT_PART")"
[[ -n "$ROOT_UUID" ]] || die "Failed to detect root UUID"

msg "Detected root UUID: $ROOT_UUID"

# 2. Create loader.conf
msg "Creating loader.conf"

cat >"$LOADER_CONF" <<'EOF'
default arch
timeout 0
console-mode max
editor no
EOF

# 3. Create arch.conf entry
msg "Creating arch.conf entry"

cat >"$ENTRY_CONF" <<EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /amd-ucode.img
initrd  /initramfs-linux.img
options root=UUID=$ROOT_UUID rw quiet loglevel=0 console=tty2 amd_pstate=passive \
modprobe.blacklist=sp5100_tco nmi_watchdog=0 ipv6.disable=1 \
rd.systemd.show_status=false rd.udev.log_level=3
EOF

msg "Systemd-boot loader configured successfully!"
msg "All setup complete! You can now exit chroot and reboot."
