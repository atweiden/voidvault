use v6;
use Voidvault::Config;
use Voidvault::Config::Base;
use Voidvault::Config::OneFA;
use Voidvault::Config::TwoFA;
use Voidvault::ConfigArgs::Constants;
use Voidvault::ConfigArgs::Utils;
use Voidvault::Parser::Filesystem;
use Voidvault::Parser::Mode;
use Voidvault::Types;
use X::Voidvault::ConfigArgs;
use X::Voidvault::Parser::Filesystem;
use X::Voidvault::Parser::Mode;

my role Opts[Mode:D $ where Mode::BASE]
{
    has Str $.admin-name;
    has Str $.admin-pass;
    has Str $.admin-pass-hash;
    has Bool $.augment;
    has Str $.chroot-dir;
    has Str $.device;
    has Bool $.disable-ipv6;
    has Str $.disk-type;
    has Bool $.enable-classic-ifnames;
    has Bool $.enable-serial-console;
    has Str $.graphics;
    has Str $.grub-name;
    has Str $.grub-pass;
    has Str $.grub-pass-hash;
    has Str $.guest-name;
    has Str $.guest-pass;
    has Str $.guest-pass-hash;
    has Str $.hostname;
    has Bool $.ignore-conf-repos;
    has Str $.kernel;
    has Str $.keymap;
    has Str $.locale;
    has Str $.packages;
    has Str $.processor;
    has List $.repository;
    has Str $.root-pass;
    has Str $.root-pass-hash;
    has Str $.sftp-name;
    has Str $.sftp-pass;
    has Str $.sftp-pass-hash;
    has Str $.timezone;
    has Str $.vault-name;
    has Str $.vault-pass;
    has Str $.vault-key-file;
    has Str $.vault-cipher;
    has Str $.vault-hash;
    has Str $.vault-iter-time;
    has Str $.vault-key-size;
    has Str $.vault-offset;
    has Str $.vault-sector-size;
}

my role Opts[Mode:D $ where Mode::<1FA>]
{
    also does Opts[Mode::BASE];
    has Str $.bootvault-name;
    has Str $.bootvault-pass;
    has Str $.bootvault-key-file;
    has Str $.vault-header;
    has Str $.bootvault-cipher;
    has Str $.bootvault-hash;
    has Str $.bootvault-iter-time;
    has Str $.bootvault-key-size;
    has Str $.bootvault-offset;
    has Str $.bootvault-sector-size;
}

my role Opts[Mode:D $ where Mode::<2FA>]
{
    also does Opts[Mode::<1FA>];
    has Str $.bootvault-device;
}

# C<ModeArgs> stores positional argument pertaining to mode without
# interfering with C<GetOpts>' ability to iterate through cmdline opts,
# by way of recording positional argument as parameterized variable and
# then reporting this variable via method (C<mode>)
my role ModeArgs[Mode:D $mode]
{
    method mode(--> Mode:D) { $mode }
}

# C<FilesystemArgs> stores positional argument pertaining to filesystem
# setup without interfering with C<GetOpts>' ability to iterate through
# cmdline opts, by way of recording positional argument as parameterized
# variables and then reporting those variables via methods (C<vaultfs>,
# C<bootvaultfs>, and C<lvm>)
#
# cheat a bit on the name "Args" vis-a-vis attribute C<$.lvm-vg-name>,
# which becomes an accepted cmdline option upon role C<FilesystemArgs>
# being mixed in to C<Voidvault::ConfigArgs::Parser>
my role FilesystemArgs[
    Filesystem $vaultfs,
    Filesystem $bootvaultfs,
    # user passed C<+lvm> on cmdline
    Bool:D $lvm where .so
]
{
    # lvm vg name opt accepted since user passed C<+lvm> on cmdline
    has Str $.lvm-vg-name;
    method vaultfs(--> Filesystem) { $vaultfs }
    method bootvaultfs(--> Filesystem) { $bootvaultfs }
    method lvm(--> Bool) { $lvm }
}

# duplicate methods for minimum amount of code duplication ironically
my role FilesystemArgs[
    Filesystem $vaultfs,
    Filesystem $bootvaultfs,
    # user didn't pass C<+lvm> on cmdline
    Bool $lvm
]
{
    method vaultfs(--> Filesystem) { $vaultfs }
    method bootvaultfs(--> Filesystem) { $bootvaultfs }
    method lvm(--> Bool) { $lvm }
}

# C<OptsStrict> rejects invalid cmdline options
my role OptsStrict
{
    # credit: ufobat/p6-StrictClass
    submethod TWEAK(*%opts --> Nil)
    {
        my Str:D @attribute-name =
            ::?CLASS.^attributes.map({ get-attribute-name($_) });
        my Str:D @invalid-option =
            %opts.keys.grep(-> $opt { so($opt ne @attribute-name.any) });
        if @invalid-option
        {
            my Str:D $message = gen-message(:@invalid-option);
            die($message);
        }
    }

    sub gen-message(Str:D :@invalid-option! where .so --> Str:D)
    {
        my Int:D $count = @invalid-option.elems;
        my Str:D $invalid-options =
            @invalid-option.map({ sprintf(Q{--%s}, $_) }).join(', ');
        my Str:D $message = "Sorry, received invalid option";
        # pluralize if necessary
        $message ~= 's' if $count > 1;
        $message ~= ": $invalid-options";
    }
}

my role GetArgs
{
    method get-args(::?CLASS:D: --> List:D)
    {
        my List:D $args = (self.mode, self.vaultfs, self.bootvaultfs, self.lvm);
    }
}

# C<GetOpts> provides method C<get-opts> for iterating through attributes.
# When mixed in to role C<Voidvault::ConfigArgs::Parser>, these attributes
# reflect proper cmdline options the valid set of which changes dynamically
# based on positional arguments. C<GetOpts> doesn't iterate through these
# positional arguments, however, only cmdline options (flags).
my role GetOpts
{
    # alternative to duplicating code in C<Mode::<1FA>>, C<Mode::<2FA>>
    method get-opts(::?CLASS:D: --> Hash:D)
    {
        # list all attributes (think: C<Voidvault::ConfigArgs::Parser>)
        my List $attributes = self.^attributes(:local);
        # C<Attribute.get_value> requires C<self>, no multi methods now
        my $*self = self;
        my %opts = get-opts(:$attributes);
    }

    multi sub get-opts(
        List :$attributes!
        --> Hash:D
    )
    {
        my Pair:D @opt = $attributes.map(-> Attribute:D $attribute {
            get-opts(:$attribute);
        });
        my %opts = @opt.hash;
    }

    multi sub get-opts(
        Attribute:D :$attribute!
        --> Pair:D
    )
    {
        my Str:D $name = get-attribute-name($attribute);
        my \value = $attribute.get_value($*self);
        get-opts($name, value);
    }

    # untyped repository array must become C<Array[Str:D]>
    multi sub get-opts(
        Str:D $name where 'repository',
        \value where .so
        --> Pair:D
    )
    {
        my Str:D @value = |value;
        my Pair:D $name-value = $name => @value;
    }

    multi sub get-opts(
        Str:D $name where 'repository',
        \value
        --> Pair:D
    )
    {
        my Str:D @value;
        my Pair:D $name-value = $name => @value;
    }

    multi sub get-opts(
        Str:D $name,
        \value
        --> Pair:D
    )
    {
        my Pair:D $name-value = $name => value;
    }
}

my role Retrospective
{
    # C<received-arg('fs')> returns C<True> if fs positional arg was
    # passed on cmdline
    method received-arg(::?CLASS:D: 'fs' --> Bool:D)
    {
        (self.vaultfs, self.bootvaultfs, self.lvm).grep(*.defined).so;
    }
}

my role ToConfig[Mode:D $ where Mode::BASE]
{
    method Voidvault::Config(::?CLASS:D: --> Voidvault::Config::Base:D)
    {
        # instantiate if fs positional arg, else C<prompt-filesystem>
        my %opts;
        %opts<filesystem> =
            Voidvault::Config::Filesystem.new(
                |self.get-args,
                |self.get-opts
            ) if self.received-arg('fs');
        Voidvault::Config::Base.new(|self.get-opts, |%opts);
    }
}

my role ToConfig[Mode:D $ where Mode::<1FA>]
{
    method Voidvault::Config(::?CLASS:D: --> Voidvault::Config::OneFA:D)
    {
        my %opts;
        %opts<filesystem> =
            Voidvault::Config::Filesystem.new(
                |self.get-args,
                |self.get-opts
            ) if self.received-arg('fs');
        Voidvault::Config::OneFA.new(|self.get-opts, |%opts);
    }
}

my role ToConfig[Mode:D $ where Mode::<2FA>]
{
    method Voidvault::Config(::?CLASS:D: --> Voidvault::Config::TwoFA:D)
    {
        my %opts;
        %opts<filesystem> =
            Voidvault::Config::Filesystem.new(
                |self.get-args,
                |self.get-opts
            ) if self.received-arg('fs');
        Voidvault::Config::TwoFA.new(|self.get-opts, |%opts);
    }
}

# Mode::BASE {{{

# --- +lvm {{{

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::BTRFS,
    Filesystem $bootvaultfs where Filesystem::BTRFS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::BTRFS, Filesystem::BTRFS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::BTRFS,
    Filesystem $bootvaultfs where Filesystem::EXT2,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::BTRFS, Filesystem::EXT2, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::BTRFS,
    Filesystem $bootvaultfs where Filesystem::EXT3,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::BTRFS, Filesystem::EXT3, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::BTRFS,
    Filesystem $bootvaultfs where Filesystem::EXT4,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::BTRFS, Filesystem::EXT4, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::BTRFS,
    Filesystem $bootvaultfs where Filesystem::F2FS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::BTRFS, Filesystem::F2FS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::BTRFS,
    Filesystem $bootvaultfs where Filesystem::NILFS2,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::BTRFS, Filesystem::NILFS2, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::BTRFS,
    Filesystem $bootvaultfs where Filesystem::XFS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::BTRFS, Filesystem::XFS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::BTRFS,
    Filesystem $bootvaultfs,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::BTRFS, Filesystem, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::EXT2,
    Filesystem $bootvaultfs where Filesystem::BTRFS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::EXT2, Filesystem::BTRFS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::EXT2,
    Filesystem $bootvaultfs where Filesystem::EXT2,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::EXT2, Filesystem::EXT2, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::EXT2,
    Filesystem $bootvaultfs where Filesystem::EXT3,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::EXT2, Filesystem::EXT3, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::EXT2,
    Filesystem $bootvaultfs where Filesystem::EXT4,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::EXT2, Filesystem::EXT4, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::EXT2,
    Filesystem $bootvaultfs where Filesystem::F2FS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::EXT2, Filesystem::F2FS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::EXT2,
    Filesystem $bootvaultfs where Filesystem::NILFS2,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::EXT2, Filesystem::NILFS2, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::EXT2,
    Filesystem $bootvaultfs where Filesystem::XFS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::EXT2, Filesystem::XFS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::EXT2,
    Filesystem $bootvaultfs,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::EXT2, Filesystem, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::EXT3,
    Filesystem $bootvaultfs where Filesystem::BTRFS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::EXT3, Filesystem::BTRFS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::EXT3,
    Filesystem $bootvaultfs where Filesystem::EXT2,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::EXT3, Filesystem::EXT2, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::EXT3,
    Filesystem $bootvaultfs where Filesystem::EXT3,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::EXT3, Filesystem::EXT3, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::EXT3,
    Filesystem $bootvaultfs where Filesystem::EXT4,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::EXT3, Filesystem::EXT4, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::EXT3,
    Filesystem $bootvaultfs where Filesystem::F2FS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::EXT3, Filesystem::F2FS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::EXT3,
    Filesystem $bootvaultfs where Filesystem::NILFS2,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::EXT3, Filesystem::NILFS2, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::EXT3,
    Filesystem $bootvaultfs where Filesystem::XFS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::EXT3, Filesystem::XFS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::EXT3,
    Filesystem $bootvaultfs,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::EXT3, Filesystem, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::EXT4,
    Filesystem $bootvaultfs where Filesystem::BTRFS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::EXT4, Filesystem::BTRFS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::EXT4,
    Filesystem $bootvaultfs where Filesystem::EXT2,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::EXT4, Filesystem::EXT2, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::EXT4,
    Filesystem $bootvaultfs where Filesystem::EXT3,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::EXT4, Filesystem::EXT3, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::EXT4,
    Filesystem $bootvaultfs where Filesystem::EXT4,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::EXT4, Filesystem::EXT4, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::EXT4,
    Filesystem $bootvaultfs where Filesystem::F2FS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::EXT4, Filesystem::F2FS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::EXT4,
    Filesystem $bootvaultfs where Filesystem::NILFS2,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::EXT4, Filesystem::NILFS2, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::EXT4,
    Filesystem $bootvaultfs where Filesystem::XFS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::EXT4, Filesystem::XFS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::EXT4,
    Filesystem $bootvaultfs,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::EXT4, Filesystem, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::F2FS,
    Filesystem $bootvaultfs where Filesystem::BTRFS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::F2FS, Filesystem::BTRFS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::F2FS,
    Filesystem $bootvaultfs where Filesystem::EXT2,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::F2FS, Filesystem::EXT2, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::F2FS,
    Filesystem $bootvaultfs where Filesystem::EXT3,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::F2FS, Filesystem::EXT3, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::F2FS,
    Filesystem $bootvaultfs where Filesystem::EXT4,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::F2FS, Filesystem::EXT4, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::F2FS,
    Filesystem $bootvaultfs where Filesystem::F2FS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::F2FS, Filesystem::F2FS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::F2FS,
    Filesystem $bootvaultfs where Filesystem::NILFS2,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::F2FS, Filesystem::NILFS2, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::F2FS,
    Filesystem $bootvaultfs where Filesystem::XFS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::F2FS, Filesystem::XFS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::F2FS,
    Filesystem $bootvaultfs,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::F2FS, Filesystem, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::NILFS2,
    Filesystem $bootvaultfs where Filesystem::BTRFS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::NILFS2, Filesystem::BTRFS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::NILFS2,
    Filesystem $bootvaultfs where Filesystem::EXT2,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::NILFS2, Filesystem::EXT2, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::NILFS2,
    Filesystem $bootvaultfs where Filesystem::EXT3,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::NILFS2, Filesystem::EXT3, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::NILFS2,
    Filesystem $bootvaultfs where Filesystem::EXT4,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::NILFS2, Filesystem::EXT4, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::NILFS2,
    Filesystem $bootvaultfs where Filesystem::F2FS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::NILFS2, Filesystem::F2FS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::NILFS2,
    Filesystem $bootvaultfs where Filesystem::NILFS2,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::NILFS2, Filesystem::NILFS2, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::NILFS2,
    Filesystem $bootvaultfs where Filesystem::XFS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::NILFS2, Filesystem::XFS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::NILFS2,
    Filesystem $bootvaultfs,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::NILFS2, Filesystem, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::XFS,
    Filesystem $bootvaultfs where Filesystem::BTRFS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::XFS, Filesystem::BTRFS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::XFS,
    Filesystem $bootvaultfs where Filesystem::EXT2,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::XFS, Filesystem::EXT2, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::XFS,
    Filesystem $bootvaultfs where Filesystem::EXT3,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::XFS, Filesystem::EXT3, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::XFS,
    Filesystem $bootvaultfs where Filesystem::EXT4,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::XFS, Filesystem::EXT4, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::XFS,
    Filesystem $bootvaultfs where Filesystem::F2FS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::XFS, Filesystem::F2FS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::XFS,
    Filesystem $bootvaultfs where Filesystem::NILFS2,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::XFS, Filesystem::NILFS2, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::XFS,
    Filesystem $bootvaultfs where Filesystem::XFS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::XFS, Filesystem::XFS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::XFS,
    Filesystem $bootvaultfs,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::XFS, Filesystem, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs,
    Filesystem $bootvaultfs where Filesystem::BTRFS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem, Filesystem::BTRFS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs,
    Filesystem $bootvaultfs where Filesystem::EXT2,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem, Filesystem::EXT2, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs,
    Filesystem $bootvaultfs where Filesystem::EXT3,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem, Filesystem::EXT3, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs,
    Filesystem $bootvaultfs where Filesystem::EXT4,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem, Filesystem::EXT4, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs,
    Filesystem $bootvaultfs where Filesystem::F2FS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem, Filesystem::F2FS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs,
    Filesystem $bootvaultfs where Filesystem::NILFS2,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem, Filesystem::NILFS2, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs,
    Filesystem $bootvaultfs where Filesystem::XFS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem, Filesystem::XFS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs,
    Filesystem $bootvaultfs,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem, Filesystem, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

# --- end +lvm }}}
# --- -lvm {{{

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::BTRFS,
    Filesystem $bootvaultfs where Filesystem::BTRFS,
    Bool $lvm
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::BTRFS, Filesystem::BTRFS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::BTRFS,
    Filesystem $bootvaultfs where Filesystem::EXT2,
    Bool $lvm
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::BTRFS, Filesystem::EXT2, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::BTRFS,
    Filesystem $bootvaultfs where Filesystem::EXT3,
    Bool $lvm
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::BTRFS, Filesystem::EXT3, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::BTRFS,
    Filesystem $bootvaultfs where Filesystem::EXT4,
    Bool $lvm
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::BTRFS, Filesystem::EXT4, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::BTRFS,
    Filesystem $bootvaultfs where Filesystem::F2FS,
    Bool $lvm
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::BTRFS, Filesystem::F2FS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::BTRFS,
    Filesystem $bootvaultfs where Filesystem::NILFS2,
    Bool $lvm
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::BTRFS, Filesystem::NILFS2, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::BTRFS,
    Filesystem $bootvaultfs where Filesystem::XFS,
    Bool $lvm
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::BTRFS, Filesystem::XFS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::BTRFS,
    Filesystem $bootvaultfs,
    Bool $lvm
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::BTRFS, Filesystem, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::EXT2,
    Filesystem $bootvaultfs where Filesystem::BTRFS,
    Bool $lvm
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::EXT2, Filesystem::BTRFS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::EXT2,
    Filesystem $bootvaultfs where Filesystem::EXT2,
    Bool $lvm
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::EXT2, Filesystem::EXT2, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::EXT2,
    Filesystem $bootvaultfs where Filesystem::EXT3,
    Bool $lvm
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::EXT2, Filesystem::EXT3, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::EXT2,
    Filesystem $bootvaultfs where Filesystem::EXT4,
    Bool $lvm
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::EXT2, Filesystem::EXT4, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::EXT2,
    Filesystem $bootvaultfs where Filesystem::F2FS,
    Bool $lvm
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::EXT2, Filesystem::F2FS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::EXT2,
    Filesystem $bootvaultfs where Filesystem::NILFS2,
    Bool $lvm
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::EXT2, Filesystem::NILFS2, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::EXT2,
    Filesystem $bootvaultfs where Filesystem::XFS,
    Bool $lvm
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::EXT2, Filesystem::XFS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::EXT2,
    Filesystem $bootvaultfs,
    Bool $lvm
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::EXT2, Filesystem, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::EXT3,
    Filesystem $bootvaultfs where Filesystem::BTRFS,
    Bool $lvm
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::EXT3, Filesystem::BTRFS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::EXT3,
    Filesystem $bootvaultfs where Filesystem::EXT2,
    Bool $lvm
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::EXT3, Filesystem::EXT2, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::EXT3,
    Filesystem $bootvaultfs where Filesystem::EXT3,
    Bool $lvm
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::EXT3, Filesystem::EXT3, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::EXT3,
    Filesystem $bootvaultfs where Filesystem::EXT4,
    Bool $lvm
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::EXT3, Filesystem::EXT4, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::EXT3,
    Filesystem $bootvaultfs where Filesystem::F2FS,
    Bool $lvm
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::EXT3, Filesystem::F2FS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::EXT3,
    Filesystem $bootvaultfs where Filesystem::NILFS2,
    Bool $lvm
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::EXT3, Filesystem::NILFS2, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::EXT3,
    Filesystem $bootvaultfs where Filesystem::XFS,
    Bool $lvm
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::EXT3, Filesystem::XFS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::EXT3,
    Filesystem $bootvaultfs,
    Bool $lvm
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::EXT3, Filesystem, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::EXT4,
    Filesystem $bootvaultfs where Filesystem::BTRFS,
    Bool $lvm
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::EXT4, Filesystem::BTRFS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::EXT4,
    Filesystem $bootvaultfs where Filesystem::EXT2,
    Bool $lvm
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::EXT4, Filesystem::EXT2, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::EXT4,
    Filesystem $bootvaultfs where Filesystem::EXT3,
    Bool $lvm
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::EXT4, Filesystem::EXT3, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::EXT4,
    Filesystem $bootvaultfs where Filesystem::EXT4,
    Bool $lvm
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::EXT4, Filesystem::EXT4, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::EXT4,
    Filesystem $bootvaultfs where Filesystem::F2FS,
    Bool $lvm
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::EXT4, Filesystem::F2FS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::EXT4,
    Filesystem $bootvaultfs where Filesystem::NILFS2,
    Bool $lvm
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::EXT4, Filesystem::NILFS2, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::EXT4,
    Filesystem $bootvaultfs where Filesystem::XFS,
    Bool $lvm
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::EXT4, Filesystem::XFS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::EXT4,
    Filesystem $bootvaultfs,
    Bool $lvm
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::EXT4, Filesystem, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::F2FS,
    Filesystem $bootvaultfs where Filesystem::BTRFS,
    Bool $lvm
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::F2FS, Filesystem::BTRFS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::F2FS,
    Filesystem $bootvaultfs where Filesystem::EXT2,
    Bool $lvm
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::F2FS, Filesystem::EXT2, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::F2FS,
    Filesystem $bootvaultfs where Filesystem::EXT3,
    Bool $lvm
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::F2FS, Filesystem::EXT3, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::F2FS,
    Filesystem $bootvaultfs where Filesystem::EXT4,
    Bool $lvm
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::F2FS, Filesystem::EXT4, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::F2FS,
    Filesystem $bootvaultfs where Filesystem::F2FS,
    Bool $lvm
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::F2FS, Filesystem::F2FS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::F2FS,
    Filesystem $bootvaultfs where Filesystem::NILFS2,
    Bool $lvm
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::F2FS, Filesystem::NILFS2, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::F2FS,
    Filesystem $bootvaultfs where Filesystem::XFS,
    Bool $lvm
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::F2FS, Filesystem::XFS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::F2FS,
    Filesystem $bootvaultfs,
    Bool $lvm
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::F2FS, Filesystem, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::NILFS2,
    Filesystem $bootvaultfs where Filesystem::BTRFS,
    Bool $lvm
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::NILFS2, Filesystem::BTRFS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::NILFS2,
    Filesystem $bootvaultfs where Filesystem::EXT2,
    Bool $lvm
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::NILFS2, Filesystem::EXT2, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::NILFS2,
    Filesystem $bootvaultfs where Filesystem::EXT3,
    Bool $lvm
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::NILFS2, Filesystem::EXT3, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::NILFS2,
    Filesystem $bootvaultfs where Filesystem::EXT4,
    Bool $lvm
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::NILFS2, Filesystem::EXT4, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::NILFS2,
    Filesystem $bootvaultfs where Filesystem::F2FS,
    Bool $lvm
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::NILFS2, Filesystem::F2FS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::NILFS2,
    Filesystem $bootvaultfs where Filesystem::NILFS2,
    Bool $lvm
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::NILFS2, Filesystem::NILFS2, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::NILFS2,
    Filesystem $bootvaultfs where Filesystem::XFS,
    Bool $lvm
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::NILFS2, Filesystem::XFS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::NILFS2,
    Filesystem $bootvaultfs,
    Bool $lvm
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::NILFS2, Filesystem, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::XFS,
    Filesystem $bootvaultfs where Filesystem::BTRFS,
    Bool $lvm
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::XFS, Filesystem::BTRFS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::XFS,
    Filesystem $bootvaultfs where Filesystem::EXT2,
    Bool $lvm
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::XFS, Filesystem::EXT2, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::XFS,
    Filesystem $bootvaultfs where Filesystem::EXT3,
    Bool $lvm
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::XFS, Filesystem::EXT3, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::XFS,
    Filesystem $bootvaultfs where Filesystem::EXT4,
    Bool $lvm
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::XFS, Filesystem::EXT4, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::XFS,
    Filesystem $bootvaultfs where Filesystem::F2FS,
    Bool $lvm
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::XFS, Filesystem::F2FS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::XFS,
    Filesystem $bootvaultfs where Filesystem::NILFS2,
    Bool $lvm
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::XFS, Filesystem::NILFS2, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::XFS,
    Filesystem $bootvaultfs where Filesystem::XFS,
    Bool $lvm
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::XFS, Filesystem::XFS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs where Filesystem::XFS,
    Filesystem $bootvaultfs,
    Bool $lvm
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem::XFS, Filesystem, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs,
    Filesystem $bootvaultfs where Filesystem::BTRFS,
    Bool $lvm
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem, Filesystem::BTRFS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs,
    Filesystem $bootvaultfs where Filesystem::EXT2,
    Bool $lvm
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem, Filesystem::EXT2, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs,
    Filesystem $bootvaultfs where Filesystem::EXT3,
    Bool $lvm
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem, Filesystem::EXT3, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs,
    Filesystem $bootvaultfs where Filesystem::EXT4,
    Bool $lvm
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem, Filesystem::EXT4, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs,
    Filesystem $bootvaultfs where Filesystem::F2FS,
    Bool $lvm
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem, Filesystem::F2FS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs,
    Filesystem $bootvaultfs where Filesystem::NILFS2,
    Bool $lvm
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem, Filesystem::NILFS2, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs,
    Filesystem $bootvaultfs where Filesystem::XFS,
    Bool $lvm
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem, Filesystem::XFS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::BASE,
    Filesystem $vaultfs,
    Filesystem $bootvaultfs,
    Bool $lvm
]
{
    also does Opts[Mode::BASE];
    also does ModeArgs[Mode::BASE];
    also does FilesystemArgs[Filesystem, Filesystem, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::BASE];
}

# --- end -lvm }}}

# end Mode::BASE }}}
# Mode::<1FA> {{{

# --- +lvm {{{

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::BTRFS,
    Filesystem $bootvaultfs where Filesystem::BTRFS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::BTRFS, Filesystem::BTRFS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::BTRFS,
    Filesystem $bootvaultfs where Filesystem::EXT2,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::BTRFS, Filesystem::EXT2, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::BTRFS,
    Filesystem $bootvaultfs where Filesystem::EXT3,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::BTRFS, Filesystem::EXT3, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::BTRFS,
    Filesystem $bootvaultfs where Filesystem::EXT4,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::BTRFS, Filesystem::EXT4, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::BTRFS,
    Filesystem $bootvaultfs where Filesystem::F2FS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::BTRFS, Filesystem::F2FS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::BTRFS,
    Filesystem $bootvaultfs where Filesystem::NILFS2,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::BTRFS, Filesystem::NILFS2, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::BTRFS,
    Filesystem $bootvaultfs where Filesystem::XFS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::BTRFS, Filesystem::XFS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::BTRFS,
    Filesystem $bootvaultfs,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::BTRFS, Filesystem, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::EXT2,
    Filesystem $bootvaultfs where Filesystem::BTRFS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::EXT2, Filesystem::BTRFS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::EXT2,
    Filesystem $bootvaultfs where Filesystem::EXT2,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::EXT2, Filesystem::EXT2, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::EXT2,
    Filesystem $bootvaultfs where Filesystem::EXT3,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::EXT2, Filesystem::EXT3, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::EXT2,
    Filesystem $bootvaultfs where Filesystem::EXT4,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::EXT2, Filesystem::EXT4, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::EXT2,
    Filesystem $bootvaultfs where Filesystem::F2FS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::EXT2, Filesystem::F2FS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::EXT2,
    Filesystem $bootvaultfs where Filesystem::NILFS2,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::EXT2, Filesystem::NILFS2, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::EXT2,
    Filesystem $bootvaultfs where Filesystem::XFS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::EXT2, Filesystem::XFS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::EXT2,
    Filesystem $bootvaultfs,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::EXT2, Filesystem, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::EXT3,
    Filesystem $bootvaultfs where Filesystem::BTRFS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::EXT3, Filesystem::BTRFS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::EXT3,
    Filesystem $bootvaultfs where Filesystem::EXT2,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::EXT3, Filesystem::EXT2, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::EXT3,
    Filesystem $bootvaultfs where Filesystem::EXT3,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::EXT3, Filesystem::EXT3, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::EXT3,
    Filesystem $bootvaultfs where Filesystem::EXT4,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::EXT3, Filesystem::EXT4, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::EXT3,
    Filesystem $bootvaultfs where Filesystem::F2FS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::EXT3, Filesystem::F2FS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::EXT3,
    Filesystem $bootvaultfs where Filesystem::NILFS2,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::EXT3, Filesystem::NILFS2, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::EXT3,
    Filesystem $bootvaultfs where Filesystem::XFS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::EXT3, Filesystem::XFS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::EXT3,
    Filesystem $bootvaultfs,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::EXT3, Filesystem, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::EXT4,
    Filesystem $bootvaultfs where Filesystem::BTRFS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::EXT4, Filesystem::BTRFS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::EXT4,
    Filesystem $bootvaultfs where Filesystem::EXT2,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::EXT4, Filesystem::EXT2, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::EXT4,
    Filesystem $bootvaultfs where Filesystem::EXT3,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::EXT4, Filesystem::EXT3, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::EXT4,
    Filesystem $bootvaultfs where Filesystem::EXT4,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::EXT4, Filesystem::EXT4, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::EXT4,
    Filesystem $bootvaultfs where Filesystem::F2FS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::EXT4, Filesystem::F2FS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::EXT4,
    Filesystem $bootvaultfs where Filesystem::NILFS2,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::EXT4, Filesystem::NILFS2, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::EXT4,
    Filesystem $bootvaultfs where Filesystem::XFS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::EXT4, Filesystem::XFS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::EXT4,
    Filesystem $bootvaultfs,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::EXT4, Filesystem, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::F2FS,
    Filesystem $bootvaultfs where Filesystem::BTRFS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::F2FS, Filesystem::BTRFS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::F2FS,
    Filesystem $bootvaultfs where Filesystem::EXT2,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::F2FS, Filesystem::EXT2, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::F2FS,
    Filesystem $bootvaultfs where Filesystem::EXT3,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::F2FS, Filesystem::EXT3, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::F2FS,
    Filesystem $bootvaultfs where Filesystem::EXT4,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::F2FS, Filesystem::EXT4, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::F2FS,
    Filesystem $bootvaultfs where Filesystem::F2FS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::F2FS, Filesystem::F2FS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::F2FS,
    Filesystem $bootvaultfs where Filesystem::NILFS2,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::F2FS, Filesystem::NILFS2, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::F2FS,
    Filesystem $bootvaultfs where Filesystem::XFS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::F2FS, Filesystem::XFS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::F2FS,
    Filesystem $bootvaultfs,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::F2FS, Filesystem, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::NILFS2,
    Filesystem $bootvaultfs where Filesystem::BTRFS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::NILFS2, Filesystem::BTRFS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::NILFS2,
    Filesystem $bootvaultfs where Filesystem::EXT2,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::NILFS2, Filesystem::EXT2, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::NILFS2,
    Filesystem $bootvaultfs where Filesystem::EXT3,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::NILFS2, Filesystem::EXT3, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::NILFS2,
    Filesystem $bootvaultfs where Filesystem::EXT4,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::NILFS2, Filesystem::EXT4, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::NILFS2,
    Filesystem $bootvaultfs where Filesystem::F2FS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::NILFS2, Filesystem::F2FS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::NILFS2,
    Filesystem $bootvaultfs where Filesystem::NILFS2,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::NILFS2, Filesystem::NILFS2, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::NILFS2,
    Filesystem $bootvaultfs where Filesystem::XFS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::NILFS2, Filesystem::XFS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::NILFS2,
    Filesystem $bootvaultfs,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::NILFS2, Filesystem, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::XFS,
    Filesystem $bootvaultfs where Filesystem::BTRFS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::XFS, Filesystem::BTRFS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::XFS,
    Filesystem $bootvaultfs where Filesystem::EXT2,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::XFS, Filesystem::EXT2, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::XFS,
    Filesystem $bootvaultfs where Filesystem::EXT3,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::XFS, Filesystem::EXT3, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::XFS,
    Filesystem $bootvaultfs where Filesystem::EXT4,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::XFS, Filesystem::EXT4, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::XFS,
    Filesystem $bootvaultfs where Filesystem::F2FS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::XFS, Filesystem::F2FS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::XFS,
    Filesystem $bootvaultfs where Filesystem::NILFS2,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::XFS, Filesystem::NILFS2, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::XFS,
    Filesystem $bootvaultfs where Filesystem::XFS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::XFS, Filesystem::XFS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::XFS,
    Filesystem $bootvaultfs,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::XFS, Filesystem, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs,
    Filesystem $bootvaultfs where Filesystem::BTRFS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem, Filesystem::BTRFS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs,
    Filesystem $bootvaultfs where Filesystem::EXT2,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem, Filesystem::EXT2, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs,
    Filesystem $bootvaultfs where Filesystem::EXT3,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem, Filesystem::EXT3, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs,
    Filesystem $bootvaultfs where Filesystem::EXT4,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem, Filesystem::EXT4, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs,
    Filesystem $bootvaultfs where Filesystem::F2FS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem, Filesystem::F2FS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs,
    Filesystem $bootvaultfs where Filesystem::NILFS2,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem, Filesystem::NILFS2, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs,
    Filesystem $bootvaultfs where Filesystem::XFS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem, Filesystem::XFS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs,
    Filesystem $bootvaultfs,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem, Filesystem, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

# --- end +lvm }}}
# --- -lvm {{{

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::BTRFS,
    Filesystem $bootvaultfs where Filesystem::BTRFS,
    Bool $lvm
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::BTRFS, Filesystem::BTRFS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::BTRFS,
    Filesystem $bootvaultfs where Filesystem::EXT2,
    Bool $lvm
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::BTRFS, Filesystem::EXT2, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::BTRFS,
    Filesystem $bootvaultfs where Filesystem::EXT3,
    Bool $lvm
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::BTRFS, Filesystem::EXT3, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::BTRFS,
    Filesystem $bootvaultfs where Filesystem::EXT4,
    Bool $lvm
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::BTRFS, Filesystem::EXT4, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::BTRFS,
    Filesystem $bootvaultfs where Filesystem::F2FS,
    Bool $lvm
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::BTRFS, Filesystem::F2FS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::BTRFS,
    Filesystem $bootvaultfs where Filesystem::NILFS2,
    Bool $lvm
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::BTRFS, Filesystem::NILFS2, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::BTRFS,
    Filesystem $bootvaultfs where Filesystem::XFS,
    Bool $lvm
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::BTRFS, Filesystem::XFS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::BTRFS,
    Filesystem $bootvaultfs,
    Bool $lvm
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::BTRFS, Filesystem, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::EXT2,
    Filesystem $bootvaultfs where Filesystem::BTRFS,
    Bool $lvm
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::EXT2, Filesystem::BTRFS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::EXT2,
    Filesystem $bootvaultfs where Filesystem::EXT2,
    Bool $lvm
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::EXT2, Filesystem::EXT2, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::EXT2,
    Filesystem $bootvaultfs where Filesystem::EXT3,
    Bool $lvm
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::EXT2, Filesystem::EXT3, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::EXT2,
    Filesystem $bootvaultfs where Filesystem::EXT4,
    Bool $lvm
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::EXT2, Filesystem::EXT4, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::EXT2,
    Filesystem $bootvaultfs where Filesystem::F2FS,
    Bool $lvm
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::EXT2, Filesystem::F2FS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::EXT2,
    Filesystem $bootvaultfs where Filesystem::NILFS2,
    Bool $lvm
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::EXT2, Filesystem::NILFS2, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::EXT2,
    Filesystem $bootvaultfs where Filesystem::XFS,
    Bool $lvm
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::EXT2, Filesystem::XFS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::EXT2,
    Filesystem $bootvaultfs,
    Bool $lvm
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::EXT2, Filesystem, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::EXT3,
    Filesystem $bootvaultfs where Filesystem::BTRFS,
    Bool $lvm
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::EXT3, Filesystem::BTRFS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::EXT3,
    Filesystem $bootvaultfs where Filesystem::EXT2,
    Bool $lvm
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::EXT3, Filesystem::EXT2, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::EXT3,
    Filesystem $bootvaultfs where Filesystem::EXT3,
    Bool $lvm
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::EXT3, Filesystem::EXT3, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::EXT3,
    Filesystem $bootvaultfs where Filesystem::EXT4,
    Bool $lvm
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::EXT3, Filesystem::EXT4, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::EXT3,
    Filesystem $bootvaultfs where Filesystem::F2FS,
    Bool $lvm
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::EXT3, Filesystem::F2FS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::EXT3,
    Filesystem $bootvaultfs where Filesystem::NILFS2,
    Bool $lvm
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::EXT3, Filesystem::NILFS2, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::EXT3,
    Filesystem $bootvaultfs where Filesystem::XFS,
    Bool $lvm
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::EXT3, Filesystem::XFS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::EXT3,
    Filesystem $bootvaultfs,
    Bool $lvm
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::EXT3, Filesystem, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::EXT4,
    Filesystem $bootvaultfs where Filesystem::BTRFS,
    Bool $lvm
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::EXT4, Filesystem::BTRFS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::EXT4,
    Filesystem $bootvaultfs where Filesystem::EXT2,
    Bool $lvm
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::EXT4, Filesystem::EXT2, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::EXT4,
    Filesystem $bootvaultfs where Filesystem::EXT3,
    Bool $lvm
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::EXT4, Filesystem::EXT3, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::EXT4,
    Filesystem $bootvaultfs where Filesystem::EXT4,
    Bool $lvm
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::EXT4, Filesystem::EXT4, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::EXT4,
    Filesystem $bootvaultfs where Filesystem::F2FS,
    Bool $lvm
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::EXT4, Filesystem::F2FS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::EXT4,
    Filesystem $bootvaultfs where Filesystem::NILFS2,
    Bool $lvm
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::EXT4, Filesystem::NILFS2, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::EXT4,
    Filesystem $bootvaultfs where Filesystem::XFS,
    Bool $lvm
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::EXT4, Filesystem::XFS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::EXT4,
    Filesystem $bootvaultfs,
    Bool $lvm
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::EXT4, Filesystem, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::F2FS,
    Filesystem $bootvaultfs where Filesystem::BTRFS,
    Bool $lvm
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::F2FS, Filesystem::BTRFS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::F2FS,
    Filesystem $bootvaultfs where Filesystem::EXT2,
    Bool $lvm
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::F2FS, Filesystem::EXT2, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::F2FS,
    Filesystem $bootvaultfs where Filesystem::EXT3,
    Bool $lvm
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::F2FS, Filesystem::EXT3, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::F2FS,
    Filesystem $bootvaultfs where Filesystem::EXT4,
    Bool $lvm
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::F2FS, Filesystem::EXT4, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::F2FS,
    Filesystem $bootvaultfs where Filesystem::F2FS,
    Bool $lvm
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::F2FS, Filesystem::F2FS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::F2FS,
    Filesystem $bootvaultfs where Filesystem::NILFS2,
    Bool $lvm
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::F2FS, Filesystem::NILFS2, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::F2FS,
    Filesystem $bootvaultfs where Filesystem::XFS,
    Bool $lvm
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::F2FS, Filesystem::XFS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::F2FS,
    Filesystem $bootvaultfs,
    Bool $lvm
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::F2FS, Filesystem, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::NILFS2,
    Filesystem $bootvaultfs where Filesystem::BTRFS,
    Bool $lvm
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::NILFS2, Filesystem::BTRFS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::NILFS2,
    Filesystem $bootvaultfs where Filesystem::EXT2,
    Bool $lvm
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::NILFS2, Filesystem::EXT2, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::NILFS2,
    Filesystem $bootvaultfs where Filesystem::EXT3,
    Bool $lvm
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::NILFS2, Filesystem::EXT3, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::NILFS2,
    Filesystem $bootvaultfs where Filesystem::EXT4,
    Bool $lvm
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::NILFS2, Filesystem::EXT4, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::NILFS2,
    Filesystem $bootvaultfs where Filesystem::F2FS,
    Bool $lvm
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::NILFS2, Filesystem::F2FS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::NILFS2,
    Filesystem $bootvaultfs where Filesystem::NILFS2,
    Bool $lvm
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::NILFS2, Filesystem::NILFS2, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::NILFS2,
    Filesystem $bootvaultfs where Filesystem::XFS,
    Bool $lvm
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::NILFS2, Filesystem::XFS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::NILFS2,
    Filesystem $bootvaultfs,
    Bool $lvm
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::NILFS2, Filesystem, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::XFS,
    Filesystem $bootvaultfs where Filesystem::BTRFS,
    Bool $lvm
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::XFS, Filesystem::BTRFS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::XFS,
    Filesystem $bootvaultfs where Filesystem::EXT2,
    Bool $lvm
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::XFS, Filesystem::EXT2, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::XFS,
    Filesystem $bootvaultfs where Filesystem::EXT3,
    Bool $lvm
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::XFS, Filesystem::EXT3, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::XFS,
    Filesystem $bootvaultfs where Filesystem::EXT4,
    Bool $lvm
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::XFS, Filesystem::EXT4, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::XFS,
    Filesystem $bootvaultfs where Filesystem::F2FS,
    Bool $lvm
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::XFS, Filesystem::F2FS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::XFS,
    Filesystem $bootvaultfs where Filesystem::NILFS2,
    Bool $lvm
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::XFS, Filesystem::NILFS2, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::XFS,
    Filesystem $bootvaultfs where Filesystem::XFS,
    Bool $lvm
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::XFS, Filesystem::XFS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs where Filesystem::XFS,
    Filesystem $bootvaultfs,
    Bool $lvm
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem::XFS, Filesystem, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs,
    Filesystem $bootvaultfs where Filesystem::BTRFS,
    Bool $lvm
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem, Filesystem::BTRFS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs,
    Filesystem $bootvaultfs where Filesystem::EXT2,
    Bool $lvm
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem, Filesystem::EXT2, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs,
    Filesystem $bootvaultfs where Filesystem::EXT3,
    Bool $lvm
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem, Filesystem::EXT3, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs,
    Filesystem $bootvaultfs where Filesystem::EXT4,
    Bool $lvm
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem, Filesystem::EXT4, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs,
    Filesystem $bootvaultfs where Filesystem::F2FS,
    Bool $lvm
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem, Filesystem::F2FS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs,
    Filesystem $bootvaultfs where Filesystem::NILFS2,
    Bool $lvm
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem, Filesystem::NILFS2, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs,
    Filesystem $bootvaultfs where Filesystem::XFS,
    Bool $lvm
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem, Filesystem::XFS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<1FA>,
    Filesystem $vaultfs,
    Filesystem $bootvaultfs,
    Bool $lvm
]
{
    also does Opts[Mode::<1FA>];
    also does ModeArgs[Mode::<1FA>];
    also does FilesystemArgs[Filesystem, Filesystem, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<1FA>];
}

# --- end -lvm }}}

# end Mode::<1FA> }}}
# Mode::<2FA> {{{

# --- +lvm {{{

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::BTRFS,
    Filesystem $bootvaultfs where Filesystem::BTRFS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::BTRFS, Filesystem::BTRFS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::BTRFS,
    Filesystem $bootvaultfs where Filesystem::EXT2,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::BTRFS, Filesystem::EXT2, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::BTRFS,
    Filesystem $bootvaultfs where Filesystem::EXT3,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::BTRFS, Filesystem::EXT3, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::BTRFS,
    Filesystem $bootvaultfs where Filesystem::EXT4,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::BTRFS, Filesystem::EXT4, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::BTRFS,
    Filesystem $bootvaultfs where Filesystem::F2FS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::BTRFS, Filesystem::F2FS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::BTRFS,
    Filesystem $bootvaultfs where Filesystem::NILFS2,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::BTRFS, Filesystem::NILFS2, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::BTRFS,
    Filesystem $bootvaultfs where Filesystem::XFS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::BTRFS, Filesystem::XFS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::BTRFS,
    Filesystem $bootvaultfs,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::BTRFS, Filesystem, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::EXT2,
    Filesystem $bootvaultfs where Filesystem::BTRFS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::EXT2, Filesystem::BTRFS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::EXT2,
    Filesystem $bootvaultfs where Filesystem::EXT2,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::EXT2, Filesystem::EXT2, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::EXT2,
    Filesystem $bootvaultfs where Filesystem::EXT3,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::EXT2, Filesystem::EXT3, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::EXT2,
    Filesystem $bootvaultfs where Filesystem::EXT4,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::EXT2, Filesystem::EXT4, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::EXT2,
    Filesystem $bootvaultfs where Filesystem::F2FS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::EXT2, Filesystem::F2FS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::EXT2,
    Filesystem $bootvaultfs where Filesystem::NILFS2,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::EXT2, Filesystem::NILFS2, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::EXT2,
    Filesystem $bootvaultfs where Filesystem::XFS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::EXT2, Filesystem::XFS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::EXT2,
    Filesystem $bootvaultfs,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::EXT2, Filesystem, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::EXT3,
    Filesystem $bootvaultfs where Filesystem::BTRFS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::EXT3, Filesystem::BTRFS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::EXT3,
    Filesystem $bootvaultfs where Filesystem::EXT2,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::EXT3, Filesystem::EXT2, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::EXT3,
    Filesystem $bootvaultfs where Filesystem::EXT3,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::EXT3, Filesystem::EXT3, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::EXT3,
    Filesystem $bootvaultfs where Filesystem::EXT4,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::EXT3, Filesystem::EXT4, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::EXT3,
    Filesystem $bootvaultfs where Filesystem::F2FS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::EXT3, Filesystem::F2FS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::EXT3,
    Filesystem $bootvaultfs where Filesystem::NILFS2,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::EXT3, Filesystem::NILFS2, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::EXT3,
    Filesystem $bootvaultfs where Filesystem::XFS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::EXT3, Filesystem::XFS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::EXT3,
    Filesystem $bootvaultfs,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::EXT3, Filesystem, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::EXT4,
    Filesystem $bootvaultfs where Filesystem::BTRFS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::EXT4, Filesystem::BTRFS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::EXT4,
    Filesystem $bootvaultfs where Filesystem::EXT2,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::EXT4, Filesystem::EXT2, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::EXT4,
    Filesystem $bootvaultfs where Filesystem::EXT3,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::EXT4, Filesystem::EXT3, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::EXT4,
    Filesystem $bootvaultfs where Filesystem::EXT4,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::EXT4, Filesystem::EXT4, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::EXT4,
    Filesystem $bootvaultfs where Filesystem::F2FS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::EXT4, Filesystem::F2FS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::EXT4,
    Filesystem $bootvaultfs where Filesystem::NILFS2,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::EXT4, Filesystem::NILFS2, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::EXT4,
    Filesystem $bootvaultfs where Filesystem::XFS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::EXT4, Filesystem::XFS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::EXT4,
    Filesystem $bootvaultfs,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::EXT4, Filesystem, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::F2FS,
    Filesystem $bootvaultfs where Filesystem::BTRFS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::F2FS, Filesystem::BTRFS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::F2FS,
    Filesystem $bootvaultfs where Filesystem::EXT2,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::F2FS, Filesystem::EXT2, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::F2FS,
    Filesystem $bootvaultfs where Filesystem::EXT3,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::F2FS, Filesystem::EXT3, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::F2FS,
    Filesystem $bootvaultfs where Filesystem::EXT4,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::F2FS, Filesystem::EXT4, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::F2FS,
    Filesystem $bootvaultfs where Filesystem::F2FS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::F2FS, Filesystem::F2FS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::F2FS,
    Filesystem $bootvaultfs where Filesystem::NILFS2,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::F2FS, Filesystem::NILFS2, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::F2FS,
    Filesystem $bootvaultfs where Filesystem::XFS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::F2FS, Filesystem::XFS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::F2FS,
    Filesystem $bootvaultfs,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::F2FS, Filesystem, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::NILFS2,
    Filesystem $bootvaultfs where Filesystem::BTRFS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::NILFS2, Filesystem::BTRFS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::NILFS2,
    Filesystem $bootvaultfs where Filesystem::EXT2,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::NILFS2, Filesystem::EXT2, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::NILFS2,
    Filesystem $bootvaultfs where Filesystem::EXT3,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::NILFS2, Filesystem::EXT3, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::NILFS2,
    Filesystem $bootvaultfs where Filesystem::EXT4,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::NILFS2, Filesystem::EXT4, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::NILFS2,
    Filesystem $bootvaultfs where Filesystem::F2FS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::NILFS2, Filesystem::F2FS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::NILFS2,
    Filesystem $bootvaultfs where Filesystem::NILFS2,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::NILFS2, Filesystem::NILFS2, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::NILFS2,
    Filesystem $bootvaultfs where Filesystem::XFS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::NILFS2, Filesystem::XFS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::NILFS2,
    Filesystem $bootvaultfs,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::NILFS2, Filesystem, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::XFS,
    Filesystem $bootvaultfs where Filesystem::BTRFS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::XFS, Filesystem::BTRFS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::XFS,
    Filesystem $bootvaultfs where Filesystem::EXT2,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::XFS, Filesystem::EXT2, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::XFS,
    Filesystem $bootvaultfs where Filesystem::EXT3,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::XFS, Filesystem::EXT3, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::XFS,
    Filesystem $bootvaultfs where Filesystem::EXT4,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::XFS, Filesystem::EXT4, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::XFS,
    Filesystem $bootvaultfs where Filesystem::F2FS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::XFS, Filesystem::F2FS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::XFS,
    Filesystem $bootvaultfs where Filesystem::NILFS2,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::XFS, Filesystem::NILFS2, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::XFS,
    Filesystem $bootvaultfs where Filesystem::XFS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::XFS, Filesystem::XFS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::XFS,
    Filesystem $bootvaultfs,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::XFS, Filesystem, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs,
    Filesystem $bootvaultfs where Filesystem::BTRFS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem, Filesystem::BTRFS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs,
    Filesystem $bootvaultfs where Filesystem::EXT2,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem, Filesystem::EXT2, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs,
    Filesystem $bootvaultfs where Filesystem::EXT3,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem, Filesystem::EXT3, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs,
    Filesystem $bootvaultfs where Filesystem::EXT4,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem, Filesystem::EXT4, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs,
    Filesystem $bootvaultfs where Filesystem::F2FS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem, Filesystem::F2FS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs,
    Filesystem $bootvaultfs where Filesystem::NILFS2,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem, Filesystem::NILFS2, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs,
    Filesystem $bootvaultfs where Filesystem::XFS,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem, Filesystem::XFS, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs,
    Filesystem $bootvaultfs,
    Bool:D $lvm where .so
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem, Filesystem, True];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

# --- end +lvm }}}
# --- -lvm {{{

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::BTRFS,
    Filesystem $bootvaultfs where Filesystem::BTRFS,
    Bool $lvm
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::BTRFS, Filesystem::BTRFS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::BTRFS,
    Filesystem $bootvaultfs where Filesystem::EXT2,
    Bool $lvm
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::BTRFS, Filesystem::EXT2, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::BTRFS,
    Filesystem $bootvaultfs where Filesystem::EXT3,
    Bool $lvm
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::BTRFS, Filesystem::EXT3, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::BTRFS,
    Filesystem $bootvaultfs where Filesystem::EXT4,
    Bool $lvm
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::BTRFS, Filesystem::EXT4, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::BTRFS,
    Filesystem $bootvaultfs where Filesystem::F2FS,
    Bool $lvm
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::BTRFS, Filesystem::F2FS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::BTRFS,
    Filesystem $bootvaultfs where Filesystem::NILFS2,
    Bool $lvm
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::BTRFS, Filesystem::NILFS2, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::BTRFS,
    Filesystem $bootvaultfs where Filesystem::XFS,
    Bool $lvm
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::BTRFS, Filesystem::XFS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::BTRFS,
    Filesystem $bootvaultfs,
    Bool $lvm
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::BTRFS, Filesystem, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::EXT2,
    Filesystem $bootvaultfs where Filesystem::BTRFS,
    Bool $lvm
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::EXT2, Filesystem::BTRFS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::EXT2,
    Filesystem $bootvaultfs where Filesystem::EXT2,
    Bool $lvm
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::EXT2, Filesystem::EXT2, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::EXT2,
    Filesystem $bootvaultfs where Filesystem::EXT3,
    Bool $lvm
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::EXT2, Filesystem::EXT3, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::EXT2,
    Filesystem $bootvaultfs where Filesystem::EXT4,
    Bool $lvm
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::EXT2, Filesystem::EXT4, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::EXT2,
    Filesystem $bootvaultfs where Filesystem::F2FS,
    Bool $lvm
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::EXT2, Filesystem::F2FS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::EXT2,
    Filesystem $bootvaultfs where Filesystem::NILFS2,
    Bool $lvm
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::EXT2, Filesystem::NILFS2, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::EXT2,
    Filesystem $bootvaultfs where Filesystem::XFS,
    Bool $lvm
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::EXT2, Filesystem::XFS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::EXT2,
    Filesystem $bootvaultfs,
    Bool $lvm
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::EXT2, Filesystem, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::EXT3,
    Filesystem $bootvaultfs where Filesystem::BTRFS,
    Bool $lvm
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::EXT3, Filesystem::BTRFS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::EXT3,
    Filesystem $bootvaultfs where Filesystem::EXT2,
    Bool $lvm
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::EXT3, Filesystem::EXT2, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::EXT3,
    Filesystem $bootvaultfs where Filesystem::EXT3,
    Bool $lvm
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::EXT3, Filesystem::EXT3, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::EXT3,
    Filesystem $bootvaultfs where Filesystem::EXT4,
    Bool $lvm
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::EXT3, Filesystem::EXT4, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::EXT3,
    Filesystem $bootvaultfs where Filesystem::F2FS,
    Bool $lvm
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::EXT3, Filesystem::F2FS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::EXT3,
    Filesystem $bootvaultfs where Filesystem::NILFS2,
    Bool $lvm
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::EXT3, Filesystem::NILFS2, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::EXT3,
    Filesystem $bootvaultfs where Filesystem::XFS,
    Bool $lvm
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::EXT3, Filesystem::XFS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::EXT3,
    Filesystem $bootvaultfs,
    Bool $lvm
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::EXT3, Filesystem, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::EXT4,
    Filesystem $bootvaultfs where Filesystem::BTRFS,
    Bool $lvm
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::EXT4, Filesystem::BTRFS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::EXT4,
    Filesystem $bootvaultfs where Filesystem::EXT2,
    Bool $lvm
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::EXT4, Filesystem::EXT2, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::EXT4,
    Filesystem $bootvaultfs where Filesystem::EXT3,
    Bool $lvm
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::EXT4, Filesystem::EXT3, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::EXT4,
    Filesystem $bootvaultfs where Filesystem::EXT4,
    Bool $lvm
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::EXT4, Filesystem::EXT4, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::EXT4,
    Filesystem $bootvaultfs where Filesystem::F2FS,
    Bool $lvm
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::EXT4, Filesystem::F2FS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::EXT4,
    Filesystem $bootvaultfs where Filesystem::NILFS2,
    Bool $lvm
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::EXT4, Filesystem::NILFS2, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::EXT4,
    Filesystem $bootvaultfs where Filesystem::XFS,
    Bool $lvm
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::EXT4, Filesystem::XFS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::EXT4,
    Filesystem $bootvaultfs,
    Bool $lvm
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::EXT4, Filesystem, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::F2FS,
    Filesystem $bootvaultfs where Filesystem::BTRFS,
    Bool $lvm
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::F2FS, Filesystem::BTRFS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::F2FS,
    Filesystem $bootvaultfs where Filesystem::EXT2,
    Bool $lvm
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::F2FS, Filesystem::EXT2, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::F2FS,
    Filesystem $bootvaultfs where Filesystem::EXT3,
    Bool $lvm
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::F2FS, Filesystem::EXT3, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::F2FS,
    Filesystem $bootvaultfs where Filesystem::EXT4,
    Bool $lvm
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::F2FS, Filesystem::EXT4, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::F2FS,
    Filesystem $bootvaultfs where Filesystem::F2FS,
    Bool $lvm
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::F2FS, Filesystem::F2FS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::F2FS,
    Filesystem $bootvaultfs where Filesystem::NILFS2,
    Bool $lvm
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::F2FS, Filesystem::NILFS2, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::F2FS,
    Filesystem $bootvaultfs where Filesystem::XFS,
    Bool $lvm
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::F2FS, Filesystem::XFS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::F2FS,
    Filesystem $bootvaultfs,
    Bool $lvm
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::F2FS, Filesystem, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::NILFS2,
    Filesystem $bootvaultfs where Filesystem::BTRFS,
    Bool $lvm
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::NILFS2, Filesystem::BTRFS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::NILFS2,
    Filesystem $bootvaultfs where Filesystem::EXT2,
    Bool $lvm
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::NILFS2, Filesystem::EXT2, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::NILFS2,
    Filesystem $bootvaultfs where Filesystem::EXT3,
    Bool $lvm
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::NILFS2, Filesystem::EXT3, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::NILFS2,
    Filesystem $bootvaultfs where Filesystem::EXT4,
    Bool $lvm
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::NILFS2, Filesystem::EXT4, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::NILFS2,
    Filesystem $bootvaultfs where Filesystem::F2FS,
    Bool $lvm
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::NILFS2, Filesystem::F2FS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::NILFS2,
    Filesystem $bootvaultfs where Filesystem::NILFS2,
    Bool $lvm
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::NILFS2, Filesystem::NILFS2, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::NILFS2,
    Filesystem $bootvaultfs where Filesystem::XFS,
    Bool $lvm
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::NILFS2, Filesystem::XFS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::NILFS2,
    Filesystem $bootvaultfs,
    Bool $lvm
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::NILFS2, Filesystem, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::XFS,
    Filesystem $bootvaultfs where Filesystem::BTRFS,
    Bool $lvm
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::XFS, Filesystem::BTRFS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::XFS,
    Filesystem $bootvaultfs where Filesystem::EXT2,
    Bool $lvm
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::XFS, Filesystem::EXT2, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::XFS,
    Filesystem $bootvaultfs where Filesystem::EXT3,
    Bool $lvm
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::XFS, Filesystem::EXT3, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::XFS,
    Filesystem $bootvaultfs where Filesystem::EXT4,
    Bool $lvm
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::XFS, Filesystem::EXT4, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::XFS,
    Filesystem $bootvaultfs where Filesystem::F2FS,
    Bool $lvm
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::XFS, Filesystem::F2FS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::XFS,
    Filesystem $bootvaultfs where Filesystem::NILFS2,
    Bool $lvm
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::XFS, Filesystem::NILFS2, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::XFS,
    Filesystem $bootvaultfs where Filesystem::XFS,
    Bool $lvm
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::XFS, Filesystem::XFS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs where Filesystem::XFS,
    Filesystem $bootvaultfs,
    Bool $lvm
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem::XFS, Filesystem, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs,
    Filesystem $bootvaultfs where Filesystem::BTRFS,
    Bool $lvm
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem, Filesystem::BTRFS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs,
    Filesystem $bootvaultfs where Filesystem::EXT2,
    Bool $lvm
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem, Filesystem::EXT2, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs,
    Filesystem $bootvaultfs where Filesystem::EXT3,
    Bool $lvm
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem, Filesystem::EXT3, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs,
    Filesystem $bootvaultfs where Filesystem::EXT4,
    Bool $lvm
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem, Filesystem::EXT4, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs,
    Filesystem $bootvaultfs where Filesystem::F2FS,
    Bool $lvm
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem, Filesystem::F2FS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs,
    Filesystem $bootvaultfs where Filesystem::NILFS2,
    Bool $lvm
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem, Filesystem::NILFS2, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs,
    Filesystem $bootvaultfs where Filesystem::XFS,
    Bool $lvm
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem, Filesystem::XFS, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode where Mode::<2FA>,
    Filesystem $vaultfs,
    Filesystem $bootvaultfs,
    Bool $lvm
]
{
    also does Opts[Mode::<2FA>];
    also does ModeArgs[Mode::<2FA>];
    also does FilesystemArgs[Filesystem, Filesystem, False];
    also does OptsStrict;
    also does GetArgs;
    also does GetOpts;
    also does Retrospective;
    also does ToConfig[Mode::<2FA>];
}

# --- end -lvm }}}

# end Mode::<2FA> }}}

class Voidvault::ConfigArgs
{
    has Voidvault::ConfigArgs::Parser $!parser is required;

    submethod BUILD(Voidvault::ConfigArgs::Parser :$!parser!)
    {*}

    method new(*@arg, *%opts --> Voidvault::ConfigArgs:D)
    {
        my List:D $args = try args(@arg);
        bail($!.message) if $!;

        my $parser = try Voidvault::ConfigArgs::Parser[|$args].new(|%opts);
        bail($!.message) if $!;

        self.bless(:$parser);
    }

    # three+ positional args present
    multi sub args(@arg ($, $, $, *@) --> List:D)
    {
        my UInt:D $extra = @arg.elems - $MAX-COUNT-POSITIONAL-ARGS;
        die(X::Voidvault::ConfigArgs::Positional::Extraneous.new(:$extra));
    }

    # two positional args present
    multi sub args(*@ ($a, $b, *@) --> List:D)
    {
        # expect to receive both mode and filesystem or error because
        # two positional args present
        my List:D $args =
            my (Mode:D $mode,
                Filesystem:D $vaultfs,
                Filesystem $bootvaultfs,
                Bool $lvm) = parse-mode-and-fs($a, $b);
    }

    # one positional arg present
    multi sub args(*@ ($a, *@) --> List:D)
    {
        # expect to receive mode or filesystem, however mode is guaranteed
        my List:D $args =
            my (Mode:D $mode,
                Filesystem $vaultfs,
                Filesystem $bootvaultfs,
                Bool $lvm) = parse-mode-or-fs($a);
    }

    # no positional args present
    multi sub args(*@ --> List:D)
    {
        # mode defaults to base
        my List:D $args = (Mode::BASE, Filesystem, Filesystem, Bool);
    }

    multi sub parse-mode-and-fs(
        $a,
        $b,
        *%opts (Bool :ran-once($))
        --> List:D
    )
    {
        # facilitate passing mode and fs positional args in any order
        CATCH { when X::Voidvault::Parser::Mode::Invalid { .resume }
                when X::Voidvault::Parser::Filesystem::Invalid { .resume } }

        # attempt to parse first positional arg as mode, second as fs
        my (Mode $mode, List $filesystem) =
            Voidvault::Parser::Mode.parse($a),
            Voidvault::Parser::Filesystem.parse($b);

        parse-mode-and-fs($a, $b, :$mode, :$filesystem, |%opts);
    }

    multi sub parse-mode-and-fs(
        $,
        $,
        :$mode! where .so,
        :$filesystem! where .so,
        *% (Bool :ran-once($))
        --> List:D
    )
    {
        ($mode, |$filesystem);
    }

    multi sub parse-mode-and-fs(
        $,
        $b,
        :mode($)! where .so,
        :filesystem($)!,
        *% (Bool :ran-once($))
        --> List:D
    )
    {
        die(X::Voidvault::ConfigArgs::Positional::Invalid['fs'].new(:fs($b)));
    }

    multi sub parse-mode-and-fs(
        $a,
        $,
        :filesystem($)! where .so,
        :mode($)!,
        *% (Bool :ran-once($))
        --> List:D
    )
    {
        die(X::Voidvault::ConfigArgs::Positional::Invalid['mode'].new(:mode($a)));
    }

    multi sub parse-mode-and-fs(
        $a,
        $b,
        :mode($)!,
        :filesystem($)!,
        # prevent infinite loop
        Bool:D :ran-once($)! where .so
        --> List:D
    )
    {
        # un-reverse order of mode and filesystem for better error message
        die(X::Voidvault::ConfigArgs::Positional::Invalid['mode+fs'].new(:mode($b), :fs($a)));
    }

    multi sub parse-mode-and-fs(
        $a,
        $b,
        :mode($)!,
        :filesystem($)!,
        *% (Bool :ran-once($))
        --> List:D
    )
    {
        # attempt to parse first positional arg as filesystem, second as mode
        parse-mode-and-fs($b, $a, :ran-once);
    }

    sub parse-mode-or-fs($a --> List:D)
    {
        # facilitate passing either mode or fs as positional arg
        CATCH { when X::Voidvault::Parser::Mode::Invalid { .resume }
                when X::Voidvault::Parser::Filesystem::Invalid { .resume } }

        # attempt to parse positional arg as mode
        with Voidvault::Parser::Mode.parse($a)
        {
            return ($^a, Filesystem, Filesystem, Bool) if $^a;
        }

        # attempt to parse positional arg as filesystem
        with Voidvault::Parser::Filesystem.parse($a)
        {
            # mode defaults to base
            return (Mode::BASE, |$^a) if $^a;
        }

        die(X::Voidvault::ConfigArgs::Positional::Invalid['mode|fs'].new(:content($a)));
    }

    method Voidvault::Config(::?CLASS:D: --> Voidvault::Config:D)
    {
        my Voidvault::Config $config = Voidvault::Config($!parser);
    }
}

sub bail(Str:D $message)
{
    note($message);
    note('');
    my Str:D $subject = 'new';
    Voidvault::ConfigArgs::Utils.USAGE(:$subject, :error);
    exit(1);
}

sub get-attribute-name(Attribute:D $attribute --> Str:D)
{
    my Str:D $name = $attribute.name.substr(2);
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
