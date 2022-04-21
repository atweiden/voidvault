use v6;

# X::Voidvault::Parser::VaultOffset::Alignment {{{

class X::Voidvault::Parser::VaultOffset::Alignment
{
    also is Exception;

    has Str:D $.content is required;

    method message(::?CLASS:D: --> Str:D)
    {
        my Str:D $message =
            "Sorry, $.content not aligned to 4096-byte sectors (multiple of 8)";
    }
}

# end X::Voidvault::Parser::VaultOffset::Alignment }}}
# X::Voidvault::Parser::VaultOffset::Invalid {{{

class X::Voidvault::Parser::VaultOffset::Invalid
{
    also is Exception;

    has Str:D $.content is required;

    method message(::?CLASS:D: --> Str:D)
    {
        my Str:D $message =
            "Sorry, received invalid cryptsetup LUKS offset ($.content)";
    }
}

# end X::Voidvault::Parser::VaultOffset::Invalid }}}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
