use v6;
unit grammar Voidvault::Parser::VaultOffset::Grammar;

token number
{
    <.digit>+
}

token valid-unit
{
    <binary-prefix> <.ibyte>?
}

proto token binary-prefix {*}
token binary-prefix:sym<K> { <sym> ** 1 }
token binary-prefix:sym<M> { <sym> ** 1 }
token binary-prefix:sym<G> { <sym> ** 1 }
token binary-prefix:sym<T> { <sym> ** 1 }

token ibyte
{
    iB
}

token TOP
{
    ^
    <number>
    <valid-unit>
    $
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
