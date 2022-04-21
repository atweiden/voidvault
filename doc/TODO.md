Todo
====

- add `random.trust_cpu=0` to unprivilege RDRAND ([1][RDRAND
  i][2][RDRAND ii][3][RDRAND iii][4][RDRAND iv][5])
- add `random.trust_bootloader=0` to unprivilege bootloader [once
  available in kernel][random.trust_bootloader]
- add [grub settings from whonix][grub settings from whonix]
- add [grub settings from tails][grub settings from tails]
- add [modules-load.d settings from whonix][modules-load.d settings from whonix]
- switch from `luks1` to `luks2` cryptsetup format once [GRUB luks2
  support][GRUB luks2 support] ships in a stable release of GRUB
  - likely grub-2.06
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
  - `--with-cryptsetup-cipher=xchacha20,aes-adiantum
    --with-cryptsetup-key-size=256` => `modprobe ...`
- pass [`--perf-no_read_workqueue`][--perf-no_read_workqueue
  i] flag to `luksOpen` ([[1]][--perf-no_read_workqueue ii]
  [[2]][--perf-no_read_workqueue iii] [[3]][--perf-no_read_workqueue iv])
  once switched to luks2 (thereby enabling passing the `--persistent`
  flag alongside it), or once [void-runit][void-runit] supports parsing
  `--perf-no_read_workqueue` from `/etc/crypttab`
- replace sudo with [doas][doas]
  - put doas behind cmdline flag
    - `--with-sudo=doas`
- enable opting out of [predictable network interface names][predictable
  network interface names]
  - `--disable-predictable-inames`
- implement {EXT4,[F2FS][F2FS]}+LVM on LUKS alternative setup with
  [fscrypt support][fscrypt support]
  - `mkfs.{ext4,f2fs} -O encrypt`
- document eudev requirement for 2fa mode
- validate configurable cryptsetup options
  - `--vault-cipher`
- use typestate pattern
  - to gate available methods by state of installer
    - `install-vault-key-file`
  - to resume installer after crashing or exiting
- implement dracut-sshd-nonet
  - new profile: `headless-nonet`
    - disable grub boot encryption
    - pkg https://github.com/atweiden/dracut-sshd-nonet
    - add `ip link set dev eth0 up` to `/etc/rc.local`
    - modify `sshd_config` to `AllowUsers admin`
    - have runit launch sshd on startup
- test voidvault installation to hdd in secondary drive bay
  - see: https://github.com/atweiden/voidvault/issues/7

[RDRAND i]: https://github.com/QubesOS/qubes-issues/issues/6941
[RDRAND ii]: https://forums.whonix.org/t/rdrand-entropy-config-random-trust-cpu-yes-or-no-rng-core-default-quality/8566
[RDRAND iii]: https://forums.whonix.org/t/use-kernel-command-line-as-a-source-of-randomness/8945/15
[RDRAND iv]: https://daniel-lange.com/archives/152-hello-buster.html
[random.trust_bootloader]: https://lore.kernel.org/lkml/20220324050930.207107-1-Jason@zx2c4.com/T/
[grub settings from whonix]: https://github.com/Whonix/security-misc/tree/master/etc/default/grub.d
[grub settings from tails]: https://tails.boum.org/contribute/design/kernel_hardening/
[modules-load.d settings from whonix]: https://github.com/Whonix/security-misc/blob/master/usr/lib/modules-load.d/30_security-misc.conf
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
[--perf-no_read_workqueue i]: https://www.reddit.com/r/Fedora/comments/rzvhyg/default_luks_encryption_settings_on_fedora_can_be/
[--perf-no_read_workqueue ii]: https://github.com/cloudflare/linux/issues/1
[--perf-no_read_workqueue iii]: https://blog.cloudflare.com/speeding-up-linux-disk-encryption/
[--perf-no_read_workqueue iv]: https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?h=v5.9-rc1&id=39d42fa96ba1b7d2544db3f8ed5da8fb0d5cb877
[void-runit]: https://github.com/void-linux/void-runit/blob/master/crypt.awk
[doas]: https://momi.ca/2020/03/20/doas.html
[predictable network interface names]: https://systemd.io/PREDICTABLE_INTERFACE_NAMES/
[F2FS]: https://savannah.gnu.org/bugs/?59976
[fscrypt support]: https://wiki.archlinux.org/title/Fscrypt#File_system
