Archvault
=========

<table>
  <tr>
    <td>Last tested</td>
    <td>2018-08-01 with <a href="https://www.archlinux.org/releng/releases/2018.08.01/">archlinux-2018.08.01-x86_64.iso</a></td>
  </tr>
</table>

Bootstrap Arch with FDE


Description
-----------

### Overview

Archvault bootstraps Arch with whole system Btrfs on LUKS
using the official [installation guide][installation guide] and
[arch-install-scripts][arch-install-scripts].

Archvault works on Arch with Intel or AMD x86-64 CPU. It assumes you
are comfortable working on the cmdline, and that you have no need for
booting any other operating systems on the target partition.

**WARNING**: failure to give appropriate values during Archvault setup
could cause catastrophic data loss and system instability.

### Features

- whole system Btrfs on LUKS, including encrypted `/boot`
- [GPT][GPT] partitioning
- no swap partition, uses [zram][zram]
  via [systemd-swap][systemd-swap] (see:
  [resources/etc/systemd/swap.conf.d/zram.conf](resources/etc/systemd/swap.conf.d/zram.conf))
- [GRUB][GRUB] bootloader with both legacy BIOS and UEFI support
- custom GRUB command line username and password
- custom root, admin, guest, and SFTP user account passwords
- configures [OpenSSH][OpenSSH]
  - SFTP-only user enforced with OpenSSH
    `ChrootDirectory` and `ForceCommand internal-sftp` (see:
    [resources/etc/ssh/sshd_config](resources/etc/ssh/sshd_config))
  - limits incoming `sshd` connections to SFTP-only user on LAN (see:
    [resources/etc/hosts.allow](resources/etc/hosts.allow))
- uses [nftables][nftables] instead of iptables
- configures kernel parameters with [Sysctl][Sysctl] (see:
  [resources/etc/sysctl.d/99-sysctl.conf](resources/etc/sysctl.d/99-sysctl.conf))
- blacklists kernel modules for floppy drives, beeping speakers, Intel
  ME, firewire, bluetooth and thunderbolt (see:
  [resources/etc/modprobe.d/modprobe.conf](resources/etc/modprobe.d/modprobe.conf))
- configures [dnscrypt-proxy][dnscrypt-proxy]
  - server must support DNS security extensions (DNSSEC)
  - always use TCP to connect to upstream servers
  - create new, unique key for each DNS query
  - disable TLS session tickets
  - disable DNS cache
- forces password entry with every `sudo`
  - passwordless `sudo reboot` and `sudo shutdown`
- ten minute shell timeout, your current shell or user
  session will end after ten minutes of inactivity (see:
  [resources/etc/profile.d/shell-timeout.sh](resources/etc/profile.d/shell-timeout.sh))
- [hides process information][hides process information] from all other
  users besides admin
- [denies console login as root][denies console login as root]
- uses mq-deadline I/O scheduler for SSDs, BFQ for HDDs (see:
  [resources/etc/udev/rules.d/60-io-schedulers.rules](resources/etc/udev/rules.d/60-io-schedulers.rules))
- disables hibernate, sleep, suspend (see:
  [resources/etc/systemd/sleep.conf](resources/etc/systemd/sleep.conf))
- enables systemd service for dnscrypt-proxy, nftables and systemd-swap
- configures [Xorg][Xorg], but does not install any Xorg packages (see:
  [resources/etc/X11](resources/etc/X11))

### Filesystem

- `/dev/sdX1` is the BIOS boot sector (size: 2MB)
- `/dev/sdX2` is the EFI system partition (size: 100MB)
- `/dev/sdX3` is the root Btrfs filesystem on LUKS (size: remainder)

Archvault creates the following Btrfs subvolumes with a [flat layout][flat
layout]:

Subvolume name       | Mounting point
---                  | ---
`@`                  | `/`
`@boot`              | `/boot`
`@home`              | `/home`
`@opt`               | `/opt`
`@srv`               | `/srv`
`@usr`               | `/usr`
`@var`               | `/var`
`@var-cache-pacman`  | `/var/cache/pacman`
`@var-lib-ex`        | `/var/lib/ex`
`@var-lib-machines`  | `/var/lib/machines`
`@var-lib-portables` | `/var/lib/portables`
`@var-lib-postgres`  | `/var/lib/postgres`
`@var-log`           | `/var/log`
`@var-opt`           | `/var/opt`
`@var-spool`         | `/var/spool`
`@var-tmp`           | `/var/tmp`

Archvault [disables Btrfs CoW][disables Btrfs CoW] on `/home`,
`/srv`, `/var/lib/ex`, `/var/lib/machines`, `/var/lib/portables`,
`/var/lib/postgres`, `/var/log`, `/var/spool` and `/var/tmp`.

Archvault mounts directories `/srv`, `/tmp`, `/var/lib/ex`, `/var/log`,
`/var/spool` and `/var/tmp` with options `nodev,noexec,nosuid`.


Synopsis
--------

### `archvault new`

Bootstrap Archvault.

**Supply options interactively (recommended)**:

```sh
archvault new
```

**Supply options via environment variables**:

```sh
export ARCHVAULT_ADMIN_NAME="live"
export ARCHVAULT_ADMIN_PASS="your admin user's password"
archvault new
```

Archvault recognizes the following environment variables:

```sh
ARCHVAULT_ADMIN_NAME="live"
ARCHVAULT_ADMIN_PASS="your admin user's password"
ARCHVAULT_ADMIN_PASS_HASH='$6$rounds=700000$sleJxKNAgRnG7E8s$Fjg0/vuRz.GgF0FwDE04gP2i6oMq/Y4kodb1RLTbR3SpABVDKGdhCVfLpC5LwCOXDMEU.ylyV40..jrGmI.4N0'
ARCHVAULT_GUEST_NAME="guest"
ARCHVAULT_GUEST_PASS="your guest user's password"
ARCHVAULT_GUEST_PASS_HASH='$6$rounds=700000$H0WWMRVAqKMmJVUx$X9NiHaL.cvZ1/nQzUL5fcRP12wvOyrZ/0YV57cFddcTEkVZKbtIBv48EEd4SVu.1D5RWVX43dfTuyudYem0gf0'
ARCHVAULT_SFTP_NAME="variable"
ARCHVAULT_SFTP_PASS="your sftp user's password"
ARCHVAULT_SFTP_PASS_HASH='$6$rounds=700000$H0WWMRVAqKMmJVUx$X9NiHaL.cvZ1/nQzUL5fcRP12wvOyrZ/0YV57cFddcTEkVZKbtIBv48EEd4SVu.1D5RWVX43dfTuyudYem0gf0'
ARCHVAULT_GRUB_NAME="grub"
ARCHVAULT_GRUB_PASS="your grub user's password"
ARCHVAULT_GRUB_PASS_HASH='grub.pbkdf2.sha512.25000.4A7BC4FE022FA7E7D32B0B132B4AA5A61A63C8076FF6A8AF38C718FF334772E499F45D186C9EECF3622E7BA24B02C24F283261AE2D18163D54FD2CAF7FF3F7B7610F85AAB2BB7BAF806EF381B73730D5032E9CF75548C8BA1813B62121DC29A75E677ED6.5C1B9525BDE9F79A90221DC423AA66D1108731C8F2F5B0A9DC74279562242F05A8CCA4522706A2A74308B272EC05D0ACC1DCDA7263B09BF2F4C006623B3CEC842AC061B6D73B09A0067B23E9BF8560F053F940D5061F413C23C9F4544FDFC3F9BD026FB7'
ARCHVAULT_ROOT_PASS="your root password"
ARCHVAULT_ROOT_PASS_HASH='$6$rounds=700000$xDn3UJKNvfOxJ1Ds$YEaaBAvQQgVdtV7jFfVnwmh57Do1awMh8vTBtI1higrZMAXUisX2XKuYbdTcxgQMleWZvK3zkSJQ4F3Jyd5Ln1'
ARCHVAULT_VAULT_NAME="vault"
ARCHVAULT_VAULT_PASS="your LUKS encrypted volume's password"
ARCHVAULT_HOSTNAME="vault"
ARCHVAULT_PARTITION="/dev/sdb"
ARCHVAULT_PROCESSOR="other"
ARCHVAULT_GRAPHICS="intel"
ARCHVAULT_DISK_TYPE="usb"
ARCHVAULT_LOCALE="en_US"
ARCHVAULT_KEYMAP="us"
ARCHVAULT_TIMEZONE="America/Los_Angeles"
ARCHVAULT_AUGMENT=1
```

**Supply options via cmdline flags**:

```sh
archvault --admin-name="live"                                  \
          --admin-pass="your admin user's password"            \
          --guest-name="guest"                                 \
          --guest-pass="your guest user's password"            \
          --sftp-name="variable"                               \
          --sftp-pass="your sftp user's password"              \
          --grub-name="grub"                                   \
          --grub-pass="your grub user's password"              \
          --root-pass="your root password"                     \
          --vault-name="vault"                                 \
          --vault-pass="your LUKS encrypted volume's password" \
          --hostname="vault"                                   \
          --partition="/dev/sdb"                               \
          --processor="other"                                  \
          --graphics="intel"                                   \
          --disk-type="usb"                                    \
          --locale="en_US"                                     \
          --keymap="us"                                        \
          --timezone="America/Los_Angeles"                     \
          --augment                                            \
          new
```

### `archvault gen-pass-hash`

Generate a password hash suitable for creating Linux user accounts or
password-protecting the GRUB command line.

```sh
archvault gen-pass-hash
Enter new password:
Retype new password:
$6$rounds=700000$sleJxKNAgRnG7E8s$Fjg0/vuRz.GgF0FwDE04gP2i6oMq/Y4kodb1RLTbR3SpABVDKGdhCVfLpC5LwCOXDMEU.ylyV40..jrGmI.4N0
```

An example of using the generated hash with Archvault:

```sh
archvault                                                                                                                                      \
  --admin-name='live'                                                                                                                          \
  --admin-pass-hash='$6$rounds=700000$sleJxKNAgRnG7E8s$Fjg0/vuRz.GgF0FwDE04gP2i6oMq/Y4kodb1RLTbR3SpABVDKGdhCVfLpC5LwCOXDMEU.ylyV40..jrGmI.4N0' \
  new
```

### `archvault ls`

List system information including keymaps, locales, timezones, and
partitions.

It's recommended to run `archvault ls <keymaps|locales|timezones>`
before running `archvault new` to ensure Archvault types
`Keymap`, `Locale`, `Timezone` are working properly (see:
[doc/TROUBLESHOOTING.md](doc/TROUBLESHOOTING.md#archvault-type-errors)).

**List keymaps**:

```sh
archvault ls keymaps
```

**List locales**:

```sh
archvault ls locales
```

**List partitions**:

```sh
archvault ls partitions
```

**List timezones**:

```sh
archvault ls timezones
```

### `archvault disable-cow`

Disable the Copy-on-Write attribute for Btrfs directories.

```sh
archvault -r disable-cow dest/
```


Installation
------------

See: [INSTALL.md](INSTALL.md).


Dependencies
------------

Name                 | Provides                                           | Included in Arch ISO¹?
---                  | ---                                                | ---
arch-install-scripts | `arch-chroot`, `genfstab`, `pacstrap`              | Y
btrfs-progs          | Btrfs support                                      | Y
coreutils            | `chmod`, `chown`, `cp`, `rm`                       | Y
cryptsetup           | FDE with LUKS                                      | Y
dosfstools           | create VFAT filesystem for UEFI with `mkfs.vfat`   | Y
e2fsprogs            | `chattr`                                           | Y
efibootmgr           | UEFI support                                       | Y
expect               | interactive command prompt automation              | N
glibc                | libcrypt, locale data in `/usr/share/i18n/locales` | Y
gptfdisk             | GPT disk partitioning with `sgdisk`                | Y
grub                 | FDE on `/boot`, `grub-mkpasswd-pbkdf2`             | Y
haveged              | entropy for `pacman-key`                           | Y
kbd                  | keymap data in `/usr/share/kbd/keymaps`, `setfont` | Y
kmod                 | `modprobe`                                         | Y
openssl              | user password salts                                | Y
pacman               | `makepkg`, `pacman`, `pacman-key`                  | Y
procps-ng            | `pkill`                                            | Y
rakudo               | `archvault` Perl6 runtime                          | N
tzdata               | timezone data in `/usr/share/zoneinfo/zone.tab`    | Y
util-linux           | `hwclock`, `lsblk`, `mkfs`, `mount`, `umount`      | Y

¹: the [official installation medium](https://www.archlinux.org/download/)


Optional Dependencies
---------------------

Name      | Provides                | Included in Arch ISO?
---       | ---                     | ---
dialog    | ncurses user input menu | Y
reflector | optimize pacman mirrors | N

`dialog` is needed if you do not provide by cmdline flag or environment
variable values for all configuration options aside from:

- `--admin-name`
- `--admin-pass`
- `--admin-pass-hash`
- `--augment`
- `--grub-name`
- `--grub-pass`
- `--grub-pass-hash`
- `--guest-name`
- `--guest-pass`
- `--guest-pass-hash`
- `--hostname`
- `--reflector`
- `--root-pass`
- `--root-pass-hash`
- `--sftp-name`
- `--sftp-pass`
- `--sftp-pass-hash`
- `--vault-name`
- `--vault-pass`

For these options, console input is read with either `cryptsetup` or
the built-in Perl6 subroutine `prompt()`.

No console input is read for configuration options:

- `--admin-pass-hash`
- `--augment`
- `--grub-pass-hash`
- `--guest-pass-hash`
- `--reflector`
- `--root-pass-hash`
- `--sftp-pass-hash`

For user input of all other options, the `dialog` program is used.

`reflector` is needed if you provide by cmdline flag or environment
variable a value for the `--reflector` configuration option. The
reflector configuration option is not enabled by default. You are
recommended to select the fastest pacman mirrors for your location
by hand in `/etc/pacman.d/mirrorlist` instead of enabling `reflector`
to save several minutes of time.


Licensing
---------

This is free and unencumbered public domain software. For more
information, see http://unlicense.org/ or the accompanying UNLICENSE file.


[arch-install-scripts]: https://git.archlinux.org/arch-install-scripts.git
[denies console login as root]: https://wiki.archlinux.org/index.php/Security#Denying_console_login_as_root
[disables Btrfs CoW]: https://wiki.archlinux.org/index.php/Btrfs#Disabling_CoW
[dnscrypt-proxy]: https://wiki.archlinux.org/index.php/DNSCrypt
[flat layout]: https://btrfs.wiki.kernel.org/index.php/SysadminGuide#Layout
[GPT]: https://wiki.archlinux.org/index.php/Partitioning#GUID_Partition_Table
[GRUB]: https://wiki.archlinux.org/index.php/GRUB
[hides process information]: https://wiki.archlinux.org/index.php/Security#hidepid
[installation guide]: https://wiki.archlinux.org/index.php/Installation_guide
[nftables]: https://wiki.archlinux.org/index.php/nftables
[OpenSSH]: https://wiki.archlinux.org/index.php/Secure_Shell
[Sysctl]: https://wiki.archlinux.org/index.php/Sysctl
[systemd-swap]: https://github.com/Nefelim4ag/systemd-swap
[Xorg]: https://wiki.archlinux.org/index.php/Xorg
[zram]: https://www.kernel.org/doc/Documentation/blockdev/zram.txt

<!-- vim: set filetype=markdown foldmethod=marker foldlevel=0 nowrap: -->
