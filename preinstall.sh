#!/usr/bin/env bash
# Author: cipherodio
# Description: Arch Linux preinstall (run from ISO)
# Assumes:
#   - Internet is connected
#   - /dev/nvme0n1 and /dev/nvme1n1 are wiped manually

set -Eeuo pipefail

DISK="/dev/nvme0n1"
DATA_DISK="/dev/nvme1n1"

msg() {
    printf '\033[1;94m==>\033[0m %s\n' "$1"
}

[[ $EUID -ne 0 ]] && {
    echo "Run as root from Arch ISO" >&2
    exit 1
}

# 1. Partition main disk
msg "Partitioning $DISK"

parted -s "$DISK" mklabel gpt
parted -s "$DISK" mkpart ESP fat32 1MiB 1025MiB
parted -s "$DISK" set 1 esp on
parted -s "$DISK" mkpart primary ext4 1025MiB 100%
partprobe "$DISK"
sleep 2

# 2. Partition data disk
msg "Partitioning $DATA_DISK"

parted -s "$DATA_DISK" mklabel gpt
parted -s "$DATA_DISK" mkpart primary ext4 1MiB 100%
partprobe "$DATA_DISK"
sleep 2

# 3. Format partitions
msg "Formatting partitions"

mkfs.fat -F32 "${DISK}p1"
mkfs.ext4 -F "${DISK}p2"
mkfs.ext4 -F "${DATA_DISK}p1"

# 4. Mount filesystems
msg "Mounting filesystems"

# Ill keep this for now, in case below one doesn't work
# mount "${DISK}p2" /mnt
# mount --mkdir "${DISK}p1" /mnt/boot
# mount --mkdir "${DATA_DISK}p1" /mnt/data

mount "${DISK}p2" /mnt
mount --mkdir -o rw,relatime,fmask=0077,dmask=0077 "${DISK}p1" /mnt/boot
mount --mkdir -o rw,noatime "${DATA_DISK}p1" /mnt/data

# 5. Set mirrorlist
msg "Setting mirrorlist"

cat >/etc/pacman.d/mirrorlist <<'EOF'
Server = https://mirror.sg.gs/archlinux/$repo/os/$arch
Server = http://mirror.xtom.com.hk/archlinux/$repo/os/$arch
Server = https://singapore.mirror.pkgbuild.com/archlinux/$repo/os/$arch
EOF

# 6. Install base system
msg "Installing base system"

pacstrap -K /mnt \
    base base-devel linux linux-firmware \
    xorg-server mesa xf86-video-amdgpu vulkan-radeon amd-ucode \
    git neovim networkmanager iwd \
    bluez bluez-utils terminus-font \
    cpupower zsh efibootmgr

# 7. Generate fstab
msg "Generating fstab"

genfstab -U /mnt >>/mnt/etc/fstab

msg "Preinstall complete."
msg "Now run: arch-chroot /mnt"
