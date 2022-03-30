use v6;
use Voidvault::Config;
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
    # verify root permissions
    $*USER == 0 or die('root privileges required');

    # ensure pressing Ctrl-C works
    signal(SIGINT).tap({ exit(130) });

    install-dependencies(:@repository, :$ignore-conf-repos);

    # instantiate voidvault config, prompting for user input as needed
    my Voidvault::Config $config .= new($mode, |%opts);

    my Voidvault:D $voidvault = new(:$config);
}

sub install-dependencies(
    *%opts (
        Bool :ignore-conf-repos($),
        :repository(@)
    )
    --> Nil
)
{
    my LibcFlavor:D $libc-flavor = $Void::XBPS::LIBC-FLAVOR;

    # fetch dependencies needed prior to voidstrap
    my Str:D @dep = qw<
        btrfs-progs
        coreutils
        cryptsetup
        dialog
        dosfstools
        e2fsprogs
        efibootmgr
        expect
        gptfdisk
        grub
        kbd
        kmod
        openssl
        procps-ng
        tzdata
        util-linux
        xbps
    >;
    push(@dep, 'glibc') if $libc-flavor eq 'GLIBC';
    push(@dep, 'musl') if $libc-flavor eq 'MUSL';
    Void::XBPS.xbps-install(@dep, |%opts);
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
# helper functions
# -----------------------------------------------------------------------------

proto method gen-partition(Str:D --> Str:D)
{
    my Str:D $device = $.config.device;
    my Str:D @*partition = Voidvault::Utils.ls-partitions($device);
}

multi method gen-partition('efi' --> Str:D)
{
    # e.g. /dev/sda2
    my UInt:D $index = 1;
    my Str:D $partition = @*partition[$index];
}

multi method gen-partition('vault' --> Str:D)
{
    # e.g. /dev/sda3
    my UInt:D $index = 2;
    my Str:D $partition = @*partition[$index];
}

# partition device with gdisk
method sgdisk(Str:D $device --> Nil)
{
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

method mkefi(Str:D $partition-efi --> Nil)
{
    run(qw<modprobe vfat>);
    run(qqw<mkfs.vfat -F 32 $partition-efi>);
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
