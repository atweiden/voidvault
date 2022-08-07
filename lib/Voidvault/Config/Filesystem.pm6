use v6;
use Voidvault::Parser::Filesystem;
use Voidvault::Types;

my role Base[
    Filesystem:D $vaultfs,
    Filesystem:D $bootvaultfs,
    Bool:D $lvm where .not
]
{
    # filesystem for vault
    method vaultfs(--> Filesystem:D) { $vaultfs }

    # filesystem for bootvault
    method bootvaultfs(--> Filesystem:D) { $bootvaultfs }

    # whether to create vault filesystem on lvm
    method lvm(--> Bool:D) { $lvm }
}

my role Base[
    Filesystem:D $vaultfs,
    Filesystem:D $bootvaultfs,
    Bool:D $lvm where .so
]
{
    also does Base[$vaultfs, $bootvaultfs, False];

    has LvmVolumeGroupName:D $.lvm-vg-name =
        ?%*ENV<VOIDVAULT_LVM_VG_NAME>
            ?? %*ENV<VOIDVAULT_LVM_VG_NAME>
            !! 'vg0';
}

class Voidvault::Config::Filesystem
{
    multi method new(Str:D $filesystem --> Voidvault::Config::Filesystem:D)
    {
        my %filesystem = try Voidvault::Parser::Filesystem.parse($filesystem);
    }

    multi method new(--> Voidvault::Config::Filesystem:D)
    {
        self.bless;
    }

    multi sub new(
        Filesystem:D $ where Filesystem::BTRFS,
        Filesystem:D $,
        Bool:D $ where .so
        --> Nil
    )
    {
        die("Sorry, Btrfs can't be paired with LVM");
    }

    multi sub new(
        Filesystem:D $vaultfs,
        Filesystem:D $bootvaultfs,
        Bool:D $lvm
        --> Voidvault::Config::Filesystem:D
    )
    {
    }
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
