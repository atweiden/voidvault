use v6;
use Voidvault::Bootstrap;
use Voidvault::Config;
unit class Voidvault;

constant $VERSION = v1.7.2;

method new(
    *%opts (
        Str :admin-name($),
        Str :admin-pass($),
        Str :admin-pass-hash($),
        Bool :augment($),
        Bool :disable-ipv6($),
        Str :disk-type($),
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
        Str :partition($),
        Str :processor($),
        Str :repository($),
        Str :root-pass($),
        Str :root-pass-hash($),
        Str :sftp-name($),
        Str :sftp-pass($),
        Str :sftp-pass-hash($),
        Str :timezone($),
        Str :vault-name($),
        Str :vault-pass($)
    )
    --> Nil
)
{
    # instantiate voidvault config, prompting for user input as needed
    my Voidvault::Config $config .= new(|%opts);

    # bootstrap voidvault
    Voidvault::Bootstrap.new(:$config).bootstrap;
}

# vim: set filetype=perl6 foldmethod=marker foldlevel=0:
