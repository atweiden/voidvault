use v6;
use Voidvault::Constants;
use Voidvault::DeviceInfo;
use Voidvault::Types;
use Voidvault::Utils;
unit role Voidvault::Replace::Crypttab;

my constant $FILE = $Voidvault::Constants::FILE-CRYPTTAB;

multi method replace(::?CLASS:D: Str:D $ where $FILE, '1fa' --> Nil)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my Str:D $file = sprintf(Q{%s%s}, $chroot-dir, $FILE);

    my VaultName:D $vault-name = $.config.vault-name;
    my VaultKeyFile:D $vault-key-file = $.config.vault-key-file;
    my VaultHeader:D $vault-header = $.config.vault-header;
    my Str:D $vault-device = self!gen-crypttab-device('vault');

    my VaultName:D $bootvault-name = $.config.bootvault-name;
    my BootvaultKeyFile:D $bootvault-key-file = $.config.bootvault-key-file;
    my Str:D $bootvault-device = self!gen-crypttab-device('boot');

    my Str:D $key = qq:to/EOF/;
    $vault-name   $vault-device   $vault-key-file   luks,force,header=$vault-header
    $bootvault-name   $bootvault-device   $bootvault-key-file   luks
    EOF
    spurt($file, "\n" ~ $key, :append);
}

multi method replace(::?CLASS:D: Str:D $ where $FILE --> Nil)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my Str:D $file = sprintf(Q{%s%s}, $chroot-dir, $FILE);

    my VaultName:D $vault-name = $.config.vault-name;
    my VaultKeyFile:D $vault-key-file = $.config.vault-key-file;
    my Str:D $vault-device = self!gen-crypttab-device('vault');

    my Str:D $key = qq:to/EOF/;
    $vault-name   $vault-device   $vault-key-file   luks
    EOF
    spurt($file, "\n" ~ $key, :append);
}

method !gen-crypttab-device(
    Str:D $subject
    --> Str:D
)
{
    my Str:D $partition = self.gen-partition($subject);
    my DeviceInfo:D $device-info = Voidvault::Utils.device-info($partition);
    my Str:D $crypttab-device = gen-crypttab-device(:$device-info);
}

multi sub gen-crypttab-device(
    DeviceInfo[DeviceLocator::ID] :$device-info! where .so
    --> Str:D
)
{
    my Str:D $crypttab-device = $device-info.devlinks;
}

multi sub gen-crypttab-device(
    DeviceInfo[DeviceLocator::PARTUUID] :$device-info! where .so
    --> Str:D
)
{
    my Str:D $partuuid = $device-info.partuuid;
    my Str:D $crypttab-device = "PARTUUID=$partuuid";
}

multi sub gen-crypttab-device(
    DeviceInfo[DeviceLocator::UUID] :$device-info! where .so
    --> Str:D
)
{
    my Str:D $uuid = $device-info.uuid;
    my Str:D $crypttab-device = "UUID=$uuid";
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
