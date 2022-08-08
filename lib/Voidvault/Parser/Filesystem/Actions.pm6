use v6;
use Voidvault::Types;
unit class Voidvault::Parser::Filesystem::Actions;

method fs-btrfs($/ --> Nil)
{
    make(Filesystem::BTRFS);
}

method fs-ext2($/ --> Nil)
{
    make(Filesystem::EXT2);
}

method fs-ext3($/ --> Nil)
{
    make(Filesystem::EXT3);
}

method fs-ext4($/ --> Nil)
{
    make(Filesystem::EXT4);
}

method fs-f2fs($/ --> Nil)
{
    make(Filesystem::F2FS);
}

method fs-nilfs2($/ --> Nil)
{
    make(Filesystem::NILFS2);
}

method fs-xfs($/ --> Nil)
{
    make(Filesystem::XFS);
}

multi method fs($/ where $<fs-btrfs>.so --> Nil)
{
    make($<fs-btrfs>.made);
}

multi method fs($/ where $<fs-ext2>.so --> Nil)
{
    make($<fs-ext2>.made);
}

multi method fs($/ where $<fs-ext3>.so --> Nil)
{
    make($<fs-ext3>.made);
}

multi method fs($/ where $<fs-ext4>.so --> Nil)
{
    make($<fs-ext4>.made);
}

multi method fs($/ where $<fs-f2fs>.so --> Nil)
{
    make($<fs-f2fs>.made);
}

multi method fs($/ where $<fs-nilfs2>.so --> Nil)
{
    make($<fs-nilfs2>.made);
}

multi method fs($/ where $<fs-xfs>.so --> Nil)
{
    make($<fs-xfs>.made);
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
