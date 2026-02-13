#!/usr/bin/env bash
# final.sh — post-deploy automation
# Author: cipherodio
# Description: Final setup — ownership, multilib, user, EFISTUB

set -Eeuo pipefail

# Helpers
msg() { printf '\033[1;94m==>\033[0m %s\n' "$1\n"; }
die() {
    printf '\033[1;31merror:\033[0m %s\n' "$1\n" >&2
    exit 1
}

# 1. Set root password interactively
msg "Setting root password"
read -s -r -p "Enter root password: " ROOT_PASS
echo
read -s -r -p "Confirm root password: " ROOT_PASS_CONFIRM
echo
[[ "$ROOT_PASS" == "$ROOT_PASS_CONFIRM" ]] || die "Passwords do not match!"
echo "root:$ROOT_PASS" | chpasswd

# 2. Create user cipherodio and set password
msg "Creating user cipherodio if it doesn't exist"
if ! id -u cipherodio >/dev/null 2>&1; then
    useradd -m -G users,wheel,video,render,audio,power,input,storage -s /bin/zsh cipherodio
fi

msg "Setting password for cipherodio"
read -s -r -p "Enter password for cipherodio: " USER_PASS
echo
read -s -r -p "Confirm password for cipherodio: " USER_PASS_CONFIRM
echo
[[ "$USER_PASS" == "$USER_PASS_CONFIRM" ]] || die "Passwords do not match!"
echo "cipherodio:$USER_PASS" | chpasswd

# Ensure sudoers entry exists
SUDO_FILE="/etc/sudoers.d/00_cipherodio"
echo "cipherodio ALL=(ALL) ALL" >"$SUDO_FILE"
chmod 440 "$SUDO_FILE"

# 3. Ownership
msg "Setting /data ownership to cipherodio"
chown -R cipherodio:cipherodio /data

# 4. Enable multilib in pacman.conf
PACMAN_CONF="/etc/pacman.conf"
msg "Enabling multilib and additional options in pacman.conf"
cp "$PACMAN_CONF" "${PACMAN_CONF}.bak"

# Enable Color, VerbosePkgLists, ParallelDownloads
sed -i \
    -e 's/^#Color/Color/' \
    -e 's/^#VerbosePkgLists/VerbosePkgLists/' \
    -e 's/^#ParallelDownloads = 5/ParallelDownloads = 2/' \
    -e '/^\[multilib\]/{s/^#//;n;s/^#Include/Include/}' \
    "$PACMAN_CONF"

# Add ILoveCandy below #DisableSandboxSyscalls if not already present
grep -q '^ILoveCandy' "$PACMAN_CONF" || sed -i '/^#DisableSandboxSyscalls/a ILoveCandy' "$PACMAN_CONF"

# 5. EFISTUB boot entry
msg "Creating EFISTUB boot entry"
ROOT_PART=$(findmnt -n -o SOURCE /)
ROOT_UUID=$(blkid -s UUID -o value "$ROOT_PART")
[[ -n "$ROOT_UUID" ]] || die "Failed to detect root UUID"
msg "Root partition: $ROOT_PART"
msg "Root UUID: $ROOT_UUID"

efibootmgr -d /dev/nvme0n1 -p 1 -c -L "Arch" -l /vmlinuz-linux -u \
    "root=UUID=$ROOT_UUID rw quiet loglevel=0 console=tty2 amd_pstate=passive \
modprobe.blacklist=sp5100_tco nmi_watchdog=0 ipv6.disable=1 \
rd.systemd.show_status=false rd.udev.log_level=3 initrd=\\amd-ucode.img \
initrd=\\initramfs-linux.img" --verbose

msg "Final setup complete! You can now exit chroot and reboot."
