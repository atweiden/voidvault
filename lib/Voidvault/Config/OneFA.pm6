use v6;
use Voidvault::Config;
use Voidvault::Types;
unit role Voidvault::Config::OneFA;
also does Voidvault::Config;


# -----------------------------------------------------------------------------
# settings
# -----------------------------------------------------------------------------

# name for LUKS encrypted boot volume (default: bootvault)
has VaultName:D $.bootvault-name =
    %*ENV<VOIDVAULT_BOOTVAULT_NAME>
        ?? Voidvault::Config.gen-vault-name(%*ENV<VOIDVAULT_BOOTVAULT_NAME>)
        !! prompt-name(:bootvault);

# password for LUKS encrypted boot volume
has VaultPass $.bootvault-pass =
    %*ENV<VOIDVAULT_BOOTVAULT_PASS>
        ?? Voidvault::Config.gen-vault-pass(%*ENV<VOIDVAULT_BOOTVAULT_PASS>)
        !! Nil;

# intended path to vault key on bootstrapped system
has Str:D $.bootvault-key =
    ?%*ENV<VOIDVAULT_BOOTVAULT_KEY>
        ?? %*ENV<VOIDVAULT_BOOTVAULT_KEY>
        !! '/boot/bootvolume.key';

submethod BUILD(
    Str :$bootvault-name,
    Str :$bootvault-pass,
    Str :$bootvault-key,
    *%
    --> Nil
)
{
    $!bootvault-name = Voidvault::Config.gen-vault-name($bootvault-name)
        if $bootvault-name;
    $!bootvault-pass = Voidvault::Config.gen-vault-pass($bootvault-pass)
        if $bootvault-pass;
    $!bootvault-key = $bootvault-key
        if $bootvault-key;
}

method new(
    *%opts (
        Str :bootvault-name($),
        Str :bootvault-pass($),
        Str :bootvault-key($),
        *%
    )
    --> Voidvault::Config::OneFA:D
)
{
    self.bless(|%opts);
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
