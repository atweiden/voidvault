use v6;
unit role Voidvault::Replace::Crypttab;

constant $FILE = '/etc/crypttab';

multi method replace(::?CLASS:D: Str:D $ where $FILE --> Nil)
{
    my VaultName:D $vault-name = $.config.vault-name;
    my Str:D $vault-key = $.config.vault-key;
    my Str:D $partition-vault = self.gen-partition('vault');
    my Str:D $vault-uuid =
        qqx<blkid --match-tag UUID --output value $partition-vault>.trim;
    my Str:D $file = sprintf(Q{/mnt%s}, $FILE);
    my Str:D $key = qq:to/EOF/;
    $vault-name   UUID=$vault-uuid   $vault-key   luks
    EOF
    spurt($file, "\n" ~ $key, :append);
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
