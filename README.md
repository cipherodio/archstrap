# Arch Linux Installation

> [!WARNING]
>
> I am not responsible for any damages, loss of data, system corruption,
> or any mishap you may somehow cause by following this guide.

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
    - [1.2 CONNECT TO THE INTERNET](#12-connect-to-the-internet)
    - [1.3 UPDATE SYSTEM CLOCK](#13-update-system-clock)
    - [1.4 PARTITION DISK](#14-partition-disk)
        - [1.4.1 FIRST DISK](#141-first-disk)
            - [1.4.1.1 BOOT PARTITION](#1411-boot-partition)
            - [1.4.1.2 ROOT PARTITION](#1412-root-partition)
            - [1.4.1.3 EFI PARTITION TYPE](#1413-efi-partition-type)
        - [1.4.2 SECOND DISK](#142-second-disk)
            - [1.4.2.1 DATA](#1421-data)
    - [1.5 FORMAT DISK](#15-format-disk)
    - [1.6 MOUNT FILE SYSTEM](#16-mount-file-system)
- [2 INSTALLATION](#2-installation)
    - [2.1 SELECT MIRRORS](#21-select-mirrors)
    - [2.2 INSTALL PACKAGES](#22-install-packages)
- [3 SYSTEM CONFIGURATION](#3-system-configuration)
    - [3.1 GENERATE FSTAB](#31-generate-fstab)
    - [3.2 CHROOT](#32-chroot)
    - [3.3 DEPLOY SCRIPT](#33-deploy-script)
    - [3.4 ROOT PASSWORD](#34-root-password)
    - [3.5 MULTILIB](#35-multilib)
    - [3.6 USER AND OWNERSHIP](#36-user-and-ownership)
    - [3.7 REMOUNT AND SYSTEMD-BOOT](#37-remount-and-systemd-boot)
    - [3.8 LOADER SCRIPT](#38-loader-script)
    - [3.9 REBOOT](#39-reboot)
- [4 POST-INSTALLATION](#4-post-installation)
    - [4.1 USER LOGIN](#41-user-login)
    - [4.2 BOOTSTRAP SCRIPT](#42-bootstrap-script)
    - [4.3 SSH](#43-ssh)
    - [4.4 SETUP SCRIPT](#44-setup-script)

<!-- tocstop -->

## 1. PRE-INSTALLATION

### 1.1 CHANGE CONSOLE FONT

```sh
setfont ter-132b
```

### 1.2 CONNECT TO THE INTERNET

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

### 1.3 UPDATE SYSTEM CLOCK

```sh
timedatectl status
timedatectl set-ntp true
```

### 1.4 PARTITION DISK

Overview of my partition layout. Suggested size for the **EFI**
partition is **512MiB**, though **1GiB** is recommended for modern
systems.

| **Mount Point** | **Partition**  | **Partition Type**   | **Suggested Size**      |
| --------------- | -------------- | -------------------- | ----------------------- |
| /mnt/boot       | /dev/nvme0n1p1 | EFI System Partition | 512MiB                  |
| /mnt            | /dev/nvme0n1p2 | Linux File System    | Remainder of the device |
| /mnt/data       | /dev/nvme1n1p1 | Linux File System    | Everything              |

- **`wipefs -af /dev/nvme0n1`**: wipes existing partition table and
  signatures
- **`lsblk -f`**: checks disk
- **`fdisk  /dev/nvme0n1`**: command to partition drive using _fdisk_.

#### 1.4.1 FIRST DISK

Main disk for installation: `fdisk /dev/nvme0n1`.

##### 1.4.1.1 BOOT PARTITION

1. Type `g` to create a new **GPT** partition table
2. Type `n` for new partition.
3. On last sector set it to `+1G`.

##### 1.4.1.2 ROOT PARTITION

1. Type `n` for new partition.
2. All remainder of the device for last sector.

##### 1.4.1.3 EFI PARTITION TYPE

Change boot partition type to **EFI**.

1. Press `t` to change the partition type
2. Type `1` to select first created partition.
3. Type `1` to set it to `EFI` partition type.
4. Type `p` to check if all partitions were correct.
5. Type `w` to write changes and exit.

#### 1.4.2 SECOND DISK

Applicable only if you have second internal disk: `fdisk /dev/nvme1n1`.

##### 1.4.2.1 DATA

1. Type `g` to create a new **GPT** partition table
2. Type `n` for new partition.
3. All remainder of the device for last sector.
4. Type `p` to check if all partitions were correct.
5. Type `w` to write changes and exit.

### 1.5 FORMAT DISK

After the partitions are created, each partition must be formatted with
an appropriate **[file system][filesystem]**.

- **Boot Partition**: `FAT32` `nvme0n1p1`
- **Root Partition**: `ext4` `nvme0n1p2`
- **Storage Disk**: `ext4` `nvme1n1p1`

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

> After generating `fstab`, edit the file **before chrooting**:
>
> `vim /mnt/etc/fstab`
>
> - For the _boot partition_, add `fmask=0077` and `dmask=0077`.
> - For `nvme1n1p1`, set it as:
>   `UUID=<uuid> /data ext4 defaults,noatime 0 2`.

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

### 3.4 ROOT PASSWORD

```sh
passwd
```

### 3.5 MULTILIB

Add _entries_ and _uncomment_ line: `nvim /etc/pacman.conf`.

```sh
Color
VerbosePkgLists
ILoveCandy
ParallelDownloads = 2

[multilib]
Include = /etc/pacman.d/mirrorlist
```

### 3.6 USER AND OWNERSHIP

```sh
useradd -m -G users,wheel,video,render,audio,power,input,storage -s /bin/zsh cipherodio
passwd cipherodio

chown -R cipherodio:cipherodio /data

# Sudoers
EDITOR=nvim visudo -f /etc/sudoers.d/00_cipherodio

# Add:
cipherodio ALL=(ALL) ALL
```

### 3.7 REMOUNT AND SYSTEMD-BOOT

Remount the filesystem to avoid potential errors with `bootctl install`.

```sh
exit
umount -R /mnt
mount /dev/nvme0n1p2 /mnt
arch-chroot /mnt
mount -a

bootctl install
```

### 3.8 LOADER SCRIPT

This ![loader script](loader.sh) configures the following:

- Configure entries in: `/boot/loader/loader.conf`
- Add loader entries: `/boot/loader/entries/arch.conf`

```sh
curl -fsSL https://gitlab.com/cipherodio/archstrap/-/raw/main/loader.sh | bash
```

### 3.9 REBOOT

Exit chroot, unmount drives, and reboot.

```sh
exit
umount -R /mnt
reboot
```

## 4 POST-INSTALLATION

### 4.1 USER LOGIN

Log in as user **cipherodio**, connect to the internet, and update the
system.

```sh
nmtui
sudo pacman -Syu
```

### 4.2 BOOTSTRAP SCRIPT

This ![bootstrap script](bootstrap.sh) configures the following:

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

### 4.3 SSH

Add SSH key to [GitLab][gitlab]

```sh
cat ~/.ssh/githubkey.pub | xclip -selection clipboard
```

### 4.4 SETUP SCRIPT

This ![setup script](setup.sh) configures the following:

- User directories
- GnuPG Permissions
- Cloning Projects
- NPM package
- Firefox user.js and chrome CSS
- Set dotfiles git remote

```sh
curl -fsSL https://gitlab.com/cipherodio/archstrap/-/raw/main/setup.sh | bash
```

[archlinux]: https://archlinux.org/
[dots]: https://gitlab.com/cipherodio/archdots
[qtile]: https://qtile.org/
[filesystem]: https://wiki.archlinux.org/title/File_systems
[gitlab]: https://gitlab.com/
