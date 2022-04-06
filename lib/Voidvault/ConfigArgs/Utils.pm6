use v6;
use Void::Constants;
use Voidvault::ConfigArgs::Constants;
use Voidvault::Types;
unit class Voidvault::ConfigArgs::Utils;

multi method USAGE(Bool:D :error($)! where .so, *%opts (Str :subject($)))
{
    # print to C<STDERR>
    my &*printer = &note;
    USAGE(|%opts);
}

multi method USAGE(Bool :error($), *%opts (Str :subject($)))
{
    # print to C<STDOUT>
    my &*printer = &say;
    USAGE(|%opts);
}

multi sub USAGE(Str:D :$subject! where 'disable-cow' --> Nil)
{
    &*printer($Voidvault::ConfigArgs::Constants::HELP-DISABLE-COW);
}

multi sub USAGE(Str:D :$subject! where 'gen-pass-hash' --> Nil)
{
    &*printer($Voidvault::ConfigArgs::Constants::HELP-GEN-PASS-HASH);
}

multi sub USAGE(Str:D :$subject! where 'ls' --> Nil)
{
    &*printer($Voidvault::ConfigArgs::Constants::HELP-LS);
}

multi sub USAGE(Str:D :$subject! where 'new' --> Nil)
{
    &*printer($Voidvault::ConfigArgs::Constants::HELP-NEW);
}

multi sub USAGE(Str :subject($) --> Nil)
{
    &*printer($Voidvault::ConfigArgs::Constants::HELP);
}

method ensure-requirements(Str:D $subject where .so --> Nil)
{
    ensure-requirements($subject);
}

proto sub ensure-requirements(
    Str:D $subject where .so
    --> Nil
)
{
    my Str:D @*missing-dependency;
    {*}
    exit-unless-requirements-satisfied($subject, @*missing-dependency);
}

multi sub ensure-requirements(
    Str:D $subject where $Voidvault::ConfigArgs::Constants::SUBJECT-DISABLE-COW
    --> Nil
)
{
    my Str:D @bin = qw<
        chmod
        chown
        cp
        rm
    >.map(-> Str:D $bin { sprintf(Q{/usr/bin/%s}, $bin) });
    so(@bin.all.IO.x)
        or push(@*missing-dependency, 'coreutils');
    '/usr/bin/chattr'.IO.x.so
        or push(@*missing-dependency, 'e2fsprogs');
}

multi sub ensure-requirements(
    Str:D $subject where $Voidvault::ConfigArgs::Constants::SUBJECT-GEN-PASS-HASH
    --> Nil
)
{
    '/usr/bin/openssl'.IO.x.so
        or push(@*missing-dependency, 'openssl');
}

multi sub ensure-requirements(
    Str:D $subject where $Voidvault::ConfigArgs::Constants::SUBJECT-GEN-PASS-HASH-GRUB
    --> Nil
)
{
    '/usr/bin/grub-mkpasswd-pbkdf2'.IO.x.so
        or push(@*missing-dependency, 'grub');
    '/usr/bin/expect'.IO.x.so
        or push(@*missing-dependency, 'expect');
}

multi sub ensure-requirements(
    Str:D $subject where $Voidvault::ConfigArgs::Constants::SUBJECT-LS-DEVICES
    --> Nil
)
{
    '/usr/bin/lsblk'.IO.x.so
        or push(@*missing-dependency, 'util-linux');
}

multi sub ensure-requirements(
    Str:D $subject where $Voidvault::ConfigArgs::Constants::SUBJECT-LS-KEYMAPS
    --> Nil
)
{
    '/usr/share/kbd/keymaps'.IO.d.so
        or push(@*missing-dependency, 'kbd');
}

multi sub ensure-requirements(
    Str:D $subject where $Voidvault::ConfigArgs::Constants::SUBJECT-LS-LOCALES
    --> Nil
)
{
    # locales not supported on musl
    '/usr/share/i18n/locales'.IO.d.so
        or push(@*missing-dependency, 'glibc')
            if $Void::Constants::LIBC-FLAVOR eq 'GLIBC';
}

multi sub ensure-requirements(
    Str:D $subject where $Voidvault::ConfigArgs::Constants::SUBJECT-LS-TIMEZONES
    --> Nil
)
{
    '/usr/share/zoneinfo/zone.tab'.IO.f.so
        or push(@*missing-dependency, 'tzdata');
}

multi sub exit-unless-requirements-satisfied(
    Str:D $subject where .so,
    Str:D @missing-dependency where .so
    --> Nil
)
{
    my Str:D $message = "Sorry, `$subject` requires installing";
    $message = sprintf("%s: %s", $message, @missing-dependency.join(', '));
    note($message);
    exit(1);
}

multi sub exit-unless-requirements-satisfied(
    Str:D $subject where .so,
    Str:D @
    --> Nil
)
{*}

method gen-mode(*%opts (Str :mode($)) --> Mode:D)
{
    my Mode:D $mode = gen-mode(|%opts);
}

multi sub gen-mode(Str:D :mode($)! where 'base' --> Mode:D)
{
    my Mode:D $mode = Mode::BASE;
}

multi sub gen-mode(Str:D :mode($)! where '1fa' --> Mode:D)
{
    my Mode:D $mode = Mode::<1FA>;
}

multi sub gen-mode(Str:D :$mode! where .so --> Mode:D)
{
    die("Sorry, invalid mode 「$mode」");
}

multi sub gen-mode(Str :mode($) --> Mode:D)
{
    my Mode:D $mode = Mode::BASE;
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
