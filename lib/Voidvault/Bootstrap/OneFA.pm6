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

    # format boot vault ext4 and mount it
    self.mkbootext4;

    # create and open vault, placing detached header in boot vault
    self.mkvault;

    # create and mount btrfs volumes
    self.mkbtrfs;

    # mount efi boot
    self.mount-efi;

    # mount boot btrfs volume on root
    self.mount-rbind-bootbtrfs;

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

# format opened bootvault ext4 and mount
method mkbootext4(::?CLASS:D: --> Nil)
{
    my AbsolutePath:D $chroot-dir-boot = $.config.chroot-dir-boot;
    my VaultName:D $bootvault-name = $.config.bootvault-name;
    my Str:D $bootvault-device-mapper =
        sprintf(Q{/dev/mapper/%s}, $bootvault-name);

    # enable fscrypt for no particular reason
    run(qqw<mkfs.ext4 -O encrypt $bootvault-device-mapper>);

    my Str:D $mount-ext4-cmdline = qqw<
        mount
        --types ext4
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
    my VaultPass $vault-pass = $.config.vault-pass;
    my AbsolutePath:D $vault-header = do {
        my AbsolutePath:D $vault-header-chomped = $.config.vault-header-chomped;
        sprintf(Q{%s%s}, $chroot-dir-boot, $vault-header-chomped);
    };

    Voidvault::Utils.mkvault(
        :open,
        :$vault-type,
        :$partition-vault,
        :$vault-name,
        :$vault-pass,
        :$vault-header
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
    mkdir($directory-efi);
    my Str:D $mount-options = qw<
        nodev
        noexec
        nosuid
    >.join(',');
    run(qqw<mount --options $mount-options $partition-efi $directory-efi>);
}

method mount-rbind-bootbtrfs(::?CLASS:D: --> Nil)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my AbsolutePath:D $chroot-dir-boot = $.config.chroot-dir-boot;
    my Str:D $mount-dir = sprintf(Q{%s/boot}, $chroot-dir);
    mkdir($mount-dir);
    run(qqw<mount --rbind $chroot-dir-boot $mount-dir>);
}

method install-vault-key(::?CLASS:D: --> Nil)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;

    my VaultPass $vault-pass = $.config.vault-pass;
    my VaultKey:D $vault-key = $.config.vault-key;
    my Str:D $partition-vault = self.gen-partition('vault');
    my AbsolutePath:D $vault-header = do {
        my VaultHeader:D $vault-header = $.config.vault-header;
        sprintf(Q{%s%s}, $chroot-dir, $vault-header);
    };

    my VaultPass $bootvault-pass = $.config.bootvault-pass;
    my BootvaultKey:D $bootvault-key = $.config.bootvault-key;
    my Str:D $partition-bootvault = self.gen-partition('boot');

    # add key to vault
    Voidvault::Utils.install-vault-key(
        :$partition-vault,
        :$vault-key,
        :$vault-pass,
        :$chroot-dir,
        :$vault-header
    );

    # add key to boot vault
    Voidvault::Utils.install-vault-key(
        :partition-vault($partition-bootvault),
        :vault-key($bootvault-key),
        :vault-pass($bootvault-pass),
        :$chroot-dir
    );

    # configure /etc/crypttab for vault and bootvault keys
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

multi method configure-bootloader(
    ::?CLASS:D:
    'default',
    Str:D $subject where 'GRUB_CMDLINE_LINUX_DEFAULT'
    --> Nil
)
{
    self.replace($Voidvault::Constants::FILE-GRUB-DEFAULT, $subject, 'PARTUUID');
}

method secure-secret-prefix(::?CLASS:D: --> Nil)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my Str:D $vault = $Voidvault::Constants::SECRET-PREFIX-VAULT;
    my Str:D $bootvault = $Voidvault::Constants::SECRET-PREFIX-BOOTVAULT;
    run(qqw<void-chroot $chroot-dir chmod -R g-rwx,o-rwx $vault $bootvault>);
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
