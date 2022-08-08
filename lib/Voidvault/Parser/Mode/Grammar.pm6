use v6;
unit grammar Voidvault::Parser::Mode::Grammar;

proto token mode {*}
token mode:sym<base> { <sym> }
token mode:sym<1fa> { <sym> }
token mode:sym<2fa> { <sym> }

token TOP { ^ <mode> $ }

# vim: set filetype=raku foldmethod=marker foldlevel=0:
