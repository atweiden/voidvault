use v6;
use Voidvault::Constants;
use Voidvault::Types;
unit role Voidvault::Replace::Grub::Linux;

my constant $FILE = $Voidvault::Constants::FILE-GRUB-LINUX;

multi method replace(::?CLASS:D: Str:D $ where $FILE --> Nil)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my Str:D $file = sprintf(Q{%s%s}, $chroot-dir, $FILE);
    my Str:D @line = $file.IO.lines;
    my UInt:D $index = @line.first(/^'CLASS='/, :k);
    my Str:D $replace = @line[$index].subst(/(.*)'"'/, {"$0 --unrestricted\""});
    @line[$index] = $replace;
    my Str:D $finalize = @line.join("\n");
    spurt($file, $finalize ~ "\n");
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
