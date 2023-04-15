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

# 1fa mode requires running C<mount-efi> earlier than base mode
multi method bootstrap(::?CLASS:D: 'mount-efi' --> Nil)
{*}

# secure disk configuration
method mkdisk(::?CLASS:D: --> Nil)
{
    # partition device with extra boot partition
    self.sgdisk;

    # create uefi partition
    self.mkefi;

    # create and open boot vault
    self.mkbootvault;

    # format boot vault ext4 and mount it
    self.mkbootext4;

    # create and open vault, placing detached header in boot vault
    self.mkvault;

    # create and mount btrfs volumes
    self.mkbtrfs;

    # mount efi boot
    self.mount-efi;

    # mount boot ext4 volume on root
    self.mount-rbind-bootext4;

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
    # assume bootvault is on same device as vault, or on non-HDD drive
    my DiskType:D $disk-type = $.config.disk-type;
    my VaultPass $bootvault-pass = $.config.bootvault-pass;
    my Str:D $bootvault-cipher = $.config.bootvault-cipher;
    my Str:D $bootvault-hash = $.config.bootvault-hash;
    my Str:D $bootvault-iter-time = $.config.bootvault-iter-time;
    my Str:D $bootvault-key-size = $.config.bootvault-key-size;
    my Str $bootvault-offset = $.config.bootvault-offset;
    my Str $bootvault-sector-size = $.config.bootvault-sector-size;
    Voidvault::Utils.mkvault(
        :open,
        :vault-type($bootvault-type),
        :partition-vault($partition-bootvault),
        :vault-name($bootvault-name),
        :$disk-type,
        :vault-pass($bootvault-pass)
        :vault-cipher($bootvault-cipher),
        :vault-hash($bootvault-hash),
        :vault-iter-time($bootvault-iter-time),
        :vault-key-size($bootvault-key-size),
        :vault-offset($bootvault-offset),
        :vault-sector-size($bootvault-sector-size)
    );
}

# format opened bootvault ext4 and mount
method mkbootext4(::?CLASS:D: --> Nil)
{
    my AbsolutePath:D $chroot-dir-boot = $.config.chroot-dir-boot;
    my VaultName:D $bootvault-name = $.config.bootvault-name;
    my Str:D $bootvault-device-mapper =
        sprintf(Q{/dev/mapper/%s}, $bootvault-name);

    # enable fscrypt for no particular reason
    run(qqw<mkfs.ext4 -O encrypt $bootvault-device-mapper>);

    my Str:D $mount-options = qw<
        nodev
        noexec
        nosuid
    >.join(',');

    my Str:D $mount-ext4-cmdline = qqw<
        mount
        --types ext4
        --options $mount-options
        $bootvault-device-mapper
        $chroot-dir-boot
    >.join(' ');

    shell($mount-ext4-cmdline);
}

method mkvault(::?CLASS:D: --> Nil)
{
    my AbsolutePath:D $chroot-dir-boot = $.config.chroot-dir-boot;
    my VaultType:D $vault-type = 'LUKS2';
    my Str:D $partition-vault = self.gen-partition('vault');
    my VaultName:D $vault-name = $.config.vault-name;
    my DiskType:D $disk-type = $.config.disk-type;
    my VaultPass $vault-pass = $.config.vault-pass;
    my AbsolutePath:D $vault-header = do {
        my AbsolutePath:D $vault-header-chomped = $.config.vault-header-chomped;
        sprintf(Q{%s%s}, $chroot-dir-boot, $vault-header-chomped);
    };
    my Str:D $vault-cipher = $.config.vault-cipher;
    my Str:D $vault-hash = $.config.vault-hash;
    my Str:D $vault-iter-time = $.config.vault-iter-time;
    my Str:D $vault-key-size = $.config.vault-key-size;
    my Str $vault-offset = $.config.vault-offset;
    my Str $vault-sector-size = $.config.vault-sector-size;

    Voidvault::Utils.mkvault(
        :open,
        :$vault-type,
        :$partition-vault,
        :$vault-name,
        :$disk-type,
        :$vault-pass,
        :$vault-header,
        :$vault-cipher,
        :$vault-hash,
        :$vault-iter-time,
        :$vault-key-size,
        :$vault-offset,
        :$vault-sector-size
    );
}

method mount-efi(::?CLASS:D: --> Nil)
{
    my AbsolutePath:D $chroot-dir-boot = $.config.chroot-dir-boot;
    my Str:D $partition-efi = self.gen-partition('efi');
    my AbsolutePath:D $directory-efi = do {
        my AbsolutePath:D $directory-efi = $.config.directory-efi-chomped;
        sprintf(Q{%s%s}, $chroot-dir-boot, $directory-efi);
    };
    Voidvault::Utils.secure-mount-efi(:$partition-efi, :$directory-efi);
}

method mount-rbind-bootext4(::?CLASS:D: --> Nil)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my AbsolutePath:D $chroot-dir-boot = $.config.chroot-dir-boot;
    my Str:D $mount-dir = sprintf(Q{%s/boot}, $chroot-dir);
    mkdir($mount-dir);
    run(qqw<mount --rbind $chroot-dir-boot $mount-dir>);
}

method install-vault-key-file(::?CLASS:D: --> Nil)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;

    my VaultPass $vault-pass = $.config.vault-pass;
    my VaultKeyFile:D $vault-key-file = $.config.vault-key-file;
    my Str:D $partition-vault = self.gen-partition('vault');
    my AbsolutePath:D $vault-header = do {
        my VaultHeader:D $vault-header = $.config.vault-header;
        sprintf(Q{%s%s}, $chroot-dir, $vault-header);
    };

    my VaultPass $bootvault-pass = $.config.bootvault-pass;
    my BootvaultKeyFile:D $bootvault-key-file = $.config.bootvault-key-file;
    my Str:D $partition-bootvault = self.gen-partition('boot');

    # add key to vault
    Voidvault::Utils.install-vault-key-file(
        :$partition-vault,
        :$vault-key-file,
        :$vault-pass,
        :$chroot-dir,
        :$vault-header
    );

    # add key to boot vault
    Voidvault::Utils.install-vault-key-file(
        :partition-vault($partition-bootvault),
        :vault-key-file($bootvault-key-file),
        :vault-pass($bootvault-pass),
        :$chroot-dir
    );
}

multi method secure-mount(::?CLASS:D: --> Nil)
{
    # 1fa mode already mounts C</boot> partition nodev,noexec,nosuid
    grep-boot(@*directory-bind-mounted);
}

multi method configure-fstab(
    ::?CLASS:D:
    Str:D :@directory-bind-mounted!
    --> Nil
)
{
    # omit C</boot> fstab entry modification, C</boot> was unmodified
    grep-boot(@directory-bind-mounted);
    self.replace($Voidvault::Constants::FILE-FSTAB, $_)
        for @directory-bind-mounted;
}

# omit repositioning C</boot/efi> fstab entry, C</boot> was unmodified
multi method configure-fstab(
    ::?CLASS:D:
    Str:D :directory-efi($)! where .so
    --> Nil
)
{*}

multi method configure-crypttab(::?CLASS:D: --> Nil)
{
    # configure /etc/crypttab for vault and bootvault key files
    self.replace($Voidvault::Constants::FILE-CRYPTTAB, '1fa');
}

multi method generate-initramfs(
    ::?CLASS:D:
    Str:D $subject where 'install_items'
    --> Nil
)
{
    self.replace($Voidvault::Constants::FILE-DRACUT, $subject, '1fa');
}

method secure-secret-prefix(::?CLASS:D: --> Nil)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my Str:D $vault = $Voidvault::Constants::SECRET-PREFIX-VAULT;
    my Str:D $bootvault = $Voidvault::Constants::SECRET-PREFIX-BOOTVAULT;
    run(qqw<void-chroot $chroot-dir chmod -R g-rwx,o-rwx $vault $bootvault>);
}

multi method unmount(::?CLASS:D: --> Nil)
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

sub grep-boot(Str:D @directory-bind-mounted --> Nil)
{
    @directory-bind-mounted .= grep(none '/boot');
}

# vim: set filetype=raku foldmethod=marker foldlevel=0 nowrap:
