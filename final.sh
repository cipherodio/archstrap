#!/usr/bin/env bash
# final.sh — post-deploy automation
# Author: cipherodio
# Description: Final setup — ownership, multilib, user, EFISTUB

set -Eeuo pipefail

# Helpers
msg() { printf '\033[1;94m==>\033[0m %s\n' "$1"; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$1" >&2; exit 1; }

# -------------------------------
# 1. Set root password (non-interactive)
# -------------------------------
ROOT_PASSWORD="${ROOT_PASSWORD:-rootpassword}"  # default if not set, override via ENV
msg "Setting root password"
printf "%s\n%s" "$ROOT_PASSWORD" "$ROOT_PASSWORD" | passwd >/dev/null 2>&1

# -------------------------------
# 2. Create user cipherodio
# -------------------------------
USER_PASSWORD="${USER_PASSWORD:-userpassword}"  # default if not set, override via ENV
msg "Creating user cipherodio"
if ! id -u cipherodio >/dev/null 2>&1; then
    useradd -m -G users,wheel,video,render,audio,power,input,storage -s /bin/zsh cipherodio
fi

msg "Setting password for cipherodio"
printf "%s\n%s" "$USER_PASSWORD" "$USER_PASSWORD" | passwd cipherodio >/dev/null 2>&1

# Ensure sudoers entry exists
SUDO_FILE="/etc/sudoers.d/00_cipherodio"
echo "cipherodio ALL=(ALL) ALL" >"$SUDO_FILE"
chmod 440 "$SUDO_FILE"

# -------------------------------
# 3. Set ownership of /data
# -------------------------------
msg "Setting /data ownership to cipherodio"
chown -R cipherodio:cipherodio /data || true

# -------------------------------
# 4. Enable multilib & pacman tweaks
# -------------------------------
PACMAN_CONF="/etc/pacman.conf"
msg "Enabling multilib and additional options in pacman.conf"
cp "$PACMAN_CONF" "${PACMAN_CONF}.bak"

# Enable Color, VerbosePkgLists, ParallelDownloads
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

# Add ILoveCandy below #DisableSandboxSyscalls if missing
grep -q '^ILoveCandy' "$PACMAN_CONF" || sed -i '/^#DisableSandboxSyscalls/a ILoveCandy' "$PACMAN_CONF"

# -------------------------------
# 5. EFISTUB boot entry
# -------------------------------
msg "Creating EFISTUB boot entry"

ROOT_PART=$(findmnt -n -o SOURCE /)
ROOT_UUID=$(blkid -s UUID -o value "$ROOT_PART")
[[ -n "$ROOT_UUID" ]] || die "Failed to detect root UUID"

msg "Root partition: $ROOT_PART"
msg "Root UUID: $ROOT_UUID"

efibootmgr -d /dev/nvme0n1 -p 1 -c -L "Arch" -l /vmlinuz-linux -u \
    'root=UUID='"$ROOT_UUID"' rw quiet loglevel=0 console=tty2 amd_pstate=passive \
modprobe.blacklist=sp5100_tco nmi_watchdog=0 ipv6.disable=1 \
rd.systemd.show_status=false rd.udev.log_level=3 initrd=\amd-ucode.img \
initrd=\initramfs-linux.img' --verbose

msg "EFISTUB entry created successfully!"
msg "Final setup complete! You can now exit chroot and reboot."