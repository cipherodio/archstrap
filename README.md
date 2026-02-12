# Arch Linux Installation

> [!WARNING]
>
> I am not responsible for any damages, loss of data, system corruption,
> or any mishap you may somehow cause by following this guide.

## Overview

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

<!-- toc -->

- [1. PRE-INSTALLATION](#1-pre-installation)
    - [1.1 CHANGE CONSOLE FONT](#11-change-console-font)
    - [1.2 CONNECT TO THE INTERNET](#12-connect-to-the-internet)
    - [1.3 UPDATE SYSTEM CLOCK](#13-update-system-clock)

<!-- tocstop -->

## 1. PRE-INSTALLATION

### 1.1 CHANGE CONSOLE FONT

```sh
setfont ter-132b
```

### 1.2 CONNECT TO THE INTERNET

Using **iwctl** for wireless networking. Check internet connection with
`ping -c 3 archlinux.org`

```sh
# Get the name with `ip link` or through `device list`
iwctl
[iwd]$ device list
[iwd]$ station wlan0 scan
[iwd]$ station wlan0 get-networks
[iwd]$ station wlan0 connect MyWifiNetwork
```

### 1.3 UPDATE SYSTEM CLOCK

```sh
timedatectl status
timedatectl set-ntp true
```

### 1.4 PARTITION DISK

Quick overview of my partition layout.

| **Mount Point** | **Partition**  | **Partition Type**   | **Suggested Size**      |
| --------------- | -------------- | -------------------- | ----------------------- |
| /mnt/boot       | /dev/nvme0n1p1 | EFI System Partition | 512MiB                  |
| /mnt            | /dev/nvme0n1p2 | Linux File System    | Remainder of the device |
| /mnt/data       | /dev/nvme1n1p1 | Linux File System    | Everything              |

- **`wipefs -af /dev/nvme0n1`**: wipes existing drive partition
- **`lsblk -f`**: checks disk
- **`fdisk  /dev/nvme0n1`**: command to partition drive using _fdisk_.

#### 1.4.1 FIRST DISK

Main disk for installation: `fdisk /dev/nvme0n1`.

##### 1.4.1.1 BOOT PARTITION

1. Type `g` to set it on **GPT** disklabel.
2. Type `n` for new partition.
3. On last sector set it to `+1G`.

##### 1.4.1.2 ROOT PARTITION

1. Type `n` for new partition.
2. All remainder of the device for last sector.

##### 1.4.1.3 EFI PARTITION TYPE

Change boot partition type to **EFI**.

1. Press `t` for disklabel specified type.
2. Type `1` to select first created partition.
3. Type `1` to set it to `EFI` partition type.
4. Type `p` to check if all partitions were correct.
5. Type `w` to write changes and exit.

#### 1.4.2 SECOND DISK

Applicable only if you have second internal disk: `fdisk /dev/nvme1n1`.

##### 1.4.2.1 DATA

1. Type `g` to set it on **GPT** disklabel.
2. Type `n` for new partition.
3. All remainder of the device for last sector.
4. Type `p` to check if all partitions were correct.
5. Type `w` to write changes and exit.

### 1.5 FORMAT DISK

After partitions have been created, each newly partition must be
formatted with an appropriate **[file system][filesystem]**.

- **Boot Partition**: `Fat32` `nvme0n1p1`
- **Root Partition**: `Ext4` `nvme0n1p2`
- **Storage Disk**: `Ext4` `nvme1n1p1`

```sh
mkfs.fat -F 32 /dev/nvme0n1p1
mkfs.ext4 /dev/nvme0n1p2
mkfs.ext4 /dev/nvme1n1p1
```

### 1.6 MOUNT FILE SYSTEM

```sh
mount /dev/nvme0n1p2 /mnt
mount --mkdir /dev/nvme0n1p1 /mnt/boot
mount --mkdir /dev/nvme1n1p1 /mnt/data
```

## 2 INSTALLATION

### 2.1 SELECT MIRRORS

`vim /etc/pacman.d/mirrorlist`

```sh
Server = https://mirror.sg.gs/archlinux/$repo/os/$arch
Server = https://mirror.xtom.com.hk/archlinux/$repo/os/$arch
Server = http://mirror.xtom.com.hk/archlinux/$repo/os/$arch
Server = https://singapore.mirror.pkgbuild.com/archlinux/$repo/os/$arch
Server = https://taipei.mirror.pkgbuild.com/archlinux/$repo/os/$arch
Server = https://sg.arch.niranjan.co/archlinux/$repo/os/$arch
```

### 2.2 INSTALL PACKAGES

```sh
pacstrap -K /mnt base base-devel linux linux-firmware xorg-server \
mesa xf86-video-amdgpu vulkan-radeon amd-ucode git neovim \
networkmanager iwd bluez bluez-utils terminus-font cpupower \
zsh efibootmgr
```

## 3 SYSTEM CONFIGURATION

### 3.1 GENERATE FSTAB

> After generating `fstab`, Change entries of _boot partition_
> `vim /mnt/etc/fstab` to `fmask=0077` and `dmask=0077`. For `nvme1n1p1`
> set it as `UUID=<uuid> /data ext4 defaults,noatime 0 2`.

```sh
genfstab -U /mnt >> /mnt/etc/fstab
```

### 3.2 CHROOT

Chroot to the new system environment.

```sh
arch-chroot /mnt
```

### 3.3 DEPLOY SCRIPT

This ![deploy script](deploy.sh) configures the following:

- Time
- Locale
- Hosts
- Hostname
- Network
- Console Font
- Touchpad
- Keyboard
- Watchdog
- Battery
- CPU

[archlinux]: https://archlinux.org/
[dots]: https://gitlab.com/cipherodio/archdots
[qtile]: https://qtile.org/
[filesystem]: https://wiki.archlinux.org/title/File_systems
