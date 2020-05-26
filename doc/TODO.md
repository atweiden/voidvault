Todo
====

- switch from `luks1` to `luks2` cryptsetup format once [GRUB luks2
  support][GRUB luks2 support] ships in a stable release of GRUB
  - likely grub-2.06
- switch `luks2` cryptsetup format from `pbkdf2` to `argon2*` key derival
  function once [libgcrypt argon2 support][libgcrypt argon2 support] ships
  in a stable release of libgcrypt, and [GRUB luks2 argon2 support][GRUB
  luks2 argon2 support] code is shipped in a stable release of GRUB
- replace sudo with [doas][doas]
- rm `wireguard-dkms` once `linux-5.6` ships in void
- figure out why Voidvault won't cleanly unmount `/mnt`
  - approaches which have failed:
    - sleep 7 seconds before attempting to unmount
    - loop the unmount command until `Proc.exitcode == 0`
    - `umount -l -R /mnt`
      - unmounts `/mnt` but `cryptsetup luksClose vault` subsequently
        fails with similar "*/mnt is busy*" error
    - create separate Raku executable for `void-chroot` and `voidstrap`
      - call out to those separate executables instead of running the
        commands in-process
    - use a fresh livecd
    - `try {umount}`
    - `CATCH { default { .resume } }; umount`
  - approaches which have not been experimented with yet:
    - simplify subroutine `chroot-setup` to not use custom mount opts
    - rewrite everything in Bash to isolate this as a Raku runtime issue
    - refrain from symlinking runit services
    - refrain from symlinking anything
    - replace dracut with mkinitcpio
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
