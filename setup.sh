#!/usr/bin/env bash
# Author: cipherodio
# Description: Run after bootstrap.sh and copying ssh key to gitlab
# via firefox `cat ~/.ssh/gitlabkey.pub | xclip -selection clipboard`
# User environment setup (post-login)
# Assumes:
#   - dotfiles are installed and sourced
#   - PATH, npm prefix, SSH config are active

set -Eeuo pipefail

[[ $EUID -eq 0 ]] && {
    echo "error: do not run setup.sh as root" >&2
    exit 1
}

# Helpers
msg() { printf "\033[1;92m==>\033[0m %s\n" "$1"; }
die() {
    printf "\033[1;31merror:\033[0m %s\n" "$1" >&2
    exit 1
}

clone_if_missing() {
    local repo="$1"
    local dest="$2"

    msg "Processing $dest"

    if [[ -d "$dest/.git" ]]; then
        git -C "$dest" pull --ff-only
        msg "Updated $dest"
    else
        git clone "$repo" "$dest"
        msg "Cloned $dest"
    fi
}

# Env variables
HOME_DIR="$HOME"
HOME_DATA="$HOME_DIR/.local/share"
GPG_DIR="$HOME_DIR/.gnupg"

REPO_BASE="git@gitlab.com:cipherodio/"
ARCHSTRAP_REPO="${REPO_BASE}archstrap.git"
STARTPAGE_REPO="${REPO_BASE}startpage.git"
NOTES_REPO="${REPO_BASE}mdnotes.git"
PODCAST_REPO="${REPO_BASE}podcast.git"

HUB_DIR="$HOME_DIR/hub"
HUB2_DIR="/data/hub2"
SRC_DIR="$HUB_DIR/src"
DOTS_DIR="$HOME_DIR/.config/.dots"

FIREFOX_SRC="$HOME_DIR/.config/firefox/user.js"
FIREFOX_DIR="$HOME_DIR/.config/mozilla/firefox"
PROFILES_INI="$FIREFOX_DIR/profiles.ini"

CHROME_SRC="$HOME_DIR/.config/firefox/chrome/onedark"

# Preconditions
msg "Checking required commands"
command -v git >/dev/null || die "git not installed"
command -v npm >/dev/null || die "npm not installed"
msg "All required commands available"

# User directories
msg "Creating hub directory structure"
mkdir -p \
    "$HUB_DIR"/{downloads,review,screencapture,screenshot,src} \
    "$HUB_DIR/data"/{documents,music,videos,wallpapers} \
    "$HUB_DIR/projects"/{main,audacity,blender,shotcut,gimp} \
    "$HUB_DIR/projects/audacity"/{output,raw,save} \
    "$HUB_DIR/projects/blender"/{output,raw,save} \
    "$HUB_DIR/projects/shotcut"/{mlts,output,raw,save} \
    "$HUB_DIR/projects/gimp"/{output,raw,save} \
    "$HOME_DIR/.venv" \
    "$HOME_DIR/.config/mpd/playlists" \
    "$HOME_DATA/fonts" \
    "$HOME_DATA/pki"
msg "Done creating hub directory structure"

# Hub2 directories
msg "Creating hub2 directory structure"
mkdir -p \
    "$HUB2_DIR/data"/{documents,music,videos,wallpapers} \
    "$HUB2_DIR/projects"/{main,audacity,blender,shotcut,gimp} \
    "$HUB2_DIR/projects/audacity"/{output,raw,save} \
    "$HUB2_DIR/projects/blender"/{output,raw,save} \
    "$HUB2_DIR/projects/gimp"/{output,raw,save}
msg "Done creating hub2 directory structure"

# GnuPG permissions
msg "Setting GnuPG permissions"
if [[ -d "$GPG_DIR" ]]; then
    find "$GPG_DIR" -type d -exec chmod 700 {} \;
    find "$GPG_DIR" -type f -exec chmod 600 {} \;

    gpgconf --kill gpg-agent >/dev/null 2>&1 || true

    msg "GnuPG permissions set"
else
    msg "No GnuPG directory found, skipping"
fi
msg "GnuPG permissions is set"

# GitLab SSH check
msg "Checking GitLab SSH access"
if git ls-remote "$ARCHSTRAP_REPO" >/dev/null 2>&1; then
    msg "GitLab SSH access OK"
else
    die "GitLab SSH access failed.
Ensure:
  - ssh-agent is running
  - your key is added (ssh-add)
  - the key is uploaded to GitLab"
fi

# Archstrap
msg "Processing archstrap"
clone_if_missing "$ARCHSTRAP_REPO" "$SRC_DIR/archstrap"
msg "Done processing archstrap"

# Startpage
msg "Processing startpage"
clone_if_missing "$STARTPAGE_REPO" "$SRC_DIR/startpage"
msg "Done processing startpage"

# Notes
msg "Processing notes"
clone_if_missing "$NOTES_REPO" "$SRC_DIR/mdnotes"
msg "Done processing notes"

# Podcast
msg "Processing podcast"
clone_if_missing "$PODCAST_REPO" "$SRC_DIR/podcast"
msg "Done processing podcast"

# NPM packages
msg "Installing NPM packages"
npm install -g markdown-toc
msg "Done installing NPM packages"

# Firefox user.js + chrome CSS
msg "Configuring Firefox user.js and chrome CSS"

if [[ ! -f "$FIREFOX_SRC" ]]; then
    msg "No Firefox user.js found, skipping Firefox config"
else
    [[ -f "$PROFILES_INI" ]] || die "Firefox profiles.ini not found"

    PROFILE_PATH="$(
        sed -n '/^\[Install/{n;/^Default=/s/^Default=//p;q}' "$PROFILES_INI"
    )"

    [[ -n "$PROFILE_PATH" ]] || die "Failed to detect Firefox profile path"

    PROFILE_DIR="$FIREFOX_DIR/$PROFILE_PATH"
    USERJS_DST="$PROFILE_DIR/user.js"
    CHROME_DST="$PROFILE_DIR/chrome"

    [[ -d "$PROFILE_DIR" ]] || die "Firefox profile directory not found"

    # User.js
    if [[ -f "$USERJS_DST" ]]; then
        cp "$USERJS_DST" "$USERJS_DST.bak"
        msg "Backed up existing user.js"
    fi

    cp "$FIREFOX_SRC" "$USERJS_DST"
    msg "Installed Firefox user.js"

    # Chrome CSS
    mkdir -p "$CHROME_DST"

    cp "$CHROME_SRC/userChrome.css" "$CHROME_DST/userChrome.css"
    cp "$CHROME_SRC/userContent.css" "$CHROME_DST/userContent.css"

    msg "Installed Firefox chrome CSS"
fi

# Change dotfiles remote (HTTPS → SSH)
msg "Fixing dotfiles git remote"
git --git-dir="$DOTS_DIR" --work-tree="$HOME_DIR" \
    remote set-url origin git@gitlab.com:cipherodio/archdots.git
msg "Done fixing git remotes"

msg "setup.sh complete"
msg "Restore gpg keys now"
