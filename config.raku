use v6;

=for pod
=head A reimagining of L<atweiden/voidvault> internal config architecture

my enum Filesystem <BTRFS EXT2 EXT3 EXT4 F2FS NILFS2 XFS>;
my enum Mode <BASE 1FA 2FA>;

my role ConfigFs[Mode:D $ where Mode::BASE, Bool:D $ where .so]
{
    has Filesystem:D $.vault is required;
    has Str:D $.lvm-vg-name is required;
}

my role ConfigFs[Mode:D $ where Mode::BASE, Bool $]
{
    has Filesystem:D $.vault is required;
}

my role ConfigFs[Mode:D $, Bool:D $ where .so]
{
    also does ConfigFs[Mode::BASE, True];
    has Filesystem:D $.bootvault is required;
}

my role ConfigFs[Mode:D $, Bool $]
{
    also does ConfigFs[Mode::BASE, False];
    has Str:D $.bootvault is required;
}

my role ConfigVt[Mode:D $ where Mode::BASE]
{
    has Str:D $.vault-name is required;
}

my role ConfigVt[Mode:D $ where Mode::<1FA>]
{
    also does ConfigVt[Mode::BASE];
    has Str:D $.bootvault-name is required;
}

my role ConfigVt[Mode:D $ where Mode::<2FA>]
{
    has Str:D $.bootvault-device is required;
}

my role Config[Mode:D $mode, Bool:D $lvm]
{
    has ConfigFs[$mode, $lvm] $.filesystem is required;
    has ConfigVt[$mode] $.vault is required;
}

=begin pod

=head Architecture

=head2 C<ConfigAccount>: account settings

    voidvault [--admin-name=<username>] [--admin-pass=<password>]
              [--guest-name=<username>] [--guest-pass=<password>]
              [--sftp-name=<username>] [--sftp-pass=<password>]
              [--grub-name=<username>] [--grub-pass=<password>]
              [--root-pass=<password>]
              new

=head2 C<ConfigDisk>: disk settings

    voidvault [--device=<device>] [--lvm-vg-name=<name>]
              new [fs[/fs][+lvm]]

=head2 C<ConfigDistro>: distro-specific settings

    voidvault [--repository=<repository>] [--ignore-conf-repos]
              new

=head2 C<ConfigSecurity>: security settings

    voidvault [--vault-name=<vaultname>] [--vault-pass=<password>]
              [--vault-key-file=<path>]
              [--vault-cipher=<cipher>] [--vault-hash=<hash>]
              [--vault-iter-time=<ms>] [--vault-key-size=<bits>]
              [--vault-offset=<offset>] [--vault-sector-size=<bytes>]
              new

    voidvault [--bootvault-name=<vaultname>] [--bootvault-pass=<password>]
              [--bootvault-key-file=<path>]
              [--bootvault-cipher=<cipher>] [--bootvault-hash=<hash>]
              [--bootvault-iter-time=<ms>] [--bootvault-key-size=<bits>]
              [--bootvault-offset=<offset>] [--bootvault-sector-size=<bytes>]
              [--vault-header=<path>]
              new 1fa

    voidvault [--bootvault-device=<device>]
              new 2fa

=head2 C<ConfigInstaller>: installer settings

    voidvault [--chroot-dir=<path>] [--augment]
              new

=head2 C<ConfigSystem>: system settings

    voidvault [--hostname=<hostname>] [--processor=<processor>]
              [--graphics=<graphics>] [--disk-type=<disktype>]
              [--locale=<locale>] [--keymap=<keymap>] [--timezone=<timezone>]
              [--packages=<packages>] [--kernel=<package>]
              [--disable-ipv6] [--enable-classic-ifnames]
              [--enable-serial-console]
              new

=end pod

my Config:D $config = do {
    my Mode:D $mode = Mode::BASE;
    my Bool:D $lvm = True;
    my ConfigFs:D $filesystem = do {
        my Filesystem:D $vault = Filesystem::NILFS2;
        my Filesystem:D $bootvault = Filesystem::NILFS2;
        my Str:D $lvm-vg-name = 'vg0';
        ConfigFs[$mode, $lvm].new(:$vault, :$bootvault, :$lvm-vg-name);
    };
    my ConfigVt:D $vault = do {
        my Str:D $vault-name = 'vault';
        ConfigVt[$mode].new(:$vault-name);
    };
    Config[$mode, $lvm].new(:$filesystem, :$vault);
};

$config.raku.say;
