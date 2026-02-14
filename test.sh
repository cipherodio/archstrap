#!/usr/bin/env bash
set -Eeuo pipefail

msg() { printf "\033[1;94m==>\033[0m %s\n" "$1"; }
die() {
    printf "\033[1;31merror:\033[0m %s\n" "$1" >&2
    exit 1
}

USERNAME="gptgay"

# -------------------------
# Check required env vars
# -------------------------
[ -z "${ROOT_PASSWORD:-}" ] && die "ROOT_PASSWORD is not set. Use: ROOT_PASSWORD='…' bash"
[ -z "${USER_PASSWORD:-}" ] && die "USER_PASSWORD is not set. Use: USER_PASSWORD='…' bash"

# -------------------------
# Set root password
# -------------------------
msg "Setting root password"
echo "root:${ROOT_PASSWORD}" | chpasswd
msg "Root password set successfully!"

# -------------------------
# Create user
# -------------------------
msg "Creating user '$USERNAME' if it doesn't exist"
if ! id -u "$USERNAME" >/dev/null 2>&1; then
    useradd -m -G wheel,video,audio,storage,power,input,render -s /bin/zsh "$USERNAME"
    msg "User '$USERNAME' created"
else
    msg "User '$USERNAME' already exists"
fi

# Set user password
msg "Setting password for '$USERNAME'"
echo "${USERNAME}:${USER_PASSWORD}" | chpasswd
msg "User password set successfully!"

# Configure sudoers
msg "Configuring sudoers for '$USERNAME'"
echo "${USERNAME} ALL=(ALL) ALL" >/etc/sudoers.d/00_"$USERNAME"
chmod 440 /etc/sudoers.d/00_"$USERNAME"
msg "Sudoers configured!"
