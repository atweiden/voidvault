use v6;
use Archvault::Bootstrap;
use Archvault::Config;
unit class Archvault;

constant $VERSION = v1.0.1;

method new(
    *%opts (
        Str :admin-name($),
        Str :admin-pass($),
        Str :admin-pass-hash($),
        Bool :augment($),
        Str :disk-type($),
        Str :graphics($),
        Str :grub-name($),
        Str :grub-pass($),
        Str :grub-pass-hash($),
        Str :guest-name($),
        Str :guest-pass($),
        Str :guest-pass-hash($),
        Str :hostname($),
        Str :keymap($),
        Str :locale($),
        Str :partition($),
        Str :processor($),
        Bool :reflector($),
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
    # instantiate archvault config, prompting for user input as needed
    my Archvault::Config $config .= new(|%opts);

    # bootstrap archvault
    Archvault::Bootstrap.new(:$config).bootstrap;
}

# vim: set filetype=perl6 foldmethod=marker foldlevel=0:
