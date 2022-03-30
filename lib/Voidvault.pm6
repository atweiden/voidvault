use v6;
use Voidvault::Config;
use Voidvault::Constants;
use Void::XBPS;
unit class Voidvault;


# -----------------------------------------------------------------------------
# constants
# -----------------------------------------------------------------------------

constant $VERSION = v1.16.0;


# -----------------------------------------------------------------------------
# attributes
# -----------------------------------------------------------------------------

has Voidvault::Config:D $.config is required;


# -----------------------------------------------------------------------------
# instantiation
# -----------------------------------------------------------------------------

method new(
    Str $mode?,
    *%opts (
        # list options pertinent to base Voidvault::Config only
        Str :admin-name($),
        Str :admin-pass($),
        Str :admin-pass-hash($),
        Bool :augment($),
        Str :device($),
        Bool :disable-ipv6($),
        Str :disk-type($),
        Bool :enable-serial-console($),
        Str :graphics($),
        Str :grub-name($),
        Str :grub-pass($),
        Str :grub-pass-hash($),
        Str :guest-name($),
        Str :guest-pass($),
        Str :guest-pass-hash($),
        Str :hostname($),
        Bool :$ignore-conf-repos,
        Str :keymap($),
        Str :locale($),
        Str :packages($),
        Str :processor($),
        :@repository,
        Str :root-pass($),
        Str :root-pass-hash($),
        Str :sftp-name($),
        Str :sftp-pass($),
        Str :sftp-pass-hash($),
        Str :timezone($),
        Str :vault-name($),
        Str :vault-pass($),
        Str :vault-key($),
        # facilitate passing additional options to non-base mode
        *%
    )
    --> Voidvault:D
)
{
    my LibcFlavor:D $libc-flavor = $Void::XBPS::LIBC-FLAVOR;

    # verify root permissions
    $*USER == 0 or die('root privileges required');

    # ensure pressing Ctrl-C works
    signal(SIGINT).tap({ exit(130) });

    # fetch dependencies
    install-dependencies($libc-flavor, :@repository, :$ignore-conf-repos);

    # instantiate voidvault config, prompting for user input as needed
    my Voidvault::Config $config .= new($mode, |%opts);

    my Voidvault:D $voidvault = new(:$config);
}

multi sub install-dependencies(
    'GLIBC',
    *%opts (Bool :ignore-conf-repos($), :repository(@))
    --> Nil
)
{
    Void::XBPS.xbps-install(@Voidvault::Constants::DEPENDENCY, 'glibc', |%opts);
}

multi sub install-dependencies(
    'MUSL',
    *%opts (Bool :ignore-conf-repos($), :repository(@))
    --> Nil
)
{
    Void::XBPS.xbps-install(@Voidvault::Constants::DEPENDENCY, 'musl', |%opts);
}

multi sub new(Voidvault::Config::Base:D :$config! --> Voidvault::Base:D)
{
    use Voidvault::Base;
    Voidvault::Base.bless(:$config);
}

multi sub new(Voidvault::Config::OneFA:D :$config! --> Voidvault::OneFA:D)
{
    use Voidvault::OneFA;
    Voidvault::OneFA.bless(:$config);
}


# -----------------------------------------------------------------------------
# worker functions
# -----------------------------------------------------------------------------

# secure disk configuration
method mkdisk(::?CLASS:D: --> Nil)
{
    # partition device
    self.sgdisk;

    # create uefi partition
    self.mkefi;

    # create, open and add randomized key to LUKS encrypted volume
    self.mkvault;

    # create and mount btrfs volumes
    self.mkbtrfs;

    # mount efi boot
    self.mount-efi;

    # disable Btrfs CoW
    self.disable-cow;
}

# partition device with gdisk
method sgdisk(::?CLASS:D: --> Nil)
{
    my Str:D $device = $.config.device;

    # erase existing partition table
    # create 2M EF02 BIOS boot sector
    # create 550M EF00 EFI system partition
    # create max sized partition for LUKS-encrypted vault
    run(qqw<
        sgdisk
        --zap-all
        --clear
        --mbrtogpt
        --new=1:0:+{$Voidvault::Constants::GDISK-SIZE-BIOS}
        --typecode=1:{$Voidvault::Constants::GDISK-TYPECODE-BIOS}
        --new=2:0:+{$Voidvault::Constants::GDISK-SIZE-EFI}
        --typecode=2:{$Voidvault::Constants::GDISK-TYPECODE-EFI}
        --new=3:0:0
        --typecode=3:{$Voidvault::Constants::GDISK-TYPECODE-LINUX}
    >, $device);
}

method mkefi(::?CLASS:D: --> Nil)
{
    my Str:D $partition-efi = self.gen-partition('efi');
    run(qw<modprobe vfat>);
    run(qqw<mkfs.vfat -F 32 $partition-efi>);
}

# create and mount btrfs filesystem on opened vault
method mkbtrfs(::?CLASS:D: --> Nil)
{
    my DiskType:D $disk-type = $.config.disk-type;
    my VaultName:D $vault-name = $.config.vault-name;

    # create btrfs filesystem on opened vault
    run(qw<modprobe btrfs xxhash_generic>);
    run(qqw<mkfs.btrfs --csum xxhash /dev/mapper/$vault-name>);

    # set mount options
    my Str:D @mount-options = qw<
        rw
        noatime
        compress-force=zstd
        space_cache=v2
    >;
    push(@mount-options, 'ssd') if $disk-type eq 'SSD';
    my Str:D $mount-options = @mount-options.join(',');

    # mount main btrfs filesystem on open vault
    mkdir('/mnt2');
    run(qqw<
        mount
        --types btrfs
        --options $mount-options
        /dev/mapper/$vault-name
        /mnt2
    >);

    # btrfs subvolumes, starting with root / ('')
    my Str:D @btrfs-dir =
        '',
        'home',
        'opt',
        'srv',
        'var',
        'var-cache-xbps',
        'var-lib-ex',
        'var-log',
        'var-opt',
        'var-spool',
        'var-tmp';

    # create btrfs subvolumes
    chdir('/mnt2');
    @btrfs-dir.map(-> Str:D $btrfs-dir {
        run(qqw<btrfs subvolume create @$btrfs-dir>);
    });
    chdir('/');

    # mount btrfs subvolumes
    @btrfs-dir.map(-> Str:D $btrfs-dir {
        mount-btrfs-subvolume($btrfs-dir, $mount-options, $vault-name);
    });

    # unmount /mnt2 and remove
    run(qw<umount /mnt2>);
    rmdir('/mnt2');
}

multi sub mount-btrfs-subvolume(
    'srv',
    Str:D $mount-options,
    VaultName:D $vault-name
    --> Nil
)
{
    my Str:D $btrfs-dir = 'srv';
    mkdir("/mnt/$btrfs-dir");
    run(qqw<
        mount
        --types btrfs
        --options $mount-options,nodev,noexec,nosuid,subvol=@$btrfs-dir
        /dev/mapper/$vault-name
        /mnt/$btrfs-dir
    >);
}

multi sub mount-btrfs-subvolume(
    'var-cache-xbps',
    Str:D $mount-options,
    VaultName:D $vault-name
    --> Nil
)
{
    my Str:D $btrfs-dir = 'var/cache/xbps';
    mkdir("/mnt/$btrfs-dir");
    run(qqw<
        mount
        --types btrfs
        --options $mount-options,subvol=@var-cache-xbps
        /dev/mapper/$vault-name
        /mnt/$btrfs-dir
    >);
}

multi sub mount-btrfs-subvolume(
    'var-lib-ex',
    Str:D $mount-options,
    VaultName:D $vault-name
    --> Nil
)
{
    my Str:D $btrfs-dir = 'var/lib/ex';
    mkdir("/mnt/$btrfs-dir");
    run(qqw<
        mount
        --types btrfs
        --options $mount-options,nodev,noexec,nosuid,subvol=@var-lib-ex
        /dev/mapper/$vault-name
        /mnt/$btrfs-dir
    >);
    run(qqw<chmod 1777 /mnt/$btrfs-dir>);
}

multi sub mount-btrfs-subvolume(
    'var-log',
    Str:D $mount-options,
    VaultName:D $vault-name
    --> Nil
)
{
    my Str:D $btrfs-dir = 'var/log';
    mkdir("/mnt/$btrfs-dir");
    run(qqw<
        mount
        --types btrfs
        --options $mount-options,nodev,noexec,nosuid,subvol=@var-log
        /dev/mapper/$vault-name
        /mnt/$btrfs-dir
    >);
}

multi sub mount-btrfs-subvolume(
    'var-opt',
    Str:D $mount-options,
    VaultName:D $vault-name
    --> Nil
)
{
    my Str:D $btrfs-dir = 'var/opt';
    mkdir("/mnt/$btrfs-dir");
    run(qqw<
        mount
        --types btrfs
        --options $mount-options,subvol=@var-opt
        /dev/mapper/$vault-name
        /mnt/$btrfs-dir
    >);
}

multi sub mount-btrfs-subvolume(
    'var-spool',
    Str:D $mount-options,
    VaultName:D $vault-name
    --> Nil
)
{
    my Str:D $btrfs-dir = 'var/spool';
    mkdir("/mnt/$btrfs-dir");
    run(qqw<
        mount
        --types btrfs
        --options $mount-options,nodev,noexec,nosuid,subvol=@var-spool
        /dev/mapper/$vault-name
        /mnt/$btrfs-dir
    >);
}

multi sub mount-btrfs-subvolume(
    'var-tmp',
    Str:D $mount-options,
    VaultName:D $vault-name
    --> Nil
)
{
    my Str:D $btrfs-dir = 'var/tmp';
    mkdir("/mnt/$btrfs-dir");
    run(qqw<
        mount
        --types btrfs
        --options $mount-options,nodev,noexec,nosuid,subvol=@var-tmp
        /dev/mapper/$vault-name
        /mnt/$btrfs-dir
    >);
    run(qqw<chmod 1777 /mnt/$btrfs-dir>);
}

multi sub mount-btrfs-subvolume(
    Str:D $btrfs-dir,
    Str:D $mount-options,
    VaultName:D $vault-name
    --> Nil
)
{
    mkdir("/mnt/$btrfs-dir");
    run(qqw<
        mount
        --types btrfs
        --options $mount-options,subvol=@$btrfs-dir
        /dev/mapper/$vault-name
        /mnt/$btrfs-dir
    >);
}

method mkvault(::?CLASS:D: --> Nil)
{
    my VaultName:D $vault-name = $.config.vault-name;
    my VaultPass $vault-pass = $.config.vault-pass;
    my Str:D $vault-key = $.config.vault-key;
    my VaultType:D $vault-type = 'LUKS1';
    my Str:D $partition-vault = self.gen-partition('vault');

    # create vault with password
    Voidvault::Utils.mkvault(:$vault-type, :$partition-vault, :$vault-pass);

    # open vault with password
    Voidvault::Utils.open-vault(
        :$vault-type,
        :$partition-vault,
        :$vault-name,
        :$vault-pass
    );

    # add key to vault
    Voidvault::Utils.install-vault-key(
        :$partition-vault,
        :$vault-key,
        :$vault-pass
    );
}

method mount-efi(::?CLASS:D: --> Nil)
{
    my Str:D $partition-efi = self.gen-partition('efi');
    my Str:D $efi-dir = '/mnt/boot/efi';
    mkdir($efi-dir);
    my Str:D $mount-options = qw<
        nodev
        noexec
        nosuid
    >.join(',');
    run(qqw<mount --options $mount-options $partition-efi $efi-dir>);
}

method disable-cow(--> Nil)
{
    my Str:D @directory = qw<
        srv
        var/lib/ex
        var/log
        var/spool
        var/tmp
    >.map(-> Str:D $directory { sprintf(Q{/mnt/%s}, $directory) });
    Voidvault::Utils.disable-cow(|@directory, :recursive);
}

# bootstrap initial chroot with voidstrap
method voidstrap-base(::?CLASS:D: --> Nil)
{
    my Str:D @repository = $.config.repository;
    my Bool:D $ignore-conf-repos = $.config.ignore-conf-repos;
    my Str:D @package = $.config.package;
    my Processor:D $processor = $.config.processor;
    my LibcFlavor:D $libc-flavor = $Void::XBPS::LIBC-FLAVOR;

    # download and install core packages with voidstrap in chroot
    my Str:D @core = @Voidvault::Constants::CORE-PACKAGE;
    my Str:D $voidstrap-core-cmdline =
        build-voidstrap-cmdline(@core, :@repository, :$ignore-conf-repos);
    Voidvault::Utils.loop-cmdline-proc(
        'Running voidstrap...',
        $voidstrap-core-cmdline
    );

    # base packages - void's C<base-minimal> with light additions
    # duplicates C<base-minimal>'s C<depends> for thoroughness
    my Str:D @base = @Voidvault::Constants::BASE-PACKAGE;
    push(@base, 'glibc') if $libc-flavor eq 'GLIBC';
    push(@base, 'musl') if $libc-flavor eq 'MUSL';
    push(@base, 'grub-i386-efi') if $*KERNEL.bits == 32;
    push(@base, 'grub-x86_64-efi') if $*KERNEL.bits == 64;
    # https://www.archlinux.org/news/changes-to-intel-microcodeupdates/
    push(@base, 'intel-ucode') if $processor eq 'INTEL';
    push(@base, $_) for @package;

    # download and install base packages with voidstrap in chroot
    my Str:D $voidstrap-base-cmdline =
        build-voidstrap-cmdline(@base, :@repository, :$ignore-conf-repos);

    # why launch a new shell process for this? superstition.
    Voidvault::Utils.loop-cmdline-proc(
        'Running voidstrap...',
        $voidstrap-base-cmdline
    );
}

multi sub build-voidstrap-cmdline(
    Str:D @base,
    Str:D :@repository! where .so,
    Bool:D :ignore-conf-repos($)! where .so
    --> Str:D
)
{
    my Str:D $repository = @repository.join(' --repository=');
    my Str:D $voidstrap-cmdline =
        "voidstrap \\
         --ignore-conf-repos \\
         --repository=$repository \\
         /mnt \\
         @base[]";
}

multi sub build-voidstrap-cmdline(
    Str:D @base,
    Str:D :@repository! where .so,
    Bool :ignore-conf-repos($)
    --> Str:D
)
{
    my Str:D $repository = @repository.join(' --repository=');
    my Str:D $voidstrap-cmdline =
        "voidstrap \\
         --repository=$repository \\
         /mnt \\
         @base[]";
}

multi sub build-voidstrap-cmdline(
    Str:D @,
    Str:D :repository(@),
    Bool:D :ignore-conf-repos($)! where .so
    --> Nil
)
{
    die(X::Void::XBPS::IgnoreConfRepos.new);
}

multi sub build-voidstrap-cmdline(
    Str:D @base,
    Str:D :repository(@),
    Bool :ignore-conf-repos($)
    --> Str:D
)
{
    my Str:D $voidstrap-cmdline =
        "voidstrap \\
         /mnt \\
         @base[]";
}


# -----------------------------------------------------------------------------
# helper functions
# -----------------------------------------------------------------------------

proto method gen-partition(::?CLASS:D: Str:D --> Str:D)
{
    my Str:D $device = $.config.device;
    my Str:D @*partition = Voidvault::Utils.ls-partitions($device);
    {*}
}

multi method gen-partition(::?CLASS:D: 'efi' --> Str:D)
{
    # e.g. /dev/sda2
    my UInt:D $index = 1;
    my Str:D $partition = @*partition[$index];
}

multi method gen-partition(::?CLASS:D: 'vault' --> Str:D)
{
    # e.g. /dev/sda3
    my UInt:D $index = 2;
    my Str:D $partition = @*partition[$index];
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
