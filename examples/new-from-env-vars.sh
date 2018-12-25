#!/bin/bash

export PATH="$(realpath bin):$PATH"
export RAKULIB="$(realpath lib)"
export RAKUDO_HOME='/usr/lib/raku'
export VOIDVAULT_ADMIN_NAME="live"
export VOIDVAULT_ADMIN_PASS="your admin user's password"
export VOIDVAULT_GUEST_NAME="guest"
export VOIDVAULT_GUEST_PASS="your guest user's password"
export VOIDVAULT_SFTP_NAME="variable"
export VOIDVAULT_SFTP_PASS="your sftp user's password"
export VOIDVAULT_GRUB_NAME="grub"
export VOIDVAULT_GRUB_PASS="your grub user's password"
export VOIDVAULT_ROOT_PASS="your root password"
export VOIDVAULT_VAULT_NAME="vault"
export VOIDVAULT_VAULT_PASS="your LUKS encrypted volume's password"
export VOIDVAULT_POOL_NAME="vg0"
export VOIDVAULT_HOSTNAME="vault"
export VOIDVAULT_PARTITION="/dev/sdb"
export VOIDVAULT_PROCESSOR="other"
export VOIDVAULT_GRAPHICS="intel"
export VOIDVAULT_DISK_TYPE="usb"
export VOIDVAULT_LOCALE="en_US"
export VOIDVAULT_KEYMAP="us"
export VOIDVAULT_TIMEZONE="America/Los_Angeles"
export VOIDVAULT_AUGMENT=1
voidvault new
