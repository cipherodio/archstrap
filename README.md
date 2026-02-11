# Arch Linux Bootstrap Quick Notes

This guide summarizes the key steps for installing Arch Linux with your
custom scripts and dotfiles.

Target system:

- AMD CPU
- systemd-boot
- NetworkManager + iwd backend
- ASUS battery limit rule

```sh
Start Arch ISO
     │
     ▼
Partition & Mount Drives
     │
     ▼
arch-chroot /mnt
     │
     ▼
┌───────────────────────────┐
│ Run deploy.sh             │
│ (time, locale, hostname,  │
│ network, console font,    │
│ touchpad, keyboard,       │
│ watchdog, battery, CPU)   │
└───────────────────────────┘
     │
     ▼
Set root password (passwd)
     │
     ▼
Edit pacman.conf (multilib etc.)
     │
     ▼
Create user, sudoers, chown /data
     │
     ▼
Remount partitions → bootctl install
     │
     ▼
┌───────────────────────────┐
│ Run loader.sh             │
│ (systemd-boot loader.conf │
│ + arch.conf with root UUID│
│ and boot options)         │
└───────────────────────────┘
     │
     ▼
Exit chroot → Umount → Reboot
     │
     ▼
Login as user → Install dotfiles
```

## Pre-installation

1. Set font `setfont ter-132b`
2. Connect to the internet.

```sh
iwctl
[iwd]$ device list
[iwd]$ station wlan0 scan
[iwd]$ station wlan0 get-networks
[iwd]$ station wlan0 connect MyWifiNetwork
```

3. Update system clock

```sh
timedatectl status
timedatectl set-ntp true
```

4. Partition drives Wipe existing drive partition:
   `wipefs -af /dev/nvme0n1`. Check disk with `lsblk -f`, then use
   `fdisk /dev/nvme0n1` to partition drives.
    - Boot partition
        - Type `g` to set it on **GPT** disklabel.
        - Type `n` for new partition.
        - On last sector set it to `+1G`.
    - Root partition
        - Type `n` for new partition.
        - All remainder of the device for last sector.
    - Change boot partition type to **EFI**
        - Press `t` for disklabel specified type.
        - Type `1` to select first created partition.
        - Type `1` to set it to `EFI` partition type.
        - Type `p` to check if all partitions were correct.
        - Type `w` to write changes and exit.
    - Data Storage: do `fdisk /dev/nvme1n1`
        - Type `g` to set it on **GPT** disklabel.
        - Type `n` for new partition.
        - All remainder of the device for last sector.
        - Type `p` to check if all partitions were correct.
        - Type `w` to write changes and exit.

5. Format drives

```sh
mkfs.fat -F 32 /dev/nvme0n1p1
mkfs.ext4 /dev/nvme0n1p2
mkfs.ext4 /dev/nvme1n1p1
```

6. Mount

```sh
mount /dev/nvme0n1p2 /mnt
mount --mkdir /dev/nvme0n1p1 /mnt/boot
mount --mkdir /dev/nvme1n1p1 /mnt/data
```

## Installation

1. Select mirrors `vim /etc/pacman.d/mirrorlist`

```sh
Server = https://mirror.sg.gs/archlinux/$repo/os/$arch
Server = https://mirror.xtom.com.hk/archlinux/$repo/os/$arch
Server = http://mirror.xtom.com.hk/archlinux/$repo/os/$arch
Server = https://singapore.mirror.pkgbuild.com/archlinux/$repo/os/$arch
Server = https://taipei.mirror.pkgbuild.com/archlinux/$repo/os/$arch
Server = https://sg.arch.niranjan.co/archlinux/$repo/os/$arch
```

2. Install essential packages.

```sh
pacstrap -K /mnt base base-devel linux linux-firmware xorg-server \
mesa xf86-video-amdgpu vulkan-radeon amd-ucode git neovim \
networkmanager iwd bluez bluez-utils terminus-font cpupower \
zsh efibootmgr
```

3. Generate Fstab

```sh
genfstab -U /mnt >> /mnt/etc/fstab
```

> After generating `fstab`, Change entries of _boot partition_
> `vim /mnt/etc/fstab` to `fmask=0077` and `dmask=0077`. For `nvme1n1p1`
> set it as `UUID=<uuid> /data ext4 defaults,noatime 0 2`.

## Chroot

```sh
arch-chroot /mnt
```

1. Run `deploy.sh` after `arch-chroot /mnt`

```sh
curl -fsSL https://gitlab.com/cipherodio/archstrap/-/raw/main/deploy.sh | bash
```

2. After that, set root password `passwd`
3. Edit `nvim /etc/pacman.conf`

```sh
Color
VerbosePkgLists
ILoveCandy
ParallelDownloads = 2

[multilib]
Include = /etc/pacman.d/mirrorlist
```

4. Create user, sudoers, and set ownership.

```sh
useradd -m -G users,wheel,video,render,audio,power,input,storage -s /bin/zsh cipherodio
passwd cipherodio

chown -R cipherodio:cipherodio /data

# Sudoers
EDITOR=nvim visudo -f /etc/sudoers.d/00_cipherodio

# Add:
cipherodio ALL=(ALL) ALL
```

5. Do `mount /dev/<root-partition> /mnt` to avoid `bootctl` errors.

```sh
exit
umount -R /mnt
mount /dev/nvme0n1p2 /mnt
arch-chroot /mnt
mount -a

bootctl install
```

6. Run `loader.sh` to configure **systemd-boot**.

```sh
curl -fsSL https://gitlab.com/cipherodio/archstrap/-/raw/main/loader.sh | bash
```

7. Exit chroot, unmount drives, and reboot.

```sh
exit
umount -R /mnt
reboot
```

## Post-installation

1. Login as user **cipherodio** and update the system.

```sh
# Connect to the internet
nmtui
sudo pacman -Syu
```

2. Install **packages** and **dotfiles**.

```sh
curl -fsSL https://gitlab.com/cipherodio/archstrap/-/raw/main/bootstrap.sh | bash
reboot
```

3. Copy **SSH** key to **Gitlab**

```sh
cat ~/.ssh/gitlabkey.pub | xclip -selection clipboard
```

4. Run `setup.sh`

```sh
curl -fsSL https://gitlab.com/cipherodio/archstrap/-/raw/main/setup.sh | bash
```
