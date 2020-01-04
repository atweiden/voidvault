use v6;
unit module Crypt::Libcrypt:auth<atweiden>;

multi sub crypt('GLIBC', Str:D $key, Str:D $salt --> Str:D) is export
{
    use Crypt::Libcrypt::Glibc;
    my Str:D $crypt = crypt($key, $salt);
}

multi sub crypt('MUSL', Str:D $key, Str:D $salt --> Str:D) is export
{
    use Crypt::Libcrypt::Musl;
    my Str:D $crypt = crypt($key, $salt);
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
