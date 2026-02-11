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

## Chroot

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
