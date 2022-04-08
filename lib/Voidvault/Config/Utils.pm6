use v6;
use Crypt::Libcrypt:auth<atweiden>;
use Voidvault::Constants;
use Voidvault::Types;
unit module Voidvault::Config::Utils;


# -----------------------------------------------------------------------------
# password hashes
# -----------------------------------------------------------------------------

# generate pbkdf2 password hash from plaintext password
multi sub gen-pass-hash(
    Str:D $grub-pass,
    Bool:D :grub($)! where .so
    --> Str:D
) is export
{
    my &gen-pass-hash = gen-pass-hash-closure(:grub);
    my Str:D $grub-pass-hash = &gen-pass-hash($grub-pass);
}

# generate sha512 salted password hash from plaintext password
multi sub gen-pass-hash(
    Str:D $user-pass,
    Bool :grub($)
    --> Str:D
) is export
{
    my &gen-pass-hash = gen-pass-hash-closure();
    my Str:D $user-pass-hash = &gen-pass-hash($user-pass);
}

# generate pbkdf2 password hash from interactive user input
multi sub prompt-pass-hash(
    Str $user-name?,
    Bool:D :grub($)! where .so,
    Str:D :@repository,
    Bool :$ignore-conf-repos
    --> Str:D
) is export
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
) is export
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
# string formatting, resolution and validation
# -----------------------------------------------------------------------------

# confirm path $p is valid AbsolutePath and return AbsolutePath
sub gen-absolute-path(Str:D $p --> AbsolutePath:D) is export
{
    my AbsolutePath:D $path =
        $p or die("Sorry, invalid absolute path 「$p」");
}

# confirm disk type $d is valid DiskType and return DiskType
sub gen-disk-type(Str:D $d --> DiskType:D) is export
{
    my DiskType:D $disk-type = $d.uc or die('Sorry, invalid disk type');
}

# confirm graphics card type $g is valid Graphics and return Graphics
sub gen-graphics(Str:D $g --> Graphics:D) is export
{
    my Graphics:D $graphics = $g.uc or die('Sorry, invalid graphics card type');
}

# confirm hostname $h is valid HostName and return HostName
sub gen-host-name(Str:D $h --> HostName:D) is export
{
    my HostName:D $host-name = $h or die("Sorry, invalid hostname 「$h」");
}

# confirm keymap $k is valid Keymap and return Keymap
sub gen-keymap(Str:D $k --> Keymap:D) is export
{
    my Keymap:D $keymap = $k or die("Sorry, invalid keymap 「$k」");
}

# confirm locale $l is valid Locale and return Locale
sub gen-locale(Str:D $l --> Locale:D) is export
{
    my Locale:D $locale = $l or die("Sorry, invalid locale 「$l」");
}

# confirm processor $p is valid Processor and return Processor
sub gen-processor(Str:D $p --> Processor:D) is export
{
    my Processor:D $processor = $p.uc or die("Sorry, invalid processor 「$p」");
}

# confirm timezone $t is valid Timezone and return Timezone
sub gen-timezone(Str:D $t --> Timezone:D) is export
{
    my Timezone:D $timezone = $t or die("Sorry, invalid timezone 「$t」");
}

# confirm user name $u is valid UserName and return UserName
sub gen-user-name(Str:D $u --> UserName:D) is export
{
    my UserName:D $user-name = $u or die("Sorry, invalid username 「$u」");
}

# confirm vault header $h is valid VaultHeader and return VaultHeader
sub gen-vault-header(Str:D $h --> VaultHeader:D) is export
{
    my Str:D $prefix = $Voidvault::Constants::SECRET-PREFIX-VAULT;
    my Str:D $message = qq:to/EOF/.trim;
    Sorry, Vault Header must be absolute path inside $prefix. Path given: $h
    EOF
    my VaultHeader:D $vault-header = $h or die($message);
}

# confirm vault key $k is valid VaultKey and return VaultKey
sub gen-vault-key(Str:D $k --> VaultKey:D) is export
{
    my Str:D $prefix = $Voidvault::Constants::SECRET-PREFIX-VAULT;
    my Str:D $message = qq:to/EOF/.trim;
    Sorry, Vault Key must be absolute path inside $prefix. Path given: $k
    EOF
    my VaultKey:D $vault-key = $k or die($message);
}

# confirm boot vault key $k is valid BootvaultKey and return BootvaultKey
sub gen-bootvault-key(Str:D $k --> BootvaultKey:D) is export
{
    my Str:D $prefix = $Voidvault::Constants::SECRET-PREFIX-BOOTVAULT;
    my Str:D $message = qq:to/EOF/.trim;
    Sorry, Bootvault Key must be absolute path inside $prefix. Path given: $k
    EOF
    my BootvaultKey:D $bootvault-key = $k or die($message);
}

# confirm vault name $n is valid VaultName and return VaultName
sub gen-vault-name(Str:D $n --> VaultName:D) is export
{
    my VaultName:D $vault-name = $n or die("Sorry, invalid Vault Name 「$n」");
}

# confirm vault pass $p is valid VaultPass and return VaultPass
sub gen-vault-pass(Str:D $p --> VaultPass:D) is export
{
    my Str:D $message = qq:to/EOF/.trim;
    Sorry, invalid Vault Pass. Length needed: 1-512. Length given: {$p.chars}
    EOF
    my VaultPass:D $vault-pass = $p or die($message);
}


# -----------------------------------------------------------------------------
# user input prompts
# -----------------------------------------------------------------------------

# dialog menu user input prompt with tags (keys) only
multi sub dprompt(
    # type of response expected
    ::T,
    # menu (T $tag)
    @menu,
    # default response
    T :$default-item! where .defined,
    # menu title
    Str:D :$title!,
    # question posed to user
    Str:D :$prompt-text!,
    UInt:D :$height = 80,
    UInt:D :$width = 80,
    UInt:D :$menu-height = 24,
    # context string for confirm text
    Str:D :$confirm-topic!
    --> Any:D
) is export
{
    my T $response;

    loop
    {
        # prompt for selection
        $response = qqx<
            dialog \\
                --stdout \\
                --no-items \\
                --scrollbar \\
                --no-cancel \\
                --default-item $default-item \\
                --title '$title' \\
                --menu '$prompt-text' $height $width $menu-height @menu[]
        >;

        # confirm selection
        my Bool:D $confirmed = shell("
            dialog \\
                --stdout \\
                --defaultno \\
                --title 'ARE YOU SURE?' \\
                --yesno 'Use $confirm-topic «$response»?' 8 35
        ").exitcode == 0;

        last if $confirmed;
    }

    $response;
}

# dialog menu user input prompt with tags (keys) and items (values)
multi sub dprompt(
    # type of response expected
    ::T,
    # menu (T $tag => Str $item)
    %menu,
    # default response
    T :$default-item! where .defined,
    # menu title
    Str:D :$title!,
    # question posed to user
    Str:D :$prompt-text!,
    UInt:D :$height = 80,
    UInt:D :$width = 80,
    UInt:D :$menu-height = 24,
    # context string for confirm text
    Str:D :$confirm-topic!
    --> Any:D
) is export
{
    my T $response;

    loop
    {
        # prompt for selection
        $response = qqx<
            dialog \\
                --stdout \\
                --scrollbar \\
                --no-cancel \\
                --default-item $default-item \\
                --title '$title' \\
                --menu '$prompt-text' $height $width $menu-height {%menu.sort}
        >;

        # confirm selection
        my Bool:D $confirmed = shell("
            dialog \\
                --stdout \\
                --defaultno \\
                --title 'ARE YOU SURE?' \\
                --yesno 'Use $confirm-topic «$response»?' 8 35
        ").exitcode == 0;

        last if $confirmed;
    }

    $response;
}

# user input prompt (text)
sub tprompt(
    # type of response expected
    ::T,
    # default response
    T $response-default where .defined,
    # question posed to user
    Str:D :$prompt-text!,
    # optional help text to display before prompt
    Str :$help-text
    --> Any:D
) is export
{
    my $response;

    loop
    {
        # display help text (optional)
        say($help-text) if $help-text;

        # prompt for response
        $response = prompt($prompt-text);

        # if empty carriage return entered, use default response value
        unless $response
        {
            $response = $response-default;
        }

        # retry if response is invalid
        unless $response ~~ T
        {
            say('Sorry, invalid response. Please try again.');
            next;
        }

        # prompt for confirmation
        my Str:D $confirmation =
            prompt("Confirm «{$response.split(/\s+/).join(', ')}» [y/N]: ");

        # check for affirmative confirmation
        last if is-confirmed($confirmation);
    }

    $response;
}

# was response affirmative?
multi sub is-confirmed(Str:D $confirmation where /:i y[e[s]?]?/ --> Bool:D)
{
    my Bool:D $is-confirmed = True;
}

# was response negatory?
multi sub is-confirmed(Str:D $confirmation where /:i n[o]?/ --> Bool:D)
{
    my Bool:D $is-confirmed = False;
}

# was response empty?
multi sub is-confirmed(Str:D $confirmation where .chars == 0 --> Bool:D)
{
    my Bool:D $is-confirmed = False;
}

# were unrecognized characters entered?
multi sub is-confirmed($confirmation --> Bool:D)
{
    my Bool:D $is-confirmed = False;
}

sub prompt-device(Str:D @device --> Str:D) is export
{
    my Str:D $device = do {
        my Str:D $default-item = @device[0];
        my Str:D $prompt-text = 'Select target device for installing Void:';
        my Str:D $title = 'TARGET DEVICE SELECTION';
        my Str:D $confirm-topic = 'target device selected';
        dprompt(
            Str,
            @device,
            :$default-item,
            :$prompt-text,
            :$title,
            :$confirm-topic
        );
    }
}

sub prompt-disk-type(--> DiskType:D) is export
{
    my DiskType:D $disk-type = do {
        my DiskType:D $default-item = 'SSD';
        my Str:D $prompt-text = 'Select disk type:';
        my Str:D $title = 'DISK TYPE SELECTION';
        my Str:D $confirm-topic = 'disk type selected';
        dprompt(
            DiskType,
            %Voidvault::Types::disktypes,
            :$default-item,
            :$prompt-text,
            :$title,
            :$confirm-topic
        );
    }
}

sub prompt-graphics(--> Graphics:D) is export
{
    my Graphics:D $graphics = do {
        my Graphics:D $default-item = 'INTEL';
        my Str:D $prompt-text = 'Select graphics card type:';
        my Str:D $title = 'GRAPHICS CARD TYPE SELECTION';
        my Str:D $confirm-topic = 'graphics card type selected';
        dprompt(
            Graphics,
            %Voidvault::Types::graphics,
            :$default-item,
            :$prompt-text,
            :$title,
            :$confirm-topic
        );
    }
}

sub prompt-keymap(--> Keymap:D) is export
{
    my Keymap:D $keymap = do {
        my Keymap:D $default-item = 'us';
        my Str:D $prompt-text = 'Select keymap:';
        my Str:D $title = 'KEYMAP SELECTION';
        my Str:D $confirm-topic = 'keymap selected';
        dprompt(
            Keymap,
            %Voidvault::Types::keymaps,
            :$default-item,
            :$prompt-text,
            :$title,
            :$confirm-topic
        );
    }
}

sub prompt-locale(--> Locale:D) is export
{
    my Locale:D $locale = do {
        my Locale:D $default-item = 'en_US';
        my Str:D $prompt-text = 'Select locale:';
        my Str:D $title = 'LOCALE SELECTION';
        my Str:D $confirm-topic = 'locale selected';
        dprompt(
            Locale,
            %Voidvault::Types::locales,
            :$default-item,
            :$prompt-text,
            :$title,
            :$confirm-topic
        );
    }
}

multi sub prompt-name(
    Bool:D :host($)! where .so
    --> HostName:D
) is export
{
    my HostName:D $host-name = do {
        my HostName:D $response-default = 'vault';
        my Str:D $prompt-text = "Enter hostname [$response-default]: ";
        my Str:D $help-text = q:to/EOF/.trim;
        Determining hostname...

        Leave blank if you don't know what this is
        EOF
        tprompt(
            HostName,
            $response-default,
            :$prompt-text,
            :$help-text
        );
    }
}

multi sub prompt-name(
    Bool:D :user($)! where .so,
    Bool:D :admin($)! where .so
    --> UserName:D
) is export
{
    my UserName:D $user-name = do {
        my UserName:D $response-default = 'live';
        my Str:D $prompt-text = "Enter username [$response-default]: ";
        my Str:D $help-text = q:to/EOF/.trim;
        Determining name for admin user...

        Leave blank if you don't know what this is
        EOF
        tprompt(
            UserName,
            $response-default,
            :$prompt-text,
            :$help-text
        );
    }
}

multi sub prompt-name(
    Bool:D :user($)! where .so,
    Bool:D :grub($)! where .so
    --> UserName:D
) is export
{
    my UserName:D $user-name = do {
        my UserName:D $response-default = 'grub';
        my Str:D $prompt-text = "Enter username [$response-default]: ";
        my Str:D $help-text = q:to/EOF/.trim;
        Determining name for GRUB user...

        Leave blank if you don't know what this is
        EOF
        tprompt(
            UserName,
            $response-default,
            :$prompt-text,
            :$help-text
        );
    }
}

multi sub prompt-name(
    Bool:D :user($)! where .so,
    Bool:D :guest($)! where .so
    --> UserName:D
) is export
{
    my UserName:D $user-name = do {
        my UserName:D $response-default = 'guest';
        my Str:D $prompt-text = "Enter username [$response-default]: ";
        my Str:D $help-text = q:to/EOF/.trim;
        Determining name for guest user...

        Leave blank if you don't know what this is
        EOF
        tprompt(
            UserName,
            $response-default,
            :$prompt-text,
            :$help-text
        );
    }
}

multi sub prompt-name(
    Bool:D :user($)! where .so,
    Bool:D :sftp($)! where .so
    --> UserName:D
) is export
{
    my UserName:D $user-name = do {
        my UserName:D $response-default = 'variable';
        my Str:D $prompt-text = "Enter username [$response-default]: ";
        my Str:D $help-text = q:to/EOF/.trim;
        Determining name for SFTP user...

        Leave blank if you don't know what this is
        EOF
        tprompt(
            UserName,
            $response-default,
            :$prompt-text,
            :$help-text
        );
    }
}

multi sub prompt-name(
    Bool:D :vault($)! where .so
    --> VaultName:D
) is export
{
    my VaultName:D $vault-name = do {
        my VaultName:D $response-default = 'vault';
        my Str:D $prompt-text = "Enter vault name [$response-default]: ";
        my Str:D $help-text = q:to/EOF/.trim;
        Determining name of LUKS encrypted volume...

        Leave blank if you don't know what this is
        EOF
        tprompt(
            VaultName,
            $response-default,
            :$prompt-text,
            :$help-text
        );
    }
}

multi sub prompt-name(
    Bool:D :bootvault($)! where .so
    --> VaultName:D
) is export
{
    my VaultName:D $vault-name = do {
        my VaultName:D $response-default = 'bootvault';
        my Str:D $prompt-text = "Enter bootvault name [$response-default]: ";
        my Str:D $help-text = q:to/EOF/.trim;
        Determining name of LUKS encrypted boot volume...

        Leave blank if you don't know what this is
        EOF
        tprompt(
            VaultName,
            $response-default,
            :$prompt-text,
            :$help-text
        );
    }
}

sub prompt-processor(--> Processor:D) is export
{
    my Processor:D $processor = do {
        my Processor:D $default-item = 'OTHER';
        my Str:D $prompt-text = 'Select processor:';
        my Str:D $title = 'PROCESSOR SELECTION';
        my Str:D $confirm-topic = 'processor selected';
        dprompt(
            Processor,
            %Voidvault::Types::processors,
            :$default-item,
            :$prompt-text,
            :$title,
            :$confirm-topic
        );
    }
}

sub prompt-timezone(--> Timezone:D) is export
{
    # get list of timezones
    my Timezone:D @timezones = @Voidvault::Types::timezones;

    # prompt choose region
    my Str:D $region = do {
        # get list of timezone regions
        my Str:D @regions =
            @timezones.map({ .subst(/'/'\N*$/, '') }).unique;
        my Str:D $default-item = 'America';
        my Str:D $prompt-text = 'Select region:';
        my Str:D $title = 'TIMEZONE REGION SELECTION';
        my Str:D $confirm-topic = 'timezone region selected';
        dprompt(
            Str,
            @regions,
            :$default-item,
            :$prompt-text,
            :$title,
            :$confirm-topic
        );
    }

    # prompt choose subregion
    my Str:D $subregion = do {
        # get list of timezone region subregions
        my Str:D @subregions =
            @timezones
            .grep(/$region/)
            .map({ .subst(/^$region'/'/, '') })
            .sort;
        my Str:D $default-item = 'Los_Angeles';
        my Str:D $prompt-text = 'Select subregion:';
        my Str:D $title = 'TIMEZONE SUBREGION SELECTION';
        my Str:D $confirm-topic = 'timezone subregion selected';
        dprompt(
            Str,
            @subregions,
            :$default-item,
            :$prompt-text,
            :$title,
            :$confirm-topic
        );
    }

    my Timezone:D $timezone = @timezones.grep("$region/$subregion").first;
}


# -----------------------------------------------------------------------------
# helper functions
# -----------------------------------------------------------------------------

sub chomp-secret-prefix(
    VaultSecretPrefix:D $prefixed where .so,
    Bool:D :vault($)! where .so
    --> AbsolutePath:D
) is export
{
    my AbsolutePath:D $chomp-secret-prefix =
        $prefixed.subst($Voidvault::Constants::SECRET-PREFIX-VAULT, '');
}

# ensure C<$chroot-dir> is existing readable writeable dir, or create it
multi sub ensure-chroot-dir(
    AbsolutePath:D $chroot-dir where .so && .IO.e.so
    --> Nil
) is export
{
    my Bool:D $is-readable = $chroot-dir.IO.r.so;
    my Bool:D $is-directory = $chroot-dir.IO.d.so;
    my Bool:D $is-writeable = $chroot-dir.IO.w.so;
    [&&] $is-readable, $is-directory, $is-writeable
        or die-chroot-dir(
            $chroot-dir,
            :$is-readable,
            :$is-directory,
            :$is-writeable
        );
}

# C<$chroot-dir> does not exist, create it
multi sub ensure-chroot-dir(
    AbsolutePath:D $chroot-dir where .so
    --> Nil
) is export
{
    mkdir($chroot-dir);
}

proto sub die-chroot-dir(
    AbsolutePath:D $chroot-dir where .so,
    Bool:D :is-readable($)!,
    Bool:D :is-directory($)!,
    Bool:D :is-writeable($)!
    --> Nil
)
{
    my Str:D $*message =
        "Sorry, requested chroot to directory $chroot-dir, but ";
    {*}
    die($*message);
}

multi sub die-chroot-dir(
    AbsolutePath:D $chroot-dir where .so,
    Bool:D :is-readable($)! where .not,
    Bool:D :is-directory($)!,
    Bool:D :is-writeable($)!
    --> Nil
)
{
    $*message ~= 'path is not readable';
}

multi sub die-chroot-dir(
    AbsolutePath:D $chroot-dir where .so,
    Bool:D :is-readable($)! where .so,
    Bool:D :is-directory($)! where .not,
    Bool:D :is-writeable($)!
    --> Nil
)
{
    $*message ~= 'this would overwrite existing non-directory';
}

multi sub die-chroot-dir(
    AbsolutePath:D $chroot-dir where .so,
    Bool:D :is-readable($)! where .so,
    Bool:D :is-directory($)! where .so,
    Bool:D :is-writeable($)! where .not
    --> Nil
)
{
    $*message ~= 'directory is not writeable';
}

sub ensure-unique-user-names(
    UserName:D :$user-name-admin! where .so,
    UserName:D :$user-name-guest! where .so,
    UserName:D :$user-name-sftp! where .so
    --> Nil
) is export
{
    # map shortnames to user names for convenience
    my UserName:D %*user-name{Str:D} =
        :admin($user-name-admin),
        :guest($user-name-guest),
        :sftp($user-name-sftp);

    my Bool:D %matchup{Pair:D} =
        Pair.new('admin', 'guest') =>
            $user-name-admin eq $user-name-guest,
        Pair.new('admin', 'sftp') =>
            $user-name-admin eq $user-name-sftp,
        Pair.new('guest', 'sftp') =>
            $user-name-guest eq $user-name-sftp;

    my Pair:D @duplicate =
        %matchup.kv.map(-> Pair:D $k, Bool:D $v { $k if $v.so });

    if @duplicate
    {
        my Str:D $message = @duplicate.reduce(&gen-message);
        die("Sorry, user names provided were not unique:\n\n$message");
    }
}

multi sub gen-message(Pair:D $a, Pair:D $b --> Str:D)
{
    (gen-message($a), gen-message($b)).join("\n")
}

multi sub gen-message(Str:D $acc, Pair:D $pair --> Str:D)
{
    ($acc, gen-message($pair)).join("\n")
}

multi sub gen-message(Pair:D $pair --> Str:D)
{
    my Str:D $duplicatee = $pair.key;
    my Str:D $duplicator = $pair.value;
    my Str:D $duplicated-user-name = %*user-name{$duplicator};
    qqw<$duplicator user name '$duplicated-user-name' is dupe of
        $duplicatee user name>.join(' ');
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
