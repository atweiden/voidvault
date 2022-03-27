use v6;
use Voidvault::Config;
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
        Bool :ignore-conf-repos($),
        Str :keymap($),
        Str :locale($),
        Str :packages($),
        Str :partition($),
        Str :processor($),
        :repository(@),
        Str :root-pass($),
        Str :root-pass-hash($),
        Str :sftp-name($),
        Str :sftp-pass($),
        Str :sftp-pass-hash($),
        Str :timezone($),
        Str :vault-name($),
        Str :vault-pass($),
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

    # instantiate voidvault config, prompting for user input as needed
    my Voidvault::Config $config .= new($mode, |%opts);

    # bootstrap voidvault
    new($config);
}

multi sub new(Voidvault::Config:D $config where .mode eq 'BASE' --> Nil)
{
    use Voidvault::Bootstrap::Base;
    Voidvault::Bootstrap::Base.new(:$config).bootstrap;
}

multi sub new(Voidvault::Config:D $config where .mode eq '1FA' --> Nil)
{
    use Voidvault::Bootstrap::OneFA;
    Voidvault::Bootstrap::OneFA.new(:$config).bootstrap;
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
