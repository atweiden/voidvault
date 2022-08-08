use v6;

# X::Voidvault::Parser::Mode::Invalid {{{

class X::Voidvault::Parser::Mode::Invalid
{
    also is Exception;

    has Str:D $.content is required;

    method message(::?CLASS:D: --> Str:D)
    {
        my Str:D $message = "Sorry, received invalid mode ($.content)";
    }
}

# end X::Voidvault::Parser::Mode::Invalid }}}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
