Voidvault
=========

Last tested | ISO                                                             | Result
----------- | --------------------------------------------------------------- | ------
2021-11-08  | [void-live-x86_64-20210930.iso][void-live-iso-x86_64-glibc]     | PASS
2021-11-08  | [void-live-x86_64-musl-20210930.iso][void-live-iso-x86_64-musl] | PASS
2021-11-08  | [void-live-i686-20210930.iso][void-live-iso-i686-glibc]         | PASS


Bootstrap Void with FDE


Description
-----------

### Overview

Voidvault bootstraps Void with whole system Btrfs on LUKS.

Voidvault works on Void with Intel or AMD x86 CPU. It assumes you are
comfortable working on the cmdline, and that you have no need for booting
any other operating systems on the target block device.

**WARNING**: failure to give appropriate values during Voidvault setup
could cause catastrophic data loss and system instability.

### Features

- whole system Btrfs on LUKS, including encrypted `/boot`
- [runit][runit] PID 1
- [GPT][GPT] partitioning
- no swap partition, uses [zram][zram] via [zramen][zramen]
- [GRUB][GRUB] bootloader with both legacy BIOS and UEFI support
- custom GRUB command line username and password
- custom root, admin, guest, and SFTP user account passwords
- custom repository selection for `xbps-install` (optional)
- adds randomized key to LUKS volume for [double password entry
  avoidance][double password entry avoidance] on boot
- configures [OpenSSH][OpenSSH]
  - SFTP-only user enforced with OpenSSH
    `ChrootDirectory` and `ForceCommand internal-sftp` (see:
    [resources/etc/ssh/sshd_config](resources/etc/ssh/sshd_config))
- uses [nftables][nftables] instead of iptables (see:
  [resources/etc/nftables.conf](resources/etc/nftables.conf))
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
  - unconditionally use fallback resolver
  - wait up to 7 minutes for network connectivity at startup
  - disable DNS cache
  - modify `/etc/resolv.conf` (see:
    [resources/etc/resolvconf.conf](resources/etc/resolvconf.conf))
- forces password entry with every `sudo`
  - passwordless `sudo reboot` and `sudo shutdown`
- ten minute shell timeout, your current shell or user
  session will end after ten minutes of inactivity (see:
  [resources/etc/profile.d/shell-timeout.sh](resources/etc/profile.d/shell-timeout.sh))
- [hides process information][hidepid] from all other users besides admin
- [denies console login as root][denies console login as root]
- disables GRUB recovery mode
- uses mq-deadline I/O scheduler for SSDs, BFQ for HDDs (see:
  [resources/etc/udev/rules.d/60-io-schedulers.rules](resources/etc/udev/rules.d/60-io-schedulers.rules))
- enables runit service for dnscrypt-proxy, nftables and socklog
- configures [Xorg][Xorg], but does not install any Xorg packages (see:
  [resources/etc/X11](resources/etc/X11))
- optionally disables IPv6, and makes IPv4-only adjustments to dhcpcd,
  dnscrypt-proxy, openresolv, OpenSSH

### Filesystem

- `/dev/sdX1` is the BIOS boot sector (size: 2M)
- `/dev/sdX2` is the EFI system partition (size: [550M][550M])
- `/dev/sdX3` is the root Btrfs filesystem on LUKS (size: remainder)

Voidvault creates the following Btrfs subvolumes with a [flat layout][flat
layout]:

Subvolume name    | Mounting point    | Mount options
---               | ---               | ---
`@`               | `/`               |
`@home`           | `/home`           | `nodev,nosuid`
`@opt`            | `/opt`            | `nodev`
`@srv`            | `/srv`            | `nodev,noexec,nosuid` + [nodatacow][nodatacow]¹
`@var`            | `/var`            | `nodev,noexec,nosuid`
`@var-cache-xbps` | `/var/cache/xbps` | `nodev,noexec,nosuid`
`@var-lib-ex`     | `/var/lib/ex`     | `nodev,noexec,nosuid` + nodatacow
`@var-log`        | `/var/log`        | `nodev,noexec,nosuid` + nodatacow
`@var-opt`        | `/var/opt`        | `nodev,noexec,nosuid`
`@var-spool`      | `/var/spool`      | `nodev,noexec,nosuid` + nodatacow
`@var-tmp`        | `/var/tmp`        | `nodev,noexec,nosuid` + nodatacow

¹: via `chattr -R +C`, not mount options

Additionally, Voidvault mounts the following directories with [protective
mount options][protective mount options]:

Directory    | Mount options
---          | ---
`/boot`      | `nodev,noexec,nosuid`
`/boot/efi`  | `nodev,nosuid`
`/etc`       | `nodev,nosuid`
`/mnt`       | `nodev`
`/proc`      | `nodev,noexec,nosuid` + [hidepid][hidepid]
`/root`      | `nodev`
`/tmp`       | `nodev,noexec,nosuid`
`/usr`       | `nodev`
`/usr/lib`   | `nodev,nosuid`
`/usr/lib32` | `nodev,nosuid`


Synopsis
--------

### `voidvault new`

Bootstrap Voidvault. Must be run as root.

**Supply options interactively (recommended)**:

```sh
voidvault new
```

**Supply options via environment variables**:

```sh
export VOIDVAULT_ADMIN_NAME="live"
export VOIDVAULT_ADMIN_PASS="your admin user's password"
voidvault new
```

Voidvault recognizes the following environment variables:

```sh
VOIDVAULT_ADMIN_NAME="live"
VOIDVAULT_ADMIN_PASS="your admin user's password"
VOIDVAULT_ADMIN_PASS_HASH='$6$rounds=700000$sleJxKNAgRnG7E8s$Fjg0/vuRz.GgF0FwDE04gP2i6oMq/Y4kodb1RLTbR3SpABVDKGdhCVfLpC5LwCOXDMEU.ylyV40..jrGmI.4N0'
VOIDVAULT_GUEST_NAME="guest"
VOIDVAULT_GUEST_PASS="your guest user's password"
VOIDVAULT_GUEST_PASS_HASH='$6$rounds=700000$H0WWMRVAqKMmJVUx$X9NiHaL.cvZ1/nQzUL5fcRP12wvOyrZ/0YV57cFddcTEkVZKbtIBv48EEd4SVu.1D5RWVX43dfTuyudYem0gf0'
VOIDVAULT_SFTP_NAME="variable"
VOIDVAULT_SFTP_PASS="your sftp user's password"
VOIDVAULT_SFTP_PASS_HASH='$6$rounds=700000$H0WWMRVAqKMmJVUx$X9NiHaL.cvZ1/nQzUL5fcRP12wvOyrZ/0YV57cFddcTEkVZKbtIBv48EEd4SVu.1D5RWVX43dfTuyudYem0gf0'
VOIDVAULT_GRUB_NAME="grub"
VOIDVAULT_GRUB_PASS="your grub user's password"
VOIDVAULT_GRUB_PASS_HASH='grub.pbkdf2.sha512.25000.4A7BC4FE022FA7E7D32B0B132B4AA5A61A63C8076FF6A8AF38C718FF334772E499F45D186C9EECF3622E7BA24B02C24F283261AE2D18163D54FD2CAF7FF3F7B7610F85AAB2BB7BAF806EF381B73730D5032E9CF75548C8BA1813B62121DC29A75E677ED6.5C1B9525BDE9F79A90221DC423AA66D1108731C8F2F5B0A9DC74279562242F05A8CCA4522706A2A74308B272EC05D0ACC1DCDA7263B09BF2F4C006623B3CEC842AC061B6D73B09A0067B23E9BF8560F053F940D5061F413C23C9F4544FDFC3F9BD026FB7'
VOIDVAULT_ROOT_PASS="your root password"
VOIDVAULT_ROOT_PASS_HASH='$6$rounds=700000$xDn3UJKNvfOxJ1Ds$YEaaBAvQQgVdtV7jFfVnwmh57Do1awMh8vTBtI1higrZMAXUisX2XKuYbdTcxgQMleWZvK3zkSJQ4F3Jyd5Ln1'
VOIDVAULT_VAULT_NAME="vault"
VOIDVAULT_VAULT_PASS="your LUKS encrypted volume's password"
VOIDVAULT_DEVICE="/dev/sda"
VOIDVAULT_HOSTNAME="vault"
VOIDVAULT_PROCESSOR="other"
VOIDVAULT_GRAPHICS="intel"
VOIDVAULT_DISK_TYPE="usb"
VOIDVAULT_LOCALE="en_US"
VOIDVAULT_KEYMAP="us"
VOIDVAULT_TIMEZONE="America/Los_Angeles"
VOIDVAULT_REPOSITORY="/path/to/void/repository"
VOIDVAULT_IGNORE_CONF_REPOS=1
VOIDVAULT_PACKAGES="space separated list of packages"
VOIDVAULT_AUGMENT=1
VOIDVAULT_DISABLE_IPV6=1
VOIDVAULT_ENABLE_SERIAL_CONSOLE=1
VOIDVAULT_CHROOT_DIR="/mnt"
```

**Supply options via cmdline flags**:

```sh
voidvault --admin-name="live"                                  \
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
          --device="/dev/sda"                                  \
          --hostname="vault"                                   \
          --processor="other"                                  \
          --graphics="intel"                                   \
          --disk-type="usb"                                    \
          --locale="en_US"                                     \
          --keymap="us"                                        \
          --timezone="America/Los_Angeles"                     \
          --repository="/path/to/void/repository"              \
          --ignore-conf-repos                                  \
          --augment                                            \
          new
```

### `voidvault gen-pass-hash`

Generate a password hash suitable for creating Linux user accounts or
password-protecting the GRUB command line.

```sh
voidvault gen-pass-hash
Enter new password:
Retype new password:
$6$rounds=700000$sleJxKNAgRnG7E8s$Fjg0/vuRz.GgF0FwDE04gP2i6oMq/Y4kodb1RLTbR3SpABVDKGdhCVfLpC5LwCOXDMEU.ylyV40..jrGmI.4N0
```

An example of using the generated hash with Voidvault:

```sh
voidvault                                                                                                                                      \
  --admin-name='live'                                                                                                                          \
  --admin-pass-hash='$6$rounds=700000$sleJxKNAgRnG7E8s$Fjg0/vuRz.GgF0FwDE04gP2i6oMq/Y4kodb1RLTbR3SpABVDKGdhCVfLpC5LwCOXDMEU.ylyV40..jrGmI.4N0' \
  new
```

### `voidvault ls`

List system information including devices, keymaps, locales, and
timezones.

It's recommended to run `voidvault ls <keymaps|locales|timezones>`
before running `voidvault new` to ensure Voidvault types
`Keymap`, `Locale`, `Timezone` are working properly (see:
[doc/TROUBLESHOOTING.md](doc/TROUBLESHOOTING.md#voidvault-type-errors)).

**List devices**:

```sh
voidvault ls devices
```

**List keymaps**:

```sh
voidvault ls keymaps
```

**List locales**:

```sh
voidvault ls locales
```

**List timezones**:

```sh
voidvault ls timezones
```

### `voidvault disable-cow`

Disable the Copy-on-Write attribute for Btrfs directories.

```sh
voidvault -r disable-cow dest/
```


Installation
------------

See: [INSTALL.md](INSTALL.md).


Dependencies
------------

Name        | Provides                                                 | Included in Void ISO²?
---         | ---                                                      | ---
btrfs-progs | Btrfs support                                            | Y
coreutils   | `chmod`, `chown`, `chroot`, `cp`, `rm`                   | Y
cryptsetup  | FDE with LUKS                                            | Y
dosfstools  | create VFAT filesystem for UEFI with `mkfs.vfat`         | Y
e2fsprogs   | `chattr`                                                 | Y
efibootmgr  | UEFI support                                             | Y
expect      | interactive command prompt automation                    | N
glibc³      | libcrypt, locale data in `/usr/share/i18n/locales`       | Y
gptfdisk    | GPT disk partitioning with `sgdisk`                      | N
grub        | FDE on `/boot`, `grub-mkpasswd-pbkdf2`                   | Y
kbd         | keymap data in `/usr/share/kbd/keymaps`, `setfont`       | Y
kmod        | `modprobe`                                               | Y
musl³       | libcrypt                                                 | Y
openssl     | user password salts                                      | Y
procps-ng   | `pkill`                                                  | Y
rakudo      | `voidvault` Raku runtime                                 | N
tzdata      | timezone data in `/usr/share/zoneinfo/zone.tab`          | Y
util-linux  | `hwclock`, `lsblk`, `mkfs`, `mount`, `umount`, `unshare` | Y
xbps        | `xbps-install`, `xbps-query`, `xbps-reconfigure`         | Y

²: the [official installation medium](https://voidlinux.org/download/)

³: glibc or musl


Optional Dependencies
---------------------

Name      | Provides                | Included in Void ISO?
---       | ---                     | ---
dialog    | ncurses user input menu | Y

`dialog` is needed if you do not provide by cmdline flag or environment
variable values for all configuration options aside from:

- `--admin-name`
- `--admin-pass-hash`
- `--admin-pass`
- `--augment`
- `--chroot-dir`
- `--disable-ipv6`
- `--enable-serial-console`
- `--grub-name`
- `--grub-pass-hash`
- `--grub-pass`
- `--guest-name`
- `--guest-pass-hash`
- `--guest-pass`
- `--hostname`
- `--ignore-conf-repos`
- `--packages`
- `--repository`
- `--root-pass-hash`
- `--root-pass`
- `--sftp-name`
- `--sftp-pass-hash`
- `--sftp-pass`
- `--vault-name`
- `--vault-pass`
- `--vault-key-file`
- `--vault-cipher`
- `--vault-hash`
- `--vault-iter-time`
- `--vault-key-size`
- `--vault-offset`
- `--vault-sector-size`

For these options, console input is read with either `cryptsetup` or
the built-in Raku subroutine `prompt()`.

No console input is read for configuration options:

- `--admin-pass-hash`
- `--augment`
- `--chroot-dir`
- `--disable-ipv6`
- `--enable-serial-console`
- `--grub-pass-hash`
- `--guest-pass-hash`
- `--ignore-conf-repos`
- `--packages`
- `--repository`
- `--root-pass-hash`
- `--sftp-pass-hash`
- `--vault-key-file`
- `--vault-cipher`
- `--vault-hash`
- `--vault-iter-time`
- `--vault-key-size`
- `--vault-offset`
- `--vault-sector-size`

For user input of all other options, the `dialog` program is used.


Licensing
---------

This is free and unencumbered public domain software. For more
information, see http://unlicense.org/ or the accompanying UNLICENSE file.

[550M]: https://wiki.archlinux.org/index.php/EFI_system_partition#Create_the_partition
[denies console login as root]: https://wiki.archlinux.org/index.php/Security#Denying_console_login_as_root
[dnscrypt-proxy]: https://wiki.archlinux.org/index.php/DNSCrypt
[double password entry avoidance]: https://wiki.archlinux.org/index.php/Dm-crypt/Encrypting_an_entire_system#Avoiding_having_to_enter_the_passphrase_twice
[flat layout]: https://btrfs.wiki.kernel.org/index.php/SysadminGuide#Layout
[GPT]: https://wiki.archlinux.org/index.php/Partitioning#GUID_Partition_Table
[GRUB]: https://wiki.archlinux.org/index.php/GRUB
[hidepid]: https://wiki.archlinux.org/index.php/Security#hidepid
[nftables]: https://wiki.archlinux.org/index.php/nftables
[nodatacow]: https://wiki.archlinux.org/index.php/Btrfs#Disabling_CoW
[OpenSSH]: https://wiki.archlinux.org/index.php/Secure_Shell
[protective mount options]: https://www.softpanorama.org/Commercial_linuxes/Security/protective_partitioning_of_the_system.shtml
[runit]: http://smarden.org/runit
[Sysctl]: https://wiki.archlinux.org/index.php/Sysctl
[void-live-iso-i686-glibc]: https://alpha.de.repo.voidlinux.org/live/current/void-live-i686-20210930.iso
[void-live-iso-x86_64-glibc]: https://alpha.de.repo.voidlinux.org/live/current/void-live-x86_64-20210930.iso
[void-live-iso-x86_64-musl]: https://alpha.de.repo.voidlinux.org/live/current/void-live-x86_64-musl-20210930.iso
[Xorg]: https://wiki.archlinux.org/index.php/Xorg
[zram]: https://www.kernel.org/doc/Documentation/blockdev/zram.txt
[zramen]: https://github.com/atweiden/zramen

<!-- vim: set filetype=markdown foldmethod=marker foldlevel=0 nowrap: -->
