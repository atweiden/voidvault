use v6;
use Crypt::Libcrypt:auth<atweiden>;
use Void::Constants;
use Voidvault::Constants;
use Voidvault::Types;
unit class Voidvault::Utils;

# disable btrfs copy-on-write
method disable-cow(
    *%opt (
        Bool :clean($),
        Bool :recursive($),
        Str :permissions($),
        Str :user($),
        Str :group($)
    ),
    *@directory
    --> Nil
)
{
    # https://wiki.archlinux.org/index.php/Btrfs#Disabling_CoW
    @directory.map(-> Str:D $directory { disable-cow($directory, |%opt) });
}

multi sub disable-cow(
    Str:D $directory,
    Bool:D :clean($)! where .so,
    # ignored, recursive is implied with :clean
    Bool :recursive($),
    Str:D :$permissions = '755',
    Str:D :$user = $*USER,
    Str:D :$group = $*GROUP
    --> Nil
)
{
    my Str:D $orig-dir = ~$directory.IO.resolve;
    $orig-dir.IO.e && $orig-dir.IO.r && $orig-dir.IO.d
        or die('directory failed exists readable directory test');
    my Str:D $backup-dir = sprintf(Q{%s-old}, $orig-dir);
    rename($orig-dir, $backup-dir);
    mkdir($orig-dir);
    run(qqw<chmod $permissions $orig-dir>);
    run(qqw<chown $user:$group $orig-dir>);
    run(qqw<chattr -R +C $orig-dir>);
    dir($backup-dir).map(-> IO::Path:D $file {
        run(qqw<
            cp
            --no-dereference
            --preserve=links,mode,ownership,timestamps
            $file
            $orig-dir
        >);
    });
    run(qqw<rm --recursive --force $backup-dir>);
}

multi sub disable-cow(
    Str:D $directory,
    Bool :clean($),
    Bool:D :recursive($)! where .so,
    Str :permissions($),
    Str :user($),
    Str :group($)
    --> Nil
)
{
    my Str:D $orig-dir = ~$directory.IO.resolve;
    $orig-dir.IO.e && $orig-dir.IO.r && $orig-dir.IO.d
        or die('directory failed exists readable directory test');
    run(qqw<chattr -R +C $orig-dir>);
}

multi sub disable-cow(
    Str:D $directory,
    Bool :clean($),
    Bool :recursive($),
    Str :permissions($),
    Str :user($),
    Str :group($)
    --> Nil
)
{
    my Str:D $orig-dir = ~$directory.IO.resolve;
    $orig-dir.IO.e && $orig-dir.IO.r && $orig-dir.IO.d
        or die('directory failed exists readable directory test');
    run(qqw<chattr +C $orig-dir>);
}

method groupadd(
    Str:D :$chroot-dir! where .so,
    *@group-name (Str:D $, *@),
    *%opts (
        Bool :system($)
    )
    --> Nil
)
{
    groupadd(@group-name, :$chroot-dir, |%opts);
}

multi sub groupadd(
    Str:D :$chroot-dir! where .so,
    Bool:D :system($)! where .so,
    *@group-name (Str:D $, *@)
    --> Nil
)
{
    @group-name.map(-> Str:D $group-name {
        run(qqw<void-chroot $chroot-dir groupadd --system $group-name>);
    });
}

multi sub groupadd(
    Str:D :$chroot-dir! where .so,
    *@group-name (Str:D $, *@)
    --> Nil
)
{
    @group-name.map(-> Str:D $group-name {
        run(qqw<void-chroot $chroot-dir groupadd $group-name>);
    });
}

# execute shell process and re-attempt on failure
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

# list block devices
method ls-devices(--> Array[Str:D])
{
    my Str:D @device =
        qx<lsblk --noheadings --nodeps --raw --output NAME>
        .trim
        .split("\n")
        .map({ .subst(/(.*)/, -> $/ { "/dev/$0" }) })
        .sort;
}

# list partitions on block device
method ls-partitions(Str:D $device --> Array[Str:D])
{
    # run lsblk only once
    state Str:D @partition =
        qqx<lsblk $device --noheadings --paths --raw --output NAME,TYPE>
        .trim
        .lines
        # make sure we're not getting the master device partition
        .grep(/part$/)
        # return only the device name
        .map({ .split(' ').first })
        .sort;
}

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

# chroot into C<$chroot-dir> to then C<dracut>
method void-chroot-dracut(Str:D :$chroot-dir! where .so --> Nil)
{
    my Str:D $linux-version = dir("$chroot-dir/usr/lib/modules").first.basename;
    run(qqw<void-chroot $chroot-dir dracut --force --kver $linux-version>);
}

# chroot into C<$chroot-dir> to then C<mkdir> there with C<$permissions>
method void-chroot-mkdir(
    Str:D :$user! where .so,
    Str:D :$group! where .so,
    # permissions should be octal: https://docs.raku.org/routine/chmod
    UInt:D :$permissions! where .so,
    Str:D :$chroot-dir! where .so,
    *@dir (Str:D $, *@)
    --> Nil
)
{
    @dir.map(-> Str:D $dir {
        mkdir("$chroot-dir/$dir", $permissions);
        run(qqw<void-chroot $chroot-dir chown $user:$group $dir>);
    });
}

# chroot into C<$chroot-dir> to then C<dracut>
method void-chroot-xbps-reconfigure-linux(Str:D :$chroot-dir! where .so --> Nil)
{
    my Str:D $xbps-linux = do {
        my Str:D $xbps-linux-version-raw =
            qqx{xbps-query --rootdir $chroot-dir --property pkgver linux}.trim;
        my Str:D $xbps-linux-version =
            $xbps-linux-version-raw.substr(6..*).split(/'.'|'_'/)[^2].join('.');
        sprintf(Q{linux%s}, $xbps-linux-version);
    };
    run(qqw<void-chroot $chroot-dir xbps-reconfigure --force $xbps-linux>);
}


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
    Str:D :@repository,
    Bool :$ignore-conf-repos
    --> Str:D
)
{
    my Str:D $pass-hash =
        prompt-pass-hash($user-name, :$grub, :@repository, :$ignore-conf-repos);
}

# generate pbkdf2 password hash from interactive user input
multi sub prompt-pass-hash(
    Str $user-name?,
    Bool:D :grub($)! where .so,
    Str:D :@repository,
    Bool :$ignore-conf-repos
    --> Str:D
)
{
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
    Str:D :repository(@),
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
    my LibcFlavor:D $libc-flavor = $Void::Constants::LIBC-FLAVOR;
    my &gen-pass-hash = sub (Str:D $user-pass --> Str:D)
    {
        my Str:D $salt = gen-pass-salt();
        my Str:D $user-pass-hash = crypt($libc-flavor, $user-pass, $salt);
    };
}

sub build-grub-mkpasswd-pbkdf2-cmdline(Str:D $grub-pass --> Str:D)
{
    my $iteration-count = $Voidvault::Constants::PBKDF2-ITERATIONS;
    my $buflen = $Voidvault::Constants::PBKDF2-LENGTH-HASH;
    my $salt = $Voidvault::Constants::PBKDF2-LENGTH-SALT;

    my Str:D $log-user =
                'log_user 0';
    my Str:D $set-timeout =
                'set timeout -1';
    my Str:D $spawn-grub-mkpasswd-pbkdf2 = qqw<
                 spawn grub-mkpasswd-pbkdf2
                 --iteration-count $iteration-count
                 --buflen $buflen
                 --salt $salt
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
    my Str:D $scheme = gen-scheme-id($Voidvault::Constants::CRYPT-SCHEME);
    my Str:D $rounds = ~$Voidvault::Constants::CRYPT-ROUNDS;
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
# vault
# -----------------------------------------------------------------------------

# create vault with cryptsetup
method mkvault(
    VaultType:D :$vault-type! where .so,
    Str:D :$partition-vault! where .so,
    *%opts (
        VaultPass :vault-pass($)
    )
    --> Nil
)
{
    # load kernel modules for cryptsetup
    run(qw<modprobe dm_mod dm-crypt>);

    # create vault
    mkvault(:$vault-type, :$partition-vault, |%opts);
}

# LUKS encrypted volume password was given
multi sub mkvault(
    VaultType:D :$vault-type! where .so,
    Str:D :$partition-vault! where .so,
    VaultPass:D :$vault-pass! where .so
    --> Nil
)
{
    my Str:D $cryptsetup-luks-format-cmdline =
        build-cryptsetup-luks-format-cmdline(
            :non-interactive,
            :$vault-type,
            :$partition-vault,
            :$vault-pass
        );

    # make LUKS encrypted volume without prompt for vault password
    shell($cryptsetup-luks-format-cmdline);
}

# LUKS encrypted volume password not given
multi sub mkvault(
    VaultType:D :$vault-type! where .so,
    Str:D :$partition-vault! where .so,
    VaultPass :vault-pass($)
    --> Nil
)
{
    my Str:D $cryptsetup-luks-format-cmdline =
        build-cryptsetup-luks-format-cmdline(
            :interactive,
            :$vault-type,
            :$partition-vault
        );

    # create LUKS encrypted volume, prompt user for vault password
    Voidvault::Utils.loop-cmdline-proc(
        'Creating LUKS vault...',
        $cryptsetup-luks-format-cmdline
    );
}

multi sub build-cryptsetup-luks-format-cmdline(
    Bool:D :interactive($)! where .so,
    VaultType:D :$vault-type!,
    Str:D :$partition-vault! where .so
    --> Str:D
)
{
    my Str:D $spawn-cryptsetup-luks-format =
        gen-spawn-cryptsetup-luks-format(:$vault-type, :$partition-vault);
    my Str:D $expect-are-you-sure-send-yes =
        'expect "Are you sure*" { send "YES\r" }';
    my Str:D $interact =
        'interact';
    my Str:D $catch-wait-result =
        'catch wait result';
    my Str:D $exit-lindex-result =
        'exit [lindex $result 3]';

    my Str:D @cryptsetup-luks-format-cmdline =
        $spawn-cryptsetup-luks-format,
        $expect-are-you-sure-send-yes,
        $interact,
        $catch-wait-result,
        $exit-lindex-result;

    my Str:D $cryptsetup-luks-format-cmdline =
        sprintf(q:to/EOF/.trim, |@cryptsetup-luks-format-cmdline);
        expect -c '%s;
                   %s;
                   %s;
                   %s;
                   %s'
        EOF
}

multi sub build-cryptsetup-luks-format-cmdline(
    Bool:D :non-interactive($)! where .so,
    VaultType:D :$vault-type!,
    Str:D :$partition-vault! where .so,
    VaultPass:D :$vault-pass! where .so
    --> Str:D
)
{
    my Str:D $spawn-cryptsetup-luks-format =
        gen-spawn-cryptsetup-luks-format(:$vault-type, :$partition-vault);
    my Str:D $sleep =
                'sleep 0.33';
    my Str:D $expect-are-you-sure-send-yes =
                'expect "Are you sure*" { send "YES\r" }';
    my Str:D $expect-enter-send-vault-pass =
        sprintf('expect "Enter*" { send "%s\r" }', $vault-pass);
    my Str:D $expect-verify-send-vault-pass =
        sprintf('expect "Verify*" { send "%s\r" }', $vault-pass);
    my Str:D $expect-eof =
                'expect eof';

    my Str:D @cryptsetup-luks-format-cmdline =
        $spawn-cryptsetup-luks-format,
        $sleep,
        $expect-are-you-sure-send-yes,
        $sleep,
        $expect-enter-send-vault-pass,
        $sleep,
        $expect-verify-send-vault-pass,
        'sleep 7',
        $expect-eof;

    my Str:D $cryptsetup-luks-format-cmdline =
        sprintf(q:to/EOF/.trim, |@cryptsetup-luks-format-cmdline);
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
        EOS
        EOF
}

multi sub gen-spawn-cryptsetup-luks-format(
    VaultType:D :vault-type($)! where 'LUKS1',
    Str:D :$partition-vault! where .so
    --> Str:D
)
{
    my Str:D $spawn-cryptsetup-luks-format = qqw<
         spawn cryptsetup
         --type luks1
         --cipher aes-xts-plain64
         --key-slot 1
         --key-size 512
         --hash sha512
         --iter-time 5000
         --use-random
         --verify-passphrase
         luksFormat $partition-vault
    >.join(' ');
}

multi sub gen-spawn-cryptsetup-luks-format(
    VaultType:D :vault-type($)! where 'LUKS2',
    Str:D :$partition-vault! where .so
    --> Str:D
)
{
    my Str:D $spawn-cryptsetup-luks-format = qqw<
         spawn cryptsetup
         --type luks2
         --cipher aes-xts-plain64
         --pbkdf argon2id
         --key-slot 1
         --key-size 512
         --hash sha512
         --iter-time 5000
         --use-random
         --verify-passphrase
         luksFormat $partition-vault
    >.join(' ');
}

method open-vault(
    # luksOpen cmdline options differ by type
    VaultType:D :$vault-type! where .so,
    Str:D :$partition-vault! where .so,
    VaultName:D :$vault-name! where .so,
    *%opts (
        VaultPass :vault-pass($)
    )
)
{
    open-vault(:$vault-type, :$partition-vault, :$vault-name, |%opts);
}

# LUKS encrypted volume password was given
multi sub open-vault(
    VaultType:D :$vault-type! where .so,
    Str:D :$partition-vault! where .so,
    VaultName:D :$vault-name! where .so,
    VaultPass:D :$vault-pass! where .so
    --> Nil
)
{
    my Str:D $cryptsetup-luks-open-cmdline =
        build-cryptsetup-luks-open-cmdline(
            :non-interactive,
            :$vault-type,
            :$partition-vault,
            :$vault-name,
            :$vault-pass
        );

    # open vault without prompt for vault password
    shell($cryptsetup-luks-open-cmdline);
}

# LUKS encrypted volume password not given
multi sub open-vault(
    VaultType:D :$vault-type! where .so,
    Str:D :$partition-vault! where .so,
    VaultName:D :$vault-name! where .so,
    VaultPass :vault-pass($)
    --> Nil
)
{
    my Str:D $cryptsetup-luks-open-cmdline =
        build-cryptsetup-luks-open-cmdline(
            :interactive,
            :$vault-type,
            :$partition-vault,
            :$vault-name
        );

    # open LUKS encrypted volume, prompt user for vault password
    Voidvault::Utils.loop-cmdline-proc(
        'Opening LUKS vault...',
        $cryptsetup-luks-open-cmdline
    );
}

multi sub build-cryptsetup-luks-open-cmdline(
    Bool:D :interactive($)! where .so,
    VaultType:D :$vault-type! where .so,
    Str:D :$partition-vault! where .so,
    VaultName:D :$vault-name! where .so
    --> Str:D
)
{
    my Str:D $cryptsetup-luks-open-cmdline =
        gen-cryptsetup-luks-open(:$vault-type, :$partition-vault, :$vault-name);
}

multi sub build-cryptsetup-luks-open-cmdline(
    Bool:D :non-interactive($)! where .so,
    VaultType:D :$vault-type! where .so,
    Str:D :$partition-vault! where .so,
    VaultName:D :$vault-name! where .so,
    VaultPass:D :$vault-pass! where .so
    --> Str:D
)
{
    my Str:D $cryptsetup-luks-open =
        gen-cryptsetup-luks-open(:$vault-type, :$partition-vault, :$vault-name);
    my Str:D $spawn-cryptsetup-luks-open =
        sprintf('spawn %s', $cryptsetup-luks-open);
    my Str:D $sleep =
                'sleep 0.33';
    my Str:D $expect-enter-send-vault-pass =
        sprintf('expect "Enter*" { send "%s\r" }', $vault-pass);
    my Str:D $expect-eof =
                'expect eof';

    my Str:D @cryptsetup-luks-open-cmdline =
        $spawn-cryptsetup-luks-open,
        $sleep,
        $expect-enter-send-vault-pass,
        $sleep,
        $expect-eof;

    my Str:D $cryptsetup-luks-open-cmdline =
        sprintf(q:to/EOF/.trim, |@cryptsetup-luks-open-cmdline);
        expect <<EOS
          %s
          %s
          %s
          %s
          %s
        EOS
        EOF
}

multi sub gen-cryptsetup-luks-open(
    VaultType:D :vault-type($)! where 'LUKS1',
    Str:D :$partition-vault! where .so,
    VaultName:D :$vault-name! where .so
    --> Str:D
)
{
    my Str:D $cryptsetup-luks-open-cmdline =
        "cryptsetup luksOpen $partition-vault $vault-name";
}

multi sub gen-cryptsetup-luks-open(
    VaultType:D :vault-type($)! where 'LUKS2',
    Str:D :$partition-vault! where .so,
    VaultName:D :$vault-name! where .so
    --> Str:D
)
{
    my Str:D $opts = qqw<
        --perf-no_read_workqueue
        --persistent
    >.join(' ');
    my Str:D $cryptsetup-luks-open-cmdline =
        "cryptsetup $opts luksOpen $partition-vault $vault-name";
}

method install-vault-key(
    Str:D :$partition-vault where .so,
    # C<$vault-key-unprefixed> contains path absent C<$chroot-dir> prefix
    VaultKey:D :vault-key($vault-key-unprefixed) where .so,
    Str:D :$chroot-dir! where .so,
    *%opts (
        VaultPass :vault-pass($)
    )
    --> Nil
)
{
    my VaultKey:D $vault-key =
        sprintf(Q{%s%s}, $chroot-dir, $vault-key-unprefixed);
    mkkey(:$vault-key);
    addkey(:$vault-key, :$partition-vault, |%opts);
    seckey(:$vault-key, :$chroot-dir);
}

# make vault key
sub mkkey(VaultKey:D :$vault-key! where .so --> Nil)
{
    # source of entropy
    my Str:D $src = '/dev/random';
    # bytes to read from C<$src>
    my UInt:D $bytes = 64;
    # exec idiomatic version of C<head -c 64 /dev/random > $vault-key>
    my IO::Handle:D $fh = $src.IO.open(:bin);
    my Buf:D $buf = $fh.read($bytes);
    $fh.close;
    spurt($vault-key, $buf);
}

# LUKS encrypted volume password was given
multi sub addkey(
    VaultKey:D :$vault-key! where .so,
    Str:D :$partition-vault! where .so,
    VaultPass:D :$vault-pass! where .so
    --> Nil
)
{
    my Str:D $cryptsetup-luks-add-key-cmdline =
        build-cryptsetup-luks-add-key-cmdline(
            :non-interactive,
            :$vault-key,
            :$partition-vault,
            :$vault-pass
        );

    # add key to LUKS encrypted volume without prompt for vault password
    shell($cryptsetup-luks-add-key-cmdline);
}

# LUKS encrypted volume password not given
multi sub addkey(
    VaultKey:D :$vault-key! where .so,
    Str:D :$partition-vault! where .so,
    VaultPass :vault-pass($)
    --> Nil
)
{
    my Str:D $cryptsetup-luks-add-key-cmdline =
        build-cryptsetup-luks-add-key-cmdline(
            :interactive,
            :$vault-key,
            :$partition-vault
        );

    # add key to LUKS encrypted volume, prompt user for vault password
    Voidvault::Utils.loop-cmdline-proc(
        'Adding LUKS key...',
        $cryptsetup-luks-add-key-cmdline
    );
}

multi sub build-cryptsetup-luks-add-key-cmdline(
    Bool:D :interactive($)! where .so,
    VaultKey:D :$vault-key! where .so,
    Str:D :$partition-vault! where .so
    --> Str:D
)
{
    my Str:D $opts = '--iter-time 1';
    my Str:D $spawn-cryptsetup-luks-add-key =
        "spawn cryptsetup $opts luksAddKey $partition-vault $vault-key";
    my Str:D $interact =
        'interact';
    my Str:D $catch-wait-result =
        'catch wait result';
    my Str:D $exit-lindex-result =
        'exit [lindex $result 3]';

    my Str:D @cryptsetup-luks-add-key-cmdline =
        $spawn-cryptsetup-luks-add-key,
        $interact,
        $catch-wait-result,
        $exit-lindex-result;

    my Str:D $cryptsetup-luks-add-key-cmdline =
        sprintf(q:to/EOF/.trim, |@cryptsetup-luks-add-key-cmdline);
        expect -c '%s;
                   %s;
                   %s;
                   %s'
        EOF
}

multi sub build-cryptsetup-luks-add-key-cmdline(
    Bool:D :non-interactive($)! where .so,
    VaultKey:D :$vault-key! where .so,
    Str:D :$partition-vault! where .so,
    VaultPass:D :$vault-pass! where .so
    --> Str:D
)
{
    my Str:D $opts = '--iter-time 1';
    my Str:D $spawn-cryptsetup-luks-add-key =
                "spawn cryptsetup $opts luksAddKey $partition-vault $vault-key";
    my Str:D $sleep =
                'sleep 0.33';
    my Str:D $expect-enter-send-vault-pass =
        sprintf('expect "Enter*" { send "%s\r" }', $vault-pass);
    my Str:D $expect-eof =
                'expect eof';

    my Str:D @cryptsetup-luks-add-key-cmdline =
        $spawn-cryptsetup-luks-add-key,
        $sleep,
        $expect-enter-send-vault-pass,
        'sleep 7',
        $expect-eof;

    my Str:D $cryptsetup-luks-add-key-cmdline =
        sprintf(q:to/EOF/.trim, |@cryptsetup-luks-add-key-cmdline);
        expect <<EOS
          %s
          %s
          %s
          %s
          %s
        EOS
        EOF
}

# secure vault key
sub seckey(
    VaultKey:D :$vault-key! where .so,
    AbsolutePath:D :$chroot-dir! where .so
    --> Nil
)
{
    run(qqw<void-chroot $chroot-dir chmod 000 $vault-key>);
    run(qqw<void-chroot $chroot-dir chmod -R g-rwx,o-rwx /boot>);
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
