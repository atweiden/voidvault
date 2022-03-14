Todo
====

- allow passing additional packages to voidstrap
  - `--packages broadcom-wl-dkms`
- switch from `luks1` to `luks2` cryptsetup format once [GRUB luks2
  support][GRUB luks2 support] ships in a stable release of GRUB
  - likely grub-2.06
- switch `luks2` cryptsetup format from `pbkdf2` to `argon2id` key derival
  function once [libgcrypt argon2 support][libgcrypt argon2 support] ships
  in a stable release of libgcrypt, and [GRUB luks2 argon2 support][GRUB
  luks2 argon2 support] code is shipped in a stable release of GRUB
- enable specifying cryptsetup `luksFormat` options
  - `--with-cryptsetup-cipher=serpent-xts-plain64`
  - `--with-cryptsetup-key-size=512`
  - `--with-cryptsetup-hash=blake2b-512`
  - `--with-cryptsetup-iter-time=5000`
  - `CRYPTSETUP_CIPHER=serpent-xts-plain64`
  - `CRYPTSETUP_KEY_SIZE=512`
  - `CRYPTSETUP_HASH=blake2b-512`
  - `CRYPTSETUP_ITER_TIME=5000`
- enable LUKS volume data integrity protection once [resizing AEAD
  volumes][resizing AEAD volumes i] is [supported][resizing AEAD
  volumes ii]
  - `--cipher chacha20-random --integrity poly1305`
- replace sudo with [doas][doas]
  - put doas behind cmdline flag
    - `--with-sudo=doas`
- enable opting out of [predictable network interface names][predictable
  network interface names]
  - `--disable-predictable-inames`
- implement {EXT4,[F2FS][F2FS]}+LVM on LUKS alternative setup with
  [fscrypt support][fscrypt support]
  - `mkfs.{ext4,f2fs} -O encrypt`
- implement dracut-sshd-nonet
  - new profile: `headless-nonet`
    - disable grub boot encryption
    - pkg https://github.com/atweiden/dracut-sshd-nonet
    - add `ip link set dev eth0 up` to `/etc/rc.local`
    - modify `sshd_config` to `AllowUsers admin`
    - have runit launch sshd on startup
- test voidvault installation to hdd in secondary drive bay
  - see: https://github.com/atweiden/voidvault/issues/7

[GRUB luks2 support]: https://savannah.gnu.org/bugs/?55093
[libgcrypt argon2 support]: https://git.savannah.gnu.org/cgit/grub.git/commit/?id=365e0cc3e7e44151c14dd29514c2f870b49f9755
[GRUB luks2 argon2 support]: https://www.mail-archive.com/grub-devel@gnu.org/msg29535.html
[resizing AEAD volumes i]: https://gitlab.com/cryptsetup/cryptsetup/-/issues/388
[resizing AEAD volumes ii]: https://gitlab.com/cryptsetup/cryptsetup/-/issues/594
[doas]: https://momi.ca/2020/03/20/doas.html
[predictable network interface names]: https://systemd.io/PREDICTABLE_INTERFACE_NAMES/
[F2FS]: https://savannah.gnu.org/bugs/?59976
[fscrypt support]: https://wiki.archlinux.org/title/Fscrypt#File_system
