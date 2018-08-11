Todo
====

- figure out why Voidvault won't cleanly unmount `/mnt`
  - approaches which have failed:
    - sleep 7 seconds before attempting to unmount
    - loop the unmount command until `Proc.exitcode == 0`
    - `umount -l -R /mnt`
      - unmounts `/mnt` but `cryptsetup luksClose vault` subsequently
        fails with similar "*/mnt is busy*" error
    - create separate perl6 executable for `void-chroot` and `voidstrap`
      - call out to those separate executables instead of running the
        commands in-process
    - use a fresh livecd
  - approaches which have not been experimented with yet:
    - simplify subroutine `chroot-setup` to not use custom mount opts
    - rewrite everything in Bash to isolate this as a Perl6 runtime issue
    - refrain from symlinking runit services
    - refrain from symlinking anything
    - replace dracut with mkinitcpio
