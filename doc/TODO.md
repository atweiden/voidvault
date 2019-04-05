Todo
====

- switch from `luks1` to `luks2` cryptsetup format once [GRUB luks2
  support][GRUB luks2 support] ships in a stable release
- switch from `lzo` to `zstd` compression once [GRUB zstd support][GRUB
  zstd support] ships in a stable release
- implement dracut-sshd-nonet
  - new profile: `headless-nonet`
    - disable grub boot encryption
    - pkg https://github.com/atweiden/dracut-sshd-nonet
    - add `ip link set dev eth0 up` to `/etc/rc.local`
    - modify `sshd_config` to `AllowUsers admin`
    - have runit launch sshd on startup
- figure out why Voidvault won't cleanly unmount `/mnt`
  - approaches which have failed:
    - sleep 7 seconds before attempting to unmount
    - loop the unmount command until `Proc.exitcode == 0`
    - `umount -l -R /mnt`
      - unmounts `/mnt` but `cryptsetup luksClose vault` subsequently
        fails with similar "*/mnt is busy*" error
    - create separate Perl 6 executable for `void-chroot` and `voidstrap`
      - call out to those separate executables instead of running the
        commands in-process
    - use a fresh livecd
    - `try {umount}`
    - `CATCH { default { .resume } }; umount`
  - approaches which have not been experimented with yet:
    - simplify subroutine `chroot-setup` to not use custom mount opts
    - rewrite everything in Bash to isolate this as a Perl 6 runtime issue
    - refrain from symlinking runit services
    - refrain from symlinking anything
    - replace dracut with mkinitcpio

[GRUB luks2 support]: https://savannah.gnu.org/bugs/?55093
[GRUB zstd support]: https://git.savannah.gnu.org/cgit/grub.git/commit/?id=386128648606a3aa6ae7108d1c9af52258202279
