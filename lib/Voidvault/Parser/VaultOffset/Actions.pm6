use v6;
use Voidvault::Constants;
use X::Voidvault::Parser::VaultOffset;
unit class Voidvault::Parser::VaultOffset::Actions;

my constant \BYTES-PER-SECTOR =
    $Voidvault::Constants::CRYPTSETUP-LUKS-BYTES-PER-SECTOR;

my enum OffsetUnit <
    KIBIBYTE
    MEBIBYTE
    GIBIBYTE
    TEBIBYTE
    SECTOR
>;

method number($/ --> Nil)
{
    make(+$/);
}

method binary-prefix:sym<K>($/ --> Nil)
{
    make(OffsetUnit::KIBIBYTE);
}

method binary-prefix:sym<M>($/ --> Nil)
{
    make(OffsetUnit::MEBIBYTE);
}

method binary-prefix:sym<G>($/ --> Nil)
{
    make(OffsetUnit::GIBIBYTE);
}

method binary-prefix:sym<T>($/ --> Nil)
{
    make(OffsetUnit::TEBIBYTE);
}

method sector($/ --> Nil)
{
    make(OffsetUnit::SECTOR);
}

multi method valid-unit($/ where $<binary-prefix>.so --> Nil)
{
    make($<binary-prefix>.made);
}

multi method valid-unit($/ where $<sector>.so --> Nil)
{
    make($<sector>.made);
}

method TOP($/ --> Nil)
{
    # user requests this number of units
    my Int:D $number = $<number>.made;
    my OffsetUnit:D $unit = $<valid-unit>.made;
    my Int:D $bytes = bytes-per-unit($unit);
    my Rat:D $offset = ($number * $bytes) / BYTES-PER-SECTOR;
    die(X::Voidvault::Parser::VaultOffset::Alignment.new(:content(~$/)))
        unless $offset %% 8;
    make($offset);
}

# units --digits 10 --terse kibibytes bytes
multi sub bytes-per-unit(OffsetUnit::KIBIBYTE --> 1024) {*}
# units --digits 10 --terse mebibytes bytes
multi sub bytes-per-unit(OffsetUnit::MEBIBYTE --> 1048576) {*}
# units --digits 10 --terse gibibytes bytes
multi sub bytes-per-unit(OffsetUnit::GIBIBYTE --> 1073741824) {*}
# units --digits 13 --terse tebibytes bytes
multi sub bytes-per-unit(OffsetUnit::TEBIBYTE --> 1099511627776) {*}
# cryptsetup defines each sector (S) as 512 bytes
multi sub bytes-per-unit(OffsetUnit::SECTOR --> BYTES-PER-SECTOR) {*}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
