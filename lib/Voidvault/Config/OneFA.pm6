use v6;
use Voidvault::Config;
use Voidvault::Types;
unit class Voidvault::Config::OneFA;
also is Voidvault::Config;


# -----------------------------------------------------------------------------
# settings
# -----------------------------------------------------------------------------

# - attributes appear in specific order for prompting user

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
        !! '/keys/bootvault.key';


# -----------------------------------------------------------------------------
# class instantation
# -----------------------------------------------------------------------------

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


# -----------------------------------------------------------------------------
# user input prompts
# -----------------------------------------------------------------------------

sub prompt-name(
    Bool:D :bootvault($)! where .so
    --> VaultName:D
)
{
    my VaultName:D $vault-name = do {
        my VaultName:D $response-default = 'bootvault';
        my Str:D $prompt-text = "Enter bootvault name [$response-default]: ";
        my Str:D $help-text = q:to/EOF/.trim;
        Determining name of LUKS encrypted boot volume...

        Leave blank if you don't know what this is
        EOF
        tprompt(
            VaultName,
            $response-default,
            :$prompt-text,
            :$help-text
        );
    }
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
