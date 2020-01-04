Todo
====

- switch from `luks1` to `luks2` cryptsetup format once [GRUB luks2
  support][GRUB luks2 support] ships in a stable release
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

[GRUB luks2 support]: https://savannah.gnu.org/bugs/?55093
