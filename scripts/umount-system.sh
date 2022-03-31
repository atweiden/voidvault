#!/bin/bash

# ----------------------------------------------------------------------------
# umount-system: unmount voidvault btrfs subvolumes and efi partition
# ----------------------------------------------------------------------------
# instructions
# - run `cryptsetup luksClose vault` after running this script

_mount_dir='/mnt'
umount --recursive "$_mount_dir"
