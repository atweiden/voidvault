#!/bin/bash

export PATH="bin:$PATH"
export PERL6LIB="lib"
archvault --admin-name="live"                                  \
          --admin-pass="your admin user's password"            \
          --guest-name="guest"                                 \
          --guest-pass="your guest user's password"            \
          --sftp-name="variable"                               \
          --sftp-pass="your sftp user's password"              \
          --grub-name="grub"                                   \
          --grub-pass="your grub user's password"              \
          --root-pass="your root password"                     \
          --vault-name="vault"                                 \
          --vault-pass="your LUKS encrypted volume's password" \
          --hostname="vault"                                   \
          --partition="/dev/sdb"                               \
          --processor="other"                                  \
          --graphics="intel"                                   \
          --disk-type="usb"                                    \
          --locale="en_US"                                     \
          --keymap="us"                                        \
          --timezone="America/Los_Angeles"                     \
          --augment                                            \
          new
