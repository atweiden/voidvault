use v6;
use Voidvault::Constants;
use Voidvault::Types;
unit role Voidvault::Replace::PAM;

my constant $FILE = $Voidvault::Constants::FILE-PAM;

multi method replace(Str:D $ where $FILE --> Nil)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my Str:D $file = sprintf(Q{%s%s}, $chroot-dir, $FILE);
    my Str:D $slurp = slurp($file).trim-trailing;
    my Str:D $replace =
        sprintf(Q{%s rounds=%s}, $slurp, $Voidvault::Constants::CRYPT-ROUNDS);
    spurt($file, $replace ~ "\n");
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
