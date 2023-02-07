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
    Str:D $subject where 'install_items',
    '1fa'
    --> Nil
)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my VaultKeyFile:D $vault-key-file = $.config.vault-key-file;
    my VaultHeader:D $vault-header = $.config.vault-header;
    my BootvaultKeyFile:D $bootvault-key-file = $.config.bootvault-key-file;
    my Str:D $file = sprintf(Q{%s%s/%s.conf}, $chroot-dir, $FILE, $subject);
    my Str:D @item = qqw<
        $vault-key-file
        $vault-header
        $bootvault-key-file
        /etc/crypttab
        /usr/bin/cryptsetup
    >;
    my Str:D $replace = sprintf(Q{%s+=" %s "}, $subject, @item.join(' '));
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
    my VaultKeyFile:D $vault-key-file = $.config.vault-key-file;
    my Str:D $file = sprintf(Q{%s%s/%s.conf}, $chroot-dir, $FILE, $subject);
    my Str:D @item = qqw<
        $vault-key-file
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
        bluetooth
        dracut-systemd
        plymouth
        systemd
        systemd-ac-power
        systemd-ask-password
        systemd-coredump
        systemd-hostnamed
        systemd-initrd
        systemd-integritysetup
        systemd-journald
        systemd-ldconfig
        systemd-modules-load
        systemd-networkd
        systemd-network-management
        systemd-repart
        systemd-resolved
        systemd-rfkill
        systemd-sysctl
        systemd-sysext
        systemd-sysusers
        systemd-timedated
        systemd-timesyncd
        systemd-tmpfiles
        systemd-udevd
        systemd-veritysetup
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
