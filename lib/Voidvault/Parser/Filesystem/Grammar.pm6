use v6;
unit grammar Voidvault::Parser::Filesystem::Grammar;

proto token fs {*}
token fs:sym<btrfs> { <sym> }
token fs:sym<ext2> { <sym> }
token fs:sym<ext3> { <sym> }
token fs:sym<ext4> { <sym> }
token fs:sym<f2fs> { <sym> }
token fs:sym<nilfs2> { <sym> }
token fs:sym<xfs> { <sym> }

token lvm { lvm }

token TOP
{
    ^
    $<vaultfs>=<.fs>
    ['/' $<bootvaultfs>=<.fs>]?
    ['+'<lvm>]?
    $
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
