use v6;
use Voidvault::Types;
unit class Voidvault::Parser::Filesystem::Actions;

method fs:sym<btrfs>($/ --> Nil)
{
    make(Filesystem::BTRFS);
}

method fs:sym<ext2>($/ --> Nil)
{
    make(Filesystem::EXT2);
}

method fs:sym<ext3>($/ --> Nil)
{
    make(Filesystem::EXT3);
}

method fs:sym<ext4>($/ --> Nil)
{
    make(Filesystem::EXT4);
}

method fs:sym<f2fs>($/ --> Nil)
{
    make(Filesystem::F2FS);
}

method fs:sym<nilfs2>($/ --> Nil)
{
    make(Filesystem::NILFS2);
}

method fs:sym<xfs>($/ --> Nil)
{
    make(Filesystem::XFS);
}

method vaultfs($/ --> Nil)
{
    make($<fs>.made);
}

method bootvaultfs($/ --> Nil)
{
    make($<fs>.made);
}

method lvm($/ --> Nil)
{
    make(True);
}

method TOP($/ --> Nil)
{
    my Filesystem:D $vaultfs = $<vaultfs>.made;
    my Filesystem $bootvaultfs = $<bootvaultfs>.made if $<bootvaultfs>;
    my Bool $lvm = $<lvm>.made if $<lvm>;
    my List:D $filesystem = ($vaultfs, $bootvaultfs, $lvm);
    make($filesystem);
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
