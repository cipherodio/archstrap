#!/usr/bin/env bash
# Usage:
# curl -fsSL https://.../final.sh | USERNAME='myuser' USER_PASSWORD='mypass' bash

set -Eeuo pipefail

msg() { printf "\033[1;94m==>\033[0m %s\n" "$1"; }
die() {
    printf "\033[1;31merror:\033[0m %s\n" "$1" >&2
    exit 1
}

# Require environment vars
[ -z "${USERNAME:-}" ] && die "USERNAME is not set. Use: USERNAME='myuser' ..."
[ -z "${USER_PASSWORD:-}" ] && die "USER_PASSWORD is not set. Use: USER_PASSWORD='mypass' ..."

# Basic sanity check (optional but smart)
if [[ "$USERNAME" =~ [^a-z_][^a-z0-9_-]* ]]; then
    die "Invalid USERNAME"
fi

# Create user
msg "Creating user '$USERNAME' if it doesn't exist"

if ! id -u "$USERNAME" >/dev/null 2>&1; then
    useradd -m -G wheel,video,audio,storage,power,input,render -s /bin/zsh "$USERNAME"
    msg "User '$USERNAME' created"
else
    msg "User '$USERNAME' already exists"
fi

# Set password
msg "Setting password for '$USERNAME'"
echo "${USERNAME}:${USER_PASSWORD}" | chpasswd || die "Failed to set password"

# Configure sudoers
SUDO_FILE="/etc/sudoers.d/00_${USERNAME}"
msg "Configuring sudoers for '$USERNAME'"

echo "${USERNAME} ALL=(ALL) ALL" >"$SUDO_FILE"
chmod 440 "$SUDO_FILE"

msg "Done! User '$USERNAME' is ready."
