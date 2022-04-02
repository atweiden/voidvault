use v6;
use Voidvault::Constants;
unit role Voidvault::Replace::Hosts;

my constant $FILE = $Voidvault::Constants::FILE-HOSTS;

multi method replace(::?CLASS:D: Str:D $ where $FILE --> Nil)
{
    my Str:D $chroot-dir = $.config.chroot-dir;
    my Bool:D $disable-ipv6 = $.config.disable-ipv6;
    my HostName:D $host-name = $.config.host-name;
    my Str:D $path = $FILE.substr(1);
    my Str:D $file = sprintf(Q{%s%s}, $chroot-dir, $FILE);
    copy(%?RESOURCES{$path}, $file);
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
