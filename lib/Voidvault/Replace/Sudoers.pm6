use v6;
use Voidvault::Constants;
unit role Voidvault::Replace::Sudoers;

my constant $FILE = $Voidvault::Constants::FILE-SUDOERS;

multi method replace(Str:D $ where $FILE --> Nil)
{
    my Str:D $chroot-dir = $.config.chroot-dir;
    my Str:D $file = sprintf(Q{%s%s}, $chroot-dir, $FILE);
    my Str:D $slurp = slurp($file);
    my Str:D $defaults = q:to/EOF/;
    # reset environment by default
    Defaults env_reset

    # set default editor to rvim, do not allow visudo to use $EDITOR/$VISUAL
    Defaults editor=/usr/bin/rvim, !env_editor

    # force password entry with every sudo
    Defaults timestamp_timeout=0

    # only allow sudo when the user is logged in to a real tty
    Defaults requiretty

    # prevent arbitrary code execution as your user when sudoing to another
    # user due to TTY hijacking via TIOCSTI ioctl
    Defaults use_pty

    # wrap logfile lines at 72 characters
    Defaults loglinelen=72
    EOF
    my Str:D $replace = join("\n", $defaults, $slurp);
    spurt($file, $replace);
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
