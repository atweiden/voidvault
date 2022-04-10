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

method sgdisk(::?CLASS:D: --> Nil)
{
    my Str:D $device = $.config.device;
    my Str:D $bootvault-device = $.config.bootvault-device;
    my Bool:D $partitionless = $.config.partitionless;
    sgdisk(:$device, :$bootvault-device, :$partitionless);
}

# partitionless mode - partition bootvault device only
multi sub sgdisk(
    Str:D :device($)! where .so,
    Str:D :$bootvault-device! where .so,
    Bool:D :partitionless($)! where .so
    --> Nil
)
{
    sgdisk('bootvault', :$bootvault-device);
}

# partition both device and bootvault device
multi sub sgdisk(
    Str:D :$device! where .so,
    Str:D :$bootvault-device! where .so,
    Bool:D :partitionless($)!
    --> Nil
)
{
    sgdisk('bootvault', :$bootvault-device);
    sgdisk('vault', :$device);
}

multi sub sgdisk(
    'bootvault',
    Str:D :$bootvault-device! where .so
    --> Nil
)
{
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
}

multi sub sgdisk(
    'vault',
    Str:D :$device! where .so
    --> Nil
)
{
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

multi method configure-crypttab(::?CLASS:D: --> Nil)
{
    my Bool:D $partitionless = $.config.partitionless;
    my Str:D $variant = gen-variant(:$partitionless);
    self.replace($Voidvault::Constants::FILE-CRYPTTAB, $variant);
}

multi sub gen-variant(Bool:D :partitionless($)! where .so --> '2fa') {*}
multi sub gen-variant(Bool:D :partitionless($)! --> '1fa') {*}

multi method configure-bootloader(
    ::?CLASS:D:
    'default',
    Str:D $subject where 'GRUB_CMDLINE_LINUX_DEFAULT'
    --> Nil
)
{
    my Bool:D $partitionless = $.config.partitionless;
    my Str:D $enable-luks = gen-enable-luks(:$partitionless);
    self.replace($Voidvault::Constants::FILE-GRUB-DEFAULT, $subject, $enable-luks);
}

multi sub gen-enable-luks(Bool:D :partitionless($)! where .so --> 'ID') {*}
multi sub gen-enable-luks(Bool:D :partitionless($)! --> 'PARTUUID') {*}

multi method install-bootloader(
    ::?CLASS:D:
    Bool:D :legacy($)! where .so
    --> Nil
)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my Str:D $bootvault-device = $.config.bootvault-device;
    Voidvault::Utils.void-chroot-grub-install(
        :legacy,
        :device($bootvault-device),
        :$chroot-dir
    );
}

multi method install-bootloader(
    ::?CLASS:D:
    Int:D $kernel-bits,
    Bool:D :uefi($)! where .so
    --> Nil
)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my Str:D $bootvault-device = $.config.bootvault-device;
    Voidvault::Utils.void-chroot-grub-install(
        :uefi,
        :device($bootvault-device),
        :$chroot-dir,
        $kernel-bits
    );
}


# -----------------------------------------------------------------------------
# helper functions
# -----------------------------------------------------------------------------

proto method gen-partition(::?CLASS:D: Str:D --> Str:D)
{
    my Str:D $device = $.config.device;
    my Str:D $bootvault-device = $.config.bootvault-device;
    my Bool:D $partitionless = $.config.partitionless;

    my Str:D @*partition = gen-partition(:$device, :$partitionless);
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
    # e.g. /dev/sda1, or /dev/sda when partitionless
    my UInt:D $index = 0;
    my Str:D $partition = @*partition[$index];
}

# trick method C<gen-partition('vault')> into returning e.g. /dev/sda
multi sub gen-partition(
    Str:D :$device where .so,
    Bool:D :partitionless($)! where .so
    --> Array[Str:D]
)
{
    # no partitions exist
    my Str:D @partition = $device;
}

multi sub gen-partition(
    Str:D :$device where .so,
    Bool:D :partitionless($)!
    --> Array[Str:D]
)
{
    my Str:D @partition = Voidvault::Utils.ls-partitions($device);
}

# vim: set filetype=raku foldmethod=marker foldlevel=0 nowrap:
