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

method sfdisk(::?CLASS:D: --> Nil)
{
    my Str:D $bootvault-device = $.config.bootvault-device;

    # erase existing partition table
    # create 2M EF02 BIOS boot sector
    # create 550M EF00 EFI system partition
    # create 1024M sized partition for LUKS1-encrypted boot
    my Str:D $sfdisk-cmdline = qqw<
        sfdisk
        --delete
        --wipe always
        --no-reread
        --no-tell-kernel
        $bootvault-device
    >.join(' ');
    my Str:D $sfdisk-size-bios =
        Voidvault::Utils.sfdisk-size-to-sectors($Voidvault::Constants::SFDISK-SIZE-BIOS);
    my Str:D $sfdisk-size-efi =
        Voidvault::Utils.sfdisk-size-to-sectors($Voidvault::Constants::SFDISK-SIZE-EFI);
    my Str:D $sfdisk-size-boot =
        Voidvault::Utils.sfdisk-size-to-sectors($Voidvault::Constants::SFDISK-SIZE-BOOT);
    shell($sfdisk-cmdline, :in(qq:to/EOF/));
    label: gpt
    device: $bootvault-device
    unit: sectors

    1 : size=$sfdisk-size-bios, type={$Voidvault::Constants::SFDISK-TYPESTR-BIOS}
    2 : size=$sfdisk-size-efi, type={$Voidvault::Constants::SFDISK-TYPESTR-EFI}
    3 : size=$sfdisk-size-boot, type={$Voidvault::Constants::SFDISK-TYPESTR-LINUX}
    EOF
}

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

    # trick method C<gen-partition('vault')> into returning e.g. /dev/sda
    my Str:D @*partition = $device;

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
    # e.g. /dev/sda
    my UInt:D $index = 0;
    my Str:D $partition = @*partition[$index];
}

# vim: set filetype=raku foldmethod=marker foldlevel=0 nowrap:
