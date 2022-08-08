use v6;
use Voidvault::Parser::Mode::Actions;
use Voidvault::Parser::Mode::Grammar;
use X::Voidvault::Parser::Mode;
unit class Voidvault::Parser::Mode;

method parse(Str:D $content --> Mode:D)
{
    my Voidvault::Parser::Mode::Actions $actions .= new;
    my $mode = Voidvault::Parser::Mode::Grammar.parse($content, :$actions).made;
    die(X::Voidvault::Parser::Mode::Invalid.new(:$content)) unless $mode;
    $mode;
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
