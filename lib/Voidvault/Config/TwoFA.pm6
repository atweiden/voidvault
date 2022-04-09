use v6;
use Voidvault::Config::OneFA::Shared;
use Voidvault::Config::Utils;
unit class Voidvault::Config::TwoFA;
also does Voidvault::Config::OneFA::Shared;


# -----------------------------------------------------------------------------
# attributes
# -----------------------------------------------------------------------------

# target block device path for boot vault
has Str:D $.bootvault-device =
    %*ENV<VOIDVAULT_BOOTVAULT_DEVICE>
        || prompt-device(Voidvault::Utils.ls-devices);


# -----------------------------------------------------------------------------
# instantiation
# -----------------------------------------------------------------------------

multi submethod TWEAK(--> Nil)
{
    $!chroot-dir-orig = $!chroot-dir;
    $!chroot-dir = sprintf(Q{%s/ROOT}, $!chroot-dir-orig);

    # run again on C<$!chroot-dir> for above alteration
    ensure-chroot-dir($!chroot-dir);
    ensure-chroot-dir(self.chroot-dir-boot);

    # ensure boot vault name differs from vault name
    $!vault-name ne $!bootvault-name
        or die("Sorry, Vault and Boot Vault names must differ");

    # ensure vault header and vault key paths differ
    $!vault-header ne $!vault-key
        or die("Sorry, Vault Key and Vault Header paths must differ");

    # ensure boot vault device differs from vault device
    $!device ne $!bootvault-device
        or die("Sorry, Vault and Boot Vault devices must differ");
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
    $!bootvault-device = $bootvault-device
        if $bootvault-device;
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
