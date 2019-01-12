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

multi sub gen-libc-flavor(Str:D $arch --> LibcFlavor:D)
{
    my LibcFlavor:D $libc-flavor = 'GLIBC';
}

constant $LIBC-FLAVOR = gen-libc-flavor($XBPS-UHELPER-ARCH);

multi sub gen-repository-official('MUSL' --> Str:D)
{
    # append /musl to official repository if machine has musl libc
    my Str:D $repository = 'https://alpha.de.repo.voidlinux.org/current/musl';
}

multi sub gen-repository-official(LibcFlavor:D $ --> Str:D)
{
    my Str:D $repository = 'https://alpha.de.repo.voidlinux.org/current';
}

constant $REPOSITORY-OFFICIAL = gen-repository-official($LIBC-FLAVOR);

# vim: set filetype=perl6 foldmethod=marker foldlevel=0 nowrap:
