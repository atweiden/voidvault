use v6;
use Voidvault::Parser::FstabEntry::Actions;
use Voidvault::Parser::FstabEntry::Grammar;
use X::Voidvault::Parser::FstabEntry;
unit class Voidvault::Parser::FstabEntry;

# transform erroneous C<genfstab>-generated fstab entry for secure remount
method gen-secure-remount(Str:D $content --> Str:D)
{
    my Voidvault::Parser::FstabEntry::Actions $actions .= new;
    my $secure-remount =
        Voidvault::Parser::FstabEntry::Grammar.parse($content, :$actions).made;
    die(X::Voidvault::Parser::FstabEntry::Invalid.new(:$content))
        unless $secure-remount;
    $secure-remount;
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
