use v6;
unit role Voidvault::Replace::SSH::SSHD;

constant $FILE = '/etc/ssh/sshd_config';

multi method replace(::?CLASS:D: Str:D $ where $FILE --> Nil)
{
    my Bool:D $disable-ipv6 = $.config.disable-ipv6;
    my UserName:D $user-name-sftp = $.config.user-name-sftp;
    my Str:D $file = sprintf(Q{/mnt%s}, $FILE);
    replace($file, $disable-ipv6, $user-name-sftp);
}

multi sub replace(
    Str:D $file where .so,
    Bool:D $disable-ipv6 where .so,
    UserName:D $user-name-sftp
    --> Nil
)
{
    my Str:D @replace =
        $file.IO.lines
        ==> replace('AddressFamily')
        ==> replace('AllowUsers', $user-name-sftp)
        ==> replace('ListenAddress');
    my Str:D $replace = @replace.join("\n");
    spurt($file, $replace ~ "\n");
}

multi sub replace(
    Str:D $file where .so,
    Bool:D $disable-ipv6,
    UserName:D $user-name-sftp
    --> Nil
)
{
    my Str:D @replace =
        $file.IO.lines
        ==> replace('AllowUsers', $user-name-sftp);
    my Str:D $replace = @replace.join("\n");
    spurt($file, $replace ~ "\n");
}

multi sub replace(
    Str:D $subject where 'AddressFamily',
    Str:D @line
    --> Array[Str:D]
)
{
    # listen on IPv4 only
    my UInt:D $index = @line.first(/^$subject/, :k);
    my Str:D $replace = sprintf(Q{%s inet}, $subject);
    @line[$index] = $replace;
    @line;
}

multi sub replace(
    Str:D $subject where 'AllowUsers',
    UserName:D $user-name-sftp,
    Str:D @line
    --> Array[Str:D]
)
{
    # put AllowUsers on the line below AddressFamily
    my UInt:D $index = @line.first(/^AddressFamily/, :k);
    my Str:D $replace = sprintf(Q{%s %s}, $subject, $user-name-sftp);
    @line.splice($index + 1, 0, $replace);
    @line;
}

multi sub replace(
    Str:D $subject where 'ListenAddress',
    Str:D @line
    --> Array[Str:D]
)
{
    # listen on IPv4 only
    my UInt:D $index = @line.first(/^"$subject ::"/, :k);
    @line.splice($index, 1);
    @line;
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
