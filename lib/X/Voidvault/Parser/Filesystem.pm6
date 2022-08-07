use v6;

# X::Voidvault::Parser::Filesystem::Invalid {{{

class X::Voidvault::Parser::Filesystem::Invalid
{
    also is Exception;

    has Str:D $.content is required;

    method message(::?CLASS:D: --> Str:D)
    {
        my Str:D $message = "Sorry, received invalid filesystem ($.content)";
    }
}

# end X::Voidvault::Parser::Filesystem::Invalid }}}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
