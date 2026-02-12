#!/usr/bin/env bash
# Author: cipherodio
# Description: Full Arch Linux system deployment after chroot
# Applies time, localization, network, services, and system optimizations

set -Eeuo pipefail

# Helpers
msg() {
    printf '\033[1;92m==>\033[0m %s\n' "$1"
}

die() {
    printf '\033[1;31merror:\033[0m %s\n' "$1" >&2
    exit 1
}

backup_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        cp "$file" "${file}.bak.$(date +%s)"
        msg "Backed up $file"
    fi
}

ensure_dir() {
    local dir="$1"
    [[ -d "$dir" ]] || mkdir -p "$dir"
}

# Require root
[[ $EUID -ne 0 ]] && die "This script must be run as root"

# -------------------------
# 1. Time zone
# -------------------------
msg "Setting time zone and syncing hardware clock"
ln -sf /usr/share/zoneinfo/Asia/Manila /etc/localtime
hwclock --systohc
msg "Time zone set"

# -------------------------
# 2. Localization
# -------------------------
msg "Generating locales"
locale_gen="/etc/locale.gen"
backup_file "$locale_gen"

# Enable en_PH.UTF-8 UTF-8 and en_PH ISO-8859-1
sed -i '/^#en_PH.UTF-8 UTF-8/s/^#//' "$locale_gen"
sed -i '/^#en_PH ISO-8859-1/s/^#//' "$locale_gen"

locale-gen
echo LANG=en_PH.UTF-8 >/etc/locale.conf
msg "Localization complete"

# -------------------------
# 3. Hostname and /etc/hosts
# -------------------------
msg "Setting hostname and hosts file"
echo core >/etc/hostname

hosts_file="/etc/hosts"
backup_file "$hosts_file"

cat >"$hosts_file" <<'EOF'
127.0.0.1    localhost
::1          localhost
127.0.1.1    core.localdomain core
EOF

msg "Hostname and hosts configured"

# -------------------------
# 4. Network services
# -------------------------
msg "Enabling NetworkManager"
systemctl enable NetworkManager.service

wifi_conf_dir="/etc/NetworkManager/conf.d"
ensure_dir "$wifi_conf_dir"

wifi_conf="$wifi_conf_dir/wifi_backend.conf"
backup_file "$wifi_conf"

cat >"$wifi_conf" <<'EOF'
[device]
wifi.backend=iwd
EOF

msg "NetworkManager configured to use iwd backend"

# -------------------------
# 5. Bluetooth service
# -------------------------
msg "Enabling Bluetooth service"
systemctl enable bluetooth.service

# -------------------------
# 6. Console font
# -------------------------
msg "Setting permanent console font"
vconsole_conf="/etc/vconsole.conf"
backup_file "$vconsole_conf"

cat >"$vconsole_conf" <<'EOF'
FONT=ter-132b
EOF

# -------------------------
# 7. Touchpad tapping
# -------------------------
msg "Enabling touchpad tapping"
xorg_dir="/etc/X11/xorg.conf.d"
ensure_dir "$xorg_dir"

touchpad_conf="$xorg_dir/40-libinput.conf"
backup_file "$touchpad_conf"

cat >"$touchpad_conf" <<'EOF'
Section "InputClass"
    Identifier "libinput touchpad catchall"
    MatchIsTouchpad "on"
    MatchDevicePath "/dev/input/event*"
    Option "Tapping" "on"
    Driver "libinput"
EndSection
EOF

# -------------------------
# 8. Keyboard caps->escape
# -------------------------
msg "Remapping Caps Lock to Escape"
keyboard_conf="$xorg_dir/00-keyboard.conf"
backup_file "$keyboard_conf"

cat >"$keyboard_conf" <<'EOF'
Section "InputClass"
    Identifier "keyboard defaults"
    MatchIsKeyboard "on"
    Option "XkbOptions" "caps:escape"
EndSection
EOF

# -------------------------
# 9. Disable watchdog
# -------------------------
msg "Disabling watchdog modules"
modprobe_conf="/etc/modprobe.d/watchdog.conf"
backup_file "$modprobe_conf"

cat >"$modprobe_conf" <<'EOF'
blacklist iTCO_wdt
blacklist iTCO_vendor_support
EOF

# -------------------------
# 10. ASUS battery charge limit
# -------------------------
msg "Setting ASUS battery charge limit (60%)"
udev_dir="/etc/udev/rules.d"
ensure_dir "$udev_dir"

battery_rule="$udev_dir/asus-battery-charge-threshold.rules"
backup_file "$battery_rule"

cat >"$battery_rule" <<'EOF'
ACTION=="add", KERNEL=="asus-nb-wmi", RUN+="/bin/bash -c 'echo 60 > /sys/class/power_supply/BAT0/charge_control_end_threshold'"
EOF

# -------------------------
# 11. Disable CPU boost
# -------------------------
msg "Disabling CPU boost"
cpu_rule="$udev_dir/99-disable-cpu-boost.rules"
backup_file "$cpu_rule"

cat >"$cpu_rule" <<'EOF'
SUBSYSTEM=="cpu", ACTION=="add", RUN+="/bin/bash -c 'echo 0 > /sys/devices/system/cpu/cpufreq/boost'"
EOF

msg "Deployment complete! Reboot recommended."
