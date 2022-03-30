use v6;
use Voidvault::Config;
unit class Voidvault::Bootstrap;


# -----------------------------------------------------------------------------
# attributes
# -----------------------------------------------------------------------------

has Voidvault::Config:D $.config is required;

# C<@partition> is C<Voidvault::Utils.lsblk> return value
multi method gen-partition(
    'efi',
    Str:D @partition
    --> Str:D
)
{
    # e.g. /dev/sda2
    my UInt:D $index = 1;
    my Str:D $partition = @partition[$index];
}

multi method gen-partition(
    'vault',
    Str:D @partition
    --> Str:D
)
{
    # e.g. /dev/sda3
    my UInt:D $index = 2;
    my Str:D $partition = @partition[$index];
}

# vim: set filetype=raku foldmethod=marker foldlevel=0 nowrap:
