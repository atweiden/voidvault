use v6;
use Voidvault::Constants;
use Voidvault::Types;
unit role Voidvault::Replace::Crypttab;

my constant $FILE = $Voidvault::Constants::FILE-CRYPTTAB;

multi method replace(::?CLASS:D: Str:D $ where $FILE --> Nil)
{
    my Str:D $chroot-dir = $.config.chroot-dir;
    my VaultName:D $vault-name = $.config.vault-name;
    my Str:D $vault-key = $.config.vault-key;
    my Str:D $partition-vault = self.gen-partition('vault');
    my Str:D $vault-uuid =
        qqx<blkid --match-tag UUID --output value $partition-vault>.trim;
    my Str:D $file = sprintf(Q{%s%s}, $chroot-dir, $FILE);
    my Str:D $key = qq:to/EOF/;
    $vault-name   UUID=$vault-uuid   $vault-key   luks
    EOF
    spurt($file, "\n" ~ $key, :append);
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
