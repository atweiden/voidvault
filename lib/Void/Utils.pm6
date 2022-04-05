use v6;
use Void::Constants;
use Voidvault::Utils;
use X::Void::XBPS;
unit class Void::Utils;

constant $VERSION = v1.16.0;

# method voidstrap {{{

# based on arch-install-scripts v24
method voidstrap(
    # C<$chroot-dir> here does not need to be C<AbsolutePath>
    Str:D $chroot-dir,
    :@repository,
    Bool :$ignore-conf-repos,
    # ensure at least one package is given
    *@pkg ($, *@)
    --> Nil
)
{
    voidstrap($chroot-dir, :@repository, :$ignore-conf-repos, @pkg);
}

sub voidstrap(
    Str:D $chroot-dir,
    :@repository,
    Bool :$ignore-conf-repos,
    *@pkg ($, *@)
    --> Nil
)
{
    my Str:D @*chroot-active-mount;
    LEAVE chroot-teardown();
    UNDO chroot-teardown();
    create-obligatory-dirs($chroot-dir);
    chroot-setup($chroot-dir);
    chroot-add-host-keys($chroot-dir);
    voidstrap-install($chroot-dir, :@repository, :$ignore-conf-repos, @pkg);
}

# --- sub create-obligatory-dirs {{{

multi sub create-obligatory-dirs(Str:D $chroot-dir where .IO.d.so --> Nil)
{
    mkdir("$chroot-dir/dev", 0o0755);
    mkdir("$chroot-dir/etc", 0o0755);
    mkdir("$chroot-dir/run", 0o0755);
    mkdir("$chroot-dir/var/db/xbps/keys", 0o0755);
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
        or die(sprintf(Q{Sorry, could not add mount: %s}, $source));
    push(@*chroot-active-mount, $dest);
}

# --- end sub chroot-add-mount }}}
# --- sub chroot-add-host-keys {{{

# copy existing host keys to the target chroot
sub chroot-add-host-keys(
    Str:D $chroot-dir
    --> Nil
)
{
    my Str:D $host-keys-dir =
        '/var/db/xbps/keys';
    my Str:D $host-keys-chroot-dir =
        sprintf(Q{%s%s}, $chroot-dir, $host-keys-dir);
    dir($host-keys-dir)
        .map(-> IO::Path:D $path {
            $path.basename
        })
        .map(-> Str:D $basename {
            copy(
                "$host-keys-dir/$basename",
                "$host-keys-chroot-dir/$basename"
            );
        });
}

# --- end sub chroot-add-host-keys }}}
# --- sub voidstrap-install {{{

sub voidstrap-install(
    # C<$chroot-dir> here does not need to be C<AbsolutePath>
    Str:D $chroot-dir,
    *@pkg ($, *@),
    *%opts (
        :repository(@),
        Bool :ignore-conf-repos($)
    )
    --> Str:D
)
{
    my Str:D $xbps-uhelper-arch = $Void::Constants::XBPS-UHELPER-ARCH;
    my Str:D @voidstrap-install-cmdline = qqw<
        XBPS_ARCH=$xbps-uhelper-arch
        unshare
        --fork
        --pid
        xbps-install
        --force
        --rootdir $chroot-dir
        --sync
        --yes
    >;
    my Str:D @repository-flag = gen-repository-flags(|%opts);
    append(@voidstrap-install-cmdline, @repository-flag);
    append(@voidstrap-install-cmdline, @pkg);
    my Str:D $voidstrap-install-cmdline = @voidstrap-install-cmdline.join(' ');
    Voidvault::Utils.loop-cmdline-proc(
        "Running voidstrap...",
        $voidstrap-install-cmdline
    );
}

multi sub gen-repository-flags(
    :@repository! where .so,
    Bool:D :ignore-conf-repos($)! where .so
    --> Array[Str:D]
)
{
    my Str:D $repository = @repository.join(' --repository ');
    # omit official repos when passed C<--repository --ignore-conf-repos>
    my Str:D @gen-repository-flag = qqw<
       --ignore-conf-repos
       --repository $repository
    >;
}

multi sub gen-repository-flags(
    :@repository! where .so,
    Bool :ignore-conf-repos($)
    --> Array[Str:D]
)
{
    my Str:D $repository = @repository.join(' --repository ');
    my Str:D $repository-official = $Void::Constants::REPOSITORY-OFFICIAL;
    my Str:D $repository-official-nonfree =
        $Void::Constants::REPOSITORY-OFFICIAL-NONFREE;
    my Str:D @gen-repository-flag = qqw<
       --repository $repository
       --repository $repository-official
       --repository $repository-official-nonfree
    >;
}

multi sub gen-repository-flags(
    :repository(@),
    Bool:D :ignore-conf-repos($)! where .so
    --> Nil
)
{
    die(X::Void::XBPS::IgnoreConfRepos.new);
}

multi sub gen-repository-flags(
    :repository(@),
    Bool :ignore-conf-repos($)
    --> Array[Str:D]
)
{
    my Str:D $repository-official = $Void::Constants::REPOSITORY-OFFICIAL;
    my Str:D $repository-official-nonfree =
        $Void::Constants::REPOSITORY-OFFICIAL-NONFREE;
    my Str:D @gen-repository-flag = qqw<
       --repository $repository-official
       --repository $repository-official-nonfree
   >;
}

# --- end sub voidstrap-install }}}

# end method voidstrap }}}
# method void-chroot {{{

method void-chroot(
    # C<$chroot-dir> here does not need to be C<AbsolutePath>
    Str:D $chroot-dir,
    *@cmdline ($, *@)
    --> Nil
)
{
    void-chroot($chroot-dir, @cmdline);
}

sub void-chroot(Str:D $chroot-dir, *@cmdline ($, *@) --> Nil)
{
    my Str:D @*chroot-active-mount;
    LEAVE chroot-teardown();
    UNDO chroot-teardown();
    create-obligatory-dirs($chroot-dir);
    chroot-setup($chroot-dir);
    chroot-add-resolv-conf($chroot-dir);
    my Str:D $cmdline =
        "SHELL=/bin/bash unshare --fork --pid chroot $chroot-dir @cmdline[]";
    shell($cmdline);
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

# vim: set filetype=raku foldmethod=marker foldlevel=0 nowrap:
