use v6;
unit role Voidvault::Replace::DNSCryptProxy;

my constant $FILE = '/etc/dnscrypt-proxy.toml';

multi method replace(::?CLASS:D: Str:D $ where $FILE --> Nil)
{
    my Bool:D $disable-ipv6 = $.config.disable-ipv6;
    my Str:D $file = sprintf(Q{/mnt%s}, $FILE);
    replace($disable-ipv6);
}

multi sub replace(
    Str:D $file where .so,
    Bool:D $disable-ipv6 where .so
    --> Nil
)
{
    my Str:D @replace =
        $file.IO.lines
        # do not listen on IPv6 address
        ==> replace('listen_addresses')
        # server must support DNS security extensions (DNSSEC)
        ==> replace('require_dnssec')
        # always use TCP to connect to upstream servers
        ==> replace('force_tcp')
        # create new, unique key for each DNS query
        ==> replace('dnscrypt_ephemeral_keys')
        # disable TLS session tickets
        ==> replace('tls_disable_session_tickets')
        # unconditionally use fallback resolver
        ==> replace('ignore_system_dns')
        # wait for network connectivity before initializing
        ==> replace('netprobe_timeout')
        # disable DNS cache
        ==> replace('cache');
    my Str:D $replace = @replace.join("\n");
    spurt($file, $replace ~ "\n");
}

multi sub replace(
    Str:D $file where .so,
    Bool:D $disable-ipv6
    --> Nil
)
{
    my Str:D @replace =
        $file.IO.lines
        # server must support DNS security extensions (DNSSEC)
        ==> replace('require_dnssec')
        # always use TCP to connect to upstream servers
        ==> replace('force_tcp')
        # create new, unique key for each DNS query
        ==> replace('dnscrypt_ephemeral_keys')
        # disable TLS session tickets
        ==> replace('tls_disable_session_tickets')
        # unconditionally use fallback resolver
        ==> replace('ignore_system_dns')
        # wait for network connectivity before initializing
        ==> replace('netprobe_timeout')
        # disable DNS cache
        ==> replace('cache');
    my Str:D $replace = @replace.join("\n");
    spurt($file, $replace ~ "\n");
}

multi sub replace(
    Str:D $subject where 'listen_addresses',
    Str:D @line
    --> Array[Str:D]
)
{
    my UInt:D $index = @line.first(/^$subject/, :k);
    my Str:D $replace = sprintf(Q{%s = ['127.0.0.1:53']}, $subject);
    @line[$index] = $replace;
    @line;
}

multi sub replace(
    Str:D $subject where 'require_dnssec',
    Str:D @line
    --> Array[Str:D]
)
{
    my UInt:D $index = @line.first(/^$subject/, :k);
    my Str:D $replace = sprintf(Q{%s = true}, $subject);
    @line[$index] = $replace;
    @line;
}

multi sub replace(
    Str:D $subject where 'force_tcp',
    Str:D @line
    --> Array[Str:D]
)
{
    my UInt:D $index = @line.first(/^$subject/, :k);
    my Str:D $replace = sprintf(Q{%s = true}, $subject);
    @line[$index] = $replace;
    @line;
}

multi sub replace(
    Str:D $subject where 'dnscrypt_ephemeral_keys',
    Str:D @line
    --> Array[Str:D]
)
{
    my UInt:D $index = @line.first(/^'#'\h*$subject/, :k);
    my Str:D $replace = sprintf(Q{%s = true}, $subject);
    @line[$index] = $replace;
    @line;
}

multi sub replace(
    Str:D $subject where 'tls_disable_session_tickets',
    Str:D @line
    --> Array[Str:D]
)
{
    my UInt:D $index = @line.first(/^'#'\h*$subject/, :k);
    my Str:D $replace = sprintf(Q{%s = true}, $subject);
    @line[$index] = $replace;
    @line;
}

multi sub replace(
    Str:D $subject where 'ignore_system_dns',
    Str:D @line
    --> Array[Str:D]
)
{
    my UInt:D $index = @line.first(/^$subject/, :k);
    my Str:D $replace = sprintf(Q{%s = true}, $subject);
    @line[$index] = $replace;
    @line;
}

multi sub replace(
    Str:D $subject where 'netprobe_timeout',
    Str:D @line
    --> Array[Str:D]
)
{
    my UInt:D $index = @line.first(/^$subject/, :k);
    my Str:D $replace = sprintf(Q{%s = 420}, $subject);
    @line[$index] = $replace;
    @line;
}

multi sub replace(
    Str:D $subject where 'cache',
    Str:D @line
    --> Array[Str:D]
)
{
    my UInt:D $index = @line.first(/^$subject\h/, :k);
    my Str:D $replace = sprintf(Q{%s = false}, $subject);
    @line[$index] = $replace;
    @line;
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
