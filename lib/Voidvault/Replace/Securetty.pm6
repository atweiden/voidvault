use v6;
use Voidvault::Constants;
use Voidvault::Types;
unit role Voidvault::Replace::Securetty;

my constant $FILE = $Voidvault::Constants::FILE-SECURETTY;

multi method replace(::?CLASS:D: Str:D $ where $FILE --> Nil)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my Bool:D $enable-serial-console = $.config.enable-serial-console;
    my Str:D $path = $FILE.substr(1);
    my Str:D $file = sprintf(Q{%s%s}, $chroot-dir, $FILE);
    copy(%?RESOURCES{$path}, $file);
    replace($file, $enable-serial-console);
}

multi sub replace(
    Str:D $file where .so,
    Bool:D $enable-serial-console where .so
    --> Nil
)
{
    my Str:D @line = $file.IO.lines;
    my UInt:D $index =
        @line.first(/^'#'$Voidvault::Constants::CONSOLE-SERIAL/, :k);
    @line[$index] = $Voidvault::Constants::CONSOLE-SERIAL;
    my Str:D $replace = @line.join("\n");
    spurt($file, $replace ~ "\n");
}

multi sub replace(
    Str:D $,
    Bool:D $
    --> Nil
)
{*}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
