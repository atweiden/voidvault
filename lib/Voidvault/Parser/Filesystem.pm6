use v6;
use Voidvault::Parser::Filesystem::Actions;
use Voidvault::Parser::Filesystem::Grammar;
use X::Voidvault::Parser::Filesystem;
unit class Voidvault::Parser::Filesystem;

method parse(Str:D $content --> List:D)
{
    my Voidvault::Parser::Filesystem::Actions $actions .= new;
    my $filesystem =
        Voidvault::Parser::Filesystem::Grammar.parse($content, :$actions).made;
    die(X::Voidvault::Parser::Filesystem::Invalid.new(:$content))
        unless $filesystem;
    $filesystem;
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
