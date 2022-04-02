use v6;
use Voidvault::Constants;
unit role Voidvault::Replace::OpenResolv;

my constant $FILE = $Voidvault::Constants::OPENRESOLV;

multi method replace(::?CLASS:D: Str:D $ where $FILE --> Nil)
{
    my Str:D $chroot-dir = $.config.chroot-dir;
    my Bool:D $disable-ipv6 = $.config.disable-ipv6;
    my Str:D $path = $FILE.substr(1);
    my Str:D $file = sprintf(Q{%s%s}, $chroot-dir, $FILE);
    copy(%?RESOURCES{$path}, $file);
    replace($file, $disable-ipv6);
}

multi sub replace(Str:D $file where .so, Bool:D $disable-ipv6 where .so --> Nil)
{
    my Str:D @replace =
        $file.IO.lines
        ==> replace('resolvconf.conf', 'name_servers');
    my Str:D $replace = @replace.join("\n");
    spurt($file, $replace ~ "\n");
}

multi sub replace(Str:D $file where .so, Bool:D $disable-ipv6 --> Nil)
{*}

multi sub replace(
    Str:D $subject where 'name_servers',
    Str:D @line
    --> Array[Str:D]
)
{
    my UInt:D $index = @line.first(/^$subject/, :k);
    my Str:D $replace = sprintf(Q{%s="127.0.0.1"}, $subject);
    @line[$index] = $replace;
    @line;
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
