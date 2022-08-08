use v6;
use Voidvault::Types;
unit class Voidvault::Parser::Mode::Actions;

method mode-base($/ --> Nil)
{
    make(Mode::BASE);
}

method mode-onefa($/ --> Nil)
{
    make(Mode::<1FA>);
}

method mode-twofa($/ --> Nil)
{
    make(Mode::<2FA>);
}

multi method mode($/ where $<mode-base>.so --> Nil)
{
    make($<mode-base>.made);
}

multi method mode($/ where $<mode-onefa>.so --> Nil)
{
    make($<mode-onefa>.made);
}

multi method mode($/ where $<mode-twofa>.so --> Nil)
{
    make($<mode-twofa>.made);
}

method TOP($/ --> Nil)
{
    make($<mode>.made);
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
