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
  - approaches which have not been experimented with yet:
    - retry with fresh livecd
      - the current 2017.10.07 livecd is about a year old at the time
        of this writing
    - refrain from symlinking runit services
    - refrain from symlinking anything
    - replace dracut with mkinitcpio
    - rewrite everything in Bash to isolate this as a Perl6 runtime issue