#!/usr/bin/env bash
# Author: cipherodio
# Description: Fully automated systemd-boot setup for Arch
# Remounts /boot securely inside chroot, configures loader, and installs systemd-boot

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

# Remount /boot according to fstab
msg "Remounting /boot to ensure fstab options are applied"
mountpoint -q /boot || die "/boot is not mounted! Mount the EFI partition before running this script."
mount -o remount /boot || die "Failed to remount /boot"

msg "/boot remounted successfully"

# Detect root UUID from mounted root
ROOT_PART="$(findmnt -n -o SOURCE /)"
ROOT_UUID="$(blkid -s UUID -o value "$ROOT_PART")"
[[ -n "$ROOT_UUID" ]] || die "Failed to detect root UUID from mounted root"
msg "Detected root UUID: $ROOT_UUID"

# Create loader.conf
msg "Creating loader.conf"
mkdir -p "$ENTRY_DIR"

cat >"$LOADER_CONF" <<'EOF'
default arch
timeout 0
console-mode max
editor no
EOF

# Create arch.conf entry
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

msg "Loader files created successfully"

# Install systemd-boot
msg "Installing systemd-boot to EFI partition"
bootctl install || die "bootctl install failed"

msg "Systemd-boot installed successfully! Your system is ready to boot."
