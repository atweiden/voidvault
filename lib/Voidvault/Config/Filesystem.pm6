use v6;
use Voidvault::Config::Utils;
use Voidvault::Parser::Filesystem;
use Voidvault::Types;
use X::Voidvault::Config::Filesystem;

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

my role Fs[Mode:D $ where Mode::<1FA>..Mode::<2FA>, Bool:D $ where .so]
{
    also does Fs[Mode::BASE, True];
    also does FsBootvault;
}

my role Fs[Mode:D $ where Mode::<1FA>..Mode::<2FA>, Bool $]
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
        Mode:D $mode,
        Filesystem $vaultfs,
        Filesystem $bootvaultfs,
        Bool $lvm,
        Str :$lvm-vg-name,
        *%
        --> Fs:D
    )
    {
        my %opts;
        %opts<vault> = $vaultfs if $vaultfs;
        %opts<bootvault> = $bootvaultfs if $bootvaultfs;
        %opts<lvm-vg-name> =
            Voidvault::Config::Utils.gen-lvm-vg-name($lvm-vg-name)
                if $lvm-vg-name;
        my Fs:D $fs = Fs[$mode, $lvm].new(|%opts);
    }
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
