use v6;
use Voidvault::Parser::CryptsetupHuman::Actions;
use Voidvault::Parser::CryptsetupHuman::Grammar;
use X::Voidvault::Parser::CryptsetupHuman;
unit class Voidvault::Parser::CryptsetupHuman;

method parse(Str:D $content, *%opts (UInt :sector-size($)) --> Hash:D)
{
    my $grammar = Voidvault::Parser::CryptsetupHuman::Grammar;
    my Voidvault::Parser::CryptsetupHuman::Actions $actions .= new(|%opts);
    my %offset-sector-size = $grammar.parse($content, :$actions).made;
    die(X::Voidvault::Parser::CryptsetupHuman::Invalid.new(:$content))
        unless %offset-sector-size;
    %offset-sector-size;
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
