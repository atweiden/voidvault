#!/bin/bash

# ----------------------------------------------------------------------------
# mount-system: mount voidvault btrfs subvolumes and efi partition
# ----------------------------------------------------------------------------
# instructions
# - modify target block device (`_device=/dev/sda`) as needed
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
_mount_options="rw,noatime,compress-force=$_compression,space_cache=v2"
_device='/dev/sda'
_vault_name='vault'
# directory within which to mount system for recovery
_mount_dir='/mnt'

# mount btrfs subvolumes starting with root ('')
for _btrfs_subvolume in "${_btrfs_subvolumes[@]}"; do
  _btrfs_dir="${_btrfs_subvolume//-//}"
  mkdir --parents "$_mount_dir/$_btrfs_dir"
  mount \
    --types btrfs \
    --options "$_mount_options,subvol=@$_btrfs_subvolume" \
    "/dev/mapper/$_vault_name" \
    "$_mount_dir/$_btrfs_dir"
done

# mount uefi boot partition
mkdir --parents "$_mount_dir/boot/efi" \
  && mount "${_device}2" "$_mount_dir/boot/efi"
