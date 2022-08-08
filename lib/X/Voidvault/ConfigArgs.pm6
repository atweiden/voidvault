use v6;

# X::Voidvault::ConfigArgs::Positional::Invalid {{{

role X::Voidvault::ConfigArgs::Positional::Invalid['mode']
{
    also is Exception;

    has Str:D $.mode is required;

    method message(::?CLASS:D: --> Str:D)
    {
        my Str:D $message = "Sorry, received invalid mode ($.mode)";
    }
}

role X::Voidvault::ConfigArgs::Positional::Invalid['fs']
{
    also is Exception;

    has Str:D $.fs is required;

    method message(::?CLASS:D: --> Str:D)
    {
        my Str:D $message = "Sorry, received invalid filesystem ($.fs)";
    }
}

role X::Voidvault::ConfigArgs::Positional::Invalid['mode+fs']
{
    also is Exception;

    has Str:D $.mode is required;
    has Str:D $.fs is required;

    method message(::?CLASS:D: --> Str:D)
    {
        my Str:D $message =
            "Sorry, received invalid mode ($.mode) and filesystem ($.fs)";
    }
}

role X::Voidvault::ConfigArgs::Positional::Invalid['mode|fs']
{
    also is Exception;

    has Str:D $.content is required;

    method message(::?CLASS:D: --> Str:D)
    {
        my Str:D $message =
            "Sorry, received invalid mode or filesystem ($.content)";
    }
}

# end X::Voidvault::ConfigArgs::Positional::Invalid }}}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
