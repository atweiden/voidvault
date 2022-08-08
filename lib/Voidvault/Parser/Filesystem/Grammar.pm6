use v6;
unit grammar Voidvault::Parser::Filesystem::Grammar;

token fs-btrfs { :i btrfs }
token fs-ext2 { :i ext2 }
token fs-ext3 { :i ext3 }
token fs-ext4 { :i ext4 }
token fs-f2fs { :i f2fs }
token fs-nilfs2 { :i nilfs2 }
token fs-xfs { :i xfs }
token fs
{
    | <fs-btrfs>
    | <fs-ext2>
    | <fs-ext3>
    | <fs-ext4>
    | <fs-f2fs>
    | <fs-nilfs2>
    | <fs-xfs>
}

token lvm { :i lvm }

token TOP
{
    ^
    $<vaultfs>=<fs>
    ['/' $<bootvaultfs>=<fs>]?
    ['+'<lvm>]?
    $
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
