use v6;
use Voidvault::Config;
use Voidvault::Config::Utils;
use Voidvault::Constants;
use Voidvault::Types;
unit role Voidvault::Config::OneFA::Shared;
also does Voidvault::Config;


# -----------------------------------------------------------------------------
# attributes
# -----------------------------------------------------------------------------

# C<$.chroot-dir> before altering, becomes C<AbsolutePath:D> upon C<TWEAK>
has Str $!chroot-dir-orig;

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

# intended path to LUKS encrypted boot volume key file on bootstrapped system
has BootvaultKeyFile:D $.bootvault-key-file =
    ?%*ENV<VOIDVAULT_BOOTVAULT_KEY_FILE>
        ?? gen-bootvault-key-file(%*ENV<VOIDVAULT_BOOTVAULT_KEY_FILE>)
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

has Str:D $.bootvault-cipher =
    ?%*ENV<VOIDVAULT_BOOTVAULT_CIPHER>
        ?? %*ENV<VOIDVAULT_BOOTVAULT_CIPHER>
        !! 'aes-xts-plain64';

has Str:D $.bootvault-hash =
    ?%*ENV<VOIDVAULT_BOOTVAULT_HASH>
        ?? %*ENV<VOIDVAULT_BOOTVAULT_HASH>
        !! 'sha512';

has Str:D $.bootvault-iter-time =
    ?%*ENV<VOIDVAULT_BOOTVAULT_ITER_TIME>
        ?? %*ENV<VOIDVAULT_BOOTVAULT_ITER_TIME>
        !! '5000';

has Str:D $.bootvault-key-size =
    ?%*ENV<VOIDVAULT_BOOTVAULT_KEY_SIZE>
        ?? %*ENV<VOIDVAULT_BOOTVAULT_KEY_SIZE>
        !! '512';

has Str $.bootvault-offset =
    ?%*ENV<VOIDVAULT_BOOTVAULT_OFFSET>
        ?? %*ENV<VOIDVAULT_BOOTVAULT_OFFSET>
        !! Nil;

has Str $.bootvault-sector-size =
    ?%*ENV<VOIDVAULT_BOOTVAULT_SECTOR_SIZE>
        ?? %*ENV<VOIDVAULT_BOOTVAULT_SECTOR_SIZE>
        !! Nil;


# -----------------------------------------------------------------------------
# accessor methods
# -----------------------------------------------------------------------------

# C<$!chroot-dir-boot> is not configurable at instantiation
method chroot-dir-boot(::?CLASS:D: --> AbsolutePath:D)
{
    # detached vault header is directly written to pre-existing boot vault
    my AbsolutePath:D $chroot-dir-boot = sprintf(Q{%s/BOOT}, $!chroot-dir-orig);
}

# needed before bind mounting boot atop root filesystem
method directory-efi-chomped(::?CLASS:D: --> AbsolutePath:D)
{
    my AbsolutePath:D $directory-efi-chomped =
        chomp-secret-prefix(:vault, $Voidvault::Constants::DIRECTORY-EFI);
}

# needed before bind mounting boot atop root filesystem
method vault-header-chomped(::?CLASS:D: --> AbsolutePath:D)
{
    # take advantage of the fact <$.vault-header> is typed C<VaultHeader>
    my AbsolutePath:D $vault-header-chomped =
        # C<VaultHeader> type validity hinges upon C<SECRET-PREFIX-VAULT>
        chomp-secret-prefix(:vault, $!vault-header);
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
