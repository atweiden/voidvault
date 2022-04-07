use v6;
use Voidvault::Bootstrap;
use Voidvault::Constants;
use Voidvault::Types;
use Voidvault::Utils;
unit class Voidvault::Bootstrap::OneFA;
also does Voidvault::Bootstrap;


# -----------------------------------------------------------------------------
# worker functions
# -----------------------------------------------------------------------------

# secure disk configuration
method mkdisk(::?CLASS:D: --> Nil)
{
    # partition device with extra boot partition
    self.sgdisk;

    # create uefi partition
    self.mkefi;

    # create and open boot vault
    self.mkbootvault;

    # create and mount boot btrfs volume
    self.mkbootbtrfs;

    # create and open vault, placing detached header in boot vault
    self.mkvault;

    # create and mount btrfs volumes
    self.mkbtrfs;

    # mount efi boot
    self.mount-efi;

    # disable btrfs copy-on-write on select directories
    self.disable-cow;
}

# partition device with gdisk
method sgdisk(::?CLASS:D: --> Nil)
{
    my Str:D $device = $.config.device;

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

method mkbootvault(::?CLASS:D: --> Nil)
{
    my VaultType:D $bootvault-type = 'LUKS1';
    my Str:D $partition-bootvault = self.gen-partition('boot');
    my VaultName:D $bootvault-name = $.config.bootvault-name;
    my VaultPass $bootvault-pass = $.config.bootvault-pass;
    Voidvault::Utils.mkvault(
        :open,
        :vault-type($bootvault-type),
        :partition-vault($partition-bootvault),
        :vault-name($bootvault-name),
        :vault-pass($bootvault-pass)
    );
}

# create and mount btrfs filesystem on opened bootvault
method mkbootbtrfs(::?CLASS:D: --> Nil)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir-boot;
    my DiskType:D $disk-type = $.config.disk-type;
    my VaultName:D $vault-name = $.config.bootvault-name;

    my Str:D @subvolume = '@boot';
    my Str:D @kernel-module = qw<btrfs xxhash_generic>;
    # btrfs manual recommends C<--mixed> for filesystems under 1 GiB
    my Str:D @mkfs-option = qw<--csum xxhash --mixed>;
    my Str:D @mount-option = qw<
        rw
        noatime
        compress-force=zstd
        space_cache=v2
    >;
    push(@mount-option, 'ssd') if $disk-type eq 'SSD';

    Voidvault::Utils.mkbtrfs(
        :$chroot-dir,
        :$vault-name,
        :@subvolume,
        :&mount-subvolume,
        :@kernel-module,
        :@mkfs-option,
        :@mount-option
    );
}

sub mount-subvolume(
    Str:D :$subvolume! where $Voidvault::Constants::SUBVOLUME-BOOT,
    Str:D :$vault-device-mapper! where .so,
    AbsolutePath:D :$chroot-dir! where .so,
    Str:D :@mount-option
    --> Nil
)
{
    # C<$mount-dir> is effectively C</> here, in anticipation of mounting
    # C</mnt/BOOT> - a separate btrfs filesystem - at C</mnt/ROOT/boot>
    my Str:D $mount-dir = $chroot-dir;
    mkdir($mount-dir);
    my Str:D $mount-btrfs-subvolume-cmdline =
        Voidvault::Utils.build-mount-btrfs-cmdline(
            :@mount-option,
            :$vault-device-mapper,
            :$mount-dir
        );
    shell($mount-btrfs-subvolume-cmdline);
}

method mkvault(::?CLASS:D: --> Nil)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my VaultType:D $vault-type = 'LUKS2';
    my Str:D $partition-vault = self.gen-partition('vault');
    my VaultName:D $vault-name = $.config.vault-name;
    my VaultPass $vault-pass = $.config.vault-pass;
    my VaultHeader:D $vault-header-unprefixed = $.config.vault-header;
    my AbsolutePath:D $vault-header =
        sprintf(Q{%s%s}, $chroot-dir, $vault-header-unprefixed);

    Voidvault::Utils.mkvault(
        :open,
        :$vault-type,
        :$partition-vault,
        :$vault-name,
        :$vault-pass,
        :$vault-header
    );
}

method unmount(::?CLASS:D: --> Nil)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my AbsolutePath:D $chroot-dir-boot = $.config.chroot-dir-boot;
    my VaultName:D $vault-name = $.config.vault-name;
    my VaultName:D $bootvault-name = $.config.bootvault-name;
    CATCH { default { .resume } };
    run(qqw<umount --recursive --verbose $chroot-dir>);
    run(qqw<cryptsetup luksClose $vault-name>);
    rmdir($chroot-dir);
    run(qqw<umount --recursive --verbose $chroot-dir-boot>);
    run(qqw<cryptsetup luksClose $bootvault-name>);
    rmdir($chroot-dir-boot);
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
