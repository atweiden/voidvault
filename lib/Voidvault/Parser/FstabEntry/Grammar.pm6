use v6;
unit grammar Voidvault::Parser::FstabEntry::Grammar;

token uuid
{
    'UUID='\S+
}

token path
{
    '/'\S*
}

token filesystem
{
    | <uuid>
    | <path>
}

token type
{
    \S+
}

token options
{
    \S+
}

token dump
{
    \d ** 1
}

token pass
{
    \d ** 1
}

token TOP
{
    ^
    <.filesystem>
    \s+
    <path>
    \s+
    <.type>
    \s+
    <options>
    \s+
    <.dump>
    \s+
    <.pass>
    $
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
