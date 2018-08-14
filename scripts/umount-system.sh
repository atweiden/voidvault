#!/bin/bash

# ----------------------------------------------------------------------------
# umount-system: unmount voidvault btrfs subvolumes and efi partition
# ----------------------------------------------------------------------------
# instructions
# - run `cryptsetup luksClose vault` after running this script

umount --recursive /mnt
