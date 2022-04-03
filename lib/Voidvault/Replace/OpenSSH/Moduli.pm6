use v6;
use Voidvault::Constants;
unit role Voidvault::Replace::OpenSSH::Moduli;

my constant $FILE = $Voidvault::Constants::FILE-OPENSSH-MODULI;

multi method replace(Str:D $ where $FILE --> Nil)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my Str:D $file = sprintf(Q{%s%s}, $chroot-dir, $FILE);
    my Str:D $replace =
        $file.IO.lines
        .grep(/^\w/)
        .grep({ .split(/\h+/)[4] > 3071 })
        .join("\n");
    spurt($file, $replace ~ "\n");
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
