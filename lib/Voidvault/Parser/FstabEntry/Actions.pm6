use v6;
use X::Voidvault::Parser::FstabEntry;
unit class Voidvault::Parser::FstabEntry::Actions;

method path($/ --> Nil)
{
    make(~$/);
}

method options($/ --> Nil)
{
    make(~$/);
}

method TOP($/ --> Nil)
{
    my Str:D $path = $<path>.made;
    my Str:D $options = $<options>.made;
    my Str:D $secure-mount-options =
        $options
        .split(',')
        .grep(/nodev|noexec|nosuid/)
        .join(',');
    die(X::Voidvault::Parser::FstabEntry::MissingOptions.new(:$options))
        unless $secure-mount-options;
    my Str:D $replace = "$path $path none remount,$secure-mount-options 0 0";
    make($replace);
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
