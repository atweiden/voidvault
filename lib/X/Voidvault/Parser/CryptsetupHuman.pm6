use v6;

# X::Voidvault::Parser::CryptsetupHuman::Alignment {{{

class X::Voidvault::Parser::CryptsetupHuman::Alignment
{
    also is Exception;

    has Str:D $.content is required;

    method message(::?CLASS:D: --> Str:D)
    {
        my Str:D $message =
            "Sorry, $.content not aligned to 4096-byte sectors (multiple of 8)";
    }
}

# end X::Voidvault::Parser::CryptsetupHuman::Alignment }}}
# X::Voidvault::Parser::CryptsetupHuman::Invalid {{{

class X::Voidvault::Parser::CryptsetupHuman::Invalid
{
    also is Exception;

    has Str:D $.content is required;

    method message(::?CLASS:D: --> Str:D)
    {
        my Str:D $message =
            "Sorry, received invalid value ($.content)";
    }
}

# end X::Voidvault::Parser::CryptsetupHuman::Invalid }}}
# X::Voidvault::Parser::CryptsetupHuman::SectorSize {{{

class X::Voidvault::Parser::CryptsetupHuman::SectorSize
{
    also is Exception;

    has UInt:D $.sector-size is required;

    method message(::?CLASS:D: --> Str:D)
    {
        my Str:D $message =
            "Sorry, received invalid cryptsetup sector size ($.sector-size)";
    }
}

# end X::Voidvault::Parser::CryptsetupHuman::SectorSize }}}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
