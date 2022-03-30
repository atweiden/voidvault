use v6;
use Voidvault::Types;
use Voidvault::Utils;
use X::Void::XBPS;
unit module Void::XBPS;


# -----------------------------------------------------------------------------
# helpers
# -----------------------------------------------------------------------------

multi sub gen-libc-flavor(Str:D $arch where /musl/ --> LibcFlavor:D)
{
    my LibcFlavor:D $libc-flavor = 'MUSL';
}

multi sub gen-libc-flavor(Str:D $ --> LibcFlavor:D)
{
    my LibcFlavor:D $libc-flavor = 'GLIBC';
}

proto sub gen-repository-official(LibcFlavor:D --> Str:D)
{
    my Str:D $*repository = 'https://alpha.de.repo.voidlinux.org/current';
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


# -----------------------------------------------------------------------------
# constants
# -----------------------------------------------------------------------------

constant $XBPS-UHELPER-ARCH = qx<xbps-uhelper arch>.trim;
constant $LIBC-FLAVOR = gen-libc-flavor($XBPS-UHELPER-ARCH);
constant $REPOSITORY-OFFICIAL = gen-repository-official($LIBC-FLAVOR);
constant $REPOSITORY-OFFICIAL-NONFREE =
    sprintf(Q{%s/nonfree}, $REPOSITORY-OFFICIAL);


# -----------------------------------------------------------------------------
# xbps
# -----------------------------------------------------------------------------

method xbps-install(
    Str:D :@repository,
    Bool :$ignore-conf-repos,
    # ensure at least one package is given
    *@pkg ($, *@)
    --> Nil
)
{
    my Str:D $xbps-install-cmdline =
        build-xbps-install-cmdline(
            @pkg,
            :@repository,
            :$ignore-conf-repos
        );
    Voidvault::Utils.loop-cmdline-proc(
        "Installing packages...",
        $xbps-install-cmdline
    );
}

multi sub build-xbps-install-cmdline(
    Str:D @pkg,
    Str:D :@repository! where .so,
    Bool:D :ignore-conf-repos($)! where .so
    --> Str:D
)
{
    my Str:D $repository = @repository.join(' --repository ');
    my Str:D $xbps-install-cmdline =
        "xbps-install \\
         --ignore-conf-repos \\
         --repository $repository \\
         --sync \\
         --yes \\
         @pkg[]";
}

multi sub build-xbps-install-cmdline(
    Str:D @pkg,
    Str:D :@repository! where .so,
    Bool :ignore-conf-repos($)
    --> Str:D
)
{
    my Str:D $repository = @repository.join(' --repository ');
    my Str:D $xbps-install-cmdline =
        "xbps-install \\
         --repository $repository \\
         --sync \\
         --yes \\
         @pkg[]";
}

multi sub build-xbps-install-cmdline(
    Str:D @,
    Str:D :repository(@),
    Bool:D :ignore-conf-repos($)! where .so
    --> Nil
)
{
    die(X::Void::XBPS::IgnoreConfRepos.new);
}

multi sub build-xbps-install-cmdline(
    Str:D @pkg,
    Str:D :repository(@),
    Bool :ignore-conf-repos($)
    --> Str:D
)
{
    my Str:D $xbps-install-cmdline =
        "xbps-install \\
         --sync \\
         --yes \\
         @pkg[]";
}

# vim: set filetype=raku foldmethod=marker foldlevel=0 nowrap:
