use v6;
use Voidvault::Types;
unit class Voidvault::Parser::Mode::Actions;

method mode:sym<base>($/ --> Nil)
{
    make(Mode::BASE);
}

method mode:sym<1fa>($/ --> Nil)
{
    make(Mode::<1FA>);
}

method mode:sym<2fa>($/ --> Nil)
{
    make(Mode::<2FA>);
}

method TOP($/ --> Nil)
{
    make($<mode>.made);
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
