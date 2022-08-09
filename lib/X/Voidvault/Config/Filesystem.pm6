use v6;

# X::Voidvault::Config::Filesystem::Impermissible {{{

role X::Voidvault::Config::Filesystem::Impermissible['base+bootvaultfs']
{
    also is Exception;

    method message(::?CLASS:D: --> Str:D)
    {
        my Str:D $message =
            "Sorry, unexpectedly received Bootvault filesystem in base mode";
    }
}

role X::Voidvault::Config::Filesystem::Impermissible['bootvaultbtrfs']
{
    also is Exception;

    method message(::?CLASS:D: --> Str:D)
    {
        my Str:D $message =
            "Sorry, unexpectedly received Bootvault filesystem of Btrfs";
    }
}

role X::Voidvault::Config::Filesystem::Impermissible['btrfs+lvm']
{
    also is Exception;

    method message(::?CLASS:D: --> Str:D)
    {
        my Str:D $message =
            "Sorry, unexpectedly received Vault filesystem of Btrfs with LVM";
    }
}

role X::Voidvault::Config::Filesystem::Impermissible['lvm-vg-name']
{
    also is Exception;

    method message(::?CLASS:D: --> Str:D)
    {
        my Str:D $message =
            "Sorry, unexpectedly received LVM Volume Group name without LVM";
    }
}

# end X::Voidvault::Config::Filesystem::Impermissible }}}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
