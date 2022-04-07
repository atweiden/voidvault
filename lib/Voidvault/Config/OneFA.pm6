use v6;
use Voidvault::Config;
use Voidvault::Config::Utils;
use Voidvault::Constants;
use Voidvault::Types;
unit class Voidvault::Config::OneFA;
also does Voidvault::Config;


# -----------------------------------------------------------------------------
# attributes
# -----------------------------------------------------------------------------

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
has BootvaultKey:D $.bootvault-key =
    ?%*ENV<VOIDVAULT_BOOTVAULT_KEY>
        ?? gen-bootvault-key(%*ENV<VOIDVAULT_BOOTVAULT_KEY>)
        !! sprintf(
            Q{%s/keys/boot.key},
            $Voidvault::Constants::SECRET-PREFIX-BOOTVAULT
        );

# intended path to LUKS encrypted volume detached header on bootstrapped system
has VaultHeader:D $.vault-header =
    ?%*ENV<VOIDVAULT_VAULT_HEADER>
        ?? gen-vault-header(%*ENV<VOIDVAULT_VAULT_HEADER>)
        !! sprintf(
            Q{%s/headers/root.header},
            $Voidvault::Constants::SECRET-PREFIX-VAULT
        );


# -----------------------------------------------------------------------------
# accessor methods
# -----------------------------------------------------------------------------

# C<$!chroot-dir-boot> is not configurable at instantiation
method chroot-dir-boot(::?CLASS:D: --> AbsolutePath:D)
{
    my AbsolutePath:D $chroot-dir = $.chroot-dir;
    # detached vault header is directly written to pre-existing boot vault
    my AbsolutePath:D $chroot-dir-boot = sprintf(Q{%s/BOOT}, $chroot-dir);
}


# -----------------------------------------------------------------------------
# instantiation
# -----------------------------------------------------------------------------

multi submethod TWEAK(--> Nil)
{
    my AbsolutePath:D $chroot-dir = $!chroot-dir;
    $!chroot-dir = sprintf(Q{%s/ROOT}, $chroot-dir);

    # run again on C<$!chroot-dir> for above alteration
    ensure-chroot-dir($!chroot-dir);
    ensure-chroot-dir($!chroot-dir-boot);

    # ensure boot vault name differs from vault name
    $!vault-name ne $!bootvault-name
        or die("Sorry, Vault and Boot Vault names must differ");

    # ensure vault header and vault key paths differ
    $!vault-header ne $!vault-key
        or die("Sorry, Vault Key and Vault Header paths must differ");
}

multi submethod BUILD(
    Str :$bootvault-name,
    Str :$bootvault-pass,
    Str :$bootvault-key,
    Str :$vault-header,
    *%
    --> Nil
)
{
    $!bootvault-name = gen-vault-name($bootvault-name)
        if $bootvault-name;
    $!bootvault-pass = gen-vault-pass($bootvault-pass)
        if $bootvault-pass;
    $!bootvault-key = gen-bootvault-key($bootvault-key)
        if $bootvault-key;
    $!vault-header = gen-vault-header($vault-header)
        if $vault-header;
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
