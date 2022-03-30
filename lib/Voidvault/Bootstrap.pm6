use v6;
use Voidvault::Config;
use Voidvault::Utils;
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

# partition device with gdisk
method sgdisk(Str:D $device --> Nil)
{
    # erase existing partition table
    # create 2M EF02 BIOS boot sector
    # create 550M EF00 EFI system partition
    # create max sized partition for LUKS-encrypted vault
    run(qqw<
        sgdisk
        --zap-all
        --clear
        --mbrtogpt
        --new=1:0:+{$Voidvault::Utils::GDISK-SIZE-BIOS}
        --typecode=1:{$Voidvault::Utils::GDISK-TYPECODE-BIOS}
        --new=2:0:+{$Voidvault::Utils::GDISK-SIZE-EFI}
        --typecode=2:{$Voidvault::Utils::GDISK-TYPECODE-EFI}
        --new=3:0:0
        --typecode=3:{$Voidvault::Utils::GDISK-TYPECODE-LINUX}
    >, $device);
}

method mkefi(Str:D $partition-efi --> Nil)
{
    run(qw<modprobe vfat>);
    run(qqw<mkfs.vfat -F 32 $partition-efi>);
}

# vim: set filetype=raku foldmethod=marker foldlevel=0 nowrap:
