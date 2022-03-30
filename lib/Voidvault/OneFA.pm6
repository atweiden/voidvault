use v6;
use Voidvault;
use Voidvault::Config;
use Voidvault::Config::OneFA;
use Voidvault::Constants;
unit class Voidvault::OneFA;
also is Voidvault;


# -----------------------------------------------------------------------------
# attributes
# -----------------------------------------------------------------------------

has Voidvault::Config::OneFA:D $.config is required;


# -----------------------------------------------------------------------------
# worker functions
# -----------------------------------------------------------------------------

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
        --new=1:0:+{$Voidvault::Constants::GDISK-SIZE-BIOS}
        --typecode=1:{$Voidvault::Constants::GDISK-TYPECODE-BIOS}
        --new=2:0:+{$Voidvault::Constants::GDISK-SIZE-EFI}
        --typecode=2:{$Voidvault::Constants::GDISK-TYPECODE-EFI}
        --new=3:0:+{$Voidvault::Constants::GDISK-SIZE-BOOT}
        --typecode=3:{$Voidvault::Constants::GDISK-TYPECODE-LINUX}
        --new=4:0:0
        --typecode=4:{$Voidvault::Constants::GDISK-TYPECODE-LINUX}
    >, $device);
}


# -----------------------------------------------------------------------------
# helper functions
# -----------------------------------------------------------------------------

multi method gen-partition(::?CLASS:D: 'boot' --> Str:D)
{
    # e.g. /dev/sda3
    my UInt:D $index = 2;
    my Str:D $partition = @*partition[$index];
}

multi method gen-partition(::?CLASS:D: 'vault' --> Str:D)
{
    # e.g. /dev/sda4
    my UInt:D $index = 3;
    my Str:D $partition = @*partition[$index];
}

# vim: set filetype=raku foldmethod=marker foldlevel=0 nowrap:
