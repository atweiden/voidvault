use v6;
unit role Voidvault::Replace::Locales;

my constant $FILE = '/etc/default/libc-locales';

multi method replace(::?CLASS:D: Str:D $ where $FILE --> Nil)
{
    my Locale:D $locale = $.config.locale;
    my Str:D $file = sprintf(Q{/mnt%s}, $FILE);
    my Str:D @line = $file.IO.lines;
    my Str:D $locale-full = sprintf(Q{%s.UTF-8 UTF-8}, $locale);
    my UInt:D $index = @line.first(/^"#$locale-full"/, :k);
    @line[$index] = $locale-full;
    my Str:D $replace = @line.join("\n");
    spurt($file, $replace ~ "\n");
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
