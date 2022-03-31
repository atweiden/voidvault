use v6;
unit role Voidvault::Replace::Dhcpcd;

constant $FILE = '/etc/dhcpcd.conf';

multi method replace(::?CLASS:D: Str:D $ where $FILE --> Nil)
{
    my Str:D $chroot-dir = $.config.chroot-dir;
    my Bool:D $disable-ipv6 = $.config.disable-ipv6;
    my Str:D $file = sprintf(Q{%s%s}, $chroot-dir, $FILE);
    replace($file, $disable-ipv6);
}

multi sub replace(Str:D $file where .so, Bool:D $disable-ipv6 where .so --> Nil)
{
    my Str:D $dhcpcd = q:to/EOF/;
    # Set vendor-class-id to empty string
    vendorclassid

    # Use the same DNS servers every time
    static domain_name_servers=127.0.0.1

    # Disable IPv6 router solicitation
    noipv6rs
    noipv6
    EOF
    spurt($file, "\n" ~ $dhcpcd, :append);
}

multi sub replace(Str:D $file where .so, Bool:D $disable-ipv6 --> Nil)
{
    my Str:D $dhcpcd = q:to/EOF/;
    # Set vendor-class-id to empty string
    vendorclassid

    # Use the same DNS servers every time
    static domain_name_servers=127.0.0.1 ::1

    # Disable IPv6 router solicitation
    #noipv6rs
    #noipv6
    EOF
    spurt($file, "\n" ~ $dhcpcd, :append);
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
