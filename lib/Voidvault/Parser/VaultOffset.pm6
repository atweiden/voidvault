use v6;
use Voidvault::Parser::VaultOffset::Actions;
use Voidvault::Parser::VaultOffset::Grammar;
use X::Voidvault::Parser::VaultOffset;
unit class Voidvault::Parser::VaultOffset;

method parse(Str:D $content --> Rat:D)
{
    my Voidvault::Parser::VaultOffset::Actions $actions .= new;
    my $offset =
        Voidvault::Parser::VaultOffset::Grammar.parse($content, :$actions).made;
    die(X::Voidvault::Parser::VaultOffset::Invalid.new(:$content))
        unless $offset;
    $offset;
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
