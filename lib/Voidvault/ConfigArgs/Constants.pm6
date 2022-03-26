use v6;
unit module Voidvault::ConfigArgs::Constants;

constant $HELP = q:to/EOF/.trim;
Usage:
  voidvault <command>

Commands:
  disable-cow          Disable copy-on-write on directories
  gen-pass-hash        Generate password hash
  help                 Show help for subcommands
  ls                   List devices, keymaps, locales, timezones
  new                  Bootstrap Void system with FDE

Options:
  -h, --help
    Print this help message
  --version
    Print version and exit
EOF

constant $HELP-DISABLE-COW = qq:to/EOF/.trim;
Usage:
  voidvault [--clean] [--recursive]
            [--permissions=<octal>]
            [--user=<username>]
            [--group=<groupname>]
            disable-cow <directory> [<directory> <directory>..]
  voidvault [-r] disable-cow <directory> [<directory> <directory>..]

Options:
  -c, --clean
    Remake directories with CoW disabled, copying in files
  -r, --recursive
    Recursively disable CoW on directories, implied by --clean
  -p, --permissions=<octal>
    Octal file mode bits (defaults to "755")
  -u, --user=<username>
    Named user to own file (defaults to "$*USER")
  -g, --group=<groupname>
    Named group to own file (defaults to "$*GROUP")

Positionals:
  <directory>        Path to directory
EOF

constant $HELP-GEN-PASS-HASH = q:to/EOF/.trim;
Usage:
  voidvault [-g|--grub] [-p|--pass=<password>] gen-pass-hash

Options:
  -g, --grub
    Generate PBKDF2 password hash for GRUB
  -p, --pass=<password>
    Plaintext password to generate hash from
EOF

constant $HELP-LS = q:to/EOF/.trim;
Usage:
  voidvault ls <positional>

Positionals
  devices           List available block devices
  keymaps           List available keyboard table descriptions
  locales           List available sets of language/cultural rules
  timezones         List available geographic regions
EOF

constant $HELP-NEW = q:to/EOF/.trim;
Usage:
  voidvault [options] new [mode]

  voidvault [--admin-name=<username>] [--admin-pass=<password>]
            [--guest-name=<username>] [--guest-pass=<password>]
            [--sftp-name=<username>] [--sftp-pass=<password>]
            [--grub-name=<username>] [--grub-pass=<password>]
            [--root-pass=<password>]
            [--vault-name=<vaultname>] [--vault-pass=<password>]
            [--vault-key=<path>]
            [--device=<device>] [--hostname=<hostname>]
            [--processor=<processor>] [--graphics=<graphics>]
            [--disk-type=<disktype>] [--locale=<locale>]
            [--keymap=<keymap>] [--timezone=<timezone>]
            [--repository=<repository>] [--ignore-conf-repos]
            [--packages=<packages>]
            [--augment]
            [--disable-ipv6] [--enable-serial-console]
            [--chroot-dir=<path>]
            new

  voidvault [--bootvault-name=<vaultname>] [--bootvault-pass=<password>]
            [--bootvault-key=<path>] [--vault-header=<path>]
            new 1fa

  voidvault [--bootvault-device=<device>]
            new 2fa

Options:
  --admin-name=<username>
    User name for admin account
  --admin-pass=<password>
    Password for admin account
  --admin-pass-hash=<passhash>
    Encrypted password hash for admin account
  --augment
    Drop to Bash console mid-execution
  --chroot-dir=<path>
    Path to directory within which to mount system for bootstrap
  --device=<device>
    Target block device for install
  --disable-ipv6
    Disable IPv6
  --disk-type=<disktype>
    Hard drive type
  --enable-serial-console
    Enable serial console
  --graphics=<graphics>
    Graphics card type
  --grub-name=<username>
    User name for GRUB
  --grub-pass=<password>
    Password for GRUB
  --grub-pass-hash=<passhash>
    Password hash for GRUB
  --guest-name=<username>
    User name for guest account
  --guest-pass=<password>
    Password for guest account
  --guest-pass-hash=<passhash>
    Encrypted password hash for guest account
  --hostname=<hostname>
    Hostname
  --ignore-conf-repos
    Only honor repositories specified on cmdline
  --keymap=<keymap>
    Keymap
  --locale=<locale>
    Locale
  --packages=<packages>
    List of additional packages to install
  --processor=<processor>
    Processor type
  --repository=<repository>
    Location of Void package repository (prioritized)
  --root-pass=<password>
    Password for root account
  --root-pass-hash=<passhash>
    Encrypted password hash for root account
  --sftp-name=<username>
    User name for SFTP account
  --sftp-pass=<password>
    Password for SFTP account
  --sftp-pass-hash=<passhash>
    Encrypted password hash for SFTP account
  --timezone=<timezone>
    Timezone
  --vault-name=<vaultname>
    Name for LUKS encrypted volume
  --vault-pass=<password>
    Password for LUKS encrypted volume
  --vault-key=<path>
    Path to LUKS encrypted volume key

Options (1FA/2FA):
  --bootvault-name=<vaultname>
    Name for LUKS encrypted boot volume
  --bootvault-pass=<password>
    Password for LUKS encrypted boot volume
  --bootvault-key=<path>
    Path to LUKS encrypted boot volume key
  --vault-header=<path>
    Path to LUKS encrypted volume detached header

Options (2FA):
  --bootvault-device=<device>
    Target block device for encrypted boot volume

Arguments:
  mode      Activate mode

Mode
  base      Make LUKS1 vault with encrypted /boot (Default)

  1fa       Make LUKS2 vault with detached header inside LUKS1 boot partition

            Make LUKS1 boot partition on same device as LUKS2 vault

  2fa       Make LUKS2 vault with detached header inside LUKS1 boot partition

            Make LUKS1 boot partition on separate device from LUKS2 vault
EOF

# for checking non-bootstrap command requirements not otherwise checked
constant $SUBJECT-DISABLE-COW = 'voidvault disable-cow';
constant $SUBJECT-GEN-PASS-HASH = 'voidvault gen-pass-hash';
constant $SUBJECT-GEN-PASS-HASH-GRUB = 'voidvault -g|--grub gen-pass-hash';
constant $SUBJECT-LS-DEVICES = 'voidvault ls devices';
constant $SUBJECT-LS-KEYMAPS = 'voidvault ls keymaps';
constant $SUBJECT-LS-LOCALES = 'voidvault ls locales';
constant $SUBJECT-LS-TIMEZONES = 'voidvault ls timezones';

# vim: set filetype=raku foldmethod=marker foldlevel=0:
