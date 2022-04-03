use v6;
use Voidvault::Config::Base;
use Voidvault::Config::OneFA;
use Voidvault::Types;
unit class Voidvault::ConfigArgs;


# -----------------------------------------------------------------------------
# attributes
# -----------------------------------------------------------------------------

has Mode:D $.mode =
    ?%*ENV<VOIDVAULT_MODE>
        ?? gen-mode(%*ENV<VOIDVAULT_MODE>)
        !! Mode::BASE;

has %.opts;


# -----------------------------------------------------------------------------
# instantiation
# -----------------------------------------------------------------------------

submethod BUILD(Str :$mode, *%opts --> Nil)
{
    $!mode = gen-mode($mode) if $mode;
    %!opts = |%opts if %opts;
}

method new(Str :$mode, *%opts --> Voidvault::ConfigArgs:D)
{
    self.bless(:$mode, |%opts);
}


# -----------------------------------------------------------------------------
# worker functions
# -----------------------------------------------------------------------------

multi method Voidvault::Config(
    ::?CLASS:D:
    $? where $.mode eq Mode::<1FA>
    --> Voidvault::Config:D
)
{
    Voidvault::Config::OneFA.new(|%.opts);
}

multi method Voidvault::Config(
    ::?CLASS:D:
    --> Voidvault::Config:D
)
{
    Voidvault::Config::Base.new(|%.opts);
}


# -----------------------------------------------------------------------------
# helper functions
# -----------------------------------------------------------------------------

multi sub gen-mode(Str:D $ where m:i/1fa/ --> Mode:D)
{
    my Mode: $mode = Mode::<1FA>;
}

multi sub gen-mode(Str:D $mode)
{
    die("Sorry, invalid mode 「$mode」");
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
