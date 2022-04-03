use v6;
use Voidvault::Constants;
use Voidvault::Types;
unit role Voidvault::Replace::Dracut;

my constant $FILE = $Voidvault::Constants::FILE-DRACUT;

multi method replace(
    ::?CLASS:D:
    Str:D $ where $FILE,
    Str:D $subject where 'add_dracutmodules'
    --> Nil
)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my Str:D $file = sprintf(Q{%s%s/%s.conf}, $chroot-dir, $FILE, $subject);
    # modules are found in C</usr/lib/dracut/modules.d>
    my Str:D @module = qw<
        btrfs
        crypt
        dm
        kernel-modules
    >;
    my Str:D $replace = sprintf(Q{%s+=" %s "}, $subject, @module.join(' '));
    spurt($file, $replace ~ "\n");
}

multi method replace(
    ::?CLASS:D:
    Str:D $ where $FILE,
    Str:D $subject where 'add_drivers'
    --> Nil
)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my Graphics:D $graphics = $.config.graphics;
    my Processor:D $processor = $.config.processor;
    my Str:D $file = sprintf(Q{%s%s/%s.conf}, $chroot-dir, $FILE, $subject);
    # drivers are C<*.ko*> files in C</lib/modules>
    my Str:D @driver = qw<
        ahci
        btrfs
        lz4
        lz4hc
        xxhash_generic
    >;
    push(@driver, 'i915') if $graphics eq 'INTEL';
    push(@driver, 'nouveau') if $graphics eq 'NVIDIA';
    push(@driver, 'radeon') if $graphics eq 'RADEON';
    my Str:D $replace = sprintf(Q{%s+=" %s "}, $subject, @driver.join(' '));
    spurt($file, $replace ~ "\n");
}

multi method replace(
    ::?CLASS:D:
    Str:D $ where $FILE,
    Str:D $subject where 'compress'
    --> Nil
)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my Str:D $file = sprintf(Q{%s%s/%s.conf}, $chroot-dir, $FILE, $subject);
    my Str:D $replace = sprintf(Q{%s="lz4"}, $subject);
    spurt($file, $replace ~ "\n");
}

multi method replace(
    ::?CLASS:D:
    Str:D $ where $FILE,
    Str:D $subject where 'hostonly'
    --> Nil
)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my Str:D $file = sprintf(Q{%s%s/%s.conf}, $chroot-dir, $FILE, $subject);
    my Str:D $replace = sprintf(Q{%s="yes"}, $subject);
    spurt($file, $replace ~ "\n");
}

multi method replace(
    ::?CLASS:D:
    Str:D $ where $FILE,
    Str:D $subject where 'install_items'
    --> Nil
)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my VaultKey:D $vault-key = $.config.vault-key;
    my Str:D $file = sprintf(Q{%s%s/%s.conf}, $chroot-dir, $FILE, $subject);
    my Str:D @item = qqw<
        $vault-key
        /etc/crypttab
    >;
    my Str:D $replace = sprintf(Q{%s+=" %s "}, $subject, @item.join(' '));
    spurt($file, $replace ~ "\n");
}

multi method replace(
    ::?CLASS:D:
    Str:D $ where $FILE,
    Str:D $subject where 'omit_dracutmodules'
    --> Nil
)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my Str:D $file = sprintf(Q{%s%s/%s.conf}, $chroot-dir, $FILE, $subject);
    my Str:D @module = qw<
        dracut-systemd
        plymouth
        systemd
        systemd-initrd
        usrmount
    >;
    my Str:D $replace = sprintf(Q{%s+=" %s "}, $subject, @module.join(' '));
    spurt($file, $replace ~ "\n");
}

multi method replace(
    ::?CLASS:D:
    Str:D $ where $FILE,
    Str:D $subject where 'persistent_policy'
    --> Nil
)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my Str:D $file = sprintf(Q{%s%s/%s.conf}, $chroot-dir, $FILE, $subject);
    my Str:D $replace = sprintf(Q{%s="by-uuid"}, $subject);
    spurt($file, $replace ~ "\n");
}

multi method replace(
    ::?CLASS:D:
    Str:D $ where $FILE,
    Str:D $subject where 'tmpdir'
    --> Nil
)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my Str:D $file = sprintf(Q{%s%s/%s.conf}, $chroot-dir, $FILE, $subject);
    my Str:D $replace = sprintf(Q{%s="/tmp"}, $subject);
    spurt($file, $replace ~ "\n");
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
