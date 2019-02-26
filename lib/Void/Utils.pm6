use v6;
use Void::XBPS;
use X::Void::XBPS;
unit class Void::Utils;

constant $VERSION = v1.7.0;

# method voidstrap {{{

# based on arch-install-scripts v21
method voidstrap(
    Str:D $chroot-dir,
    Str :$repository,
    Bool :$ignore-conf-repos,
    *@pkg ($, *@)
    --> Nil
)
{
    voidstrap($chroot-dir, :$repository, :$ignore-conf-repos, @pkg);
}

sub voidstrap(
    Str:D $chroot-dir,
    Str :$repository,
    Bool :$ignore-conf-repos,
    *@pkg ($, *@)
    --> Nil
)
{
    my Str:D @*chroot-active-mount;
    create-obligatory-dirs($chroot-dir);
    chroot-setup($chroot-dir);
    chroot-add-host-keys($chroot-dir);
    voidstrap-install($chroot-dir, :$repository, :$ignore-conf-repos, @pkg);
    LEAVE chroot-teardown();
}

# --- sub create-obligatory-dirs {{{

multi sub create-obligatory-dirs(Str:D $chroot-dir where .IO.d.so --> Nil)
{
    mkdir("$chroot-dir/dev", 0o0755);
    mkdir("$chroot-dir/etc", 0o0755);
    mkdir("$chroot-dir/run", 0o0755);
    mkdir("$chroot-dir/var/log", 0o0755);
    run(qqw<mkdir --mode=1777 --parents $chroot-dir/tmp>);
    mkdir("$chroot-dir/proc", 0o0555);
    mkdir("$chroot-dir/sys", 0o0555);
}

multi sub create-obligatory-dirs($chroot-dir --> Nil)
{
    my Str:D $message = sprintf(Q{Sorry, %s is not a directory}, $chroot-dir);
    die($message);
}

# --- end sub create-obligatory-dirs }}}
# --- sub chroot-setup {{{

# mount API filesystems
sub chroot-setup(Str:D $chroot-dir --> Nil)
{
    chroot-add-mount(|qqw<
        proc
        $chroot-dir/proc
        --types proc
        --options nodev,noexec,nosuid
    >);
    chroot-add-mount(|qqw<
        sys
        $chroot-dir/sys
        --types sysfs
        --options nodev,noexec,nosuid,ro
    >);
    chroot-add-mount(|qqw<
        efivarfs
        $chroot-dir/sys/firmware/efi/efivars
        --types efivarfs
        --options nodev,noexec,nosuid
    >) if "$chroot-dir/sys/firmware/efi/efivars".IO.d;
    chroot-add-mount(|qqw<
        udev
        $chroot-dir/dev
        --types devtmpfs
        --options mode=0755,nosuid
    >);
    chroot-add-mount(|qqw<
        devpts
        $chroot-dir/dev/pts
        --types devpts
        --options gid=5,mode=0620,noexec,nosuid
    >);
    chroot-add-mount(|qqw<
        shm
        $chroot-dir/dev/shm
        --types tmpfs
        --options mode=1777,nodev,nosuid
    >);
    chroot-add-mount(|qqw<
        /run
        $chroot-dir/run
        --bind
    >);
    chroot-add-mount(|qqw<
        tmp
        $chroot-dir/tmp
        --types tmpfs
        --options mode=1777,nodev,nosuid,strictatime
    >);
}

# --- end sub chroot-setup }}}
# --- sub chroot-teardown {{{

sub chroot-teardown(--> Nil)
{
    # C<umount> deeper directories first with C<.reverse>
    @*chroot-active-mount.reverse.map(-> Str:D $dir { run(qqw<umount $dir>) });
    @*chroot-active-mount = Empty;
}

# --- end sub chroot-teardown }}}
# --- sub chroot-add-mount {{{

sub chroot-add-mount(Str:D $source, Str:D $dest, *@opts --> Nil)
{
    my Str:D $mount-cmdline =
        sprintf(Q{mount %s %s %s}, $source, $dest, @opts.join(' '));
    my Proc:D $proc = shell($mount-cmdline);
    $proc.exitcode == 0
        or die('Sorry, could not add mount');
    push(@*chroot-active-mount, $dest);
}

# --- end sub chroot-add-mount }}}
# --- sub chroot-add-host-keys {{{

# copy existing host keys to the target chroot
multi sub chroot-add-host-keys(
    Str:D $chroot-dir,
    Str:D $host-keys-dir where .IO.d.so = '/var/db/xbps/keys'
    --> Nil
)
{
    my Str:D $host-keys-chroot-dir =
        sprintf(Q{%s%s}, $chroot-dir, $host-keys-dir);
    mkdir($host-keys-chroot-dir);
    dir($host-keys-dir)
        .map(-> IO::Path:D $path { $path.basename })
        .map(-> Str:D $basename {
            copy("$host-keys-dir/$basename", "$host-keys-chroot-dir/$basename");
        });
}

# no existing host keys to copy
multi sub chroot-add-host-keys(
    Str:D $,
    Str:D $
    --> Nil
)
{*}

# --- end sub chroot-add-host-keys }}}
# --- sub voidstrap-install {{{

multi sub voidstrap-install(
    Str:D $chroot-dir,
    Str:D :$repository! where .so,
    Bool:D :ignore-conf-repos($)! where .so,
    *@pkg ($, *@)
    --> Nil
)
{
    my Str:D $xbps-uhelper-arch = $Void::XBPS::XBPS-UHELPER-ARCH;
    # rm official repo in the presence of C<--repository --ignore-conf-repos>
    shell(
        "XBPS_ARCH=$xbps-uhelper-arch \\
         xbps-install \\
         --force \\
         --ignore-conf-repos \\
         --repository $repository \\
         --rootdir $chroot-dir \\
         --sync \\
         --yes \\
         @pkg[]"
    );
}

multi sub voidstrap-install(
    Str:D $chroot-dir,
    Str:D :$repository! where .so,
    Bool :ignore-conf-repos($),
    *@pkg ($, *@)
    --> Nil
)
{
    my Str:D $xbps-uhelper-arch = $Void::XBPS::XBPS-UHELPER-ARCH;
    my Str:D $repository-official = $Void::XBPS::REPOSITORY-OFFICIAL;
    shell(
        "XBPS_ARCH=$xbps-uhelper-arch \\
         xbps-install \\
         --force \\
         --repository $repository \\
         --repository $repository-official \\
         --rootdir $chroot-dir \\
         --sync \\
         --yes \\
         @pkg[]"
    );
}

multi sub voidstrap-install(
    Str:D $chroot-dir,
    Str :repository($),
    Bool:D :ignore-conf-repos($)! where .so,
    *@pkg ($, *@)
    --> Nil
)
{
    die(X::Void::XBPS::IgnoreConfRepos.new);
}

multi sub voidstrap-install(
    Str:D $chroot-dir,
    Str :repository($),
    Bool :ignore-conf-repos($),
    *@pkg ($, *@)
    --> Nil
)
{
    my Str:D $xbps-uhelper-arch = $Void::XBPS::XBPS-UHELPER-ARCH;
    my Str:D $repository-official = $Void::XBPS::REPOSITORY-OFFICIAL;
    shell(
        "XBPS_ARCH=$xbps-uhelper-arch \\
         xbps-install \\
         --force \\
         --repository $repository-official \\
         --rootdir $chroot-dir \\
         --sync \\
         --yes \\
         @pkg[]"
    );
}

# --- end sub voidstrap-install }}}

# end method voidstrap }}}
# method void-chroot {{{

method void-chroot(Str:D $chroot-dir, *@cmdline ($, *@) --> Nil)
{
    void-chroot($chroot-dir, @cmdline);
}

sub void-chroot(Str:D $chroot-dir, *@cmdline ($, *@) --> Nil)
{
    my Str:D @*chroot-active-mount;
    chroot-setup($chroot-dir);
    chroot-add-resolv-conf($chroot-dir);
    my Str:D $cmdline =
        "SHELL=/bin/bash unshare --fork --pid chroot $chroot-dir @cmdline[]";
    shell($cmdline);
    LEAVE chroot-teardown();
}

# --- sub chroot-add-resolv-conf {{{

multi sub chroot-add-resolv-conf(
    Str:D $chroot-dir where '/etc/resolv.conf'.IO.e.so
    --> Nil
)
{
    my Str:D $path = 'etc/resolv.conf';
    copy("/$path", "$chroot-dir/$path");
}

# nothing to do
multi sub chroot-add-resolv-conf(
    Str:D $
    --> Nil
)
{*}

# --- end sub chroot-add-resolv-conf }}}

# end method void-chroot }}}

# vim: set filetype=perl6 foldmethod=marker foldlevel=0 nowrap:
