=head DOCUMENTATION

constant $README = q:to/EOF/.trim;
Description
-----------

### Features

- whole system [NILFS][NILFS]+LVM on LUKS, including encrypted `/boot`
- configures [nilfs_cleanerd][nilfs_cleanerd] to reduce overhead

### Filesystem

- `/dev/sdX1` is the BIOS boot sector (size: 2M)
- `/dev/sdX2` is the EFI system partition (size: [550M][550M])
- `/dev/sdX3` is the root NILFS+LVM filesystem on LUKS (size: remainder)

Voidvault creates the following LVM logical volumes:

Logical Volume name | Mounting point    | Sizing
---                 | ---               | ---
`root`              | `/`               | `8G`
`opt`               | `/opt`            | `200M`
`srv`               | `/srv`            | `200M`
`var`               | `/var`            | `1G`
`var-cache-xbps`    | `/var/cache/xbps` | `2G`
`var-lib-ex`        | `/var/lib/ex`     | `200M`
`var-log`           | `/var/log`        | `200M`
`var-opt`           | `/var/opt`        | `200M`
`var-spool`         | `/var/spool`      | `200M`
`var-tmp`           | `/var/tmp`        | `800M`
`home`              | `/home`           | `100%FREE`

Voidvault mounts directories `/srv`, `/tmp`, `/var/lib/ex`, `/var/log`,
`/var/spool` and `/var/tmp` with options `nodev,noexec,nosuid`.

Synopsis
--------

VOIDVAULT_LVM_VG_NAME="vg0"

Dependencies
------------

Name                 | Provides              | Included in Void ISO¹?
---                  | ---                   | ---
lvm2                 | LVM disk partitioning | N
nilfs-utils          | NILFS support         | N

[NILFS]: https://nilfs.sourceforge.io/
[nilfs_cleanerd]: https://news.ycombinator.com/item?id=18753858
EOF

my $guide = "doc/guides/nilfs-lvm-administration.md";

my @script = qw<
    scripts/umount-system.sh
    scripts/mount-system.sh
>;

=head CONFIG

# name for LVM volume group (default: vg0)
has LvmVolumeGroupName:D $.lvm-vg-name =
    %*ENV<VOIDVAULT_LVM_VG_NAME>
        ?? Voidvault::Config.gen-lvm-vg-name(%*ENV<VOIDVAULT_LVM_VG_NAME>)
        !! prompt-name(:lvm-vg);

# submethod BUILD...
$!lvm-vg-name = Voidvault::Config.gen-lvm-vg-name($lvm-vg-name)
    if $lvm-vg-name;

=head GRAMMAR

# LVM volume group name validation
token lvm-vg-name
{
    # from `man 8 lvm` line 136:
    # - VG name can only contain valid chars: A-Z a-z 0-9 + _ . -
    # - VG name cannot begin with a hyphen
    # - VG name cannot be anything that exists in /dev/ at the time of creation
    # - VG name cannot be `.` or `..`
    (
        <+alnum +[+] +[_] +[\.]>
        <+alnum +[+] +[_] +[\.] +[-]>*
    )
    { $0 !~~ /^^ '.' ** 1..2 $$/ or fail }
}

=head TYPES

# LVM volume group name
subset LvmVolumeGroupName of Str is export where
{
    Voidvault::Grammar.parse($_, :rule<lvm-vg-name>);
}

=head BOOTSTRAP

push(@pre, "libnilfs");
push(@pre, "lvm2");
push(@pre, "nilfs-utils");

push(@pkg, "lvm2");
push(@pkg, "nilfs-utils");

# create and mount nilfs+lvm structure on open vault
sub mknilfslvm(LvmVolumeGroupName:D $lvm-vg-name, VaultName:D $vault-name --> Nil)
{
    # create lvm physical volume (pv) on open vault
    run(qqw<pvcreate /dev/mapper/$vault-name>);

    # create lvm volume group (vg) hosting physical volume
    run(qqw<vgcreate $lvm-vg-name /dev/mapper/$vault-name>);

    # logical volume (lv), deliberately custom ordered
    my Str:D @lv =
        'root',
        'opt',
        'srv',
        'var',
        'var-cache-xbps',
        'var-lib-ex',
        'var-log',
        'var-opt',
        'var-spool',
        'var-tmp',
        'home';

    # create lvm lvs
    lvcreate(@lv, $lvm-vg-name);

    # activate lvm lvs
    run(qw<vgchange --activate y>);

    # make nilfs on each lvm lv
    mknilfs(@lv, $lvm-vg-name);

    # mount nilfs lvm structure
    mount-nilfslvm(@lv, $lvm-vg-name);
}

multi sub lvcreate(
    Str:D @lv,
    LvmVolumeGroupName:D $lvm-vg-name
    --> Nil
)
{
    @lv.map(-> Str:D $lv {
        lvcreate($lv, $lvm-vg-name);
    });
}

multi sub lvcreate(
    Str:D $lv where 'root',
    LvmVolumeGroupName:D $lvm-vg-name
    --> Nil
)
{
    # root (C</>) sized at 8G
    my Str:D $size = '8G';
    lvcreate($lv, :$size, $lvm-vg-name);
}

multi sub lvcreate(
    Str:D $lv where 'opt',
    LvmVolumeGroupName:D $lvm-vg-name
    --> Nil
)
{
    # opt (C</opt>) sized at 200M
    my Str:D $size = '200M';
    lvcreate($lv, :$size, $lvm-vg-name);
}

multi sub lvcreate(
    Str:D $lv where 'srv',
    LvmVolumeGroupName:D $lvm-vg-name
    --> Nil
)
{
    # srv (C</srv>) sized at 200M
    my Str:D $size = '200M';
    lvcreate($lv, :$size, $lvm-vg-name);
}

multi sub lvcreate(
    Str:D $lv where 'var',
    LvmVolumeGroupName:D $lvm-vg-name
    --> Nil
)
{
    # var (C</var>) sized at 1G
    my Str:D $size = '1G';
    lvcreate($lv, :$size, $lvm-vg-name);
}

multi sub lvcreate(
    Str:D $lv where 'var-cache-xbps',
    LvmVolumeGroupName:D $lvm-vg-name
    --> Nil
)
{
    # var-cache-xbps (C</var/cache/xbps>) sized at 2G
    my Str:D $size = '2G';
    lvcreate($lv, :$size, $lvm-vg-name);
}

multi sub lvcreate(
    Str:D $lv where 'var-lib-ex',
    LvmVolumeGroupName:D $lvm-vg-name
    --> Nil
)
{
    # var-lib-ex (C</var/lib/ex>) sized at 200M
    my Str:D $size = '200M';
    lvcreate($lv, :$size, $lvm-vg-name);
}

multi sub lvcreate(
    Str:D $lv where 'var-log',
    LvmVolumeGroupName:D $lvm-vg-name
    --> Nil
)
{
    # var-log (C</var/log>) sized at 200M
    my Str:D $size = '200M';
    lvcreate($lv, :$size, $lvm-vg-name);
}

multi sub lvcreate(
    Str:D $lv where 'var-opt',
    LvmVolumeGroupName:D $lvm-vg-name
    --> Nil
)
{
    # var-opt (C</var/opt>) sized at 200M
    my Str:D $size = '200M';
    lvcreate($lv, :$size, $lvm-vg-name);
}

multi sub lvcreate(
    Str:D $lv where 'var-spool',
    LvmVolumeGroupName:D $lvm-vg-name
    --> Nil
)
{
    # var-spool (C</var/spool>) sized at 200M
    my Str:D $size = '200M';
    lvcreate($lv, :$size, $lvm-vg-name);
}

multi sub lvcreate(
    Str:D $lv where 'var-tmp',
    LvmVolumeGroupName:D $lvm-vg-name
    --> Nil
)
{
    # var-tmp (C</var/tmp>) sized at 800M
    my Str:D $size = '800M';
    lvcreate($lv, :$size, $lvm-vg-name);
}

multi sub lvcreate(
    Str:D $lv where 'home',
    LvmVolumeGroupName:D $lvm-vg-name
    --> Nil
)
{
    # home (C</home>) sized at 100% of remaining free space in vg
    my Str:D $extents = '100%FREE';
    lvcreate($lv, :$extents, $lvm-vg-name);
}

multi sub lvcreate(
    Str:D $name,
    LvmVolumeGroupName:D $lvm-vg-name,
    Str:D :$extents! where .so
    --> Nil
)
{
    run(qqw<lvcreate --name $name --extents $extents $lvm-vg-name>);
}

multi sub lvcreate(
    Str:D $name,
    LvmVolumeGroupName:D $lvm-vg-name,
    Str:D :$size! where .so
    --> Nil
)
{
    run(qqw<lvcreate --name $name --size $size $lvm-vg-name>);
}

multi sub mknilfs(Str:D @lv, LvmVolumeGroupName:D $lvm-vg-name --> Nil)
{
    run(qw<modprobe nilfs2>);
    @lv.map(-> Str:D $lv {
        mknilfs($lv, $lvm-vg-name);
    });
}

multi sub mknilfs(Str:D $lv, LvmVolumeGroupName:D $lvm-vg-name --> Nil)
{
    run(qqw<mkfs.nilfs2 -L $lv /dev/$lvm-vg-name/$lv>);
}

multi sub mount-nilfslvm(
    Str:D @lv,
    LvmVolumeGroupName:D $lvm-vg-name
    --> Nil
)
{
    @lv.map(-> Str:D $lv {
        mount-nilfslvm($lv, $lvm-vg-name);
    });
}

multi sub mount-nilfslvm(
    Str:D $lv where 'root',
    LvmVolumeGroupName:D $lvm-vg-name
    --> Nil
)
{
    # set mount options
    my Str:D $mount-options = 'rw,noatime';

    # mount nilfs+lvm root on open vault
    run(qqw<
        mount
        --types nilfs2
        --options $mount-options
        /dev/$lvm-vg-name/$lv
        /mnt
    >);
}

multi sub mount-nilfslvm(
    Str:D $lv where 'srv',
    LvmVolumeGroupName:D $lvm-vg-name
    --> Nil
)
{
    mkdir("/mnt/$lv");
    my Str:D $mount-options = 'rw,noatime,nodev,noexec,nosuid';
    run(qqw<
        mount
        --types nilfs2
        --options $mount-options
        /dev/$lvm-vg-name/$lv
        /mnt/$lv
    >);
}

multi sub mount-nilfslvm(
    Str:D $lv where 'var-cache-xbps',
    LvmVolumeGroupName:D $lvm-vg-name
    --> Nil
)
{
    my Str:D $dir = $lv.subst('-', '/', :g);
    mkdir("/mnt/$dir");
    my Str:D $mount-options = 'rw,noatime';
    run(qqw<
        mount
        --types nilfs2
        --options $mount-options
        /dev/$lvm-vg-name/$lv
        /mnt/$dir
    >);
}

multi sub mount-nilfslvm(
    Str:D $lv where 'var-lib-ex',
    LvmVolumeGroupName:D $lvm-vg-name
    --> Nil
)
{
    my Str:D $dir = $lv.subst('-', '/', :g);
    mkdir("/mnt/$dir");
    my Str:D $mount-options = 'rw,noatime,nodev,noexec,nosuid';
    run(qqw<
        mount
        --types nilfs2
        --options $mount-options
        /dev/$lvm-vg-name/$lv
        /mnt/$dir
    >);
}

multi sub mount-nilfslvm(
    Str:D $lv where 'var-log',
    LvmVolumeGroupName:D $lvm-vg-name
    --> Nil
)
{
    my Str:D $dir = $lv.subst('-', '/', :g);
    mkdir("/mnt/$dir");
    my Str:D $mount-options = 'rw,noatime,nodev,noexec,nosuid';
    run(qqw<
        mount
        --types nilfs2
        --options $mount-options
        /dev/$lvm-vg-name/$lv
        /mnt/$dir
    >);
}

multi sub mount-nilfslvm(
    Str:D $lv where 'var-opt',
    LvmVolumeGroupName:D $lvm-vg-name
    --> Nil
)
{
    my Str:D $dir = $lv.subst('-', '/', :g);
    mkdir("/mnt/$dir");
    my Str:D $mount-options = 'rw,noatime';
    run(qqw<
        mount
        --types nilfs2
        --options $mount-options
        /dev/$lvm-vg-name/$lv
        /mnt/$dir
    >);
}

multi sub mount-nilfslvm(
    Str:D $lv where 'var-spool',
    LvmVolumeGroupName:D $lvm-vg-name
    --> Nil
)
{
    my Str:D $dir = $lv.subst('-', '/', :g);
    mkdir("/mnt/$dir");
    my Str:D $mount-options = 'rw,noatime,nodev,noexec,nosuid';
    run(qqw<
        mount
        --types nilfs2
        --options $mount-options
        /dev/$lvm-vg-name/$lv
        /mnt/$dir
    >);
}

multi sub mount-nilfslvm(
    Str:D $lv where 'var-tmp',
    LvmVolumeGroupName:D $lvm-vg-name
    --> Nil
)
{
    my Str:D $dir = $lv.subst('-', '/', :g);
    mkdir("/mnt/$dir");
    my Str:D $mount-options = 'rw,noatime,nodev,noexec,nosuid';
    run(qqw<
        mount
        --types nilfs2
        --options $mount-options
        /dev/$lvm-vg-name/$lv
        /mnt/$dir
    >);
    run(qqw<chmod 1777 /mnt/$dir>);
}

multi sub mount-nilfslvm(
    Str:D $lv,
    LvmVolumeGroupName:D $lvm-vg-name
    --> Nil
)
{
    my Str:D $mount-options = 'rw,noatime';
    mkdir("/mnt/$lv");
    run(qqw<
        mount
        --types nilfs2
        --options $mount-options
        /dev/$lvm-vg-name/$lv
        /mnt/$lv
    >);
}

method !configure-nilfs(--> Nil)
{
    replace('nilfs_cleanerd.conf');
}

multi sub replace(
    'nilfs_cleanerd.conf'
    --> Nil
)
{
    my Str:D $file = '/mnt/etc/nilfs_cleanerd.conf';
    my Str:D @replace =
        $file.IO.lines
        # do continuous cleaning
        ==> replace('nilfs_cleanerd.conf', 'min_clean_segments')
        # increase maximum number of clean segments
        ==> replace('nilfs_cleanerd.conf', 'max_clean_segments')
        # decrease clean segment check interval
        ==> replace('nilfs_cleanerd.conf', 'clean_check_interval')
        # decrease cleaning interval
        ==> replace('nilfs_cleanerd.conf', 'cleaning_interval')
        # increase minimum number of reclaimable blocks in a segment
        # before it can be cleaned
        ==> replace('nilfs_cleanerd.conf', 'min_reclaimable_blocks');
    my Str:D $replace = @replace.join("\n");
    spurt($file, $replace ~ "\n");
}

multi sub replace(
    'nilfs_cleanerd.conf',
    Str:D $subject where 'min_clean_segments',
    Str:D @line
    --> Array[Str:D]
)
{
    my UInt:D $index = @line.first(/^$subject/, :k);
    my Str:D $replace = sprintf(Q{%s 0}, $subject);
    @line[$index] = $replace;
    @line;
}

multi sub replace(
    'nilfs_cleanerd.conf',
    Str:D $subject where 'max_clean_segments',
    Str:D @line
    --> Array[Str:D]
)
{
    my UInt:D $index = @line.first(/^$subject/, :k);
    # double C<%> symbol is quirk of sprintf syntax for C<90%>
    my Str:D $replace = sprintf(Q{%s 90%%}, $subject);
    @line[$index] = $replace;
    @line;
}

multi sub replace(
    'nilfs_cleanerd.conf',
    Str:D $subject where 'clean_check_interval',
    Str:D @line
    --> Array[Str:D]
)
{
    my UInt:D $index = @line.first(/^$subject/, :k);
    my Str:D $replace = sprintf(Q{%s 2}, $subject);
    @line[$index] = $replace;
    @line;
}

multi sub replace(
    'nilfs_cleanerd.conf',
    Str:D $subject where 'cleaning_interval',
    Str:D @line
    --> Array[Str:D]
)
{
    my UInt:D $index = @line.first(/^$subject/, :k);
    my Str:D $replace = sprintf(Q{%s 2}, $subject);
    @line[$index] = $replace;
    @line;
}

multi sub replace(
    'nilfs_cleanerd.conf',
    Str:D $subject where 'min_reclaimable_blocks',
    Str:D @line
    --> Array[Str:D]
)
{
    my UInt:D $index = @line.first(/^$subject/, :k);
    my Str:D $replace = sprintf(Q{%s 60%%}, $subject);
    @line[$index] = $replace;
    @line;
}

method !unmount(--> Nil)
{
    # ...
    run(qw<vgchange --activate n>);
    run(qqw<cryptsetup luksClose $vault-name>);
}

=head GRUB

my Str:D @grub-cmdline-linux = qqw<
    rd.luks=1
    rd.luks.uuid=$vault-uuid
    rd.luks.name=$vault-uuid=$vault-name
    rd.lvm.vg=$lvm-vg-name
    root=/dev/$lvm-vg-name/root
    loglevel=6
>;

multi sub replace(
    'grub',
    Str:D $subject where 'GRUB_PRELOAD_MODULES',
    Str:D @line
    --> Array[Str:D]
)
{
    # if C<GRUB_PRELOAD_MODULES> not found, append to bottom of file
    my UInt:D $index = @line.first(/^'#'?$subject/, :k) // @line.elems;
    # preload lvm module
    my Str:D $replace = sprintf(Q{%s="lvm"}, $subject);
    @line[$index] = $replace;
    @line;
}

=head DRACUT

multi sub replace(
    'dracut.conf',
    Str:D $subject where 'add_dracutmodules'
    --> Nil
)
{
    my Str:D $file = sprintf(Q{/mnt/etc/dracut.conf.d/%s.conf}, $subject);
    # modules are found in C</usr/lib/dracut/modules.d>
    my Str:D @module = qw<
        crypt
        dm
        kernel-modules
        lvm
    >;
    my Str:D $replace = sprintf(Q{%s+=" %s "}, $subject, @module.join(' '));
    spurt($file, $replace ~ "\n");
}

# NOTE: crc32c needed for nilfs
multi sub replace(
    'dracut.conf',
    Str:D $subject where 'add_drivers',
    Graphics:D $graphics,
    Processor:D $processor
    --> Nil
)
{
    my Str:D $file = sprintf(Q{/mnt/etc/dracut.conf.d/%s.conf}, $subject);
    # drivers are C<*.ko*> files in C</lib/modules>
    my Str:D @driver = qw<
        ahci
        libcrc32c
        lz4
        lz4hc
        nilfs2
    >;
    push(@driver, 'crc32c-intel') if $processor eq 'INTEL';
    push(@driver, 'i915') if $graphics eq 'INTEL';
    push(@driver, 'nouveau') if $graphics eq 'NVIDIA';
    push(@driver, 'radeon') if $graphics eq 'RADEON';
    my Str:D $replace = sprintf(Q{%s+=" %s "}, $subject, @driver.join(' '));
    spurt($file, $replace ~ "\n");
}
