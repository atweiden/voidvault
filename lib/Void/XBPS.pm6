use v6;
use Voidvault::Types;
unit module Void::XBPS;

# -----------------------------------------------------------------------------
# constants
# -----------------------------------------------------------------------------

constant $XBPS-UHELPER-ARCH = qx<xbps-uhelper arch>.trim;

multi sub gen-libc-flavor(Str:D $arch where /musl/ --> LibcFlavor:D)
{
    my LibcFlavor:D $libc-flavor = 'MUSL';
}

multi sub gen-libc-flavor(Str:D $ --> LibcFlavor:D)
{
    my LibcFlavor:D $libc-flavor = 'GLIBC';
}

constant $LIBC-FLAVOR = gen-libc-flavor($XBPS-UHELPER-ARCH);

proto sub gen-repository-official(LibcFlavor:D --> Str:D)
{
    my Str:D $*repository = 'https://a-hel-fi.m.voidlinux.org/current';
    {*}
}

multi sub gen-repository-official('MUSL' --> Str:D)
{
    # append /musl to official repository if machine has musl libc
    my Str:D $repository = sprintf(Q{%s/musl}, $*repository);
}

multi sub gen-repository-official(LibcFlavor:D $ --> Str:D)
{
    my Str:D $repository = $*repository;
}

constant $REPOSITORY-OFFICIAL = gen-repository-official($LIBC-FLAVOR);

# vim: set filetype=perl6 foldmethod=marker foldlevel=0 nowrap:
