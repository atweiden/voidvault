use v6;
use Voidvault::Constants;
use Voidvault::Replace::Grub::Utils;
use Voidvault::Types;
unit role Voidvault::Replace::Grub::Default;

my constant $FILE = $Voidvault::Constants::FILE-GRUB-DEFAULT;

multi method replace(
    ::?CLASS:D:
    Str:D $ where $FILE,
    Str:D $subject where 'GRUB_CMDLINE_LINUX_DEFAULT'
    --> Nil
)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my Bool:D $disable-ipv6 = $.config.disable-ipv6;
    my Bool:D $enable-serial-console = $.config.enable-serial-console;
    my Graphics:D $graphics = $.config.graphics;
    my Str:D $partition-vault = self.gen-partition('vault');
    my VaultName:D $vault-name = $.config.vault-name;
    my $default-utils = Voidvault::Replace::Grub::Utils;

    # prepare GRUB_CMDLINE_LINUX_DEFAULT
    my Str:D @grub-cmdline-linux;
    $default-utils.set-log-level('informational', @grub-cmdline-linux);
    $default-utils.enable-luks(
        'UUID',
        @grub-cmdline-linux,
        :$partition-vault,
        :$vault-name
    );
    $default-utils.enable-serial-console(@grub-cmdline-linux, $subject)
        if $enable-serial-console;
    $default-utils.enable-security-features(@grub-cmdline-linux);
    $default-utils.enable-radeon(@grub-cmdline-linux) if $graphics eq 'RADEON';
    $default-utils.disable-ipv6(@grub-cmdline-linux) if $disable-ipv6.so;

    # replace GRUB_CMDLINE_LINUX_DEFAULT
    $default-utils.finalize($subject, @grub-cmdline-linux, :$chroot-dir);
}

multi method replace(
    ::?CLASS:D:
    Str:D $ where $FILE,
    Str:D $subject where 'GRUB_DISABLE_OS_PROBER'
    --> Nil
)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my Str:D $file = sprintf(Q{%s%s}, $chroot-dir, $FILE);
    my Str:D @line = $file.IO.lines;
    # if C<GRUB_DISABLE_OS_PROBER> not found, append to bottom of file
    my UInt:D $index = @line.first(/^'#'$subject/, :k) // @line.elems;
    my Str:D $replace = sprintf(Q{%s=true}, $subject);
    @line[$index] = $replace;
    my Str:D $finalize = @line.join("\n");
    spurt($file, $finalize ~ "\n");
}

multi method replace(
    ::?CLASS:D:
    Str:D $ where $FILE,
    Str:D $subject where 'GRUB_DISABLE_RECOVERY'
    --> Nil
)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my Str:D $file = sprintf(Q{%s%s}, $chroot-dir, $FILE);
    my Str:D @line = $file.IO.lines;
    # if C<GRUB_DISABLE_RECOVERY> not found, append to bottom of file
    my UInt:D $index = @line.first(/^'#'$subject/, :k) // @line.elems;
    my Str:D $replace = sprintf(Q{%s=true}, $subject);
    @line[$index] = $replace;
    my Str:D $finalize = @line.join("\n");
    spurt($file, $finalize ~ "\n");
}

multi method replace(
    ::?CLASS:D:
    Str:D $ where $FILE,
    Str:D $subject where 'GRUB_ENABLE_CRYPTODISK'
    --> Nil
)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my Str:D $file = sprintf(Q{%s%s}, $chroot-dir, $FILE);
    my Str:D @line = $file.IO.lines;
    # if C<GRUB_ENABLE_CRYPTODISK> not found, append to bottom of file
    my UInt:D $index = @line.first(/^'#'$subject/, :k) // @line.elems;
    my Str:D $replace = sprintf(Q{%s=y}, $subject);
    @line[$index] = $replace;
    my Str:D $finalize = @line.join("\n");
    spurt($file, $finalize ~ "\n");
}

multi method replace(
    ::?CLASS:D:
    Str:D $ where $FILE,
    Str:D $subject where 'GRUB_TERMINAL_INPUT'
    --> Nil
)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my Bool:D $enable-serial-console = $.config.enable-serial-console;
    my Str:D $file = sprintf(Q{%s%s}, $chroot-dir, $FILE);
    my Str:D @replace =
        $file.IO.lines
        ==> replace('GRUB_TERMINAL_INPUT', $enable-serial-console);
    my Str:D $finalize = @replace.join("\n");
    spurt($file, $finalize ~ "\n");
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
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
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
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
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
    my Str:D $finalize = @line.join("\n");
    spurt($file, $finalize ~ "\n");
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
