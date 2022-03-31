use v6;
unit role Voidvault::Replace::Dracut;

my constant $FILE = '/etc/dracut.conf.d'

multi method replace(::?CLASS:D: Str:D $ where $FILE --> Nil)
{
    my Graphics:D $graphics = $.config.graphics;
    my Processor:D $processor = $.config.processor;
    my Str:D $vault-key = $.config.vault-key;
    replace('add_dracutmodules');
    replace('add_drivers', $graphics, $processor);
    replace('compress');
    replace('hostonly');
    replace('install_items', $vault-key);
    replace('omit_dracutmodules');
    replace('persistent_policy');
    replace('tmpdir');
}

multi sub replace(
    Str:D $subject where 'add_dracutmodules'
    --> Nil
)
{
    my Str:D $file = sprintf(Q{/mnt%s/%s.conf}, $FILE, $subject);
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

multi sub replace(
    Str:D $subject where 'add_drivers',
    Graphics:D $graphics,
    Processor:D $processor
    --> Nil
)
{
    my Str:D $file = sprintf(Q{/mnt%s/%s.conf}, $FILE, $subject);
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

multi sub replace(
    Str:D $subject where 'compress'
    --> Nil
)
{
    my Str:D $file = sprintf(Q{/mnt%s/%s.conf}, $FILE, $subject);
    my Str:D $replace = sprintf(Q{%s="lz4"}, $subject);
    spurt($file, $replace ~ "\n");
}

multi sub replace(
    Str:D $subject where 'hostonly'
    --> Nil
)
{
    my Str:D $file = sprintf(Q{/mnt%s/%s.conf}, $FILE, $subject);
    my Str:D $replace = sprintf(Q{%s="yes"}, $subject);
    spurt($file, $replace ~ "\n");
}

multi sub replace(
    Str:D $subject where 'install_items',
    Str:D $vault-key
    --> Nil
)
{
    my Str:D $file = sprintf(Q{/mnt%s/%s.conf}, $FILE, $subject);
    my Str:D @item = qqw<
        $vault-key
        /etc/crypttab
    >;
    my Str:D $replace = sprintf(Q{%s+=" %s "}, $subject, @item.join(' '));
    spurt($file, $replace ~ "\n");
}

multi sub replace(
    Str:D $subject where 'omit_dracutmodules'
    --> Nil
)
{
    my Str:D $file = sprintf(Q{/mnt%s/%s.conf}, $FILE, $subject);
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

multi sub replace(
    Str:D $subject where 'persistent_policy'
    --> Nil
)
{
    my Str:D $file = sprintf(Q{/mnt%s/%s.conf}, $FILE, $subject);
    my Str:D $replace = sprintf(Q{%s="by-uuid"}, $subject);
    spurt($file, $replace ~ "\n");
}

multi sub replace(
    Str:D $subject where 'tmpdir'
    --> Nil
)
{
    my Str:D $file = sprintf(Q{/mnt%s/%s.conf}, $FILE, $subject);
    my Str:D $replace = sprintf(Q{%s="/tmp"}, $subject);
    spurt($file, $replace ~ "\n");
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
