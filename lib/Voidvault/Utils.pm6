use v6;
use Crypt::Libcrypt:auth<atweiden>;
use Void::Constants;
use Voidvault::Constants;
use Voidvault::Types;
unit class Voidvault::Utils;


# -----------------------------------------------------------------------------
# btrfs
# -----------------------------------------------------------------------------

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

proto sub disable-cow(
    Str:D $directory,
    Bool :clean($),
    Bool :recursive($),
    Str :permissions($),
    Str :user($),
    Str :group($)
    --> Nil
)
{
    my Str:D $*directory = ~$directory.IO.resolve;
    with $*directory
    {
        [&&] .IO.e.so, .IO.r.so, .IO.d.so
            or die('directory failed exists readable directory test');
    }
    {*}
}

multi sub disable-cow(
    Str:D $,
    Bool:D :clean($)! where .so,
    # ignored, recursive is implied with :clean
    Bool :recursive($),
    Str:D :$permissions = '755',
    Str:D :$user = $*USER,
    Str:D :$group = $*GROUP
    --> Nil
)
{
    my Str:D $backup-dir = sprintf(Q{%s-old}, $*directory);
    rename($*directory, $backup-dir);
    mkdir($*directory);
    run(qqw<chmod $permissions $*directory>);
    run(qqw<chown $user:$group $*directory>);
    run(qqw<chattr -R +C $*directory>);
    dir($backup-dir).map(-> IO::Path:D $file {
        run(qqw<cp --archive --reflink=never $file $*directory>);
    });
    run(qqw<rm --recursive --force $backup-dir>);
}

multi sub disable-cow(
    Str:D $,
    Bool :clean($),
    Bool:D :recursive($)! where .so,
    Str :permissions($),
    Str :user($),
    Str :group($)
    --> Nil
)
{
    run(qqw<chattr -R +C $*directory>);
}

multi sub disable-cow(
    Str:D $,
    Bool :clean($),
    Bool :recursive($),
    Str :permissions($),
    Str :user($),
    Str :group($)
    --> Nil
)
{
    run(qqw<chattr +C $*directory>);
}

method mkbtrfs(
    AbsolutePath:D :$chroot-dir! where .so,
    VaultName:D :$vault-name! where .so,
    # names of btrfs subvolumes to create
    Str:D :@subvolume!,
    # function to be called for mounting subvolumes
    :&mount-subvolume!,
    # optional kernel modules to load prior to C<mkfs.btrfs>
    Str:D :@kernel-module,
    # optional options to pass to C<mkfs.btrfs>
    Str:D :@mkfs-option,
    # optional base options with which to mount main btrfs filesystem
    Str:D :@mount-option
    --> Nil
)
{
    my Str:D $vault-device-mapper = sprintf(Q{/dev/mapper/%s}, $vault-name);
    my Str:D $mount-dir = sprintf(Q{%s2}, $chroot-dir);

    # create btrfs filesystem on opened vault
    run(qqw<modprobe $_>) for @kernel-module;
    run('mkfs.btrfs', |@mkfs-option, $vault-device-mapper);

    # mount main btrfs filesystem on open vault
    mkdir($mount-dir);
    my Str:D $mount-btrfs-cmdline =
        Voidvault::Utils.build-mount-btrfs-cmdline(
            :@mount-option,
            :$vault-device-mapper,
            :$mount-dir
        );
    shell($mount-btrfs-cmdline);

    # create btrfs subvolumes
    indir($mount-dir, {
        run(qqw<btrfs subvolume create $_>) for @subvolume;
    });

    # mount btrfs subvolumes
    @subvolume.map(-> Str:D $subvolume {
        mount-subvolume(
            :$subvolume,
            :$vault-device-mapper,
            :$chroot-dir,
            :@mount-option
        );
    });

    # unmount /mnt2 and remove
    run(qqw<umount $mount-dir>);
    rmdir($mount-dir);
}

# prepend --options only when options are present
method build-mount-options-cmdline(Str:D :@mount-option --> Str:D)
{
    my Str:D $mount-options-cmdline =
        build-mount-options-cmdline(:@mount-option);
}

multi sub build-mount-options-cmdline(Str:D :@mount-option where .so --> Str:D)
{
    my Str:D @mount-options-cmdline = '--options', @mount-option.join(',');
    my Str:D $mount-options-cmdline = @mount-options-cmdline.join(' ');
}

multi sub build-mount-options-cmdline(Str:D :mount-option(@) --> Str:D)
{
    my Str:D @mount-options-cmdline = '';
}

method build-mount-btrfs-cmdline(
    Str:D :@mount-option! where .so,
    Str:D :$vault-device-mapper! where .so,
    Str:D :$mount-dir! where .so
    --> Str:D
)
{
    my Str:D $mount-options-cmdline =
        Voidvault::Utils.build-mount-options-cmdline(:@mount-option);
    my Str:D $mount-subvolume-cmdline = qqw<
        mount
        --types btrfs
        $mount-options-cmdline
        $vault-device-mapper
        $mount-dir
    >.join(' ');
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
        $pass ne '' or do {
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
    ENTER disable-echo();
    LEAVE enable-echo();
    UNDO enable-echo();
    my Str:D $secret = prompt($prompt-text);
}

sub disable-echo()
{
    run(qw<stty -echo>);
}

sub enable-echo()
{
    run(qw<stty echo>);
    say('');
}


# -----------------------------------------------------------------------------
# system
# -----------------------------------------------------------------------------

method groupadd(
    AbsolutePath:D :$chroot-dir! where .so,
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
    AbsolutePath:D :$chroot-dir! where .so,
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
    AbsolutePath:D :$chroot-dir! where .so,
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

method install-resource(
    # unprefixed, relative path to resource for copy
    RelativePath:D $resource where .so,
    AbsolutePath:D :$chroot-dir! where .so
)
{
    my AbsolutePath:D $path = sprintf(Q{%s/%s}, $chroot-dir, $resource);
    my Bool:D $parent-exists = $path.IO.dirname.IO.d.so;
    # only attempt to make parent directory if does not exist
    Voidvault::Utils.mkdir-parent($path) unless $parent-exists;
    copy(%?RESOURCES{$resource}, $path);
}

# make parent directory of C<$path> with (octal) C<$permissions>
method mkdir-parent(
    AbsolutePath:D $path where .so,
    UInt:D $permissions = 0o755
    --> Nil
)
{
    my Str:D $parent = $path.IO.dirname;
    mkdir($parent, $permissions);
}

# chroot into C<$chroot-dir> to then C<dracut>
method void-chroot-dracut(AbsolutePath:D :$chroot-dir! where .so --> Nil)
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
    AbsolutePath:D :$chroot-dir! where .so,
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
method void-chroot-xbps-reconfigure-linux(
    AbsolutePath:D :$chroot-dir! where .so
    --> Nil
)
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
# vault
# -----------------------------------------------------------------------------

# create vault with cryptsetup, then open it if requested
proto method mkvault(
    VaultType:D :$vault-type! where .so,
    Str:D :$partition-vault! where .so,
    VaultName:D :$vault-name! where .so,
    # pass C<:open> to open vault after creating it
    Bool :open($),
    *%opts (
        # prefixed C<VaultHeader> path is C<AbsolutePath>, but
        # C<$vault-header> is optional here, hence C<Str>
        Str :$vault-header,
        VaultPass :vault-pass($)
    )
    --> Nil
)
{
    # load kernel modules for cryptsetup
    run(qw<modprobe dm_mod dm-crypt>);

    # create base directory for vault header if necessary
    Voidvault::Utils.mkdir-parent($vault-header, 0o700) if $vault-header;

    # create vault with password
    mkvault(:$vault-type, :$partition-vault, |%opts);

    # open vault if requested
    {*}
}

# open vault with password
multi method mkvault(
    Bool:D :open($)! where .so,
    VaultType:D :$vault-type! where .so,
    Str:D :$partition-vault! where .so,
    VaultName:D :$vault-name! where .so,
    *%opts (
        Str :vault-header($),
        VaultPass :vault-pass($)
    )
    --> Nil
)
{
    Voidvault::Utils.open-vault(
        :$vault-type,
        :$partition-vault,
        :$vault-name,
        |%opts
    );
}

# opening vault not requested
multi method mkvault(
    VaultType:D :vault-type($)!,
    Str:D :partition-vault($)!,
    VaultName:D :vault-name($)!,
    Bool :open($),
    *%opts (
        Str :vault-header($),
        VaultPass :vault-pass($)
    )
    --> Nil
)
{*}

# LUKS encrypted volume password was given
multi sub mkvault(
    VaultType:D :$vault-type! where .so,
    Str:D :$partition-vault! where .so,
    VaultPass:D :$vault-pass! where .so,
    *%opts (
        Str :vault-header($)
    )
    --> Nil
)
{
    my Str:D $cryptsetup-luks-format-cmdline =
        build-cryptsetup-luks-format-cmdline(
            :non-interactive,
            :$vault-type,
            :$partition-vault,
            :$vault-pass,
            |%opts
        );

    # make LUKS encrypted volume without prompt for vault password
    shell($cryptsetup-luks-format-cmdline);
}

# LUKS encrypted volume password not given
multi sub mkvault(
    VaultType:D :$vault-type! where .so,
    Str:D :$partition-vault! where .so,
    VaultPass :vault-pass($),
    *%opts (
        Str :vault-header($)
    )
    --> Nil
)
{
    my Str:D $cryptsetup-luks-format-cmdline =
        build-cryptsetup-luks-format-cmdline(
            :interactive,
            :$vault-type,
            :$partition-vault,
            |%opts
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
    Str:D :$partition-vault! where .so,
    *%opts (
        Str :vault-header($)
    )
    --> Str:D
)
{
    my Str:D $spawn-cryptsetup-luks-format =
        gen-spawn-cryptsetup-luks-format(
            :$vault-type,
            :$partition-vault,
            |%opts
        );
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
    VaultPass:D :$vault-pass! where .so,
    *%opts (
        Str :vault-header($)
    )
    --> Str:D
)
{
    my Str:D $spawn-cryptsetup-luks-format =
        gen-spawn-cryptsetup-luks-format(
            :$vault-type,
            :$partition-vault,
            |%opts
        );
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
    Str:D :$partition-vault! where .so,
    # LUKS1 variant is never called with optional C<$vault-header>
    *% (
        Str :vault-header($)
    )
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
    Str:D :$partition-vault! where .so,
    AbsolutePath:D :$vault-header! where .so
    --> Str:D
)
{
    my Str:D $spawn-cryptsetup-luks-format = qqw<
        spawn cryptsetup
        --type luks2
        --header $vault-header
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

# effectively dead code until GRUB ships reasonable support for LUKS2
multi sub gen-spawn-cryptsetup-luks-format(
    VaultType:D :vault-type($)! where 'LUKS2',
    Str:D :$partition-vault! where .so,
    Str :vault-header($)
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
        # prefixed C<VaultHeader> path is C<AbsolutePath>
        Str :vault-header($),
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
    VaultPass:D :$vault-pass! where .so,
    *%opts (
        Str :vault-header($)
    )
    --> Nil
)
{
    my Str:D $cryptsetup-luks-open-cmdline =
        build-cryptsetup-luks-open-cmdline(
            :non-interactive,
            :$vault-type,
            :$partition-vault,
            :$vault-name,
            :$vault-pass,
            |%opts
        );

    # open vault without prompt for vault password
    shell($cryptsetup-luks-open-cmdline);
}

# LUKS encrypted volume password not given
multi sub open-vault(
    VaultType:D :$vault-type! where .so,
    Str:D :$partition-vault! where .so,
    VaultName:D :$vault-name! where .so,
    VaultPass :vault-pass($),
    *%opts (
        Str :vault-header($)
    )
    --> Nil
)
{
    my Str:D $cryptsetup-luks-open-cmdline =
        build-cryptsetup-luks-open-cmdline(
            :interactive,
            :$vault-type,
            :$partition-vault,
            :$vault-name,
            |%opts
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
    VaultName:D :$vault-name! where .so,
    *%opts (
        Str :vault-header($)
    )
    --> Str:D
)
{
    my Str:D $cryptsetup-luks-open-cmdline =
        gen-cryptsetup-luks-open(
            :$vault-type,
            :$partition-vault,
            :$vault-name,
            |%opts
        );
}

multi sub build-cryptsetup-luks-open-cmdline(
    Bool:D :non-interactive($)! where .so,
    VaultType:D :$vault-type! where .so,
    Str:D :$partition-vault! where .so,
    VaultName:D :$vault-name! where .so,
    VaultPass:D :$vault-pass! where .so,
    *%opts (
        Str :vault-header($)
    )
    --> Str:D
)
{
    my Str:D $cryptsetup-luks-open =
        gen-cryptsetup-luks-open(
            :$vault-type,
            :$partition-vault,
            :$vault-name,
            |%opts
        );
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
    VaultName:D :$vault-name! where .so,
    # LUKS1 variant is never called with optional C<$vault-header>
    Str :vault-header($)
    --> Str:D
)
{
    my Str:D $cryptsetup-luks-open-cmdline =
        "cryptsetup luksOpen $partition-vault $vault-name";
}

multi sub gen-cryptsetup-luks-open(
    VaultType:D :vault-type($)! where 'LUKS2',
    Str:D :$partition-vault! where .so,
    VaultName:D :$vault-name! where .so,
    AbsolutePath:D :$vault-header! where .so
    --> Str:D
)
{
    my Str:D $opts = qqw<
        --header $vault-header
        --perf-no_read_workqueue
        --persistent
    >.join(' ');
    my Str:D $cryptsetup-luks-open-cmdline =
        "cryptsetup $opts luksOpen $partition-vault $vault-name";
}

# effectively dead code until GRUB ships reasonable support for LUKS2
multi sub gen-cryptsetup-luks-open(
    VaultType:D :vault-type($)! where 'LUKS2',
    Str:D :$partition-vault! where .so,
    VaultName:D :$vault-name! where .so,
    Str :vault-header($)
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
    AbsolutePath:D :$chroot-dir! where .so,
    *%opts (
        VaultPass :vault-pass($)
    )
    --> Nil
)
{
    my AbsolutePath:D $vault-key =
        sprintf(Q{%s%s}, $chroot-dir, $vault-key-unprefixed);
    Voidvault::Utils.mkdir-parent($vault-key, 0o700);
    mkkey(:$vault-key);
    addkey(:$vault-key, :$partition-vault, |%opts);
    run(qqw<void-chroot $chroot-dir chmod 000 $vault-key-unprefixed>);
}

# make vault key
sub mkkey(
    # requires passing prefixed C<VaultKey> path, hence C<AbsolutePath>
    AbsolutePath:D :$vault-key! where .so
    --> Nil
)
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
    # requires passing prefixed C<VaultKey> path, hence C<AbsolutePath>
    AbsolutePath:D :$vault-key! where .so,
    Str:D :$partition-vault! where .so,
    VaultPass:D :$vault-pass! where .so,
    *%opts (
        Str :vault-header($)
    )
    --> Nil
)
{
    my Str:D $cryptsetup-luks-add-key-cmdline =
        build-cryptsetup-luks-add-key-cmdline(
            :non-interactive,
            :$vault-key,
            :$partition-vault,
            :$vault-pass,
            |%opts
        );

    # add key to LUKS encrypted volume without prompt for vault password
    shell($cryptsetup-luks-add-key-cmdline);
}

# LUKS encrypted volume password not given
multi sub addkey(
    AbsolutePath:D :$vault-key! where .so,
    Str:D :$partition-vault! where .so,
    VaultPass :vault-pass($),
    *%opts (
        Str :vault-header($)
    )
    --> Nil
)
{
    my Str:D $cryptsetup-luks-add-key-cmdline =
        build-cryptsetup-luks-add-key-cmdline(
            :interactive,
            :$vault-key,
            :$partition-vault,
            |%opts
        );

    # add key to LUKS encrypted volume, prompt user for vault password
    Voidvault::Utils.loop-cmdline-proc(
        'Adding LUKS key...',
        $cryptsetup-luks-add-key-cmdline
    );
}

multi sub build-cryptsetup-luks-add-key-cmdline(
    Bool:D :interactive($)! where .so,
    # requires passing prefixed C<VaultKey> path, hence C<AbsolutePath>
    AbsolutePath:D :$vault-key! where .so,
    Str:D :$partition-vault! where .so,
    *%opts (
        Str :vault-header($)
    )
    --> Str:D
)
{
    my Str:D $spawn-cryptsetup-luks-add-key =
        gen-spawn-cryptsetup-luks-add-key(
            :$vault-key,
            :$partition-vault,
            |%opts
        );
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
    AbsolutePath:D :$vault-key! where .so,
    Str:D :$partition-vault! where .so,
    VaultPass:D :$vault-pass! where .so,
    *%opts (
        Str :vault-header($)
    )
    --> Str:D
)
{
    my Str:D $spawn-cryptsetup-luks-add-key =
        gen-spawn-cryptsetup-luks-add-key(
            :$vault-key,
            :$partition-vault,
            |%opts
        );
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

sub gen-spawn-cryptsetup-luks-add-key(
    AbsolutePath:D :$vault-key! where .so,
    Str:D :$partition-vault! where .so,
    *%opts (
        Str :vault-header($)
    )
    --> Str:D
)
{
    my Str:D $opts = build-cryptsetup-luks-add-key-options-cmdline(|%opts);
    my Str:D $spawn-cryptsetup-luks-add-key =
        "spawn cryptsetup $opts luksAddKey $partition-vault $vault-key";
}

multi sub build-cryptsetup-luks-add-key-options-cmdline(
    AbsolutePath:D :$vault-header! where .so
    --> Str:D
)
{
    my Str:D $opts = qqw<--header $vault-header --iter-time 1 >.join(' ');
}

multi sub build-cryptsetup-luks-add-key-options-cmdline(
    Str :vault-header($)
    --> Str:D
)
{
    my Str:D $opts = '--iter-time 1';
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
