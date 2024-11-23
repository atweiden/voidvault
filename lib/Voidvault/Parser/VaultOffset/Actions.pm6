use v6;
use Voidvault::Constants;
use X::Voidvault::Parser::VaultOffset;
unit class Voidvault::Parser::VaultOffset::Actions;

has UInt:D $.bytes-per-sector = bytes-per-sector();

sub bytes-per-sector(--> UInt:D)
{
    my Str:D $df = qx{df --output=source /}.lines.tail;
    my UInt:D $bytes-per-sector =
        +qqx{lsblk --raw --output PHY-SEC $df}.lines.tail;
}

submethod TWEAK(--> Nil)
{
    is-valid-bytes-per-sector($!bytes-per-sector) or do {
        my UInt:D $sector-size = $!bytes-per-sector;
        die(X::Voidvault::Parser::VaultOffset::SectorSize.new(:$sector-size));
    };
}

sub is-valid-bytes-per-sector(UInt:D $bytes-per-sector --> Bool:D)
{
    # must be power of 2 and in range 512 - 4096
    return False if $bytes-per-sector < 512;
    return False if $bytes-per-sector > 4096;
    my Bool:D $is-valid-bytes-per-sector =
        $bytes-per-sector +& ($bytes-per-sector - 1) == 0;
}

submethod BUILD(:$sector-size --> Nil)
{
    # coerce possible C<IntStr>
    $!bytes-per-sector = +$sector-size if $sector-size;
}

method new(
    *%opts (:sector-size($))
    --> Voidvault::Parser::VaultOffset::Actions:D
)
{
    self.bless(|%opts);
}

my enum OffsetUnit <
    KIBIBYTE
    MEBIBYTE
    GIBIBYTE
    TEBIBYTE
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

multi method valid-unit($/ where $<binary-prefix>.so --> Nil)
{
    make($<binary-prefix>.made);
}

method TOP($/ --> Nil)
{
    # user requests this number of units
    my Int:D $number = $<number>.made;
    my OffsetUnit:D $unit = $<valid-unit>.made;
    my Int:D $bytes = bytes-per-unit($unit);
    my UInt:D $offset = Int(($number * $bytes) / $.bytes-per-sector);
    die(X::Voidvault::Parser::VaultOffset::Alignment.new(:content(~$/)))
        unless $offset %% 8;
    my %offset-sector-size = :$offset, :sector-size($.bytes-per-sector);
    make(%offset-sector-size);
}

# units --digits 10 --terse kibibytes bytes
multi sub bytes-per-unit(OffsetUnit::KIBIBYTE --> 1024) {*}
# units --digits 10 --terse mebibytes bytes
multi sub bytes-per-unit(OffsetUnit::MEBIBYTE --> 1048576) {*}
# units --digits 10 --terse gibibytes bytes
multi sub bytes-per-unit(OffsetUnit::GIBIBYTE --> 1073741824) {*}
# units --digits 13 --terse tebibytes bytes
multi sub bytes-per-unit(OffsetUnit::TEBIBYTE --> 1099511627776) {*}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
