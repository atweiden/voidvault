use v6;
use Voidvault::Bootstrap;
use Voidvault::Config;
use Voidvault::Config::OneFA;
use Voidvault::Utils;
unit class Voidvault::Bootstrap::OneFA;
also is Voidvault::Bootstrap;


# -----------------------------------------------------------------------------
# attributes
# -----------------------------------------------------------------------------

has Voidvault::Config::OneFA:D $.config is required;


# -----------------------------------------------------------------------------
# helper functions
# -----------------------------------------------------------------------------

multi method gen-partition('boot' --> Str:D)
{
    # e.g. /dev/sda3
    my UInt:D $index = 2;
    my Str:D $partition = @*partition[$index];
}

multi method gen-partition('vault' --> Str:D)
{
    # e.g. /dev/sda4
    my UInt:D $index = 3;
    my Str:D $partition = @*partition[$index];
}

# partition device with gdisk
method sgdisk(Str:D $device --> Nil)
{
    # erase existing partition table
    # create 2M EF02 BIOS boot sector
    # create 550M EF00 EFI system partition
    # create 1024M sized partition for LUKS1-encrypted boot
    # create max sized partition for LUKS2-encrypted vault
    run(qqw<
        sgdisk
        --zap-all
        --clear
        --mbrtogpt
        --new=1:0:+{$Voidvault::Utils::GDISK-SIZE-BIOS}
        --typecode=1:{$Voidvault::Utils::GDISK-TYPECODE-BIOS}
        --new=2:0:+{$Voidvault::Utils::GDISK-SIZE-EFI}
        --typecode=2:{$Voidvault::Utils::GDISK-TYPECODE-EFI}
        --new=3:0:+{$Voidvault::Utils::GDISK-SIZE-BOOT}
        --typecode=3:{$Voidvault::Utils::GDISK-TYPECODE-LINUX}
        --new=4:0:0
        --typecode=4:{$Voidvault::Utils::GDISK-TYPECODE-LINUX}
    >, $device);
}

# vim: set filetype=raku foldmethod=marker foldlevel=0 nowrap:
