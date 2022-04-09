use v6;
unit role Voidvault::Config::Roles::TwoFA;
also does Voidvault::Config::Roles::OneFA;


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
    # ensure boot vault device differs from vault device
    $!device ne $!bootvault-device
        or die("Sorry, Vault and Boot Vault devices must differ");
}

multi submethod BUILD(
    Str :$bootvault-device,
    *%
    --> Nil
)
{
    $!bootvault-device = $bootvault-device
        if $bootvault-device;
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
