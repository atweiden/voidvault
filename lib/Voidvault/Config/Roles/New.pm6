use v6;
use Voidvault::Config::Base;
use Voidvault::Config::OneFA;
unit role Voidvault::Config::Roles::New;

multi method new(
    Str:D $mode where m:i/1fa/,
    *%opts (
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
        Bool :ignore-conf-repos($),
        Str :keymap($),
        Str :locale($),
        Str :packages($),
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
        Str :vault-key($),
        *%
    )
    --> Voidvault::Config::OneFA:D
)
{
    Voidvault::Config::OneFA.bless($mode, |%opts);
}

multi method new(
    Str $mode?,
    *%opts (
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
        Bool :ignore-conf-repos($),
        Str :keymap($),
        Str :locale($),
        Str :packages($),
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
        Str :vault-key($),
        *%
    )
    --> Voidvault::Config::Base:D
)
{
    Voidvault::Config::Base.bless($mode, |%opts);
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
