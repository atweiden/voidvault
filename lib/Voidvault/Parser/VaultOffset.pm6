use v6;
use Voidvault::Parser::VaultOffset::Actions;
use Voidvault::Parser::VaultOffset::Grammar;
use X::Voidvault::Parser::VaultOffset;
unit class Voidvault::Parser::VaultOffset;

method parse(Str:D $content, *%opts (UInt :sector-size($)) --> Hash:D)
{
    my Voidvault::Parser::VaultOffset::Actions $actions .= new(|%opts);
    my %offset-sector-size =
        Voidvault::Parser::VaultOffset::Grammar.parse($content, :$actions).made;
    die(X::Voidvault::Parser::VaultOffset::Invalid.new(:$content))
        unless %offset-sector-size;
    %offset-sector-size;
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
