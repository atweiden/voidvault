use v6;
use Voidvault::Config;
use Voidvault::Config::Base;
use Voidvault::Config::OneFA;
use Voidvault::ConfigArgs::Utils;
use Voidvault::Types;

my role Args[Mode:D $ where Mode::BASE]
{
    has Str $.admin-name;
    has Str $.admin-pass;
    has Str $.admin-pass-hash;
    has Bool $.augment;
    has Str $.chroot-dir;
    has Str $.device;
    has Bool $.disable-ipv6;
    has Str $.disk-type;
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
    has Str $.vault-key;
}

my role Args[Mode:D $ where Mode::<1FA>]
{
    also does Args[Mode::BASE];
    has Str $.bootvault-name;
    has Str $.bootvault-pass;
    has Str $.bootvault-key;
    has Str $.vault-header;
}

my role Args[Mode:D $ where Mode::<2FA>]
{
    also does Args[Mode::<1FA>];
    has Str $.bootvault-device;
}

my role Opts
{
    # alternative to duplicating code in C<Mode::<1FA>>, C<Mode::<2FA>>
    method opts(::?CLASS:D: --> Hash:D)
    {
        # list all attributes (think: C<Voidvault::ConfigArgs::Parser>)
        my List $attributes = self.^attributes(:local);
        # C<Attribute.get_value> requires C<self>, no multi methods now
        my $*self = self;
        my %opts = opts(:$attributes);
    }

    multi sub opts(List :$attributes! --> Hash:D)
    {
        my Pair:D @opt = $attributes.map(-> Attribute:D $attribute {
            opts(:$attribute);
        });
        my %opts = @opt.hash;
    }

    multi sub opts(Attribute:D :$attribute! --> Pair:D)
    {
        my Str:D $name = get-attribute-name($attribute);
        my \value = $attribute.get_value($*self);
        opts($name, value);
    }

    # untyped repository array must become C<Array[Str:D]>
    multi sub opts(Str:D $name where 'repository', \value where .so --> Pair:D)
    {
        my Str:D @value = |value;
        my Pair:D $name-value = $name => @value;
    }

    multi sub opts(Str:D $name where 'repository', \value --> Pair:D)
    {
        my Str:D @value;
        my Pair:D $name-value = $name => @value;
    }

    multi sub opts(Str:D $name, \value --> Pair:D)
    {
        my Pair:D $name-value = $name => value;
    }
}

my role Strict
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
        Voidvault::Config::Base.new(|self.opts);
    }
}

my role ToConfig[Mode:D $ where Mode::<1FA>]
{
    method Voidvault::Config(::?CLASS:D: --> Voidvault::Config::OneFA:D)
    {
        Voidvault::Config::OneFA.new(|self.opts);
    }
}

my role ToConfig[Mode:D $ where Mode::<2FA>]
{
    method Voidvault::Config(::?CLASS:D: --> Voidvault::Config::TwoFA:D)
    {
        Voidvault::Config::TwoFA.new(|self.opts);
    }
}

my role Voidvault::ConfigArgs::Parser[Mode:D $ where Mode::BASE]
{
    also does Args[Mode::BASE];
    also does Opts;
    also does Strict;
    also does ToConfig[Mode::BASE];
}

my role Voidvault::ConfigArgs::Parser[Mode:D $ where Mode::<1FA>]
{
    also does Args[Mode::<1FA>];
    also does Opts;
    also does Strict;
    also does ToConfig[Mode::<1FA>];
}

my role Voidvault::ConfigArgs::Parser[Mode:D $ where Mode::<2FA>]
{
    also does Args[Mode::<2FA>];
    also does Opts;
    also does Strict;
    also does ToConfig[Mode::<2FA>];
}

class Voidvault::ConfigArgs
{
    has Voidvault::ConfigArgs::Parser $!parser is required;

    submethod BUILD(Voidvault::ConfigArgs::Parser :$!parser!)
    {*}

    method new(Str :mode($m), *%opts --> Voidvault::ConfigArgs:D)
    {
        my Mode:D $mode = Voidvault::ConfigArgs::Utils.gen-mode(:mode($m));
        my $parser = try Voidvault::ConfigArgs::Parser[$mode].bless(|%opts);
        bail($!.message) if $!;
        self.bless(:$parser);
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
