use v6;
use Void::XBPS;
use Voidvault;
use Voidvault::Config;
use Voidvault::Config::Base;
use Voidvault::Constants;
use Voidvault::Types;
use X::Void::XBPS;
unit class Voidvault::Base;
also is Voidvault;


# -----------------------------------------------------------------------------
# attributes
# -----------------------------------------------------------------------------

has Voidvault::Config::Base:D $.config is required;

# vim: set filetype=raku foldmethod=marker foldlevel=0 nowrap:
