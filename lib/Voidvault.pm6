use v6;
use Void::Constants;
use Void::Utils;
use Void::XBPS;
use Voidvault::Config;
use Voidvault::Config::Base;
use Voidvault::Config::OneFA;
use Voidvault::Config::TwoFA;
use Voidvault::ConfigArgs;
use Voidvault::Constants;
use Voidvault::Types;
use Voidvault::Utils;
unit class Voidvault;


# -----------------------------------------------------------------------------
# constants
# -----------------------------------------------------------------------------

constant $VERSION = v2.0.0;


# -----------------------------------------------------------------------------
# instantiation
# -----------------------------------------------------------------------------

method new(*@arg, *%opts (Bool :$ignore-conf-repos, :@repository, *%) --> Nil)
{
    my LibcFlavor:D $libc-flavor = $Void::Constants::LIBC-FLAVOR;

    # verify root permissions
    $*USER == 0 or die('root privileges required');

    # verify cmdline arguments
    my Voidvault::ConfigArgs $config-args .= new(@arg, |%opts);

    # ensure pressing Ctrl-C works
    signal(SIGINT).tap({ exit(130) });

    # fetch dependencies
    xbps-install-dependencies($libc-flavor, :@repository, :$ignore-conf-repos);

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

multi sub new(Voidvault::Config::TwoFA:D :$config! --> Nil)
{
    use Voidvault::Bootstrap::TwoFA;
    Voidvault::Bootstrap::TwoFA.new(:$config).bootstrap;
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
