use v6;
use Voidvault::Config;
unit class Voidvault::Bootstrap;


# -----------------------------------------------------------------------------
# attributes
# -----------------------------------------------------------------------------

has Voidvault::Config:D $.config is required;


# -----------------------------------------------------------------------------
# helper functions
# -----------------------------------------------------------------------------

proto method gen-partition(Str:D --> Str:D)
{
    my Str:D $device = $.config.device;
    my Str:D @*partition = Voidvault::Utils.ls-partitions($device);
}

multi method gen-partition('efi' --> Str:D)
{
    # e.g. /dev/sda2
    my UInt:D $index = 1;
    my Str:D $partition = @*partition[$index];
}

multi method gen-partition('vault' --> Str:D)
{
    # e.g. /dev/sda3
    my UInt:D $index = 2;
    my Str:D $partition = @*partition[$index];
}

# vim: set filetype=raku foldmethod=marker foldlevel=0 nowrap:
