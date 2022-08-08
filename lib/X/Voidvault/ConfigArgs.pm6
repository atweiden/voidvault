use v6;

# X::Voidvault::ConfigArgs::Positional::Impermissible {{{

role X::Voidvault::ConfigArgs::Positional::Impermissible['base+bootvaultfs']
{
    also is Exception;

    method message(::?CLASS:D: --> Str:D)
    {
        my Str:D $message =
            "Sorry, unexpectedly received Bootvault filesystem in base mode";
    }
}

role X::Voidvault::ConfigArgs::Positional::Impermissible['bootvaultbtrfs']
{
    also is Exception;

    method message(::?CLASS:D: --> Str:D)
    {
        my Str:D $message =
            "Sorry, unexpectedly received Bootvault filesystem of Btrfs";
    }
}

role X::Voidvault::ConfigArgs::Positional::Impermissible['btrfs+lvm']
{
    also is Exception;

    method message(::?CLASS:D: --> Str:D)
    {
        my Str:D $message =
            "Sorry, unexpectedly received Vault filesystem of Btrfs with LVM";
    }
}

# end X::Voidvault::ConfigArgs::Positional::Impermissible }}}
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
