use v6;
use Void::XBPS;
use Voidvault::Types;
use Voidvault::Utils;
unit class Voidvault::Config;


# -----------------------------------------------------------------------------
# settings
# -----------------------------------------------------------------------------

# - attributes appear in specific order for prompting user
# - defaults are geared towards live media installation

# location of void package repository (prioritized)
has Str $.repository =
    ?%*ENV<VOIDVAULT_REPOSITORY>
        ?? %*ENV<VOIDVAULT_REPOSITORY>
        !! Nil;

# only honor repository specified in C<$.repository>
has Bool:D $.ignore-conf-repos =
    ?%*ENV<VOIDVAULT_IGNORE_CONF_REPOS>;

# name for admin user (default: live)
has UserName:D $.user-name-admin =
    %*ENV<VOIDVAULT_ADMIN_NAME>
        ?? Voidvault::Config.gen-user-name(%*ENV<VOIDVAULT_ADMIN_NAME>)
        !! prompt-name(:user, :admin);

# sha512 password hash for admin user
has Str:D $.user-pass-hash-admin =
    %*ENV<VOIDVAULT_ADMIN_PASS_HASH>
        ?? %*ENV<VOIDVAULT_ADMIN_PASS_HASH>
        !! %*ENV<VOIDVAULT_ADMIN_PASS>
            ?? Voidvault::Utils.gen-pass-hash(%*ENV<VOIDVAULT_ADMIN_PASS>)
            !! Voidvault::Utils.prompt-pass-hash($!user-name-admin);

# name for guest user (default: guest)
has UserName:D $.user-name-guest =
    %*ENV<VOIDVAULT_GUEST_NAME>
        ?? Voidvault::Config.gen-user-name(%*ENV<VOIDVAULT_GUEST_NAME>)
        !! prompt-name(:user, :guest);

# sha512 password hash for guest user
has Str:D $.user-pass-hash-guest =
    %*ENV<VOIDVAULT_GUEST_PASS_HASH>
        ?? %*ENV<VOIDVAULT_GUEST_PASS_HASH>
        !! %*ENV<VOIDVAULT_GUEST_PASS>
            ?? Voidvault::Utils.gen-pass-hash(%*ENV<VOIDVAULT_GUEST_PASS>)
            !! Voidvault::Utils.prompt-pass-hash($!user-name-guest);

# name for sftp user (default: variable)
has UserName:D $.user-name-sftp =
    %*ENV<VOIDVAULT_SFTP_NAME>
        ?? Voidvault::Config.gen-user-name(%*ENV<VOIDVAULT_SFTP_NAME>)
        !! prompt-name(:user, :sftp);

# sha512 password hash for sftp user
has Str:D $.user-pass-hash-sftp =
    %*ENV<VOIDVAULT_SFTP_PASS_HASH>
        ?? %*ENV<VOIDVAULT_SFTP_PASS_HASH>
        !! %*ENV<VOIDVAULT_SFTP_PASS>
            ?? Voidvault::Utils.gen-pass-hash(%*ENV<VOIDVAULT_SFTP_PASS>)
            !! Voidvault::Utils.prompt-pass-hash($!user-name-sftp);

# sha512 password hash for root user
has Str:D $.user-pass-hash-root =
    %*ENV<VOIDVAULT_ROOT_PASS_HASH>
        ?? %*ENV<VOIDVAULT_ROOT_PASS_HASH>
        !! %*ENV<VOIDVAULT_ROOT_PASS>
            ?? Voidvault::Utils.gen-pass-hash(%*ENV<VOIDVAULT_ROOT_PASS>)
            !! Voidvault::Utils.prompt-pass-hash('root');

# name for grub user (default: grub)
has UserName:D $.user-name-grub =
    %*ENV<VOIDVAULT_GRUB_NAME>
        ?? Voidvault::Config.gen-user-name(%*ENV<VOIDVAULT_GRUB_NAME>)
        !! prompt-name(:user, :grub);

# pbkdf2 password hash for grub user
has Str:D $.user-pass-hash-grub =
    %*ENV<VOIDVAULT_GRUB_PASS_HASH>
        ?? %*ENV<VOIDVAULT_GRUB_PASS_HASH>
        !! %*ENV<VOIDVAULT_GRUB_PASS>
            ?? Voidvault::Utils.gen-pass-hash(%*ENV<VOIDVAULT_GRUB_PASS>, :grub)
            !! Voidvault::Utils.prompt-pass-hash(
                   $!user-name-grub,
                   :grub,
                   :$!repository,
                   :$!ignore-conf-repos
               );

# name for LUKS encrypted volume (default: vault)
has VaultName:D $.vault-name =
    %*ENV<VOIDVAULT_VAULT_NAME>
        ?? Voidvault::Config.gen-vault-name(%*ENV<VOIDVAULT_VAULT_NAME>)
        !! prompt-name(:vault);

# password for LUKS encrypted volume
has VaultPass $.vault-pass =
    %*ENV<VOIDVAULT_VAULT_PASS>
        ?? Voidvault::Config.gen-vault-pass(%*ENV<VOIDVAULT_VAULT_PASS>)
        !! Nil;

# name for LVM volume group (default: vg0)
has PoolName:D $.pool-name =
    %*ENV<VOIDVAULT_POOL_NAME>
        ?? Voidvault::Config.gen-pool-name(%*ENV<VOIDVAULT_POOL_NAME>)
        !! prompt-name(:pool);

# name for host (default: vault)
has HostName:D $.host-name =
    %*ENV<VOIDVAULT_HOSTNAME>
        ?? Voidvault::Config.gen-host-name(%*ENV<VOIDVAULT_HOSTNAME>)
        !! prompt-name(:host);

# device path of target partition (default: /dev/sdb)
has Str:D $.partition =
    %*ENV<VOIDVAULT_PARTITION>
        || prompt-partition(Voidvault::Utils.ls-partitions);

# type of processor (default: other)
has Processor:D $.processor =
    %*ENV<VOIDVAULT_PROCESSOR>
        ?? Voidvault::Config.gen-processor(%*ENV<VOIDVAULT_PROCESSOR>)
        !! prompt-processor();

# type of graphics card (default: intel)
has Graphics:D $.graphics =
    %*ENV<VOIDVAULT_GRAPHICS>
        ?? Voidvault::Config.gen-graphics(%*ENV<VOIDVAULT_GRAPHICS>)
        !! prompt-graphics();

# type of hard drive (default: usb)
has DiskType:D $.disk-type =
    %*ENV<VOIDVAULT_DISK_TYPE>
        ?? Voidvault::Config.gen-disk-type(%*ENV<VOIDVAULT_DISK_TYPE>)
        !! prompt-disk-type();

# locale (default: en_US)
has Locale:D $.locale =
    %*ENV<VOIDVAULT_LOCALE>
        ?? Voidvault::Config.gen-locale(%*ENV<VOIDVAULT_LOCALE>)
        !! prompt-locale();

# keymap (default: us)
has Keymap:D $.keymap =
    %*ENV<VOIDVAULT_KEYMAP>
        ?? Voidvault::Config.gen-keymap(%*ENV<VOIDVAULT_KEYMAP>)
        !! prompt-keymap();

# timezone (default: America/Los_Angeles)
has Timezone:D $.timezone =
    %*ENV<VOIDVAULT_TIMEZONE>
        ?? Voidvault::Config.gen-timezone(%*ENV<VOIDVAULT_TIMEZONE>)
        !! prompt-timezone();

# augment
has Bool:D $.augment =
    ?%*ENV<VOIDVAULT_AUGMENT>;

# disable ipv6
has Bool:D $.disable-ipv6 =
    ?%*ENV<VOIDVAULT_DISABLE_IPV6>;


# -----------------------------------------------------------------------------
# class instantation
# -----------------------------------------------------------------------------

submethod TWEAK(--> Nil)
{
    # map shortnames to user names for convenience
    my UserName:D %user-name{Str:D} =
        :admin($!user-name-admin),
        :guest($!user-name-guest),
        :sftp($!user-name-sftp);

    # ensure user names are unique
    my Bool:D %matchup{Pair:D} =
        Pair.new('admin', 'guest') =>
            $!user-name-admin eq $!user-name-guest,
        Pair.new('admin', 'sftp') =>
            $!user-name-admin eq $!user-name-sftp,
        Pair.new('guest', 'sftp') =>
            $!user-name-guest eq $!user-name-sftp;

    my Str $message =
        %matchup
            .kv
            .map(-> Pair:D $k, Bool:D $v {
                sprintf("%s user name '%s' is dupe of %s user name",
                        $k.key,
                        %user-name{$k.key},
                        $k.value) if $v.so })
            .join("\n");

    die("Sorry, user names provided were not unique:\n\n$message")
        if $message.so;
}

submethod BUILD(
    Str :$admin-name,
    Str :$admin-pass,
    Str :$admin-pass-hash,
    Bool :$augment,
    Bool :$disable-ipv6,
    Str :$disk-type,
    Str :$graphics,
    Str :$grub-name,
    Str :$grub-pass,
    Str :$grub-pass-hash,
    Str :$guest-name,
    Str :$guest-pass,
    Str :$guest-pass-hash,
    Str :$hostname,
    Bool :$ignore-conf-repos,
    Str :$keymap,
    Str :$locale,
    Str :$partition,
    Str :$pool-name,
    Str :$processor,
    Str :$repository,
    Str :$root-pass,
    Str :$root-pass-hash,
    Str :$sftp-name,
    Str :$sftp-pass,
    Str :$sftp-pass-hash,
    Str :$timezone,
    Str :$vault-name,
    Str :$vault-pass
    --> Nil
)
{
    $!augment = $augment
        if $augment;
    $!disable-ipv6 = $disable-ipv6
        if $disable-ipv6;
    $!disk-type = Voidvault::Config.gen-disk-type($disk-type)
        if $disk-type;
    $!graphics = Voidvault::Config.gen-graphics($graphics)
        if $graphics;
    $!host-name = Voidvault::Config.gen-host-name($hostname)
        if $hostname;
    $!ignore-conf-repos = $ignore-conf-repos
        if $ignore-conf-repos;
    $!keymap = Voidvault::Config.gen-keymap($keymap)
        if $keymap;
    $!locale = Voidvault::Config.gen-locale($locale)
        if $locale;
    $!partition = $partition
        if $partition;
    $!pool-name = Voidvault::Config.gen-pool-name($pool-name)
        if $pool-name;
    $!processor = Voidvault::Config.gen-processor($processor)
        if $processor;
    $!repository = $repository
        if $repository;
    $!timezone = Voidvault::Config.gen-timezone($timezone)
        if $timezone;
    $!user-name-admin = Voidvault::Config.gen-user-name($admin-name)
        if $admin-name;
    $!user-name-grub = Voidvault::Config.gen-user-name($grub-name)
        if $grub-name;
    $!user-name-guest = Voidvault::Config.gen-user-name($guest-name)
        if $guest-name;
    $!user-name-sftp = Voidvault::Config.gen-user-name($sftp-name)
        if $sftp-name;
    $!user-pass-hash-admin = Voidvault::Utils.gen-pass-hash($admin-pass)
        if $admin-pass;
    $!user-pass-hash-admin = $admin-pass-hash
        if $admin-pass-hash;
    $!user-pass-hash-grub = Voidvault::Utils.gen-pass-hash($grub-pass, :grub)
        if $grub-pass;
    $!user-pass-hash-grub = $grub-pass-hash
        if $grub-pass-hash;
    $!user-pass-hash-guest = Voidvault::Utils.gen-pass-hash($guest-pass)
        if $guest-pass;
    $!user-pass-hash-guest = $guest-pass-hash
        if $guest-pass-hash;
    $!user-pass-hash-root = Voidvault::Utils.gen-pass-hash($root-pass)
        if $root-pass;
    $!user-pass-hash-root = $root-pass-hash
        if $root-pass-hash;
    $!user-pass-hash-sftp = Voidvault::Utils.gen-pass-hash($sftp-pass)
        if $sftp-pass;
    $!user-pass-hash-sftp = $sftp-pass-hash
        if $sftp-pass-hash;
    $!vault-name = Voidvault::Config.gen-vault-name($vault-name)
        if $vault-name;
    $!vault-pass = Voidvault::Config.gen-vault-pass($vault-pass)
        if $vault-pass;
}

method new(
    *%opts (
        Str :admin-name($),
        Str :admin-pass($),
        Str :admin-pass-hash($),
        Bool :augment($),
        Bool :disable-ipv6($),
        Str :disk-type($),
        Str :graphics($),
        Str :grub-name($),
        Str :grub-pass($),
        Str :grub-pass-hash($),
        Str :guest-name($),
        Str :guest-pass($),
        Str :guest-pass-hash($),
        Str :hostname($),
        Bool :ignore-conf-repos($),
        Str :keymap($),
        Str :locale($),
        Str :partition($),
        Str :pool-name($),
        Str :processor($),
        Str :repository($),
        Str :root-pass($),
        Str :root-pass-hash($),
        Str :sftp-name($),
        Str :sftp-pass($),
        Str :sftp-pass-hash($),
        Str :timezone($),
        Str :vault-name($),
        Str :vault-pass($)
    )
    --> Voidvault::Config:D
)
{
    self.bless(|%opts);
}


# -----------------------------------------------------------------------------
# string formatting, resolution and validation
# -----------------------------------------------------------------------------

# confirm disk type $d is valid DiskType and return DiskType
method gen-disk-type(Str:D $d --> DiskType:D)
{
    my DiskType:D $disk-type = $d.uc or die('Sorry, invalid disk type');
}

# confirm graphics card type $g is valid Graphics and return Graphics
method gen-graphics(Str:D $g --> Graphics:D)
{
    my Graphics:D $graphics = $g.uc or die('Sorry, invalid graphics card type');
}

# confirm hostname $h is valid HostName and return HostName
method gen-host-name(Str:D $h --> HostName:D)
{
    my HostName:D $host-name = $h or die("Sorry, invalid hostname 「$h」");
}

# confirm keymap $k is valid Keymap and return Keymap
method gen-keymap(Str:D $k --> Keymap:D)
{
    my Keymap:D $keymap = $k or die("Sorry, invalid keymap 「$k」");
}

# confirm locale $l is valid Locale and return Locale
method gen-locale(Str:D $l --> Locale:D)
{
    my Locale:D $locale = $l or die("Sorry, invalid locale 「$l」");
}

# confirm pool name $p is valid PoolName and return PoolName
method gen-pool-name(Str:D $p --> PoolName:D)
{
    my PoolName:D $pool-name = $p or die("Sorry, invalid pool name 「$p」");
}

# confirm processor $p is valid Processor and return Processor
method gen-processor(Str:D $p --> Processor:D)
{
    my Processor:D $processor = $p.uc or die("Sorry, invalid processor 「$p」");
}

# confirm timezone $t is valid Timezone and return Timezone
method gen-timezone(Str:D $t --> Timezone:D)
{
    my Timezone:D $timezone = $t or die("Sorry, invalid timezone 「$t」");
}

# confirm user name $u is valid UserName and return UserName
method gen-user-name(Str:D $u --> UserName:D)
{
    my UserName:D $user-name = $u or die("Sorry, invalid username 「$u」");
}

# confirm vault name $v is valid VaultName and return VaultName
method gen-vault-name(Str:D $v --> VaultName:D)
{
    my VaultName:D $vault-name = $v or die("Sorry, invalid vault name 「$v」");
}

# confirm vault pass $v is valid VaultPass and return VaultPass
method gen-vault-pass(Str:D $v --> VaultPass:D)
{
    my Str:D $message = qq:to/EOF/.trim;
    Sorry, invalid vault pass. Length needed: 1-512. Length given: {$v.chars}
    EOF
    my VaultPass:D $vault-pass = $v or die($message);
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
)
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
)
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
)
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

sub prompt-disk-type(--> DiskType:D)
{
    my DiskType:D $disk-type = do {
        my DiskType:D $default-item = 'USB';
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

sub prompt-graphics(--> Graphics:D)
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

sub prompt-keymap(--> Keymap:D)
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

sub prompt-locale(--> Locale:D)
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
)
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
    Bool:D :pool($)! where .so
    --> PoolName:D
)
{
    my PoolName:D $pool-name = do {
        my PoolName:D $response-default = 'vg0';
        my Str:D $prompt-text = "Enter pool name [$response-default]: ";
        my Str:D $help-text = q:to/EOF/.trim;
        Determining name of LVM volume group...

        Cannot be named the same as vault. Name should be unique in /dev/.

        Leave blank if you don't know what this is
        EOF
        tprompt(
            PoolName,
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
)
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
)
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
)
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
)
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
)
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

sub prompt-partition(Str:D @partitions --> Str:D)
{
    my Str:D $partition = do {
        my Str:D $default-item = '/dev/sdb';
        my Str:D $prompt-text = 'Select partition for installing Void:';
        my Str:D $title = 'PARTITION SELECTION';
        my Str:D $confirm-topic = 'partition selected';
        dprompt(
            Str,
            @partitions,
            :$default-item,
            :$prompt-text,
            :$title,
            :$confirm-topic
        );
    }
}

sub prompt-processor(--> Processor:D)
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

sub prompt-timezone(--> Timezone:D)
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

# vim: set filetype=raku foldmethod=marker foldlevel=0:
