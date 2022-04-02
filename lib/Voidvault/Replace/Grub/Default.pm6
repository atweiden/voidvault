use v6;
use Voidvault::Constants;
unit role Voidvault::Replace::Grub::Default;

constant $FILE = '/etc/default/grub';

multi method replace(
    ::?CLASS:D:
    Str:D $ where $FILE,
    Str:D $subject where 'GRUB_CMDLINE_LINUX_DEFAULT'
    --> Nil
)
{
    my Str:D $chroot-dir = $.config.chroot-dir;
    my Bool:D $disable-ipv6 = $.config.disable-ipv6;
    my Bool:D $enable-serial-console = $.config.enable-serial-console;
    my Graphics:D $graphics = $.config.graphics;
    my Str:D $partition-vault = self.gen-partition('vault');
    my VaultName:D $vault-name = $.config.vault-name;

    # prepare GRUB_CMDLINE_LINUX_DEFAULT
    my Str:D @grub-cmdline-linux;
    set-log-level('informational', @grub-cmdline-linux);
    enable-luks('UUID', @grub-cmdline-linux, :$partition-vault, :$vault-name);
    enable-serial-console(@grub-cmdline-linux) if $enable-serial-console.so;
    enable-security-features(@grub-cmdline-linux);
    enable-radeon(@grub-cmdline-linux) if $graphics eq 'RADEON';
    disable-ipv6(@grub-cmdline-linux) if $disable-ipv6.so;
    my Str:D $grub-cmdline-linux = @grub-cmdline-linux.join(' ');

    # replace GRUB_CMDLINE_LINUX_DEFAULT
    my Str:D $file = sprintf(Q{%s%s}, $chroot-dir, $FILE);
    my Str:D @line = $file.IO.lines;
    my UInt:D $index = @line.first(/^$subject'='/, :k);
    my Str:D $replace = sprintf(Q{%s="%s"}, $subject, $grub-cmdline-linux);
    @line[$index] = $replace;
    my Str:D $replace = @line.join("\n");
    spurt($file, $replace ~ "\n");
}

multi sub set-log-level(Str:D $log-level, Str:D @grub-cmdline-linux --> Nil)
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

multi sub enable-luks(
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

sub enable-serial-console(Str:D @grub-cmdline-linux --> Nil)
{
    # e.g. console=tty0
    my Str:D $virtual = gen-console('virtual');
    # e.g. console=ttyS0,115200n8
    my Str:D $serial = gen-console('serial');
    # enable both serial and virtual console on boot
    push(@grub-cmdline-linux, $virtual);
    push(@grub-cmdline-linux, $serial);
}

multi sub gen-console('virtual' --> Str:D)
{
    # e.g. console=tty0
    my Str:D $virtual =
        sprintf('console=%s', $Voidvault::Constants::VIRTUAL-CONSOLE);
}

multi sub gen-console('serial' --> Str:D)
{
    # e.g. console=ttyS0,115200n8
    my Str:D $serial = sprintf(
        'console=%s,%s%s%s',
        $Voidvault::Constants::SERIAL-CONSOLE,
        $Voidvault::Constants::GRUB-SERIAL-PORT-BAUD-RATE,
        %Voidvault::Constants::GRUB-SERIAL-PORT-PARITY{$Voidvault::Constants::GRUB-SERIAL-PORT-PARITY}{$subject},
        $Voidvault::Constants::GRUB-SERIAL-PORT-WORD-LENGTH-BITS
    );
}

sub enable-security-features(Str:D @grub-cmdline-linux --> Nil)
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

sub enable-radeon(Str:D @grub-cmdline-linux --> Nil)
{
    push(@grub-cmdline-linux, 'radeon.dpm=1');
}

sub disable-ipv6(Str:D @grub-cmdline-linux --> Nil)
{
    push(@grub-cmdline-linux, 'ipv6.disable=1');
}

multi method replace(
    ::?CLASS:D:
    Str:D $ where $FILE,
    Str:D $subject where 'GRUB_DISABLE_OS_PROBER'
    --> Nil
)
{
    my Str:D $chroot-dir = $.config.chroot-dir;
    my Str:D $file = sprintf(Q{%s%s}, $chroot-dir, $FILE);
    my Str:D @line = $file.IO.lines;
    # if C<GRUB_DISABLE_OS_PROBER> not found, append to bottom of file
    my UInt:D $index = @line.first(/^'#'$subject/, :k) // @line.elems;
    my Str:D $replace = sprintf(Q{%s=true}, $subject);
    @line[$index] = $replace;
    my Str:D $replace = @line.join("\n");
    spurt($file, $replace ~ "\n");
}

multi method replace(
    ::?CLASS:D:
    Str:D $ where $FILE,
    Str:D $subject where 'GRUB_DISABLE_RECOVERY'
    --> Nil
)
{
    my Str:D $chroot-dir = $.config.chroot-dir;
    my Str:D $file = sprintf(Q{%s%s}, $chroot-dir, $FILE);
    my Str:D @line = $file.IO.lines;
    # if C<GRUB_DISABLE_RECOVERY> not found, append to bottom of file
    my UInt:D $index = @line.first(/^'#'$subject/, :k) // @line.elems;
    my Str:D $replace = sprintf(Q{%s=true}, $subject);
    @line[$index] = $replace;
    my Str:D $replace = @line.join("\n");
    spurt($file, $replace ~ "\n");
}

multi method replace(
    ::?CLASS:D:
    Str:D $ where $FILE,
    Str:D $subject where 'GRUB_ENABLE_CRYPTODISK'
    --> Nil
)
{
    my Str:D $chroot-dir = $.config.chroot-dir;
    my Str:D $file = sprintf(Q{%s%s}, $chroot-dir, $FILE);
    my Str:D @line = $file.IO.lines;
    # if C<GRUB_ENABLE_CRYPTODISK> not found, append to bottom of file
    my UInt:D $index = @line.first(/^'#'$subject/, :k) // @line.elems;
    my Str:D $replace = sprintf(Q{%s=y}, $subject);
    @line[$index] = $replace;
    my Str:D $replace = @line.join("\n");
    spurt($file, $replace ~ "\n");
}

multi method replace(
    ::?CLASS:D:
    Str:D $ where $FILE,
    Str:D $subject where 'GRUB_TERMINAL_INPUT'
    --> Nil
)
{
    my Str:D $chroot-dir = $.config.chroot-dir;
    my Bool:D $enable-serial-console = $.config.enable-serial-console;
    my Str:D $file = sprintf(Q{%s%s}, $chroot-dir, $FILE);
    my Str:D @replace =
        $file.IO.lines
        ==> replace('GRUB_TERMINAL_INPUT', $enable-serial-console);
    my Str:D $replace = @replace.join("\n");
    spurt($file, $replace ~ "\n");
}

multi sub replace(
    Str:D $subject where 'GRUB_TERMINAL_INPUT',
    Bool:D $enable-serial-console where .so,
    Str:D @line
    --> Array[Str:D]
)
{
    # if C<GRUB_TERMINAL_INPUT> not found, append to bottom of file
    my UInt:D $index = @line.first(/^'#'?$subject/, :k) // @line.elems;
    my Str:D $replace = sprintf(Q{%s="console serial"}, $subject);
    @line[$index] = $replace;
    @line;
}

multi sub replace(
    Str:D $subject where 'GRUB_TERMINAL_INPUT',
    Bool:D $enable-serial-console,
    Str:D @line
    --> Array[Str:D]
)
{
    # if C<GRUB_TERMINAL_INPUT> not found, append to bottom of file
    my UInt:D $index = @line.first(/^'#'?$subject/, :k) // @line.elems;
    my Str:D $replace = sprintf(Q{%s="console"}, $subject);
    @line[$index] = $replace;
    @line;
}

multi method replace(
    ::?CLASS:D:
    Str:D $ where $FILE,
    Str:D $subject where 'GRUB_TERMINAL_OUTPUT'
    --> Nil
)
{
    my Str:D $chroot-dir = $.config.chroot-dir;
    my Bool:D $enable-serial-console = $.config.enable-serial-console;
    my Str:D $file = sprintf(Q{%s%s}, $chroot-dir, $FILE);
    my Str:D @replace =
        $file.IO.lines
        ==> replace('GRUB_TERMINAL_OUTPUT', $enable-serial-console);
    my Str:D $replace = @replace.join("\n");
    spurt($file, $replace ~ "\n");
}

multi sub replace(
    Str:D $subject where 'GRUB_TERMINAL_OUTPUT',
    Bool:D $enable-serial-console where .so,
    Str:D @line
    --> Array[Str:D]
)
{
    # if C<GRUB_TERMINAL_OUTPUT> not found, append to bottom of file
    my UInt:D $index = @line.first(/^'#'?$subject/, :k) // @line.elems;
    my Str:D $replace = sprintf(Q{%s="console serial"}, $subject);
    @line[$index] = $replace;
    @line;
}

multi sub replace(
    Str:D $subject where 'GRUB_TERMINAL_OUTPUT',
    Bool:D $enable-serial-console,
    Str:D @line
    --> Array[Str:D]
)
{
    # if C<GRUB_TERMINAL_OUTPUT> not found, append to bottom of file
    my UInt:D $index = @line.first(/^'#'?$subject/, :k) // @line.elems;
    my Str:D $replace = sprintf(Q{%s="console"}, $subject);
    @line[$index] = $replace;
    @line;
}

multi method replace(
    ::?CLASS:D:
    Str:D $ where $FILE,
    Str:D $subject where 'GRUB_SERIAL_COMMAND'
    --> Nil
)
{
    my Str:D $chroot-dir = $.config.chroot-dir;
    my Str:D $file = sprintf(Q{%s%s}, $chroot-dir, $FILE);
    my Str:D @line = $file.IO.lines;
    # if C<GRUB_SERIAL_COMMAND> not found, append to bottom of file
    my UInt:D $index = @line.first(/^'#'?$subject/, :k) // @line.elems;
    my Str:D $speed = $Voidvault::Constants::GRUB-SERIAL-PORT-BAUD-RATE;
    my Str:D $unit = $Voidvault::Constants::GRUB-SERIAL-PORT-UNIT;
    my Str:D $word = $Voidvault::Constants::GRUB-SERIAL-PORT-WORD-LENGTH-BITS;
    my Str:D $parity = %Voidvault::Constants::GRUB-SERIAL-PORT-PARITY{$Voidvault::Constants::GRUB-SERIAL-PORT-PARITY}{$subject};
    my Str:D $stop = $Voidvault::Constants::GRUB-SERIAL-PORT-STOP-BITS;
    my Str:D $grub-serial-command = qqw<
        serial
        --speed=$speed
        --unit=$unit
        --word=$word
        --parity=$parity
        --stop=$stop
    >.join(' ');
    my Str:D $replace = sprintf(Q{%s="%s"}, $subject, $grub-serial-command);
    @line[$index] = $replace;
    my Str:D $replace = @line.join("\n");
    spurt($file, $replace ~ "\n");
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
