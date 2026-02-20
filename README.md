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
- EFISTUB or systemd-boot

<!-- toc -->

- [1. PRE-INSTALLATION](#1-pre-installation)
    - [1.1 CHANGE CONSOLE FONT](#11-change-console-font)
    - [1.2 WIPE DISK](#12-wipe-disk)
    - [1.3 CONNECT TO THE INTERNET](#13-connect-to-the-internet)
    - [1.4 UPDATE SYSTEM CLOCK](#14-update-system-clock)
    - [1.5 INSTALL](#15-install)
- [2. SYSTEM ENVIRONMENT](#2-system-environment)
    - [2.1 CHROOT](#21-chroot)
    - [2.2 CREATE ROOT PASSWORD](#22-create-root-password)
    - [2.3 CONFIGURE](#23-configure)
    - [2.4 BOOTLOADER](#24-bootloader)
        - [2.4.1 EFISTUB](#241-efistub)
        - [2.4.2 SYSTEMD-BOOT](#242-systemd-boot)
    - [2.5 REBOOT](#25-reboot)
- [3. POST-INSTALLATION](#3-post-installation)
    - [3.1 USER LOGIN](#31-user-login)
    - [3.2 BOOTSTRAP](#32-bootstrap)
    - [3.3 SSH](#33-ssh)
    - [3.4 SETUP](#34-setup)

<!-- tocstop -->

## 1. PRE-INSTALLATION

### 1.1 CHANGE CONSOLE FONT

```sh
setfont ter-124b
```

### 1.2 WIPE DISK

> [!IMPORTANT]
>
> Verify disk names with `lsblk` before running `preinstall.sh`.
>
> Prerequisite disk names should match:
>
> - **`nvme0n1`**: 500GB
> - **`nvme1n1`**: 1TB

```sh
# DISK
wipefs -af /dev/nvme0n1

# DATA_DISK
wipefs -af /dev/nvme1n1
```

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

### 1.5 INSTALL

Before running, verify disk with: `lsblk`. This
[install script](install.sh) configures the following:

- Partition main disk
- Partition data disk
- Format partitions
- Mount filesystems
- Set mirrorlist
- pacstrap
- Generate fstab

```sh
curl -fsSL https://gitlab.com/cipherodio/archstrap/-/raw/main/install.sh | bash
```

## 2. SYSTEM ENVIRONMENT

### 2.1 CHROOT

Chroot to the new system environment.

```sh
arch-chroot /mnt
```

### 2.2 CREATE ROOT PASSWORD

```sh
passwd
```

### 2.3 CONFIGURE

This [configure script](configure.sh) configures the following:

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
- User and password creation
- Configure sudoers
- Set ownership for /data
- Pacman configuration

```sh
curl -fsSL https://gitlab.com/cipherodio/archstrap/-/raw/main/configure.sh | CREATEUSER='myuser' USERPASS='mypass' bash
```

### 2.4 BOOTLOADER

Pick one of the bootloaders:

- **EFISTUB**: `efistub.sh`
- **systemd-boot**: `systemdboot.sh`

#### 2.4.1 EFISTUB

```sh
curl -fsSL https://gitlab.com/cipherodio/archstrap/-/raw/main/efistub.sh | bash
```

#### 2.4.2 SYSTEMD-BOOT

```sh
curl -fsSL https://gitlab.com/cipherodio/archstrap/-/raw/main/systemdboot.sh | bash
```

### 2.5 REBOOT

Exit chroot, unmount drives, and reboot.

```sh
exit
umount -R /mnt
reboot
```

## 3. POST-INSTALLATION

### 3.1 USER LOGIN

Log in with your created username, connect to the internet, and update
the system.

```sh
nmtui
sudo pacman -Syu
```

### 3.2 BOOTSTRAP

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

### 3.4 SETUP

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
