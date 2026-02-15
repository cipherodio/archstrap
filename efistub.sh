#!/usr/bin/env bash
# Author: cipherodio
# Description: EFISTUB bootloader

set -Eeuo pipefail

# Helpers
msg() { printf "\033[1;92m==>\033[0m %s\n" "$1"; }
die() {
    printf "\033[1;31merror:\033[0m %s\n" "$1" >&2
    exit 1
}

# EFISTUB boot entry (NVMe only)
msg "Creating EFISTUB boot entry"

EFI_PART=$(findmnt -nr -o SOURCE /boot)
ROOT_PART=$(findmnt -nr -o SOURCE /)
ROOT_UUID=$(blkid -s UUID -o value "$ROOT_PART")
[[ -n "$ROOT_UUID" ]] || die "Failed to detect root UUID"

msg "Root partition: $ROOT_PART"
msg "EFI partition: $EFI_PART"
msg "Root UUID: $ROOT_UUID"

EFI_DISK="${EFI_PART%p*}"
EFI_PART_NUM="${EFI_PART##*p}"

msg "EFI disk: $EFI_DISK"
msg "EFI partition number: $EFI_PART_NUM"

efibootmgr -d "$EFI_DISK" \
    -p "$EFI_PART_NUM" \
    -c -L "ArchLinux" \
    -l /vmlinuz-linux \
    -u "root=UUID=$ROOT_UUID rw quiet loglevel=0 console=tty2 amd_pstate=passive modprobe.blacklist=sp5100_tco nmi_watchdog=0 ipv6.disable=1 rd.systemd.show_status=false rd.udev.log_level=3 initrd=\\amd-ucode.img initrd=\\initramfs-linux.img"

msg "EFISTUB entry created successfully!"
msg "All setup complete! You can now exit chroot and reboot."
