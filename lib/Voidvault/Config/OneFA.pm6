use v6;
use Voidvault::Config;
use Voidvault::Config::Utils;
use Voidvault::Types;
unit class Voidvault::Config::OneFA;
also does Voidvault::Config;


# -----------------------------------------------------------------------------
# attributes
# -----------------------------------------------------------------------------

# vault detached header goes directly into pre-existing bootvault
has AbsolutePath:D $.chroot-dir-bootvault = sprintf(Q{%s/BOOT}, $!chroot-dir);

# bootvault must be mounted separately at first
has AbsolutePath:D $.chroot-dir-rootvault = sprintf(Q{%s/ROOT}, $!chroot-dir);

# name for LUKS encrypted boot volume (default: bootvault)
has VaultName:D $.bootvault-name =
    %*ENV<VOIDVAULT_BOOTVAULT_NAME>
        ?? gen-vault-name(%*ENV<VOIDVAULT_BOOTVAULT_NAME>)
        !! prompt-name(:bootvault);

# password for LUKS encrypted boot volume
has VaultPass $.bootvault-pass =
    %*ENV<VOIDVAULT_BOOTVAULT_PASS>
        ?? gen-vault-pass(%*ENV<VOIDVAULT_BOOTVAULT_PASS>)
        !! Nil;

# intended path to LUKS encrypted boot volume key on bootstrapped system
has VaultKey:D $.bootvault-key =
    ?%*ENV<VOIDVAULT_BOOTVAULT_KEY>
        ?? gen-vault-key(%*ENV<VOIDVAULT_BOOTVAULT_KEY>)
        !! '/keys/bootvault.key';


# -----------------------------------------------------------------------------
# instantiation
# -----------------------------------------------------------------------------

multi submethod TWEAK(--> Nil)
{*}

multi submethod BUILD(
    Str :$bootvault-name,
    Str :$bootvault-pass,
    Str :$bootvault-key,
    *%
    --> Nil
)
{
    $!bootvault-name = gen-vault-name($bootvault-name)
        if $bootvault-name;
    $!bootvault-pass = gen-vault-pass($bootvault-pass)
        if $bootvault-pass;
    $!bootvault-key = gen-vault-key($bootvault-key)
        if $bootvault-key;
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
