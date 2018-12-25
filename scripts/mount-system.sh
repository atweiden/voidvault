#!/bin/bash

# ----------------------------------------------------------------------------
# mount-system: mount voidvault nilfs+lvm on luks and efi partition
# ----------------------------------------------------------------------------
# instructions
# - modify target partition (`_partition=/dev/sda`) as needed
# - run `cryptsetup luksOpen /dev/sda3 vault` before running this script

# setup
_lvs=('opt'
      'srv'
      'var'
      'var-cache-xbps'
      'var-lib-ex'
      'var-log'
      'var-opt'
      'var-spool'
      'var-tmp'
      'home')
_mount_options='rw,noatime'
_partition='/dev/sda'
_pool_name='vg0'
_vault_name='vault'

# activate lvm lvs
vgchange --activate y

# mount root lv
mkdir --parents /mnt
mount \
  --types nilfs2 \
  --options "$_mount_options" \
  "/dev/$_pool_name/root" \
  /mnt

# mount remaining lvs
for _lv in "${_lvs[@]}"; do
  # replace hyphen in volume name with forward slash
  _dir="${_lv//-//}"
  mkdir --parents "/mnt/$_dir"
  mount \
    --types nilfs2 \
    --options "$_mount_options" \
    "/dev/$_pool_name/$_lv" \
    "/mnt/$_dir"
done

# mount uefi boot partition
mkdir --parents /mnt/boot/efi && mount "${_partition}2" /mnt/boot/efi
