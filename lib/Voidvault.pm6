use v6;
use Voidvault::Config;
use Void::XBPS;
unit class Voidvault;

constant $VERSION = v1.16.0;

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
    --> Nil
)
{
    # verify root permissions
    $*USER == 0 or die('root privileges required');

    # ensure pressing Ctrl-C works
    signal(SIGINT).tap({ exit(130) });

    install-dependencies(:@repository, :$ignore-conf-repos);

    # instantiate voidvault config, prompting for user input as needed
    my Voidvault::Config $config .= new($mode, |%opts);

    # mode-dependent bootstrap
    new($config);
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

multi sub new(Voidvault::Config::Base:D $config --> Nil)
{
    use Voidvault::Bootstrap::Base;
    Voidvault::Bootstrap::Base.new(:$config).bootstrap;
}

multi sub new(Voidvault::Config::OneFA:D $config --> Nil)
{
    use Voidvault::Bootstrap::OneFA;
    Voidvault::Bootstrap::OneFA.new(:$config).bootstrap;
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
