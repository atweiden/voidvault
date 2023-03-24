use v6;
use Voidvault::Constants;
use Voidvault::Types;
unit role Voidvault::Replace::Sudoers;

my constant $FILE = $Voidvault::Constants::FILE-SUDOERS;

multi method replace(Str:D $ where $FILE --> Nil)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
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

    # set PATH environment variable for commands run using sudo
    Defaults secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

    # always use indicated umask regardless of what umask user has set
    Defaults umask=0022
    Defaults umask_override

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
