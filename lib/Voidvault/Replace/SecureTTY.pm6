use v6;
use Voidvault::Constants;
unit role Voidvault::Replace::SecureTTY;

constant $FILE = '/etc/securetty';

multi method replace(Str:D $ where $FILE --> Nil)
{
    my Str:D $file = sprintf(Q{/mnt%s}, $FILE);
    my Str:D @line = $file.IO.lines;
    my UInt:D $index =
        @line.first(/^'#'$Voidvault::Constants::SERIAL-CONSOLE/, :k);
    @line[$index] = $Voidvault::Constants::SERIAL-CONSOLE;
    my Str:D $replace = @line.join("\n");
    spurt($file, $replace ~ "\n");
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
