use v6;
use Voidvault::Config::Utils;
use Voidvault::Parser::Filesystem;
use Voidvault::Types;
use X::Voidvault::Config::Filesystem;

# default filesystem for vault
my constant $DEFAULT-VAULTFS = Filesystem::BTRFS;

my role Lvm[Bool:D $ where .so]
{
    # name for lvm volume group
    has LvmVolumeGroupName:D $.lvm-vg-name =
        ?%*ENV<VOIDVAULT_LVM_VG_NAME>
            ?? Voidvault::Config::Utils.gen-lvm-vg-name(%*ENV<VOIDVAULT_LVM_VG_NAME>)
            !! prompt-name(:lvm-vg);

    # whether to create vault filesystem on lvm
    method lvm(--> Bool:D) { True }
}

my role Lvm[Bool $]
{
    method lvm(--> Bool:D) { False }
}

my role FsVault
{
    # filesystem for vault
    has Filesystem:D $.vault is required;
}

my role FsBootvault
{
    # filesystem for bootvault
    has Filesystem:D $.bootvault is required;
}

my role Fs[Mode:D $ where Mode::BASE, Bool:D $ where .so]
{
    also does Lvm[True];
    also does FsVault;
}

my role Fs[Mode:D $ where Mode::BASE, Bool $]
{
    also does Lvm[False];
    also does FsVault;
}

my role Fs[Mode:D $, Bool:D $ where .so]
{
    also does Fs[Mode::BASE, True];
    also does FsBootvault;
}

my role Fs[Mode:D $, Bool $]
{
    also does Fs[Mode::BASE, False];
    also does FsBootvault;
}

class Voidvault::Config::Filesystem
{
    has Fs:D $.fs is required;

    # handle environment variable C<VOIDVAULT_LVM_VG_NAME> absent any
    # fs cmdline positional args
    multi method new(
        Mode:D $mode,
        Str:D $content
        --> Voidvault::Config::Filesystem:D
    )
    {
        # TODO: gracefully handle error case
        my List:D $filesystem = Voidvault::Parser::Filesystem.parse($content);
        # TODO: also pass in C<--lvm-vg-name> cmdline option
        my Fs:D $fs = fs($mode, |$filesystem);
        self.bless(:$fs);
    }

    # handle direct invocation via fs cmdline positional args
    multi method new(
        Mode:D $mode,
        Filesystem $vaultfs,
        Filesystem $bootvaultfs,
        Bool $lvm,
        *%opts (
            Str :lvm-vg-name($),
            # for api convenience++, esp from C<Voidvault::ConfigArgs>
            *%
        )
        --> Voidvault::Config::Filesystem:D
    )
    {
        my Fs:D $fs = fs($mode, $vaultfs, $bootvaultfs, $lvm, |%opts);
        self.bless(:$fs);
    }

    proto sub fs(
        Mode:D $,
        Filesystem $vaultfs,
        Filesystem $,
        Bool $,
        *% (
            Str :lvm-vg-name($),
            *%
        )
        --> Fs:D
    )
    {
        my %*opts;

        %*opts<vault> = $vaultfs ?? $vaultfs !! $DEFAULT-VAULTFS;

        # either error or get C<%*opts<bootvault>> if applicable
        {*}

        %*opts<lvm-vg-name> =
            Voidvault::Config::Utils.gen-lvm-vg-name($lvm-vg-name)
                if $lvm-vg-name;

        my Fs:D $fs = Fs[$mode, $lvm].new(|%*opts);
    }

    multi sub fs(
        Mode:D $ where Mode::BASE,
        Filesystem $,
        Filesystem:D $ where .so,
        Bool $,
        *% (
            Str :lvm-vg-name($),
            *%
        )
        --> Fs:D
    )
    {
        die(X::Voidvault::Config::Filesystem::Impermissible['base+bootvaultfs'].new);
    }

    multi sub fs(
        Mode:D $,
        Filesystem:D $ where Filesystem::BTRFS,
        Filesystem $,
        Bool:D $ where .so,
        *% (
            Str :lvm-vg-name($),
            *%
        )
        --> Fs:D
    )
    {
        die(X::Voidvault::Config::Filesystem::Impermissible['btrfs+lvm'].new);
    }

    multi sub fs(
        Mode:D $,
        Filesystem $,
        Filesystem:D $ where Filesystem::BTRFS,
        Bool $,
        *% (
            Str :lvm-vg-name($),
            *%
        )
        --> Fs:D
    )
    {
        die(X::Voidvault::Config::Filesystem::Impermissible['bootvaultbtrfs'].new);
    }

    multi sub fs(
        Mode:D $,
        Filesystem $,
        Filesystem $,
        Bool $ where .not,
        Str:D :lvm-vg-name($) where .so,
        *%
        --> Fs:D
    )
    {
        die(X::Voidvault::Config::Filesystem::Impermissible['lvm-vg-name'].new);
    }

    multi sub fs(
        Mode:D $ where Mode::BASE,
        Filesystem $,
        Filesystem $,
        Bool $,
        *% (
            Str :lvm-vg-name($),
            *%
        )
        --> Fs:D
    )
    {*}

    # every other mode beyond base creates filesystem on bootvault
    multi sub fs(
        Mode:D $,
        Filesystem $,
        Filesystem $bootvaultfs,
        Bool $lvm,
        *% (
            Str :lvm-vg-name($),
            *%
        )
        --> Fs:D
    )
    {
        %*opts<bootvault> =
            $bootvaultfs ?? $bootvaultfs !! default-bootvaultfs(%*opts<vault>);
    }
}

# default bootvaultfs given vaultfs
multi sub default-bootvaultfs(Filesystem::BTRFS --> Filesystem::EXT4) is export {*}
multi sub default-bootvaultfs(Filesystem::EXT2 --> Filesystem::EXT2) is export {*}
multi sub default-bootvaultfs(Filesystem::EXT3 --> Filesystem::EXT3) is export {*}
multi sub default-bootvaultfs(Filesystem::EXT4 --> Filesystem::EXT4) is export {*}
multi sub default-bootvaultfs(Filesystem::F2FS --> Filesystem::F2FS) is export {*}
multi sub default-bootvaultfs(Filesystem::NILFS2 --> Filesystem::NILFS2) is export {*}
multi sub default-bootvaultfs(Filesystem::XFS --> Filesystem::XFS) is export {*}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
