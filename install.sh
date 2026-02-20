#!/usr/bin/env bash
# Author: cipherodio
# Description: Arch Linux preinstall (run from ISO)
# Assumes:
#   - Internet is connected
#   - nvme0n1 = 500GB nvme1n1 = 1TB
#   - /dev/nvme0n1 and /dev/nvme1n1 are wiped manually

set -Eeuo pipefail

# Helpers
msg() { printf "\033[1;92m==>\033[0m %s\n" "$1"; }
die() {
    printf "\033[1;31merror:\033[0m %s\n" "$1" >&2
    exit 1
}

# Env variables
DISK="/dev/nvme0n1"
DATA_DISK="/dev/nvme1n1"

# Partition main disk
msg "Partitioning $DISK"
parted -s "$DISK" mklabel gpt
parted -s "$DISK" mkpart ESP fat32 1MiB 1025MiB
parted -s "$DISK" set 1 esp on
parted -s "$DISK" mkpart primary ext4 1025MiB 100%
partprobe "$DISK"
sleep 2

# Partition data disk
msg "Partitioning $DATA_DISK"
parted -s "$DATA_DISK" mklabel gpt
parted -s "$DATA_DISK" mkpart primary ext4 1MiB 100%
partprobe "$DATA_DISK"
sleep 2

# Format partitions
msg "Formatting partitions"
mkfs.fat -F32 "${DISK}p1"
mkfs.ext4 -F "${DISK}p2"
mkfs.ext4 -F "${DATA_DISK}p1"

# Mount filesystems
msg "Mounting filesystems"
mount "${DISK}p2" /mnt
mount --mkdir -o rw,relatime,fmask=0077,dmask=0077 "${DISK}p1" /mnt/boot
mount --mkdir -o rw,noatime "${DATA_DISK}p1" /mnt/data
msg "All drives are ready"

# Set mirrorlist
msg "Setting mirrorlist"
cat >/etc/pacman.d/mirrorlist <<'EOF'
Server = https://mirror.xtom.com.hk/archlinux/$repo/os/$arch
Server = https://sg.mirrors.cicku.me/archlinux/$repo/os/$arch
Server = https://hk.mirrors.cicku.me/archlinux/$repo/os/$arch
Server = https://singapore.mirror.pkgbuild.com/archlinux/$repo/os/$arch
EOF
msg "Mirrors is set"

# Install base system
msg "Installing base system"
pacstrap -K /mnt \
    base base-devel linux linux-firmware \
    xorg-server mesa xf86-video-amdgpu vulkan-radeon amd-ucode \
    git neovim networkmanager iwd \
    bluez bluez-utils terminus-font \
    cpupower zsh efibootmgr
msg "Base system installed"

# Generate fstab
msg "Generating fstab"
genfstab -U /mnt >>/mnt/etc/fstab
msg "Preinstall complete."

msg "Now run: arch-chroot /mnt"
