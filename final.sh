#!/usr/bin/env bash
# Author: cipherodio
# Description: Create user, configure pacman, and setup
# EFISTUB boot entry (NVMe only)
# Usage:
# curl -fsSL https://.../final.sh | CREATEUSER='myuser' USERPASS='mypass' bash

set -Eeuo pipefail

msg() { printf "\033[1;94m==>\033[0m %s\n" "$1"; }
die() {
    printf "\033[1;31merror:\033[0m %s\n" "$1" >&2
    exit 1
}

# 0. Require environment variables
[ -z "${CREATEUSER:-}" ] && die "CREATEUSER is not set"
[ -z "${USERPASS:-}" ] && die "USERPASS is not set"

USERNAME="$CREATEUSER"
PASSWORD="$USERPASS"

# 1. Validate username
if ! [[ "$USERNAME" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
    die "Invalid username format"
fi

# 2. Create user
msg "Creating user '$USERNAME' if it doesn't exist"

if ! id -u "$USERNAME" >/dev/null 2>&1; then
    useradd -m -G wheel,video,audio,storage,power,input,render -s /bin/zsh "$USERNAME"
    msg "User '$USERNAME' created"
else
    msg "User '$USERNAME' already exists"
fi

msg "Setting password for '$USERNAME'"
echo "${USERNAME}:${PASSWORD}" | chpasswd || die "Failed to set password"

# Configure sudoers
SUDO_FILE="/etc/sudoers.d/00_${USERNAME}"
msg "Configuring sudoers for '$USERNAME'"

if [ ! -f "$SUDO_FILE" ]; then
    echo "${USERNAME} ALL=(ALL) ALL" >"$SUDO_FILE"
    chmod 440 "$SUDO_FILE"
fi

msg "Done! User '$USERNAME' is ready."

# 3. Ownership of /data
msg "Setting /data ownership to '$USERNAME'"
chown -R "$USERNAME:$USERNAME" /data 2>/dev/null || true

# 4. Configure pacman
PACMAN_CONF="/etc/pacman.conf"
msg "Updating pacman.conf"
[ -f "${PACMAN_CONF}.bak" ] || cp "$PACMAN_CONF" "${PACMAN_CONF}.bak"

sed -i \
    -e 's/^#Color/Color/' \
    -e 's/^#VerbosePkgLists/VerbosePkgLists/' \
    -e 's/^ParallelDownloads = .*/ParallelDownloads = 2/' \
    -e '/^#\[multilib\]$/{
        s/^#\[multilib\]/[multilib]/;
        n;
        s/^#Include/Include/;
    }' \
    "$PACMAN_CONF"

grep -q '^ILoveCandy' "$PACMAN_CONF" || sed -i '/^#DisableSandboxSyscalls/a ILoveCandy' "$PACMAN_CONF"

# 5. EFISTUB boot entry
msg "Creating EFISTUB boot entry"

EFI_PART=$(findmnt -nr -o SOURCE /boot) # /dev/nvme0n1p1
ROOT_PART=$(findmnt -nr -o SOURCE /)    # /dev/nvme0n1p2
ROOT_UUID=$(blkid -s UUID -o value "$ROOT_PART")
[[ -n "$ROOT_UUID" ]] || die "Failed to detect root UUID"

msg "Root partition: $ROOT_PART"
msg "EFI partition: $EFI_PART"
msg "Root UUID: $ROOT_UUID"

# NVMe disks: remove the trailing partition number (p1, p2, etc.)
EFI_DISK="${EFI_PART%p*}"      # /dev/nvme0n1
EFI_PART_NUM="${EFI_PART##*p}" # 1

msg "EFI disk: $EFI_DISK"
msg "EFI partition number: $EFI_PART_NUM"

efibootmgr -d "$EFI_DISK" \
    -p "$EFI_PART_NUM" \
    -c -L "ArchLinux" \
    -l /vmlinuz-linux \
    -u "root=UUID=$ROOT_UUID rw quiet loglevel=0 console=tty2 amd_pstate=passive modprobe.blacklist=sp5100_tco nmi_watchdog=0 ipv6.disable=1 rd.systemd.show_status=false rd.udev.log_level=3 initrd=\\amd-ucode.img initrd=\\initramfs-linux.img"

msg "EFISTUB entry created successfully!"
msg "Final setup complete! You can now exit chroot and reboot."
