use v6;
use Archvault::Types;
use Archvault::Utils;
unit class Archvault::Config;

# -----------------------------------------------------------------------------
# settings
# -----------------------------------------------------------------------------

# - attributes appear in specific order for prompting user
# - defaults are geared towards live media installation

# name for admin user (default: live)
has UserName:D $.user-name-admin =
    %*ENV<ARCHVAULT_ADMIN_NAME>
        ?? self.gen-user-name(%*ENV<ARCHVAULT_ADMIN_NAME>)
        !! prompt-name(:user, :admin);

# sha512 password hash for admin user
has Str:D $.user-pass-hash-admin =
    %*ENV<ARCHVAULT_ADMIN_PASS_HASH>
        ?? %*ENV<ARCHVAULT_ADMIN_PASS_HASH>
        !! %*ENV<ARCHVAULT_ADMIN_PASS>
            ?? Archvault::Utils.gen-pass-hash(%*ENV<ARCHVAULT_ADMIN_PASS>)
            !! Archvault::Utils.prompt-pass-hash($!user-name-admin);

# name for guest user (default: guest)
has UserName:D $.user-name-guest =
    %*ENV<ARCHVAULT_GUEST_NAME>
        ?? self.gen-user-name(%*ENV<ARCHVAULT_GUEST_NAME>)
        !! prompt-name(:user, :guest);

# sha512 password hash for guest user
has Str:D $.user-pass-hash-guest =
    %*ENV<ARCHVAULT_GUEST_PASS_HASH>
        ?? %*ENV<ARCHVAULT_GUEST_PASS_HASH>
        !! %*ENV<ARCHVAULT_GUEST_PASS>
            ?? Archvault::Utils.gen-pass-hash(%*ENV<ARCHVAULT_GUEST_PASS>)
            !! Archvault::Utils.prompt-pass-hash($!user-name-guest);

# name for sftp user (default: variable)
has UserName:D $.user-name-sftp =
    %*ENV<ARCHVAULT_SFTP_NAME>
        ?? self.gen-user-name(%*ENV<ARCHVAULT_SFTP_NAME>)
        !! prompt-name(:user, :sftp);

# sha512 password hash for sftp user
has Str:D $.user-pass-hash-sftp =
    %*ENV<ARCHVAULT_SFTP_PASS_HASH>
        ?? %*ENV<ARCHVAULT_SFTP_PASS_HASH>
        !! %*ENV<ARCHVAULT_SFTP_PASS>
            ?? Archvault::Utils.gen-pass-hash(%*ENV<ARCHVAULT_SFTP_PASS>)
            !! Archvault::Utils.prompt-pass-hash($!user-name-sftp);

# sha512 password hash for root user
has Str:D $.user-pass-hash-root =
    %*ENV<ARCHVAULT_ROOT_PASS_HASH>
        ?? %*ENV<ARCHVAULT_ROOT_PASS_HASH>
        !! %*ENV<ARCHVAULT_ROOT_PASS>
            ?? Archvault::Utils.gen-pass-hash(%*ENV<ARCHVAULT_ROOT_PASS>)
            !! Archvault::Utils.prompt-pass-hash('root');

# name for grub user (default: grub)
has UserName:D $.user-name-grub =
    %*ENV<ARCHVAULT_GRUB_NAME>
        ?? self.gen-user-name(%*ENV<ARCHVAULT_GRUB_NAME>)
        !! prompt-name(:user, :grub);

# pbkdf2 password hash for grub user
has Str:D $.user-pass-hash-grub =
    %*ENV<ARCHVAULT_GRUB_PASS_HASH>
        ?? %*ENV<ARCHVAULT_GRUB_PASS_HASH>
        !! %*ENV<ARCHVAULT_GRUB_PASS>
            ?? Archvault::Utils.gen-pass-hash(%*ENV<ARCHVAULT_GRUB_PASS>, :grub)
            !! Archvault::Utils.prompt-pass-hash($!user-name-grub, :grub);

# name for LUKS encrypted volume (default: vault)
has VaultName:D $.vault-name =
    %*ENV<ARCHVAULT_VAULT_NAME>
        ?? self.gen-vault-name(%*ENV<ARCHVAULT_VAULT_NAME>)
        !! prompt-name(:vault);

# password for LUKS encrypted volume
has VaultPass $.vault-pass =
    %*ENV<ARCHVAULT_VAULT_PASS>
        ?? self.gen-vault-pass(%*ENV<ARCHVAULT_VAULT_PASS>)
        !! Nil;

# name for host (default: vault)
has HostName:D $.host-name =
    %*ENV<ARCHVAULT_HOSTNAME>
        ?? self.gen-host-name(%*ENV<ARCHVAULT_HOSTNAME>)
        !! prompt-name(:host);

# device path of target partition (default: /dev/sdb)
has Str:D $.partition =
    %*ENV<ARCHVAULT_PARTITION>
        || prompt-partition(Archvault::Utils.ls-partitions);

# type of processor (default: other)
has Processor:D $.processor =
    %*ENV<ARCHVAULT_PROCESSOR>
        ?? self.gen-processor(%*ENV<ARCHVAULT_PROCESSOR>)
        !! prompt-processor();

# type of graphics card (default: intel)
has Graphics:D $.graphics =
    %*ENV<ARCHVAULT_GRAPHICS>
        ?? self.gen-graphics(%*ENV<ARCHVAULT_GRAPHICS>)
        !! prompt-graphics();

# type of hard drive (default: usb)
has DiskType:D $.disk-type =
    %*ENV<ARCHVAULT_DISK_TYPE>
        ?? self.gen-disk-type(%*ENV<ARCHVAULT_DISK_TYPE>)
        !! prompt-disk-type();

# locale (default: en_US)
has Locale:D $.locale =
    %*ENV<ARCHVAULT_LOCALE>
        ?? self.gen-locale(%*ENV<ARCHVAULT_LOCALE>)
        !! prompt-locale();

# keymap (default: us)
has Keymap:D $.keymap =
    %*ENV<ARCHVAULT_KEYMAP>
        ?? self.gen-keymap(%*ENV<ARCHVAULT_KEYMAP>)
        !! prompt-keymap();

# timezone (default: America/Los_Angeles)
has Timezone:D $.timezone =
    %*ENV<ARCHVAULT_TIMEZONE>
        ?? self.gen-timezone(%*ENV<ARCHVAULT_TIMEZONE>)
        !! prompt-timezone();

# augment
has Bool:D $.augment =
    ?%*ENV<ARCHVAULT_AUGMENT>;

# reflector
has Bool:D $.reflector =
    ?%*ENV<ARCHVAULT_REFLECTOR>;


# -----------------------------------------------------------------------------
# class instantation
# -----------------------------------------------------------------------------

submethod BUILD(
    Str :$admin-name,
    Str :$admin-pass,
    Str :$admin-pass-hash,
    Bool :$augment,
    Str :$disk-type,
    Str :$graphics,
    Str :$grub-name,
    Str :$grub-pass,
    Str :$grub-pass-hash,
    Str :$guest-name,
    Str :$guest-pass,
    Str :$guest-pass-hash,
    Str :$hostname,
    Str :$keymap,
    Str :$locale,
    Str :$partition,
    Str :$processor,
    Bool :$reflector,
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
    $!augment = $augment if $augment;
    $!disk-type = self.gen-disk-type($disk-type) if $disk-type;
    $!graphics = self.gen-graphics($graphics) if $graphics;
    $!host-name = self.gen-host-name($hostname) if $hostname;
    $!keymap = self.gen-keymap($keymap) if $keymap;
    $!locale = self.gen-locale($locale) if $locale;
    $!partition = $partition if $partition;
    $!processor = self.gen-processor($processor) if $processor;
    $!reflector = $reflector if $reflector;
    $!timezone = self.gen-timezone($timezone) if $timezone;
    $!user-name-admin = self.gen-user-name($admin-name) if $admin-name;
    $!user-name-grub = self.gen-user-name($grub-name) if $grub-name;
    $!user-name-guest = self.gen-user-name($guest-name) if $guest-name;
    $!user-name-sftp = self.gen-user-name($sftp-name) if $sftp-name;
    $!user-pass-hash-admin =
        Archvault::Utils.gen-pass-hash($admin-pass) if $admin-pass;
    $!user-pass-hash-admin = $admin-pass-hash if $admin-pass-hash;
    $!user-pass-hash-grub =
        Archvault::Utils.gen-pass-hash($grub-pass, :grub) if $grub-pass;
    $!user-pass-hash-grub = $grub-pass-hash if $grub-pass-hash;
    $!user-pass-hash-guest =
        Archvault::Utils.gen-pass-hash($guest-pass) if $guest-pass;
    $!user-pass-hash-guest = $guest-pass-hash if $guest-pass-hash;
    $!user-pass-hash-root =
        Archvault::Utils.gen-pass-hash($root-pass) if $root-pass;
    $!user-pass-hash-root = $root-pass-hash if $root-pass-hash;
    $!user-pass-hash-sftp =
        Archvault::Utils.gen-pass-hash($sftp-pass) if $sftp-pass;
    $!user-pass-hash-sftp = $sftp-pass-hash if $sftp-pass-hash;
    $!vault-name = self.gen-vault-name($vault-name) if $vault-name;
    $!vault-pass = self.gen-vault-pass($vault-pass) if $vault-pass;
}

method new(
    *%opts (
        Str :admin-name($),
        Str :admin-pass($),
        Str :admin-pass-hash($),
        Bool :augment($),
        Str :disk-type($),
        Str :graphics($),
        Str :grub-name($),
        Str :grub-pass($),
        Str :grub-pass-hash($),
        Str :guest-name($),
        Str :guest-pass($),
        Str :guest-pass-hash($),
        Str :hostname($),
        Str :keymap($),
        Str :locale($),
        Str :partition($),
        Str :processor($),
        Bool :reflector($),
        Str :root-pass($),
        Str :root-pass-hash($),
        Str :sftp-name($),
        Str :sftp-pass($),
        Str :sftp-pass-hash($),
        Str :timezone($),
        Str :vault-name($),
        Str :vault-pass($)
    )
    --> Archvault::Config:D
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
    my VaultPass:D $vault-pass = $v
        or die('Sorry, invalid vault pass. Length needed: 1-512. '
                ~ 'Length given: ' ~ $v.chars);
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
            %Archvault::Types::disktypes,
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
            %Archvault::Types::graphics,
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
            %Archvault::Types::keymaps,
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
            %Archvault::Types::locales,
            :$default-item,
            :$prompt-text,
            :$title,
            :$confirm-topic
        );
    }
}

multi sub prompt-name(Bool:D :host($)! where .so --> HostName:D)
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
        Determining name for Grub user...

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

multi sub prompt-name(Bool:D :vault($)! where .so --> VaultName:D)
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
        my Str:D $prompt-text = 'Select partition for installing Arch:';
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
            %Archvault::Types::processors,
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
    my Timezone:D @timezones = @Archvault::Types::timezones;

    # prompt choose region
    my Str:D $region = do {
        # get list of timezone regions
        my Str:D @regions =
            @timezones.hyper.map({ .subst(/'/'\N*$/, '') }).unique;
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
            .hyper
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

# vim: set filetype=perl6 foldmethod=marker foldlevel=0:
