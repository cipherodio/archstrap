#!/usr/bin/env bash
# RUn:
# USER_PASSWORD='MyTestPass123' curl -fsSL https://gitlab.com/cipherodio/archstrap/-/raw/main/test.sh | bash

set -Eeuo pipefail

msg() { printf "\033[1;94m==>\033[0m %s\n" "$1"; }
die() {
    printf "\033[1;31merror:\033[0m %s\n" "$1" >&2
    exit 1
}

USERNAME="slutshit"

# -------------------------
# REQUIRE PASSWORD
# -------------------------

if [ -z "${USER_PASSWORD:-}" ]; then
    die "USER_PASSWORD is not set. Use: USER_PASSWORD='mypassword' $0"
fi

# -------------------------
# CREATE USER
# -------------------------

msg "Creating user '$USERNAME' if it doesn't exist"
if ! id -u "$USERNAME" >/dev/null 2>&1; then
    useradd -m -G wheel,video,audio,storage,power,input,render -s /bin/zsh "$USERNAME"
    msg "User '$USERNAME' created"
else
    msg "User '$USERNAME' already exists"
fi

# -------------------------
# SET PASSWORD
# -------------------------

msg "Setting password for '$USERNAME'"
echo "${USERNAME}:${USER_PASSWORD}" | chpasswd || die "Failed to set password"

# -------------------------
# SET SUDOERS
# -------------------------

SUDO_FILE="/etc/sudoers.d/00_${USERNAME}"
msg "Configuring sudoers for '$USERNAME'"
echo "${USERNAME} ALL=(ALL) ALL" >"$SUDO_FILE"
chmod 440 "$SUDO_FILE"

msg "Done! User '$USERNAME' is ready."
