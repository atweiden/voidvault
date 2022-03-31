use v6;
unit role Voidvault::Replace::GRUB::Linux;

constant $FILE = '/etc/grub.d/10_linux';

multi method replace(Str:D $ where $FILE --> Nil)
{
    my Str:D $chroot-dir = $.config.chroot-dir;
    my Str:D $file = sprintf(Q{%s%s}, $chroot-dir, $FILE);
    my Str:D @line = $file.IO.lines;
    my Regex:D $regex = /'${CLASS}'\h/;
    my UInt:D @index = @line.grep($regex, :k);
    @index.race.map(-> UInt:D $index {
        @line[$index] .= subst($regex, '--unrestricted ${CLASS} ')
    });
    my Str:D $replace = @line.join("\n");
    spurt($file, $replace ~ "\n");
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
