# Arch Linux Installation

> [!WARNING]
>
> I am not responsible for any damages, loss of data, system corruption,
> or any mishap you may somehow cause by following this guide. I
> recommend checking the [Official Arch Installation Guide][archguide]
> and [Arch Wiki][archwiki].

## OVERVIEW

This repository contains my personal **[Arch Linux][archlinux]**
installation guide and setup workflow.

It is designed specifically for my **[dotfiles][dots]**, which use
**[Qtile][qtile]** as the window manager, and reflects the exact
environment I run daily.

This setup is built and tested on an **ASUS TUF A16 Advantage Edition**,
so some hardware-specific steps or optimizations may reflect that
platform.

This guide walks through my full Arch setup, from a fresh installation
to a fully working system.

## TARGET SYSTEM

- UEFI
- GPT partition table
- AMD GPU
- systemd-boot

<!-- toc -->

- [1. PRE-INSTALLATION](#1-pre-installation)
    - [1.1 CHANGE CONSOLE FONT](#11-change-console-font)
    - [1.2 WIPE DISK](#12-wipe-disk)
    - [1.3 CONNECT TO THE INTERNET](#13-connect-to-the-internet)
    - [1.4 UPDATE SYSTEM CLOCK](#14-update-system-clock)
    - [1.5 PRE-INSTALL SCRIPT](#15-pre-install-script)
- [2. SYSTEM ENVIRONMENT](#2-system-environment)
    - [2.1 CHROOT](#21-chroot)
    - [2.2 DEPLOY SCRIPT](#22-deploy-script)
    - [2.3 ROOT PASSWORD](#23-root-password)
    - [2.4 MULTILIB](#24-multilib)
    - [2.5 USER AND OWNERSHIP](#25-user-and-ownership)
    - [2.6 REMOUNT AND SYSTEMD-BOOT](#26-remount-and-systemd-boot)
    - [2.7 LOADER SCRIPT](#27-loader-script)
    - [2.8 REBOOT](#28-reboot)
- [3. POST-INSTALLATION](#3-post-installation)
    - [3.1 USER LOGIN](#31-user-login)
    - [3.2 BOOTSTRAP SCRIPT](#32-bootstrap-script)
    - [3.3 SSH](#33-ssh)
    - [3.4 SETUP SCRIPT](#34-setup-script)

<!-- tocstop -->

## 1. PRE-INSTALLATION

### 1.1 CHANGE CONSOLE FONT

```sh
setfont ter-132b
```

### 1.2 WIPE DISK

> [!IMPORTANT]
>
> **Important:** Verify disk names with `lsblk` before running
> `preinstall.sh`.
>
> Wipe DISK: `wipefs -af /dev/nvme0n1`
>
> Wipe DATA_DISK: `wipefs -af /dev/nvme1n1`

Prerequisite disk names should match:

- **`nvme0n1`**: 500GB
- **`nvme1n1`**: 1TB

### 1.3 CONNECT TO THE INTERNET

Using **iwctl** for wireless networking. Verify the connection with:
`ping -c 3 archlinux.org`

```sh
# Get the name with `ip link` or through `device list`

iwctl
[iwd]$ device list
[iwd]$ station wlan0 scan
[iwd]$ station wlan0 get-networks
[iwd]$ station wlan0 connect MyWifiNetwork
```

### 1.4 UPDATE SYSTEM CLOCK

```sh
timedatectl status
timedatectl set-ntp true
```

### 1.5 PRE-INSTALL SCRIPT

Before running, verify disk with: `lsblk`. This
[preinstall script](preinstall.sh) configures the following:

- Partition main disk
- Partition data disk
- Format partitions
- Mount filesystems
- Set mirrorlist
- pacstrap
- Generate fstab

```sh
curl -fsSL https://gitlab.com/cipherodio/archstrap/-/raw/main/preinstall.sh | bash
```

## 2. SYSTEM ENVIRONMENT

### 2.1 CHROOT

Chroot to the new system environment.

```sh
arch-chroot /mnt
```

### 2.2 DEPLOY SCRIPT

This [deploy script](deploy.sh) configures the following:

- Time
- Locale
- Hosts
- Hostname
- Network
- Bluetooth
- Console Font
- Touchpad
- Keyboard
- Watchdog
- Battery
- CPU

```sh
curl -fsSL https://gitlab.com/cipherodio/archstrap/-/raw/main/deploy.sh | bash
```

### 2.3 ROOT PASSWORD

```sh
passwd
```

### 2.4 MULTILIB

Add _entries_ and _uncomment_ line: `nvim /etc/pacman.conf`.

```sh
Color
VerbosePkgLists
ILoveCandy
ParallelDownloads = 2

[multilib]
Include = /etc/pacman.d/mirrorlist
```

### 2.5 USER AND OWNERSHIP

```sh
useradd -m -G users,wheel,video,render,audio,power,input,storage -s /bin/zsh cipherodio
passwd cipherodio

chown -R cipherodio:cipherodio /data

# Sudoers
EDITOR=nvim visudo -f /etc/sudoers.d/00_cipherodio

# Add:
cipherodio ALL=(ALL) ALL
```

### 2.6 REMOUNT AND SYSTEMD-BOOT

Remount the filesystem to avoid potential errors with `bootctl install`.

```sh
exit
umount -R /mnt
mount /dev/nvme0n1p2 /mnt
arch-chroot /mnt
mount -a

bootctl install
```

### 2.7 LOADER SCRIPT

This [loader script](loader.sh) configures the following:

- Configure entries in: `/boot/loader/loader.conf`
- Add loader entries: `/boot/loader/entries/arch.conf`

```sh
curl -fsSL https://gitlab.com/cipherodio/archstrap/-/raw/main/loader.sh | bash
```

### 2.8 REBOOT

Exit chroot, unmount drives, and reboot.

```sh
exit
umount -R /mnt
reboot
```

## 3. POST-INSTALLATION

### 3.1 USER LOGIN

Log in as user **cipherodio**, connect to the internet, and update the
system.

```sh
nmtui
sudo pacman -Syu
```

### 3.2 BOOTSTRAP SCRIPT

This [bootstrap script](bootstrap.sh) configures the following:

- Install packages
- Dotfiles
- Cleanup
- Pipewire
- Pip package
- SSH

```sh
curl -fsSL https://gitlab.com/cipherodio/archstrap/-/raw/main/bootstrap.sh | bash
reboot
```

### 3.3 SSH

Add SSH key to [GitLab][gitlab]

```sh
cat ~/.ssh/gitlabkey.pub | xclip -selection clipboard
```

### 3.4 SETUP SCRIPT

This [setup script](setup.sh) configures the following:

- User directories
- GnuPG Permissions
- Cloning Projects
- NPM package
- Firefox user.js and chrome CSS
- Set dotfiles git remote

```sh
curl -fsSL https://gitlab.com/cipherodio/archstrap/-/raw/main/setup.sh | bash
```

[archguide]: https://wiki.archlinux.org/title/Installation_guide
[archwiki]: https://wiki.archlinux.org/title/Main_page
[archlinux]: https://archlinux.org/
[dots]: https://gitlab.com/cipherodio/archdots
[qtile]: https://qtile.org/
[filesystem]: https://wiki.archlinux.org/title/File_systems
[gitlab]: https://gitlab.com/
