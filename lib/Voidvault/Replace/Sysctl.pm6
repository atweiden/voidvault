use v6;
unit role Voidvault::Replace::Sysctl;

constant $FILE = '/etc/sysctl.d/99-sysctl.conf'

multi method replace(::?CLASS:D: Str:D $ where $FILE --> Nil)
{
    my Bool:D $disable-ipv6 = $.config.disable-ipv6;
    my DiskType:D $disk-type = $.config.disk-type;
    my Str:D $path = $FILE.substr(1);
    my Str:D $file = sprintf(Q{/mnt%s}, $FILE);
    my Str:D $base-path = $path.IO.dirname;
    mkdir("/mnt/$base-path");
    copy(%?RESOURCES{$path}, $file);
    replace($file, $disable-ipv6, $disk-type);
}

multi sub replace(
    Str:D $file where .so,
    Bool:D $disable-ipv6 where .so,
    DiskType:D $disk-type where /SSD|USB/
    --> Nil
)
{
    my Str:D @replace =
        $file.IO.lines
        ==> replace('kernel.pid_max')
        ==> replace('net.ipv6.conf.all.disable_ipv6')
        ==> replace('net.ipv6.conf.default.disable_ipv6')
        ==> replace('net.ipv6.conf.lo.disable_ipv6')
        ==> replace('vm.mmap_rnd_bits')
        ==> replace('vm.vfs_cache_pressure')
        ==> replace('vm.swappiness');
    my Str:D $replace = @replace.join("\n");
    spurt($file, $replace ~ "\n");
}

multi sub replace(
    Str:D $file where .so,
    Bool:D $disable-ipv6 where .so,
    DiskType:D $disk-type
    --> Nil
)
{
    my Str:D @replace =
        $file.IO.lines
        ==> replace('kernel.pid_max')
        ==> replace('net.ipv6.conf.all.disable_ipv6')
        ==> replace('net.ipv6.conf.default.disable_ipv6')
        ==> replace('net.ipv6.conf.lo.disable_ipv6')
        ==> replace('vm.mmap_rnd_bits');
    my Str:D $replace = @replace.join("\n");
    spurt($file, $replace ~ "\n");
}

multi sub replace(
    Str:D $file where .so,
    Bool:D $disable-ipv6,
    DiskType:D $disk-type where /SSD|USB/
    --> Nil
)
{
    my Str:D @replace =
        $file.IO.lines
        ==> replace('kernel.pid_max')
        ==> replace('vm.mmap_rnd_bits')
        ==> replace('vm.vfs_cache_pressure')
        ==> replace('vm.swappiness');
    my Str:D $replace = @replace.join("\n");
    spurt($file, $replace ~ "\n");
}

multi sub replace(
    Str:D $file where .so,
    Bool:D $disable-ipv6,
    DiskType:D $disk-type
    --> Nil
)
{
    my Str:D @replace =
        $file.IO.lines
        ==> replace('kernel.pid_max')
        ==> replace('vm.mmap_rnd_bits');
    my Str:D $replace = @replace.join("\n");
    spurt($file, $replace ~ "\n");
}

multi sub replace(
    Str:D $subject where 'kernel.pid_max',
    Str:D @line
    --> Array[Str:D]
)
{
    my UInt:D $kernel-bits = $*KERNEL.bits;
    replace($subject, @line, :$kernel-bits);
}

multi sub replace(
    Str:D $subject where 'kernel.pid_max',
    Str:D @line,
    UInt:D :kernel-bits($)! where 64
    --> Array[Str:D]
)
{
    my UInt:D $index = @line.first(/^'#'$subject/, :k);
    # extract C<kernel.pid_max> value from file 99-sysctl.conf
    my Str:D $pid-max = @line[$index].split('=').map({ .trim }).tail;
    my Str:D $replace = sprintf(Q{%s = %s}, $subject, $pid-max);
    @line[$index] = $replace;
    @line;
}

multi sub replace(
    Str:D $subject where 'kernel.pid_max',
    Str:D @line,
    UInt:D :kernel-bits($)!
    --> Array[Str:D]
)
{
    @line;
}

multi sub replace(
    Str:D $subject where 'net.ipv6.conf.all.disable_ipv6',
    Str:D @line
    --> Array[Str:D]
)
{
    my UInt:D $index = @line.first(/^'#'$subject/, :k);
    my Str:D $replace = sprintf(Q{%s = 1}, $subject);
    @line[$index] = $replace;
    @line;
}

multi sub replace(
    Str:D $subject where 'net.ipv6.conf.default.disable_ipv6',
    Str:D @line
    --> Array[Str:D]
)
{
    my UInt:D $index = @line.first(/^'#'$subject/, :k);
    my Str:D $replace = sprintf(Q{%s = 1}, $subject);
    @line[$index] = $replace;
    @line;
}

multi sub replace(
    Str:D $subject where 'net.ipv6.conf.lo.disable_ipv6',
    Str:D @line
    --> Array[Str:D]
)
{
    my UInt:D $index = @line.first(/^'#'$subject/, :k);
    my Str:D $replace = sprintf(Q{%s = 1}, $subject);
    @line[$index] = $replace;
    @line;
}

multi sub replace(
    Str:D $subject where 'vm.mmap_rnd_bits',
    Str:D @line
    --> Array[Str:D]
)
{
    my UInt:D $kernel-bits = $*KERNEL.bits;
    replace($subject, @line, :$kernel-bits);
}

multi sub replace(
    Str:D $subject where 'vm.mmap_rnd_bits',
    Str:D @line,
    UInt:D :kernel-bits($)! where 32
    --> Array[Str:D]
)
{
    my UInt:D $index = @line.first(/^$subject/, :k);
    my Str:D $replace = sprintf(Q{%s = 16}, $subject);
    @line[$index] = $replace;
    @line;
}

multi sub replace(
    Str:D $subject where 'vm.mmap_rnd_bits',
    Str:D @line,
    UInt:D :kernel-bits($)!
    --> Array[Str:D]
)
{
    @line;
}

multi sub replace(
    Str:D $subject where 'vm.vfs_cache_pressure',
    Str:D @line
    --> Array[Str:D]
)
{
    my UInt:D $index = @line.first(/^'#'$subject/, :k);
    my Str:D $replace = sprintf(Q{%s = 50}, $subject);
    @line[$index] = $replace;
    @line;
}

multi sub replace(
    Str:D $subject where 'vm.swappiness',
    Str:D @line
    --> Array[Str:D]
)
{
    my UInt:D $index = @line.first(/^'#'$subject/, :k);
    my Str:D $replace = sprintf(Q{%s = 1}, $subject);
    @line[$index] = $replace;
    @line;
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
