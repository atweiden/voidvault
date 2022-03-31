use v6;
unit role Voidvault::Replace::SSH::Moduli;

my constant $FILE = '/etc/ssh/moduli';

multi method replace(Str:D $ where $FILE --> Nil)
{
    my Str:D $file = sprintf(Q{/mnt%s}, $FILE);
    my Str:D $replace =
        $file.IO.lines
        .grep(/^\w/)
        .grep({ .split(/\h+/)[4] > 3071 })
        .join("\n");
    spurt($file, $replace ~ "\n");
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
