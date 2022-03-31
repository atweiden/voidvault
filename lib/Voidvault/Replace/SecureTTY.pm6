use v6;
use Voidvault::Constants;
unit role Voidvault::Replace::SecureTTY;

constant $FILE = '/etc/securetty';

multi method replace(::?CLASS:D: Str:D $ where $FILE --> Nil)
{
    my Bool:D $enable-serial-console = $.config.enable-serial-console;
    my Str:D $path = $FILE.substr(1);
    my Str:D $file = sprintf(Q{/mnt%s}, $FILE);
    copy(%?RESOURCES{$path}, $file);
    replace($enable-serial-console);
}

multi sub replace(Bool:D $enable-serial-console where .so --> Nil)
{
    my Str:D $file = sprintf(Q{/mnt%s}, $FILE);
    my Str:D @line = $file.IO.lines;
    my UInt:D $index =
        @line.first(/^'#'$Voidvault::Constants::SERIAL-CONSOLE/, :k);
    @line[$index] = $Voidvault::Constants::SERIAL-CONSOLE;
    my Str:D $replace = @line.join("\n");
    spurt($file, $replace ~ "\n");
}

multi sub replace(Bool:D $enable-serial-console --> Nil)
{*}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
