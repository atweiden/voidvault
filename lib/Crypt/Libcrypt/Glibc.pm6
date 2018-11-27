use v6;
use NativeCall;
unit module Crypt::Libcrypt::Glibc;

# POSIX crypt() for glibc systems
sub crypt(Str, Str --> Str) is native('crypt', v1) is export {*}
