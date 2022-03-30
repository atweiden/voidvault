use v6;
use Voidvault::Config;
use Voidvault::Constants;
use Void::XBPS;
unit class Voidvault;


# -----------------------------------------------------------------------------
# constants
# -----------------------------------------------------------------------------

constant $VERSION = v1.16.0;


# -----------------------------------------------------------------------------
# attributes
# -----------------------------------------------------------------------------

has Voidvault::Config:D $.config is required;


# -----------------------------------------------------------------------------
# instantiation
# -----------------------------------------------------------------------------

method new(
    Str $mode?,
    *%opts (
        # list options pertinent to base Voidvault::Config only
        Str :admin-name($),
        Str :admin-pass($),
        Str :admin-pass-hash($),
        Bool :augment($),
        Str :device($),
        Bool :disable-ipv6($),
        Str :disk-type($),
        Bool :enable-serial-console($),
        Str :graphics($),
        Str :grub-name($),
        Str :grub-pass($),
        Str :grub-pass-hash($),
        Str :guest-name($),
        Str :guest-pass($),
        Str :guest-pass-hash($),
        Str :hostname($),
        Bool :$ignore-conf-repos,
        Str :keymap($),
        Str :locale($),
        Str :packages($),
        Str :processor($),
        :@repository,
        Str :root-pass($),
        Str :root-pass-hash($),
        Str :sftp-name($),
        Str :sftp-pass($),
        Str :sftp-pass-hash($),
        Str :timezone($),
        Str :vault-name($),
        Str :vault-pass($),
        Str :vault-key($),
        # facilitate passing additional options to non-base mode
        *%
    )
    --> Voidvault:D
)
{
    my LibcFlavor:D $libc-flavor = $Void::XBPS::LIBC-FLAVOR;

    # verify root permissions
    $*USER == 0 or die('root privileges required');

    # ensure pressing Ctrl-C works
    signal(SIGINT).tap({ exit(130) });

    # fetch dependencies
    install-dependencies($libc-flavor, :@repository, :$ignore-conf-repos);

    # instantiate voidvault config, prompting for user input as needed
    my Voidvault::Config $config .= new($mode, |%opts);

    my Voidvault:D $voidvault = new(:$config);
}

multi sub install-dependencies(
    'GLIBC',
    *%opts (Bool :ignore-conf-repos($), :repository(@))
    --> Nil
)
{
    Void::XBPS.xbps-install(@Voidvault::Constants::DEPENDENCY, 'glibc', |%opts);
}

multi sub install-dependencies(
    'MUSL',
    *%opts (Bool :ignore-conf-repos($), :repository(@))
    --> Nil
)
{
    Void::XBPS.xbps-install(@Voidvault::Constants::DEPENDENCY, 'musl', |%opts);
}

multi sub new(Voidvault::Config::Base:D :$config! --> Voidvault::Base:D)
{
    use Voidvault::Base;
    Voidvault::Base.bless(:$config);
}

multi sub new(Voidvault::Config::OneFA:D :$config! --> Voidvault::OneFA:D)
{
    use Voidvault::OneFA;
    Voidvault::OneFA.bless(:$config);
}


# -----------------------------------------------------------------------------
# worker functions
# -----------------------------------------------------------------------------

# partition device with gdisk
method sgdisk(::?CLASS:D: --> Nil)
{
    my Str:D $device = $.config.device;

    # erase existing partition table
    # create 2M EF02 BIOS boot sector
    # create 550M EF00 EFI system partition
    # create max sized partition for LUKS-encrypted vault
    run(qqw<
        sgdisk
        --zap-all
        --clear
        --mbrtogpt
        --new=1:0:+{$Voidvault::Constants::GDISK-SIZE-BIOS}
        --typecode=1:{$Voidvault::Constants::GDISK-TYPECODE-BIOS}
        --new=2:0:+{$Voidvault::Constants::GDISK-SIZE-EFI}
        --typecode=2:{$Voidvault::Constants::GDISK-TYPECODE-EFI}
        --new=3:0:0
        --typecode=3:{$Voidvault::Constants::GDISK-TYPECODE-LINUX}
    >, $device);
}

method mkefi(::?CLASS:D: --> Nil)
{
    my Str:D $partition-efi = self.gen-partition('efi');
    run(qw<modprobe vfat>);
    run(qqw<mkfs.vfat -F 32 $partition-efi>);
}

# create and mount btrfs filesystem on opened vault
method mkbtrfs(::?CLASS:D: --> Nil)
{
    my DiskType:D $disk-type = $.config.disk-type;
    my VaultName:D $vault-name = $.config.vault-name;

    # create btrfs filesystem on opened vault
    run(qw<modprobe btrfs xxhash_generic>);
    run(qqw<mkfs.btrfs --csum xxhash /dev/mapper/$vault-name>);

    # set mount options
    my Str:D @mount-options = qw<
        rw
        noatime
        compress-force=zstd
        space_cache=v2
    >;
    push(@mount-options, 'ssd') if $disk-type eq 'SSD';
    my Str:D $mount-options = @mount-options.join(',');

    # mount main btrfs filesystem on open vault
    mkdir('/mnt2');
    run(qqw<
        mount
        --types btrfs
        --options $mount-options
        /dev/mapper/$vault-name
        /mnt2
    >);

    # btrfs subvolumes, starting with root / ('')
    my Str:D @btrfs-dir =
        '',
        'home',
        'opt',
        'srv',
        'var',
        'var-cache-xbps',
        'var-lib-ex',
        'var-log',
        'var-opt',
        'var-spool',
        'var-tmp';

    # create btrfs subvolumes
    chdir('/mnt2');
    @btrfs-dir.map(-> Str:D $btrfs-dir {
        run(qqw<btrfs subvolume create @$btrfs-dir>);
    });
    chdir('/');

    # mount btrfs subvolumes
    @btrfs-dir.map(-> Str:D $btrfs-dir {
        mount-btrfs-subvolume($btrfs-dir, $mount-options, $vault-name);
    });

    # unmount /mnt2 and remove
    run(qw<umount /mnt2>);
    rmdir('/mnt2');
}

multi sub mount-btrfs-subvolume(
    'srv',
    Str:D $mount-options,
    VaultName:D $vault-name
    --> Nil
)
{
    my Str:D $btrfs-dir = 'srv';
    mkdir("/mnt/$btrfs-dir");
    run(qqw<
        mount
        --types btrfs
        --options $mount-options,nodev,noexec,nosuid,subvol=@$btrfs-dir
        /dev/mapper/$vault-name
        /mnt/$btrfs-dir
    >);
}

multi sub mount-btrfs-subvolume(
    'var-cache-xbps',
    Str:D $mount-options,
    VaultName:D $vault-name
    --> Nil
)
{
    my Str:D $btrfs-dir = 'var/cache/xbps';
    mkdir("/mnt/$btrfs-dir");
    run(qqw<
        mount
        --types btrfs
        --options $mount-options,subvol=@var-cache-xbps
        /dev/mapper/$vault-name
        /mnt/$btrfs-dir
    >);
}

multi sub mount-btrfs-subvolume(
    'var-lib-ex',
    Str:D $mount-options,
    VaultName:D $vault-name
    --> Nil
)
{
    my Str:D $btrfs-dir = 'var/lib/ex';
    mkdir("/mnt/$btrfs-dir");
    run(qqw<
        mount
        --types btrfs
        --options $mount-options,nodev,noexec,nosuid,subvol=@var-lib-ex
        /dev/mapper/$vault-name
        /mnt/$btrfs-dir
    >);
    run(qqw<chmod 1777 /mnt/$btrfs-dir>);
}

multi sub mount-btrfs-subvolume(
    'var-log',
    Str:D $mount-options,
    VaultName:D $vault-name
    --> Nil
)
{
    my Str:D $btrfs-dir = 'var/log';
    mkdir("/mnt/$btrfs-dir");
    run(qqw<
        mount
        --types btrfs
        --options $mount-options,nodev,noexec,nosuid,subvol=@var-log
        /dev/mapper/$vault-name
        /mnt/$btrfs-dir
    >);
}

multi sub mount-btrfs-subvolume(
    'var-opt',
    Str:D $mount-options,
    VaultName:D $vault-name
    --> Nil
)
{
    my Str:D $btrfs-dir = 'var/opt';
    mkdir("/mnt/$btrfs-dir");
    run(qqw<
        mount
        --types btrfs
        --options $mount-options,subvol=@var-opt
        /dev/mapper/$vault-name
        /mnt/$btrfs-dir
    >);
}

multi sub mount-btrfs-subvolume(
    'var-spool',
    Str:D $mount-options,
    VaultName:D $vault-name
    --> Nil
)
{
    my Str:D $btrfs-dir = 'var/spool';
    mkdir("/mnt/$btrfs-dir");
    run(qqw<
        mount
        --types btrfs
        --options $mount-options,nodev,noexec,nosuid,subvol=@var-spool
        /dev/mapper/$vault-name
        /mnt/$btrfs-dir
    >);
}

multi sub mount-btrfs-subvolume(
    'var-tmp',
    Str:D $mount-options,
    VaultName:D $vault-name
    --> Nil
)
{
    my Str:D $btrfs-dir = 'var/tmp';
    mkdir("/mnt/$btrfs-dir");
    run(qqw<
        mount
        --types btrfs
        --options $mount-options,nodev,noexec,nosuid,subvol=@var-tmp
        /dev/mapper/$vault-name
        /mnt/$btrfs-dir
    >);
    run(qqw<chmod 1777 /mnt/$btrfs-dir>);
}

multi sub mount-btrfs-subvolume(
    Str:D $btrfs-dir,
    Str:D $mount-options,
    VaultName:D $vault-name
    --> Nil
)
{
    mkdir("/mnt/$btrfs-dir");
    run(qqw<
        mount
        --types btrfs
        --options $mount-options,subvol=@$btrfs-dir
        /dev/mapper/$vault-name
        /mnt/$btrfs-dir
    >);
}


# -----------------------------------------------------------------------------
# helper functions
# -----------------------------------------------------------------------------

proto method gen-partition(::?CLASS:D: Str:D --> Str:D)
{
    my Str:D $device = $.config.device;
    my Str:D @*partition = Voidvault::Utils.ls-partitions($device);
    {*}
}

multi method gen-partition(::?CLASS:D: 'efi' --> Str:D)
{
    # e.g. /dev/sda2
    my UInt:D $index = 1;
    my Str:D $partition = @*partition[$index];
}

multi method gen-partition(::?CLASS:D: 'vault' --> Str:D)
{
    # e.g. /dev/sda3
    my UInt:D $index = 2;
    my Str:D $partition = @*partition[$index];
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
