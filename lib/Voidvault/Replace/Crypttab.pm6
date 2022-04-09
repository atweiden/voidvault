use v6;
use Voidvault::Constants;
use Voidvault::Types;
use Voidvault::Utils;
unit role Voidvault::Replace::Crypttab;

my constant $FILE = $Voidvault::Constants::FILE-CRYPTTAB;

multi method replace(::?CLASS:D: Str:D $ where $FILE, '1fa' --> Nil)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my Str:D $file = sprintf(Q{%s%s}, $chroot-dir, $FILE);

    # in 1fa mode, vault must be identified by C<PARTUUID>
    my VaultName:D $vault-name = $.config.vault-name;
    my VaultKeyFile:D $vault-key-file = $.config.vault-key-file;
    my VaultHeader:D $vault-header = $.config.vault-header;
    my Str:D $partition-vault = self.gen-partition('vault');
    my Str:D $vault-partuuid = Voidvault::Utils.partuuid($partition-vault);

    my VaultName:D $bootvault-name = $.config.bootvault-name;
    my BootvaultKeyFile:D $bootvault-key-file = $.config.bootvault-key-file;
    my Str:D $partition-bootvault = self.gen-partition('boot');
    my Str:D $bootvault-uuid = Voidvault::Utils.uuid($partition-bootvault);

    my Str:D $key = qq:to/EOF/;
    $vault-name   PARTUUID=$vault-partuuid   $vault-key-file   luks,force,header=$vault-header
    $bootvault-name   UUID=$bootvault-uuid   $bootvault-key-file   luks
    EOF
    spurt($file, "\n" ~ $key, :append);
}

multi method replace(::?CLASS:D: Str:D $ where $FILE --> Nil)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my Str:D $file = sprintf(Q{%s%s}, $chroot-dir, $FILE);

    my VaultName:D $vault-name = $.config.vault-name;
    my VaultKeyFile:D $vault-key-file = $.config.vault-key-file;
    my Str:D $partition-vault = self.gen-partition('vault');
    my Str:D $vault-uuid = Voidvault::Utils.uuid($partition-vault);

    my Str:D $key = qq:to/EOF/;
    $vault-name   UUID=$vault-uuid   $vault-key-file   luks
    EOF
    spurt($file, "\n" ~ $key, :append);
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
