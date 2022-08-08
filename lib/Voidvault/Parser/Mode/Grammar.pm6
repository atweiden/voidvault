use v6;
unit grammar Voidvault::Parser::Mode::Grammar;

token mode-base { :i base }
token mode-onefa { :i 1fa }
token mode-twofa { :i 2fa }
token mode
{
    | <mode-base>
    | <mode-onefa>
    | <mode-twofa>
}

token TOP { ^ <mode> $ }

# vim: set filetype=raku foldmethod=marker foldlevel=0:
