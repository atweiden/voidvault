Todo
====

### Config

- warn if `{,boot}vault-offset` value is problematic
  - in particular, bootvault is 1024M in size

### Filesystem

- enable configuring Btrfs to use [negative ZSTD compression
  level][zstd-compression] for speed
  - may default HDD to this pending arrival of linux>=[6.15][linux6.15]

### Installer

- replace genfstab from arch-install-scripts with xgenfstab from xtools
- fix setting timezone to UTC

### Security

- add `random.trust_bootloader=0` to unprivilege bootloader [once
  available in kernel][random.trust_bootloader]
- enable [jitterentropy-rngd][jitterentropy-rngd i]
  ([i][jitterentropy-rngd ii])
- replace [ntp][chrony] with [something][Kicksecure/sdwdate]
  [more][konstruktoid/tymely] [secure][madaidan/secure-time-sync]
  (see also: [i][Kicksecure/bootclockrandomization], [ii][time attacks])

### `cryptsetup`

- switch from `luks1` to `luks2` cryptsetup format once [GRUB luks2
  support][GRUB luks2 support] ships in a stable release of GRUB
- switch `luks2` cryptsetup format from `pbkdf2` to `argon2id` key derival
  function once [libgcrypt argon2 support][libgcrypt argon2 support] ships
  in a stable release of libgcrypt, and [GRUB luks2 argon2 support][GRUB
  luks2 argon2 support] code is shipped in a stable release of GRUB
- enable LUKS volume data integrity protection once [resizing AEAD
  volumes][resizing AEAD volumes i] is [supported][resizing AEAD
  volumes ii]
  - `--cipher chacha20-random --integrity poly1305`
- ensure vault partition size has 4096 byte alignment for
  [optimal][optimal cryptsetup performance i] [cryptsetup][optimal
  cryptsetup performance ii] [performance][optimal cryptsetup performance
  iii]
  - see also: [nvme][nvme format i] [format][nvme format ii],
    [parted][parted], [alignment validator][alignment validator]
- load [kernel crypto modules][kernel crypto modules] for performance
  if applicable
  - `--vault-cipher=xchacha20,aes-adiantum --vault-key-size=256` => `modprobe ...`
- validate configurable cryptsetup options
  - `--vault-cipher`

### General

- enable replacing sudo with [doas][doas]
  - `--with-sudo=doas`
- implement {EXT4,[F2FS][F2FS]}+LVM on LUKS alternative setup with
  [fscrypt support][fscrypt support]
  - `mkfs.{ext4,f2fs} -O encrypt`

### Internal

- use typestate pattern
  - to gate available methods by state of installer
    - `install-vault-key-file`
  - to resume installer after crashing or exiting

### Maintenance

- test voidvault installation to hdd in secondary drive bay
  - see: https://github.com/atweiden/voidvault/issues/7

[zstd-compression]: https://lore.kernel.org/linux-btrfs/20250130175821.1792279-1-neelx@suse.com/T/
[linux6.15]: https://kernelnewbies.org/Linux_6.15
[random.trust_bootloader]: https://lore.kernel.org/lkml/20220324050930.207107-1-Jason@zx2c4.com/T/
[jitterentropy-rngd i]: https://github.com/void-linux/void-packages/pull/36401
[jitterentropy-rngd ii]: https://github.com/Whonix/security-misc/blob/master/usr/lib/modules-load.d/30_security-misc.conf
[chrony]: https://chrony.tuxfamily.org/
[Kicksecure/sdwdate]: https://github.com/Kicksecure/sdwdate
[konstruktoid/tymely]: https://github.com/konstruktoid/tymely
[madaidan/secure-time-sync]: https://gitlab.com/madaidan/secure-time-sync
[Kicksecure/bootclockrandomization]: https://github.com/Kicksecure/bootclockrandomization
[time attacks]: https://www.whonix.org/wiki/Time_Attacks
[GRUB luks2 support]: https://savannah.gnu.org/bugs/?55093
[libgcrypt argon2 support]: https://git.savannah.gnu.org/cgit/grub.git/commit/?id=365e0cc3e7e44151c14dd29514c2f870b49f9755
[GRUB luks2 argon2 support]: https://www.mail-archive.com/grub-devel@gnu.org/msg29535.html
[resizing AEAD volumes i]: https://gitlab.com/cryptsetup/cryptsetup/-/issues/388
[resizing AEAD volumes ii]: https://gitlab.com/cryptsetup/cryptsetup/-/issues/594
[optimal cryptsetup performance i]: https://gitlab.com/cryptsetup/cryptsetup/-/issues/585
[optimal cryptsetup performance ii]: https://unix.stackexchange.com/questions/588930/sgdisk-force-alignment-of-end-sector
[optimal cryptsetup performance iii]: https://gitlab.com/cryptsetup/cryptsetup/-/issues/585
[nvme format i]: https://wiki.archlinux.org/title/Advanced_Format#Solid_state_drives
[nvme format ii]: https://www.reddit.com/r/Fedora/comments/rzvhyg/default_luks_encryption_settings_on_fedora_can_be/
[parted]: https://rainbow.chard.org/2013/01/30/how-to-align-partitions-for-best-performance-using-parted/
[alignment validator]: https://bananaman.github.io/friendly-guides/pages/storage_alignment.html
[kernel crypto modules]: https://www.reddit.com/r/crypto/comments/b3we04/aesadiantum_new_mode_in_linux_kernel_5/ej32sjf/
[doas]: https://momi.ca/2020/03/20/doas.html
[F2FS]: https://savannah.gnu.org/bugs/?59976
[fscrypt support]: https://wiki.archlinux.org/title/Fscrypt#File_system
