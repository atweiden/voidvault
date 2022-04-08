use v6;
use Voidvault::Bootstrap::OneFA;
use Voidvault::Constants;
use Voidvault::Types;
use Voidvault::Utils;
unit class Voidvault::Bootstrap::TwoFA;
also is Voidvault::Bootstrap::OneFA;


# -----------------------------------------------------------------------------
# worker functions
# -----------------------------------------------------------------------------

# partition device and bootvault device with gdisk
method sgdisk(::?CLASS:D: --> Nil)
{
    my Str:D $device = $.config.device;
    my Str:D $bootvault-device = $.config.bootvault-device;

    # erase existing partition table
    # create 2M EF02 BIOS boot sector
    # create 550M EF00 EFI system partition
    # create 1024M sized partition for LUKS1-encrypted boot
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
    >, $bootvault-device);

    # erase existing partition table
    # create max sized partition for LUKS2-encrypted vault
    run(qqw<
        sgdisk
        --zap-all
        --clear
        --mbrtogpt
        --new=1:0:0
        --typecode=1:{$Voidvault::Constants::GDISK-TYPECODE-LINUX}
    >, $device);
}


# -----------------------------------------------------------------------------
# helper functions
# -----------------------------------------------------------------------------

proto method gen-partition(::?CLASS:D: Str:D --> Str:D)
{
    my Str:D $device = $.config.device;
    my Str:D $bootvault-device = $.config.bootvault-device;
    my Str:D @*partition = Voidvault::Utils.ls-partitions($device);
    my Str:D @*bootvault-partition =
        Voidvault::Utils.ls-partitions($bootvault-device);
    {*}
}

multi method gen-partition(::?CLASS:D: 'efi' --> Str:D)
{
    # e.g. /dev/sdb2
    my UInt:D $index = 1;
    my Str:D $partition = @*bootvault-partition[$index];
}

multi method gen-partition(::?CLASS:D: 'boot' --> Str:D)
{
    # e.g. /dev/sdb3
    my UInt:D $index = 2;
    my Str:D $partition = @*bootvault-partition[$index];
}

multi method gen-partition(::?CLASS:D: 'vault' --> Str:D)
{
    # e.g. /dev/sda1
    my UInt:D $index = 0;
    my Str:D $partition = @*partition[$index];
}

# vim: set filetype=raku foldmethod=marker foldlevel=0 nowrap:
