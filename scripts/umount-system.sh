#!/bin/bash

# ----------------------------------------------------------------------------
# umount-system: unmount voidvault nilfs+lvm on luks and efi partition
# ----------------------------------------------------------------------------
# instructions
# - modify vault name (`_vault_name='vault'`) as needed

# setup
_vault_name='vault'

# unmount filesystems
umount --recursive /mnt

# deactivate lvm lvs
vgchange --activate n

# close vault
cryptsetup luksClose "$_vault_name"
