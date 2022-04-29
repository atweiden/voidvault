use v6;

# X::Voidvault::Parser::FstabEntry::Invalid {{{

class X::Voidvault::Parser::FstabEntry::Invalid
{
    also is Exception;

    has Str:D $.content is required;

    method message(::?CLASS:D: --> Str:D)
    {
        my Str:D $message =
            "Sorry, unexpectedly failed to parse fstab entry:\n\n"
            ~ "$.content";
    }
}

# end X::Voidvault::Parser::FstabEntry::Invalid }}}
# X::Voidvault::Parser::FstabEntry::MissingOptions {{{

class X::Voidvault::Parser::FstabEntry::MissingOptions
{
    also is Exception;

    has Str:D $.options is required;

    method message(::?CLASS:D: --> Str:D)
    {
        my Str:D $message =
            "Sorry, unexpectedly failed to find any secure mount options:\n\n"
            ~ "$.options";
    }
}

# end X::Voidvault::Parser::FstabEntry::MissingOptions }}}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
