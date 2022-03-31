use v6;
unit role Voidvault::Replace::Hosts;

my constant $FILE = '/etc/hosts';

multi method replace(::?CLASS:D: Str:D $ where $FILE --> Nil)
{
    my Bool:D $disable-ipv6 = $.config.disable-ipv6;
    my HostName:D $host-name = $.config.host-name;
    my Str:D $file = sprintf(Q{/mnt%s}, $FILE);
    replace($file, $disable-ipv6, $host-name);
}

multi sub replace(
    Str:D $file where .so,
    Bool:D $disable-ipv6 where .so,
    HostName:D $host-name
    --> Nil
)
{
    my Str:D @replace =
        $file.IO.lines
        # remove IPv6 hosts
        ==> replace('hosts', '::1')
        ==> replace('hosts', '127.0.1.1', $host-name);
    my Str:D $replace = @replace.join("\n");
    spurt($file, $replace ~ "\n");
}

multi sub replace(
    Str:D $file where .so,
    Bool:D $disable-ipv6,
    HostName:D $host-name
    --> Nil
)
{
    my Str:D @replace =
        $file.IO.lines
        ==> replace('hosts', '127.0.1.1', $host-name);
    my Str:D $replace = @replace.join("\n");
    spurt($file, $replace ~ "\n");
}

multi sub replace(
    'hosts',
    '::1',
    Str:D @line
    --> Array[Str:D]
)
{
    my UInt:D $index = @line.first(/^'::1'/, :k);
    @line.splice($index, 1);
    @line;
}

multi sub replace(
    'hosts',
    '127.0.1.1',
    HostName:D $host-name,
    Str:D @line
    --> Array[Str:D]
)
{
    my UInt:D $index = @line.elems;
    my Str:D $replace =
        "127.0.1.1       $host-name.localdomain       $host-name";
    @line[$index] = $replace;
    @line;
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
