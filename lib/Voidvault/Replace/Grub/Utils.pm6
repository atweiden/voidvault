use v6;
use Voidvault::Constants;
use Voidvault::Types;
unit role Voidvault::Replace::Grub::Utils;

my constant $FILE = $Voidvault::Constants::FILE-GRUB-DEFAULT;

method set-log-level(Str:D $log-level, Str:D @grub-cmdline-linux --> Nil)
{
    my Str:D $gen-log-level = gen-log-level($log-level);
    my Str:D $set-log-level = sprintf(Q{loglevel=%s}, $gen-log-level);
    push(@grub-cmdline-linux, $set-log-level);
}

# kernel message limit level accessed phonetically
multi sub gen-log-level('emergency' --> Str:D)     { '0' }
multi sub gen-log-level('alert' --> Str:D)         { '1' }
multi sub gen-log-level('critical' --> Str:D)      { '2' }
multi sub gen-log-level('error' --> Str:D)         { '3' }
multi sub gen-log-level('warning' --> Str:D)       { '4' }
multi sub gen-log-level('notice' --> Str:D)        { '5' }
multi sub gen-log-level('informational' --> Str:D) { '6' }
multi sub gen-log-level('debug' --> Str:D)         { '7' }

multi method enable-luks(
    'UUID',
    Str:D @grub-cmdline-linux,
    Str:D :$partition-vault! where .so,
    Str:D :$vault-name! where .so
    --> Nil
)
{
    my Str:D $vault-uuid =
        qqx<blkid --match-tag UUID --output value $partition-vault>.trim;
    my Str:D @enable-luks = qqw<
        rd.luks=1
        rd.luks.uuid=$vault-uuid
        rd.luks.name=$vault-uuid=$vault-name
    >;
    push(@grub-cmdline-linux, $_) for @enable-luks;
}

multi method enable-luks(
    'PARTUUID',
    Str:D @grub-cmdline-linux,
    Str:D :$partition-vault! where .so,
    Str:D :$vault-name! where .so
    --> Nil
)
{
    my Str:D $vault-partuuid =
        qqx<blkid --match-tag PARTUUID --output value $partition-vault>.trim;
    my Str:D @enable-luks = qqw<
        rd.luks=1
        rd.luks.partuuid=$vault-partuuid
        rd.luks.name=$vault-partuuid=$vault-name
    >;
    push(@grub-cmdline-linux, $_) for @enable-luks;
}

method enable-serial-console(
    Str:D @grub-cmdline-linux,
    Str:D $subject where .so
    --> Nil
)
{
    # e.g. console=tty0
    my Str:D $virtual = gen-console('virtual');
    # e.g. console=ttyS0,115200n8
    my Str:D $serial = gen-console('serial', $subject);
    # enable both serial and virtual console on boot
    push(@grub-cmdline-linux, $virtual);
    push(@grub-cmdline-linux, $serial);
}

multi sub gen-console('virtual' --> Str:D)
{
    # e.g. console=tty0
    my Str:D $virtual =
        sprintf('console=%s', $Voidvault::Constants::CONSOLE-VIRTUAL);
}

multi sub gen-console('serial', Str:D $subject where .so --> Str:D)
{
    # e.g. console=ttyS0,115200n8
    my Str:D $serial = sprintf(
        'console=%s,%s%s%s',
        $Voidvault::Constants::CONSOLE-SERIAL,
        $Voidvault::Constants::GRUB-SERIAL-PORT-BAUD-RATE,
        %Voidvault::Constants::GRUB-SERIAL-PORT-PARITY{$Voidvault::Constants::GRUB-SERIAL-PORT-PARITY}{$subject},
        $Voidvault::Constants::GRUB-SERIAL-PORT-WORD-LENGTH-BITS
    );
}

method enable-security-features(Str:D @grub-cmdline-linux --> Nil)
{
    # enable slub/slab allocator free poisoning (needs CONFIG_SLUB_DEBUG=y)
    push(@grub-cmdline-linux, 'slub_debug=FZ');
    #                                     ||
    #                                     |+--- redzoning (Z)
    #                                     +---- sanity checks (F)
    # disable slab merging (makes many heap overflow attacks more difficult)
    push(@grub-cmdline-linux, 'slab_nomerge=1');
    # always enable Kernel Page Table Isolation (to be safe from Meltdown)
    push(@grub-cmdline-linux, 'pti=on');
    # always panic on uncorrected errors, log corrected errors
    push(@grub-cmdline-linux, 'mce=0');
    push(@grub-cmdline-linux, 'printk.time=1');
}

method enable-radeon(Str:D @grub-cmdline-linux --> Nil)
{
    push(@grub-cmdline-linux, 'radeon.dpm=1');
}

method disable-ipv6(Str:D @grub-cmdline-linux --> Nil)
{
    push(@grub-cmdline-linux, 'ipv6.disable=1');
}

method finalize(
    Str:D $subject where 'GRUB_CMDLINE_LINUX_DEFAULT',
    Str:D @grub-cmdline-linux,
    AbsolutePath:D :$chroot-dir! where .so
    --> Nil
)
{
    my Str:D $grub-cmdline-linux = @grub-cmdline-linux.join(' ');
    my Str:D $file = sprintf(Q{%s%s}, $chroot-dir, $FILE);
    my Str:D @line = $file.IO.lines;
    my UInt:D $index = @line.first(/^$subject'='/, :k);
    my Str:D $replace = sprintf(Q{%s="%s"}, $subject, $grub-cmdline-linux);
    @line[$index] = $replace;
    my Str:D $finalize = @line.join("\n");
    spurt($file, $finalize ~ "\n");
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
