Todo
====

- switch from `luks1` to `luks2` cryptsetup format once [GRUB luks2
  support][GRUB luks2 support] ships in a stable release of GRUB
  - likely grub-2.06
- switch `luks2` cryptsetup format from `pbkdf2` to `argon2*` key derival
  function once [libgcrypt argon2 support][libgcrypt argon2 support] ships
  in a stable release of libgcrypt, and [GRUB luks2 argon2 support][GRUB
  luks2 argon2 support] code is shipped in a stable release of GRUB
- enable LUKS volume data integrity protection once [resizing AEAD
  volumes][resizing AEAD volumes i] is [supported][resizing AEAD
  volumes ii]
  - `--cipher chacha20-random --integrity poly1305`
- replace sudo with [doas][doas]
  - put doas behind cmdline flag
    - `--with-sudo=doas`
- implement dracut-sshd-nonet
  - new profile: `headless-nonet`
    - disable grub boot encryption
    - pkg https://github.com/atweiden/dracut-sshd-nonet
    - add `ip link set dev eth0 up` to `/etc/rc.local`
    - modify `sshd_config` to `AllowUsers admin`
    - have runit launch sshd on startup
- test voidvault installation to hdd in secondary drive bay
  - see: https://github.com/atweiden/voidvault/issues/7

[doas]: https://momi.ca/2020/03/20/doas.html
[GRUB luks2 support]: https://savannah.gnu.org/bugs/?55093
[libgcrypt argon2 support]: https://git.savannah.gnu.org/cgit/grub.git/commit/?id=365e0cc3e7e44151c14dd29514c2f870b49f9755
[GRUB luks2 argon2 support]: https://www.mail-archive.com/grub-devel@gnu.org/msg29535.html
[resizing AEAD volumes i]: https://gitlab.com/cryptsetup/cryptsetup/-/issues/388
[resizing AEAD volumes ii]: https://gitlab.com/cryptsetup/cryptsetup/-/issues/594
