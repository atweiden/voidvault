use v6;
use Voidvault::Constants;
unit role Voidvault::Replace::GRUB::Default;

constant $FILE = '/etc/default/grub';

multi method replace(::?CLASS:D: Str:D $ where $FILE --> Nil)
{
    my Bool:D $disable-ipv6 = $.config.disable-ipv6;
    my Bool:D $enable-serial-console = $.config.enable-serial-console;
    my Graphics:D $graphics = $.config.graphics;
    my Str:D $partition-vault = self.gen-partition('vault');
    my VaultName:D $vault-name = $.config.vault-name;
    my Str:D $file = sprintf(Q{/mnt%s}, $FILE);
    replace(
        $file,
        $disable-ipv6,
        $enable-serial-console,
        $graphics,
        $partition-vault,
        $vault-name
    );
}

multi sub replace(
    Str:D $file where .so,
    *@opts (
        Bool:D $disable-ipv6,
        Bool:D $enable-serial-console,
        Graphics:D $graphics,
        Str:D $partition-vault,
        VaultName:D $vault-name
    )
    --> Nil
)
{
    my Str:D @replace =
        $file.IO.lines
        ==> replace('GRUB_CMDLINE_LINUX_DEFAULT', |@opts)
        ==> replace('GRUB_DISABLE_OS_PROBER')
        ==> replace('GRUB_DISABLE_RECOVERY')
        ==> replace('GRUB_ENABLE_CRYPTODISK')
        ==> replace('GRUB_TERMINAL_INPUT', $enable-serial-console)
        ==> replace('GRUB_TERMINAL_OUTPUT', $enable-serial-console)
        ==> replace('GRUB_SERIAL_COMMAND', $enable-serial-console);
    my Str:D $replace = @replace.join("\n");
    spurt($file, $replace ~ "\n");
}

multi sub replace(
    Str:D $subject where 'GRUB_CMDLINE_LINUX_DEFAULT',
    Bool:D $disable-ipv6,
    Bool:D $enable-serial-console,
    Graphics:D $graphics,
    Str:D $partition-vault,
    VaultName:D $vault-name,
    Str:D @line
    --> Array[Str:D]
)
{
    # prepare GRUB_CMDLINE_LINUX_DEFAULT
    my Str:D $vault-uuid =
        qqx<blkid --match-tag UUID --output value $partition-vault>.trim;
    my Str:D @grub-cmdline-linux = qqw<
        rd.luks=1
        rd.luks.uuid=$vault-uuid
        rd.luks.name=$vault-uuid=$vault-name
        loglevel=6
    >;
    if $enable-serial-console.so
    {
        # e.g. console=tty0
        my Str:D $virtual =
            sprintf('console=%s', $Voidvault::Constants::VIRTUAL-CONSOLE);

        # e.g. console=ttyS0,115200n8
        my Str:D $serial = sprintf(
            'console=%s,%s%s%s',
            $Voidvault::Constants::SERIAL-CONSOLE,
            $Voidvault::Constants::GRUB-SERIAL-PORT-BAUD-RATE,
            %Voidvault::Constants::GRUB-SERIAL-PORT-PARITY{$Voidvault::Constants::GRUB-SERIAL-PORT-PARITY}{$subject},
            $Voidvault::Constants::GRUB-SERIAL-PORT-WORD-LENGTH-BITS
        );

        # enable both serial and virtual console on boot
        push(@grub-cmdline-linux, $virtual);
        push(@grub-cmdline-linux, $serial);
    }
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
    push(@grub-cmdline-linux, 'radeon.dpm=1') if $graphics eq 'RADEON';
    push(@grub-cmdline-linux, 'ipv6.disable=1') if $disable-ipv6.so;
    my Str:D $grub-cmdline-linux = @grub-cmdline-linux.join(' ');
    # replace GRUB_CMDLINE_LINUX_DEFAULT
    my UInt:D $index = @line.first(/^$subject'='/, :k);
    my Str:D $replace = sprintf(Q{%s="%s"}, $subject, $grub-cmdline-linux);
    @line[$index] = $replace;
    @line;
}

multi sub replace(
    Str:D $subject where 'GRUB_DISABLE_OS_PROBER',
    Str:D @line
    --> Array[Str:D]
)
{
    # if C<GRUB_DISABLE_OS_PROBER> not found, append to bottom of file
    my UInt:D $index = @line.first(/^'#'$subject/, :k) // @line.elems;
    my Str:D $replace = sprintf(Q{%s=true}, $subject);
    @line[$index] = $replace;
    @line;
}

multi sub replace(
    Str:D $subject where 'GRUB_DISABLE_RECOVERY',
    Str:D @line
    --> Array[Str:D]
)
{
    # if C<GRUB_DISABLE_RECOVERY> not found, append to bottom of file
    my UInt:D $index = @line.first(/^'#'$subject/, :k) // @line.elems;
    my Str:D $replace = sprintf(Q{%s=true}, $subject);
    @line[$index] = $replace;
    @line;
}

multi sub replace(
    Str:D $subject where 'GRUB_ENABLE_CRYPTODISK',
    Str:D @line
    --> Array[Str:D]
)
{
    # if C<GRUB_ENABLE_CRYPTODISK> not found, append to bottom of file
    my UInt:D $index = @line.first(/^'#'$subject/, :k) // @line.elems;
    my Str:D $replace = sprintf(Q{%s=y}, $subject);
    @line[$index] = $replace;
    @line;
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

multi sub replace(
    Str:D $subject where 'GRUB_SERIAL_COMMAND',
    Bool:D $enable-serial-console where .so,
    Str:D @line
    --> Array[Str:D]
)
{
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
    @line;
}

multi sub replace(
    Str:D $ where 'GRUB_SERIAL_COMMAND',
    Bool:D $,
    Str:D @line
    --> Array[Str:D]
)
{
    @line;
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
