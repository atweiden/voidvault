use v6;
use Voidvault::Types;
unit module Voidvault::Config::Utils;


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

# confirm vault key $k is valid VaultKey and return VaultKey
sub gen-vault-key(Str:D $k --> VaultKey:D) is export
{
    my VaultKey:D $vault-key = $k or die("Sorry, invalid vault key 「$k」");
}

# confirm vault name $v is valid VaultName and return VaultName
sub gen-vault-name(Str:D $v --> VaultName:D) is export
{
    my VaultName:D $vault-name = $v or die("Sorry, invalid vault name 「$v」");
}

# confirm vault pass $v is valid VaultPass and return VaultPass
sub gen-vault-pass(Str:D $v --> VaultPass:D) is export
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

# vim: set filetype=raku foldmethod=marker foldlevel=0: