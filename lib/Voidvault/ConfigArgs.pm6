use v6;
use Voidvault::Config;
use Voidvault::Config::Base;
use Voidvault::Config::OneFA;
use Voidvault::Config::TwoFA;
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

# C<FilesystemArgs> stores positional argument pertaining to filesystem
# setup without interfering with C<GetOpts>' ability to iterate through
# cmdline opts, by way of recording positional argument as parameterized
# variables and then reporting those variables via methods (C<vaultfs>,
# C<bootvaultfs>, and C<lvm>)
my role FilesystemArgs[
    Filesystem $vaultfs,
    Filesystem $bootvaultfs,
    # user didn't pass C<+lvm> on cmdline
    Bool:D $lvm where .not
]
{
    method vaultfs(--> Str) { $vaultfs }
    method bootvaultfs(--> Str) { $bootvaultfs }
    method lvm(--> Bool) { $lvm }
}

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
    also does FilesystemArgs[$vaultfs, $bootvaultfs, False];

    # lvm vg name opt accepted since user passed C<+lvm> on cmdline
    has Str $.lvm-vg-name;

    # necessary override
    method lvm(--> Bool) { $lvm }
}

# C<GetOpts> provides method C<get-opts> for iterating through attributes.
# When mixed in to role C<Voidvault::ConfigArgs::Parser>, these attributes
# reflect proper cmdline options the valid set of which changes dynamically
# based on positional arguments. C<GetOpts> doesn't iterate through these
# positional arguments, however.
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

# C<OptsStrict> rejects invalid cmdline options.
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

my role ToConfig[Mode:D $ where Mode::BASE]
{
    method Voidvault::Config(::?CLASS:D: --> Voidvault::Config::Base:D)
    {
        Voidvault::Config::Base.new(|self.get-opts);
    }
}

my role ToConfig[Mode:D $ where Mode::<1FA>]
{
    method Voidvault::Config(::?CLASS:D: --> Voidvault::Config::OneFA:D)
    {
        Voidvault::Config::OneFA.new(|self.get-opts);
    }
}

my role ToConfig[Mode:D $ where Mode::<2FA>]
{
    method Voidvault::Config(::?CLASS:D: --> Voidvault::Config::TwoFA:D)
    {
        Voidvault::Config::TwoFA.new(|self.get-opts);
    }
}

my role Voidvault::ConfigArgs::Parser[
    Mode:D $mode,
    Filesystem $vaultfs,
    Filesystem $bootvaultfs,
    Bool $lvm
]
{
    also does Opts[$mode];
    also does FilesystemArgs[$vaultfs, $bootvaultfs, $lvm];
    also does OptsStrict;
    also does GetOpts;
    also does ToConfig[$mode];
}

class Voidvault::ConfigArgs
{
    has Voidvault::ConfigArgs::Parser $!parser is required;

    submethod BUILD(Voidvault::ConfigArgs::Parser :$!parser!)
    {*}

    method new(*@arg, *%opts --> Voidvault::ConfigArgs:D)
    {
        my List:D $args = try args(@arg);
        bail($!.message) if $!;

        my $parser = try Voidvault::ConfigArgs::Parser[|$args].bless(|%opts);
        bail($!.message) if $!;

        self.bless(:$parser);
    }

    multi sub args(*@ ($a, $b, *@) --> List:D)
    {
        # both C<$mode> and C<$filesystem> expected since two positional args
        my (Mode:D $mode, List:D $filesystem) = parse-mode-filesystem($a, $b);

        # C<Mode $mode, Filesystem $vaultfs, Filesystem $bootvaultfs, Bool $lvm>
        my List:D $args = ($mode, |$filesystem);
    }

    multi sub args(*@ ($a, *@) --> List:D)
    {
        CATCH { when X::Voidvault::Parser::Mode::Invalid { .resume }
                when X::Voidvault::Parser::Filesystem::Invalid { .resume } }

        # attempt to parse first positional arg as mode
        with Voidvault::Parser::Mode.parse($a)
        {
            return ($^a, Filesystem, Filesystem, Bool) if $^a;
        }

        # attempt to parse first positional arg as filesystem
        with Voidvault::Parser::Filesystem.parse($a)
        {
            # mode defaults to base
            return (Mode::BASE, |$^a) if $^a;
        }

        die(X::Voidvault::ConfigArgs::Positional::Invalid['mode|fs'].new(:content($a)));
    }

    multi sub args(*@ --> List:D)
    {
        # mode defaults to base
        my List:D $args = (Mode::BASE, Filesystem, Filesystem, Bool);
    }

    sub parse-mode-filesystem($a, $b --> List:D)
    {
        # prevent infinite loop
        state $already-tried = False;

        # facilitate passing mode and fs positional args in any order
        CATCH { when X::Voidvault::Parser::Mode::Invalid { .resume }
                when X::Voidvault::Parser::Filesystem::Invalid { .resume } }

        # attempt to parse first positional arg as mode, second as fs
        my (Mode $mode, List $filesystem) =
            Voidvault::Parser::Mode.parse($a),
            Voidvault::Parser::Filesystem.parse($b);

        given ($mode.so, $filesystem.so)
        {
            when (True, True)
            { break ($mode, $filesystem); }
            when (True, False)
            { die(X::Voidvault::ConfigArgs::Positional::Invalid['fs'].new(:fs($b))); }
            when (False, True)
            { die(X::Voidvault::ConfigArgs::Positional::Invalid['mode'].new(:mode($a))); }
            when (False, False)
            { die(X::Voidvault::ConfigArgs::Positional::Invalid['mode+fs'].new(:mode($a), :fs($b)))
                  if $already-tried;
              $already-tried = True;
              # attempt to parse second positional arg as mode, first as fs
              parse-mode-filesystem($b, $a); }
        }
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
