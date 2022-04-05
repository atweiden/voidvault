use v6;
use Voidvault::Config;
use Voidvault::Config::Base;
use Voidvault::Config::OneFA;
use Voidvault::ConfigArgs;
use Voidvault::Constants;
use Voidvault::Types;
use Voidvault::Utils;
use Void::Constants;
use Void::Utils;
use Void::XBPS;
unit class Voidvault;


# -----------------------------------------------------------------------------
# constants
# -----------------------------------------------------------------------------

constant $VERSION = v1.16.0;


# -----------------------------------------------------------------------------
# instantiation
# -----------------------------------------------------------------------------

method new(
    Str :$mode,
    *%opts (
        # list options pertinent to base Voidvault::Config only
        Str :admin-name($),
        Str :admin-pass($),
        Str :admin-pass-hash($),
        Bool :augment($),
        Str :chroot-dir($),
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
    my LibcFlavor:D $libc-flavor = $Void::Constants::LIBC-FLAVOR;

    # verify root permissions
    $*USER == 0 or die('root privileges required');

    # ensure pressing Ctrl-C works
    signal(SIGINT).tap({ exit(130) });

    # fetch dependencies
    xbps-install-dependencies($libc-flavor, :@repository, :$ignore-conf-repos);

    # ascertain mode from config args
    my Voidvault::ConfigArgs $config-args .= new(:$mode, |%opts);

    # instantiate voidvault config, prompting for user input as needed
    my Voidvault::Config $config = Voidvault::Config($config-args);

    # bootstrap voidvault
    new(:$config);
}

multi sub xbps-install-dependencies(
    'GLIBC',
    *%opts (Bool :ignore-conf-repos($), :repository(@))
    --> Nil
)
{
    Void::XBPS.xbps-install(@Voidvault::Constants::DEPENDENCY, 'glibc', |%opts);
}

multi sub xbps-install-dependencies(
    'MUSL',
    *%opts (Bool :ignore-conf-repos($), :repository(@))
    --> Nil
)
{
    Void::XBPS.xbps-install(@Voidvault::Constants::DEPENDENCY, 'musl', |%opts);
}

multi sub new(Voidvault::Config::Base:D :$config! --> Nil)
{
    use Voidvault::Bootstrap::Base;
    Voidvault::Bootstrap::Base.new(:$config).bootstrap;
}

multi sub new(Voidvault::Config::OneFA:D :$config! --> Nil)
{
    use Voidvault::Bootstrap::OneFA;
    Voidvault::Bootstrap::OneFA.new(:$config).bootstrap;
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
