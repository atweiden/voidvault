use v6;
use Void::XBPS;
use Voidvault::Bootstrap;
use Voidvault::Config;
use Voidvault::Config::OneFA;
use Voidvault::Types;
use Voidvault::Utils;
use X::Void::XBPS;
unit class Voidvault::Bootstrap::OneFA;
also is Voidvault::Bootstrap;


# -----------------------------------------------------------------------------
# attributes
# -----------------------------------------------------------------------------

has Voidvault::Config::OneFA:D $.config is required;

# vim: set filetype=raku foldmethod=marker foldlevel=0 nowrap:
