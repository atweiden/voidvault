use v6;
use Crypt::Libcrypt:auth<atweiden>;
use Void::XBPS;
use Voidvault::Types;
use X::Void::XBPS;
unit class Voidvault::Utils;

# -----------------------------------------------------------------------------
# constants
# -----------------------------------------------------------------------------

# libcrypt crypt encryption rounds
constant $CRYPT-ROUNDS = 700_000;

# libcrypt crypt encryption scheme
constant $CRYPT-SCHEME = 'SHA512';

# grub-mkpasswd-pbkdf2 iterations
constant $PBKDF2-ITERATIONS = 25_000;

# grub-mkpasswd-pbkdf2 length of generated hash
constant $PBKDF2-LENGTH-HASH = 100;

# grub-mkpasswd-pbkdf2 length of salt
constant $PBKDF2-LENGTH-SALT = 100;


# -----------------------------------------------------------------------------
# password hashes
# -----------------------------------------------------------------------------

method gen-pass-hash(Str:D $pass, Bool :$grub --> Str:D)
{
    my Str:D $pass-hash = gen-pass-hash($pass, :$grub);
}

# generate pbkdf2 password hash from plaintext password
multi sub gen-pass-hash(Str:D $grub-pass, Bool:D :grub($)! where .so --> Str:D)
{
    my &gen-pass-hash = gen-pass-hash-closure(:grub);
    my Str:D $grub-pass-hash = &gen-pass-hash($grub-pass);
}

# generate sha512 salted password hash from plaintext password
multi sub gen-pass-hash(Str:D $user-pass, Bool :grub($) --> Str:D)
{
    my &gen-pass-hash = gen-pass-hash-closure();
    my Str:D $user-pass-hash = &gen-pass-hash($user-pass);
}

method prompt-pass-hash(
    Str $user-name?,
    Bool :$grub,
    Str :$repository,
    Bool :$ignore-conf-repos
    --> Str:D
)
{
    my Str:D $pass-hash =
        prompt-pass-hash($user-name, :$grub, :$repository, :$ignore-conf-repos);
}

# generate pbkdf2 password hash from interactive user input
multi sub prompt-pass-hash(
    Str $user-name?,
    Bool:D :grub($)! where .so,
    Str :$repository,
    Bool :$ignore-conf-repos
    --> Str:D
)
{
    # install grub, expect for scripting C<grub-mkpasswd-pbkdf2>
    '/usr/bin/grub-mkpasswd-pbkdf2'.IO.x.so
        or Voidvault::Utils.xbps-install(
               'grub',
               :$repository,
               :$ignore-conf-repos
           );
    '/usr/bin/expect'.IO.x.so
        or Voidvault::Utils.xbps-install(
               'expect',
               :$repository,
               :$ignore-conf-repos
           );
    my &gen-pass-hash = gen-pass-hash-closure(:grub);
    my Str:D $enter = 'Enter password: ';
    my Str:D $confirm = 'Reenter password: ';
    my Str:D $context =
        "Determining grub password for grub user $user-name..." if $user-name;
    my %h;
    %h<enter> = $enter;
    %h<confirm> = $confirm;
    %h<context> = $context if $context;
    my Str:D $grub-pass-hash = loop-prompt-pass-hash(&gen-pass-hash, |%h);
}

# generate sha512 salted password hash from interactive user input
multi sub prompt-pass-hash(
    Str $user-name?,
    Bool :grub($),
    Str :repository($),
    Bool :ignore-conf-repos($)
    --> Str:D
)
{
    my &gen-pass-hash = gen-pass-hash-closure();
    my Str:D $enter = 'Enter new password: ';
    my Str:D $confirm = 'Retype new password: ';
    my Str:D $context =
        "Determining login password for user $user-name..." if $user-name;
    my %h;
    %h<enter> = $enter;
    %h<confirm> = $confirm;
    %h<context> = $context if $context;
    my Str:D $user-pass-hash = loop-prompt-pass-hash(&gen-pass-hash, |%h);
}

multi sub gen-pass-hash-closure(Bool:D :grub($)! where .so --> Sub:D)
{
    my &gen-pass-hash = sub (Str:D $grub-pass --> Str:D)
    {
        my Str:D $grub-mkpasswd-pbkdf2-cmdline =
            build-grub-mkpasswd-pbkdf2-cmdline($grub-pass);
        my Str:D $grub-pass-hash =
            qqx{$grub-mkpasswd-pbkdf2-cmdline}.trim.comb(/\S+/).tail;
    };
}

multi sub gen-pass-hash-closure(Bool :grub($) --> Sub:D)
{
    my LibcFlavor:D $libc-flavor = $Void::XBPS::LIBC-FLAVOR;
    my &gen-pass-hash = sub (Str:D $user-pass --> Str:D)
    {
        my Str:D $salt = gen-pass-salt();
        my Str:D $user-pass-hash = crypt($libc-flavor, $user-pass, $salt);
    };
}

sub build-grub-mkpasswd-pbkdf2-cmdline(Str:D $grub-pass --> Str:D)
{
    my Str:D $log-user =
                'log_user 0';
    my Str:D $set-timeout =
                'set timeout -1';
    my Str:D $spawn-grub-mkpasswd-pbkdf2 = qqw<
                 spawn grub-mkpasswd-pbkdf2
                 --iteration-count $PBKDF2-ITERATIONS
                 --buflen $PBKDF2-LENGTH-HASH
                 --salt $PBKDF2-LENGTH-SALT
    >.join(' ');
    my Str:D $sleep =
                'sleep 0.33';
    my Str:D $expect-enter =
        sprintf('expect "Enter*" { send "%s\r" }', $grub-pass);
    my Str:D $expect-reenter =
        sprintf('expect "Reenter*" { send "%s\r" }', $grub-pass);
    my Str:D $expect-eof =
                'expect eof { puts "\$expect_out(buffer)" }';
    my Str:D $exit =
                'exit 0';

    my Str:D @grub-mkpasswd-pbkdf2-cmdline =
        $log-user,
        $set-timeout,
        $spawn-grub-mkpasswd-pbkdf2,
        $sleep,
        $expect-enter,
        $sleep,
        $expect-reenter,
        $sleep,
        $expect-eof,
        $exit;

    my Str:D $grub-mkpasswd-pbkdf2-cmdline =
        sprintf(q:to/EOF/, |@grub-mkpasswd-pbkdf2-cmdline);
        expect <<EOS
          %s
          %s
          %s
          %s
          %s
          %s
          %s
          %s
          %s
          %s
        EOS
        EOF
}

sub gen-pass-salt(--> Str:D)
{
    my Str:D $scheme = gen-scheme-id($CRYPT-SCHEME);
    my Str:D $rounds = ~$CRYPT-ROUNDS;
    my Str:D $rand =
        qx<openssl rand -base64 16>.trim.subst(/<[+=]>/, '', :g).substr(0, 16);
    my Str:D $salt = sprintf('$%s$rounds=%s$%s$', $scheme, $rounds, $rand);
}

# linux crypt encrypted method id accessed by encryption method
multi sub gen-scheme-id('MD5' --> Str:D)      { '1' }
multi sub gen-scheme-id('BLOWFISH' --> Str:D) { '2a' }
multi sub gen-scheme-id('SHA256' --> Str:D)   { '5' }
multi sub gen-scheme-id('SHA512' --> Str:D)   { '6' }

sub loop-prompt-pass-hash(
    # closure for generating pass hash from plaintext password
    &gen-pass-hash,
    # prompt message text for initial password entry
    Str:D :$enter!,
    # prompt message text for password confirmation
    Str:D :$confirm!,
    # non-prompt message for general context
    Str :$context
    --> Str:D
)
{
    my Str $pass-hash;
    my Str:D $blank = 'Password cannot be blank. Please try again';
    my Str:D $no-match = 'Please try again';
    loop
    {
        say($context) if $context;
        my Str:D $pass = stprompt($enter);
        $pass !eqv '' or do {
            say($blank);
            next;
        }
        my Str:D $pass-confirm = stprompt($confirm);
        $pass eqv $pass-confirm or do {
            say($no-match);
            next;
        }
        $pass-hash = &gen-pass-hash($pass);
        last;
    }
    $pass-hash;
}

# user input prompt (secret text)
sub stprompt(Str:D $prompt-text --> Str:D)
{
    ENTER { run(qw<stty -echo>); }
    LEAVE { run(qw<stty echo>); say(''); }
    my Str:D $secret = prompt($prompt-text);
}


# -----------------------------------------------------------------------------
# partitions
# -----------------------------------------------------------------------------

# generate target partition based on subject
method gen-partition(Str:D $subject, Str:D $p --> Str:D)
{
    # run lsblk only once
    state Str:D @partition =
        qqx<lsblk $p --noheadings --paths --raw --output NAME,TYPE>
        .trim
        .lines
        # make sure we're not getting the master device partition
        .grep(/part$/)
        # return only the device name
        .map({ .split(' ').first })
        .sort;
    my Str:D $partition = gen-partition($subject, @partition);
}

multi sub gen-partition('efi', Str:D @partition --> Str:D)
{
    # e.g. /dev/sda2
    my UInt:D $index = 1;
    my Str:D $partition = @partition[$index];
}

multi sub gen-partition('vault', Str:D @partition --> Str:D)
{
    # e.g. /dev/sda3
    my UInt:D $index = 2;
    my Str:D $partition = @partition[$index];
}


# -----------------------------------------------------------------------------
# system information
# -----------------------------------------------------------------------------

# list keymaps
method ls-keymaps(--> Array[Keymap:D])
{
    # equivalent to `localectl list-keymaps --no-pager`
    # see: src/basic/def.h in systemd source code
    my Keymap:D @keymaps = ls-keymaps();
}

sub ls-keymaps(--> Array[Str:D])
{
    my Str:D @keymap =
        ls-keymap-tarballs()
        .race
        .map({ .split('/').tail.split('.').first })
        .sort;
}

multi sub ls-keymap-tarballs(--> Array[Str:D])
{
    my Str:D $keymaps-dir = '/usr/share/kbd/keymaps';
    my Str:D @tarball =
        ls-keymap-tarballs(
            Array[Str:D].new(dir($keymaps-dir).race.map({ .Str }))
        )
        .grep(/'.map.gz'$/);
}

multi sub ls-keymap-tarballs(Str:D @path --> Array[Str:D])
{
    my Str:D @tarball =
        @path
        .race
        .map({ .Str })
        .map(-> Str:D $path { ls-keymap-tarballs($path) })
        .flat;
}

multi sub ls-keymap-tarballs(Str:D $path where .IO.d.so --> Array[Str:D])
{
    my Str:D @tarball =
        ls-keymap-tarballs(
            Array[Str:D].new(dir($path).race.map({ .Str }))
        ).flat;
}

multi sub ls-keymap-tarballs(Str:D $path where .IO.f.so --> Array[Str:D])
{
    my Str:D @tarball = $path;
}

# list locales
method ls-locales(--> Array[Locale:D])
{
    my Str:D $locale-dir = '/usr/share/i18n/locales';
    my Locale:D @locale = ls-locales($locale-dir);
}

multi sub ls-locales(
    Str:D $locale-dir where .IO.e.so && .IO.d.so
    --> Array[Locale:D]
)
{
    my Locale:D @locale =
        dir($locale-dir).race.map({ .Str }).map({ .split('/').tail }).sort;
}

multi sub ls-locales(
    Str:D $locale-dir
    --> Array[Locale:D]
)
{
    my Locale:D @locale;
}

# list block devices (partitions)
method ls-partitions(--> Array[Str:D])
{
    my Str:D @partitions = qx<
        lsblk --output NAME --nodeps --noheadings --raw
    >.trim.split("\n").map({ .subst(/(.*)/, -> $/ { "/dev/$0" }) }).sort;
}

# list timezones
method ls-timezones(--> Array[Timezone:D])
{
    # equivalent to `timedatectl list-timezones --no-pager`
    # see: src/basic/time-util.c in systemd source code
    my Str:D $zoneinfo-file = '/usr/share/zoneinfo/zone.tab';
    my Str:D @zoneinfo =
        $zoneinfo-file
        .IO.lines
        .grep(/^\w.*/)
        .race
        .map({ .split(/\h+/)[2] })
        .sort;
    my Timezone:D @timezones = |@zoneinfo, 'UTC';
}


# -----------------------------------------------------------------------------
# utils
# -----------------------------------------------------------------------------

method loop-cmdline-proc(
    Str:D $message where .so,
    Str:D $cmdline where .so
    --> Nil
)
{
    loop
    {
        say($message);
        my Proc:D $proc = shell($cmdline);
        last if $proc.exitcode == 0;
    }
}

method xbps-install(
    Str:D $package where .so,
    Str :$repository,
    Bool :$ignore-conf-repos
    --> Nil
)
{
    # Cxbps-install> requires root privileges
    my Str:D $message =
        "Sorry, missing pkg $package. Please install: xbps-install $package";
    $*USER == 0 or die($message);
    my Str:D $xbps-install-cmdline =
        build-xbps-install-cmdline(
            $package,
            :$repository,
            :$ignore-conf-repos
        );
    Voidvault::Utils.loop-cmdline-proc(
        "Installing $package...",
        $xbps-install-cmdline
    );
}

multi sub build-xbps-install-cmdline(
    Str:D $package where .so,
    Str:D :$repository! where .so,
    Bool:D :ignore-conf-repos($)! where .so
    --> Str:D
)
{
    my Str:D $xbps-install-cmdline =
        "xbps-install \\
         --ignore-conf-repos \\
         --repository $repository \\
         --sync \\
         --yes \\
         $package";
}

multi sub build-xbps-install-cmdline(
    Str:D $package where .so,
    Str:D :$repository! where .so,
    Bool :ignore-conf-repos($)
    --> Str:D
)
{
    my Str:D $xbps-install-cmdline =
        "xbps-install \\
         --repository $repository \\
         --sync \\
         --yes \\
         $package";
}

multi sub build-xbps-install-cmdline(
    $,
    Str :repository($),
    Bool:D :ignore-conf-repos($)! where .so
    --> Nil
)
{
    die(X::Void::XBPS::IgnoreConfRepos.new);
}

multi sub build-xbps-install-cmdline(
    Str:D $package where .so,
    Str :repository($),
    Bool :ignore-conf-repos($)
    --> Str:D
)
{
    my Str:D $xbps-install-cmdline =
        "xbps-install \\
         --sync \\
         --yes \\
         $package";
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
