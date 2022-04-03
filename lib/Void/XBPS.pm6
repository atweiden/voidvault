use v6;
use Voidvault::Utils;
use X::Void::XBPS;
unit class Void::XBPS;

method xbps-install(
    :@repository,
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
