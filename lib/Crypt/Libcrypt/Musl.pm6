use v6;
use NativeCall;
unit module Crypt::Libcrypt::Musl;

# POSIX crypt() for musl systems
sub crypt(Str, Str --> Str) is native is export {*}
