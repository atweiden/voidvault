use v6;
use NativeCall;
unit module Crypt::Libcrypt:auth<atweiden>;

# Credit: https://github.com/jonathanstowe/Crypt-Libcrypt
sub crypt(Str, Str --> Str) is native('crypt', v1) is export {*}

# vim: set filetype=perl6 foldmethod=marker foldlevel=0:
