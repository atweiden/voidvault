use v6;
use Voidvault::Constants;
use Voidvault::Types;
unit role Voidvault::Replace::EFI::Startup;

my constant $FILE = $Voidvault::Constants::FILE-EFI-STARTUP;

multi method replace(::?CLASS:D: Str:D $ where $FILE, 32 --> Nil)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my Str:D $replace = q:to/EOF/;
    fs0:
    \EFI\BOOT\BOOTIA32.EFI
    EOF
    my Str:D $file = sprintf(Q{%s%s}, $chroot-dir, $FILE);
    spurt($file, $replace, :append);
}

multi method replace(::?CLASS:D: Str:D $ where $FILE, 64 --> Nil)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my Str:D $replace = q:to/EOF/;
    fs0:
    \EFI\BOOT\BOOTX64.EFI
    EOF
    my Str:D $file = sprintf(Q{%s%s}, $chroot-dir, $FILE);
    spurt($file, $replace, :append);
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
