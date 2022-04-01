use v6;
unit role Voidvault::Replace::OpenSSH::Moduli;

constant $FILE = '/etc/ssh/moduli';

multi method replace(Str:D $ where $FILE --> Nil)
{
    my Str:D $chroot-dir = $.config.chroot-dir;
    my Str:D $file = sprintf(Q{%s%s}, $chroot-dir, $FILE);
    my Str:D $replace =
        $file.IO.lines
        .grep(/^\w/)
        .grep({ .split(/\h+/)[4] > 3071 })
        .join("\n");
    spurt($file, $replace ~ "\n");
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
