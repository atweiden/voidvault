use v6;
unit role Voidvault::Replace::FSTab;

my constant $FILE = '/etc/fstab';

multi method replace(Str:D $ where $FILE --> Nil)
{
    my Str:D $file = sprintf(Q{/mnt%s}, $FILE);
    my Str:D @replace =
        $file.IO.lines
        # rm default /tmp mount in fstab
        ==> replace('rm')
        # add /tmp mount with options
        ==> replace('add');
    my Str:D $replace = @replace.join("\n");
    spurt($file, $replace ~ "\n");
}

multi sub replace('rm', Str:D @line --> Array[Str:D])
{
    my UInt:D $index = @line.first(/^tmpfs/, :k);
    @line.splice($index, 1);
    @line;
}

multi sub replace('add', Str:D @line --> Array[Str:D])
{
    my UInt:D $index = @line.elems;
    my Str:D $replace =
        'tmpfs /tmp tmpfs mode=1777,strictatime,nodev,noexec,nosuid 0 0';
    @line[$index] = $replace;
    @line;
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
