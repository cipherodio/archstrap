#!/usr/bin/env bash
# Author: cipherodio
# Description: Full Arch Linux post-chroot deployment
# - Sets timezone, locale, hostname, network, services
# - Configures console, touchpad, keyboard, watchdog, battery, CPU
# - Creates user, configures pacman, sets /data ownership
# - Creates NVMe EFISTUB boot entry
# Assumes:
#   - You are already chroot in the new system environment
#   - Connected to the internet with iwctl
#   - Update system clock with timedatectl
# Usage:
# curl -fsSL https://.../deploy-final.sh | CREATEUSER='myuser' USERPASS='mypass' bash

set -Eeuo pipefail

# Helpers
msg() { printf "\033[1;92m==>\033[0m %s\n" "$1"; }
die() {
    printf "\033[1;31merror:\033[0m %s\n" "$1" >&2
    exit 1
}

# Required user env variables
[ -z "${CREATEUSER:-}" ] && die "CREATEUSER is not set"
[ -z "${USERPASS:-}" ] && die "USERPASS is not set"
USERNAME="$CREATEUSER"
PASSWORD="$USERPASS"

# 0. Timezone
msg "Setting time zone and syncing hardware clock"

ln -sf /usr/share/zoneinfo/Asia/Manila /etc/localtime
hwclock --systohc

msg "Time zone set"

# 1. Locale
msg "Generating locales"

locale_gen="/etc/locale.gen"
sed -i '/^#en_PH.UTF-8 UTF-8/s/^#//' "$locale_gen"
sed -i '/^#en_PH ISO-8859-1/s/^#//' "$locale_gen"
locale-gen
echo LANG=en_PH.UTF-8 >/etc/locale.conf

msg "Localization complete"

# 2. Hostname
msg "Setting hostname and /etc/hosts"

echo core >/etc/hostname
hosts_file="/etc/hosts"
cat >"$hosts_file" <<'EOF'
127.0.0.1    localhost
::1          localhost
127.0.1.1    core.localdomain core
EOF

msg "Hostname configured"

# 3. Network
msg "Enabling NetworkManager"

systemctl enable NetworkManager.service
wifi_conf_dir="/etc/NetworkManager/conf.d"
wifi_conf="$wifi_conf_dir/wifi_backend.conf"
cat >"$wifi_conf" <<'EOF'
[device]
wifi.backend=iwd
EOF

msg "NetworkManager configured to use iwd"

# 4. Bluetooth
msg "Enabling Bluetooth service"

systemctl enable bluetooth.service

msg "Bluetooth service enabled"

# 5. Console font
msg "Setting console font"

vconsole_conf="/etc/vconsole.conf"
echo "FONT=ter-128b" >"$vconsole_conf"

msg "Console font is set"

# 6. Touchpad tapping
msg "Enabling touchpad tapping"

xorg_dir="/etc/X11/xorg.conf.d"
touchpad_conf="$xorg_dir/40-libinput.conf"
cat >"$touchpad_conf" <<'EOF'
Section "InputClass"
    Identifier "libinput touchpad catchall"
    MatchIsTouchpad "on"
    MatchDevicePath "/dev/input/event*"
    Option "Tapping" "on"
    Driver "libinput"
EndSection
EOF

msg "Touchpad configured"

# 7. Keyboard caps->escape
msg "Remapping Caps Lock to Escape"

keyboard_conf="$xorg_dir/00-keyboard.conf"
cat >"$keyboard_conf" <<'EOF'
Section "InputClass"
    Identifier "keyboard defaults"
    MatchIsKeyboard "on"
    Option "XkbOptions" "caps:escape"
EndSection
EOF

msg "Caps remapped to Escape"

# 8. Disable watchdog
msg "Disabling watchdog modules"

modprobe_conf="/etc/modprobe.d/watchdog.conf"
cat >"$modprobe_conf" <<'EOF'
blacklist iTCO_wdt
blacklist iTCO_vendor_support
EOF

msg "Watchdog disabled"

# 9. ASUS battery limit
msg "Setting ASUS battery charge limit (60%)"

udev_dir="/etc/udev/rules.d"
battery_rule="$udev_dir/asus-battery-charge-threshold.rules"
cat >"$battery_rule" <<'EOF'
ACTION=="add", KERNEL=="asus-nb-wmi", RUN+="/bin/bash -c 'echo 60 > /sys/class/power_supply/BAT0/charge_control_end_threshold'"
EOF

msg "ASUS battery limited to 60%"

# 10. Disable CPU boost
msg "Disabling CPU boost"

cpu_rule="$udev_dir/99-disable-cpu-boost.rules"
cat >"$cpu_rule" <<'EOF'
SUBSYSTEM=="cpu", ACTION=="add", RUN+="/bin/bash -c 'echo 0 > /sys/devices/system/cpu/cpufreq/boost'"
EOF

msg "CPU boost disabled"

# 11. User creation
msg "Creating user '$USERNAME' if it doesn't exist"

if ! id -u "$USERNAME" >/dev/null 2>&1; then
    useradd -m -G wheel,video,audio,storage,power,input,render -s /bin/zsh "$USERNAME"
    msg "User '$USERNAME' created"
else
    msg "User '$USERNAME' already exists"
fi

msg "Setting password for '$USERNAME'"
echo "${USERNAME}:${PASSWORD}" | chpasswd || die "Failed to set password"

# 12. Configure sudoers
SUDO_FILE="/etc/sudoers.d/00_${USERNAME}"
msg "Configuring sudoers for '$USERNAME'"

if [ ! -f "$SUDO_FILE" ]; then
    echo "${USERNAME} ALL=(ALL) ALL" >"$SUDO_FILE"
    chmod 440 "$SUDO_FILE"
fi

msg "Done! User: '$USERNAME' is ready!"

# 13. Ownership of /data
msg "Setting /data ownership to '$USERNAME'"

chown -R "$USERNAME:$USERNAME" /data 2>/dev/null || true

# 14. Pacman configuration
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

msg "Done! pacman.conf configured"

# 15. EFISTUB boot entry (NVMe only)
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
