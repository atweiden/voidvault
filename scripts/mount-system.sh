#!/bin/bash

# ----------------------------------------------------------------------------
# mount-system: mount voidvault btrfs subvolumes and efi partition
# ----------------------------------------------------------------------------
# instructions
# - modify target partition (`_partition=/dev/sda`) as needed
# - run `cryptsetup luksOpen /dev/sda3 vault` before running this script

# setup
_btrfs_subvolumes=(''
                   'home'
                   'opt'
                   'srv'
                   'var'
                   'var-cache-xbps'
                   'var-lib-ex'
                   'var-log'
                   'var-opt'
                   'var-spool'
                   'var-tmp')
_compression='zstd'
_mount_options="rw,noatime,compress=$_compression,space_cache=v2"
_partition='/dev/sda'
_vault_name='vault'

# mount btrfs subvolumes starting with root ('')
for _btrfs_subvolume in "${_btrfs_subvolumes[@]}"; do
  _btrfs_dir="${_btrfs_subvolume//-//}"
  mkdir --parents "/mnt/$_btrfs_dir"
  mount \
    --types btrfs \
    --options "$_mount_options,subvol=@$_btrfs_subvolume" \
    "/dev/mapper/$_vault_name" \
    "/mnt/$_btrfs_dir"
done

# mount uefi boot partition
mkdir --parents /mnt/boot/efi && mount "${_partition}2" /mnt/boot/efi
