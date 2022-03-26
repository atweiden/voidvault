use v6;
use Voidvault::Config;
unit class Voidvault::Config::Base;
also does Voidvault::Config;

multi submethod TWEAK(--> Nil)
{*}

multi submethod BUILD(
    *%
    --> Nil
)
{*}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
