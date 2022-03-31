use v6;
use Voidvault::Config;
use Voidvault::Constants;
use Voidvault::Replace;
use Void::XBPS;
unit class Voidvault;
also does Voidvault::Replace[$Voidvault::Replace::FILE-CRYPTTAB];
also does Voidvault::Replace[$Voidvault::Replace::FILE-DNSCRYPT-PROXY];
also does Voidvault::Replace[$Voidvault::Replace::FILE-DHCPCD];
also does Voidvault::Replace[$Voidvault::Replace::FILE-DRACUT];
also does Voidvault::Replace[$Voidvault::Replace::FILE-FSTAB];
also does Voidvault::Replace[$Voidvault::Replace::FILE-GRUB-DEFAULT];
also does Voidvault::Replace[$Voidvault::Replace::FILE-GRUB-LINUX];
also does Voidvault::Replace[$Voidvault::Replace::FILE-HOSTS];
also does Voidvault::Replace[$Voidvault::Replace::FILE-LOCALES];
also does Voidvault::Replace[$Voidvault::Replace::FILE-OPENRESOLV];
also does Voidvault::Replace[$Voidvault::Replace::FILE-PAM];
also does Voidvault::Replace[$Voidvault::Replace::FILE-RC];
also does Voidvault::Replace[$Voidvault::Replace::FILE-SSH-MODULI];
also does Voidvault::Replace[$Voidvault::Replace::FILE-SSH-SSHD];
also does Voidvault::Replace[$Voidvault::Replace::FILE-SECURETTY];
also does Voidvault::Replace[$Voidvault::Replace::FILE-SUDOERS];
also does Voidvault::Replace[$Voidvault::Replace::FILE-SYSCTL];


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
# bootstrap
# -----------------------------------------------------------------------------

method bootstrap(::?CLASS:D: --> Nil)
{
    my Bool:D $augment = $.config.augment;
    self.mkdisk;
    self.voidstrap-base;
    self.install-vault-key;
    self.configure-users;
    self.configure-sudoers;
    self.genfstab;
    self.set-hostname;
    self.configure-hosts;
    self.configure-dhcpcd;
    self.configure-dnscrypt-proxy;
    self.set-nameservers;
    self.set-locale;
    self.set-keymap;
    self.set-timezone;
    self.set-hwclock;
    self.configure-modprobe;
    self.configure-modules-load;
    self.generate-initramfs;
    self.install-bootloader;
    self.configure-sysctl;
    self.configure-nftables;
    self.configure-openssh;
    self.configure-udev;
    self.configure-hidepid;
    self.configure-securetty;
    self.configure-shell-timeout;
    self.configure-pamd;
    self.configure-xorg;
    self.configure-rc-local;
    self.configure-rc-shutdown;
    self.enable-runit-services;
    self.augment if $augment.so;
    self.unmount;
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

    # create and open vault
    self.mkvault;

    # create and mount btrfs volumes
    self.mkbtrfs;

    # mount efi boot
    self.mount-efi;

    # disable btrfs copy-on-write on select directories
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
}

method mount-efi(::?CLASS:D: --> Nil)
{
    my Str:D $partition-efi = self.gen-partition('efi');
    my Str:D $efi-dir = sprintf(Q{/mnt%}, $Voidvault::Constants::EFI-DIR);
    mkdir($efi-dir);
    my Str:D $mount-options = qw<
        nodev
        noexec
        nosuid
    >.join(',');
    run(qqw<mount --options $mount-options $partition-efi $efi-dir>);
}

method disable-cow(::?CLASS:D: --> Nil)
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

method install-vault-key(::?CLASS:D: --> Nil)
{
    my VaultPass $vault-pass = $.config.vault-pass;
    my Str:D $vault-key = $.config.vault-key;
    my Str:D $partition-vault = self.gen-partition('vault');

    # add key to vault
    Voidvault::Utils.install-vault-key(
        :$partition-vault,
        :$vault-key,
        :$vault-pass
    );

    # configure /etc/crypttab for vault key
    self.replace($Voidvault::Replace::FILE-CRYPTTAB);
}

# secure user configuration
multi method configure-users(::?CLASS:D: --> Nil)
{
    self.configure-users('root');
    self.configure-users('admin');
    self.configure-users('guest');
    self.configure-users('sftp');
}

multi method configure-users(::?CLASS:D: 'admin' --> Nil)
{
    my UserName:D $user-name-admin = $.config.user-name-admin;
    self.useradd('admin');
    say("Giving sudo privileges to admin user $user-name-admin...");
    my Str:D $sudoers = qq:to/EOF/;
    $user-name-admin ALL=(ALL) ALL
    $user-name-admin ALL=(ALL) NOPASSWD: /usr/bin/reboot
    $user-name-admin ALL=(ALL) NOPASSWD: /usr/bin/shutdown
    EOF
    spurt('/mnt/etc/sudoers', "\n" ~ $sudoers, :append);
}

multi method configure-users(::?CLASS:D: 'guest' --> Nil)
{
    self.useradd('guest');
}

multi method configure-users(::?CLASS:D: 'root' --> Nil)
{
    self.usermod('root');
}

multi method configure-users(::?CLASS:D: 'sftp' --> Nil)
{
    self.useradd('sftp');
}

multi method useradd(::?CLASS:D: 'admin' --> Nil)
{
    my UserName:D $user-name-admin = $.config.user-name-admin;
    my Str:D $user-pass-hash-admin = $.config.user-pass-hash-admin;
    my Str:D $user-group-admin = qw<
        audio
        cdrom
        dialout
        floppy
        input
        kvm
        optical
        proc
        socklog
        storage
        users
        video
        wheel
        xbuilder
    >.join(',');
    my Str:D $user-shell-admin = '/bin/bash';

    say("Creating new admin user named $user-name-admin...");
    groupadd(:system, 'proc');
    groupadd($user-name-admin);
    run(qqw<
        void-chroot
        /mnt
        useradd
        --create-home
        --gid $user-name-admin
        --groups $user-group-admin
        --password '$user-pass-hash-admin'
        --shell $user-shell-admin
        $user-name-admin
    >);
    chmod(0o700, "/mnt/home/$user-name-admin");
}

multi method useradd(::?CLASS:D: 'guest' --> Nil)
{
    my UserName:D $user-name-guest = $.config.user-name-guest;
    my Str:D $user-pass-hash-guest = $.config.user-pass-hash-guest;
    my Str:D $user-group-guest = qw<
        guests
        users
    >.join(',');
    my Str:D $user-shell-guest = '/bin/bash';

    say("Creating new guest user named $user-name-guest...");
    groupadd($user-name-guest, 'guests');
    run(qqw<
        void-chroot
        /mnt
        useradd
        --create-home
        --gid $user-name-guest
        --groups $user-group-guest
        --password '$user-pass-hash-guest'
        --shell $user-shell-guest
        $user-name-guest
    >);
    chmod(0o700, "/mnt/home/$user-name-guest");
}

multi method useradd(::?CLASS:D: 'sftp' --> Nil)
{
    my UserName:D $user-name-sftp = $.config.user-name-sftp;
    my Str:D $user-pass-hash-sftp = $.config.user-pass-hash-sftp;
    # https://wiki.archlinux.org/index.php/SFTP_chroot
    my Str:D $user-group-sftp = 'sftponly';
    my Str:D $user-shell-sftp = '/sbin/nologin';
    my Str:D $auth-dir = '/etc/ssh/authorized_keys';
    my Str:D $jail-dir = '/srv/ssh/jail';
    my Str:D $home-dir = "$jail-dir/$user-name-sftp";
    my Str:D @root-dir = $auth-dir, $jail-dir;

    say("Creating new SFTP user named $user-name-sftp...");
    void-chroot-mkdir(@root-dir, 'root', 'root', 0o755);
    groupadd($user-name-sftp, $user-group-sftp);
    run(qqw<
        void-chroot
        /mnt
        useradd
        --no-create-home
        --home-dir $home-dir
        --gid $user-name-sftp
        --groups $user-group-sftp
        --password '$user-pass-hash-sftp'
        --shell $user-shell-sftp
        $user-name-sftp
    >);
    void-chroot-mkdir($home-dir, $user-name-sftp, $user-name-sftp, 0o700);
}

method usermod(::?CLASS:D: 'root' --> Nil)
{
    my Str:D $user-pass-hash-root = $.config.user-pass-hash-root;
    say('Updating root password...');
    run(qqw<void-chroot /mnt usermod --password '$user-pass-hash-root' root>);
    say('Changing root shell to bash...');
    run(qqw<void-chroot /mnt usermod --shell /bin/bash root>);
}

multi sub groupadd(Bool:D :system($)! where .so, *@group-name --> Nil)
{
    @group-name.map(-> Str:D $group-name {
        run(qqw<void-chroot /mnt groupadd --system $group-name>);
    });
}

multi sub groupadd(*@group-name --> Nil)
{
    @group-name.map(-> Str:D $group-name {
        run(qqw<void-chroot /mnt groupadd $group-name>);
    });
}

method configure-sudoers(::?CLASS:D: --> Nil)
{
    self.replace($Voidvault::Replace::FILE-SUDOERS);
}

method genfstab(::?CLASS:D: --> Nil)
{
    my Str:D $path = 'usr/bin/genfstab';
    my Str:D $file = sprintf(Q{/mnt%s}, $Voidvault::Replace::FILE-FSTAB);
    copy(%?RESOURCES{$path}, $file);
    shell("%?RESOURCES{$path} -U -p /mnt >> $file");
    self.replace($Voidvault::Replace::FILE-FSTAB);
}

method set-hostname(::?CLASS:D: --> Nil)
{
    my HostName:D $host-name = $.config.host-name;
    spurt('/mnt/etc/hostname', $host-name ~ "\n");
}

method configure-hosts(::?CLASS:D: --> Nil)
{
    self.replace($Voidvault::Replace::FILE-HOSTS);
}

method configure-dhcpcd(::?CLASS:D: --> Nil)
{
    self.replace($Voidvault::Replace::FILE-DHCPCD);
}

method configure-dnscrypt-proxy(::?CLASS:D: --> Nil)
{
    self.replace($Voidvault::Replace::FILE-DNSCRYPT-PROXY);
}

method set-nameservers(::?CLASS:D: --> Nil)
{
    self.replace($Voidvault::Replace::FILE-OPENRESOLV);
}

method set-locale(::?CLASS:D: --> Nil)
{
    my Locale:D $locale = $.config.locale;
    my Str:D $locale-fallback = $locale.substr(0, 2);
    my LibcFlavor:D $libc-flavor = $Void::XBPS::LIBC-FLAVOR;

    # customize /etc/locale.conf
    my Str:D $locale-conf = qq:to/EOF/;
    LANG=$locale.UTF-8
    LANGUAGE=$locale:$locale-fallback
    LC_TIME=$locale.UTF-8
    EOF
    spurt('/mnt/etc/locale.conf', $locale-conf);

    # musl doesn't support locales
    if $libc-flavor eq 'GLIBC'
    {
        # customize /etc/default/libc-locales
        self.replace($Voidvault::Replace::FILE-LOCALES);
        # regenerate locales
        run(qqw<void-chroot /mnt xbps-reconfigure --force glibc-locales>);
    }
}

method set-keymap(::?CLASS:D: --> Nil)
{
    self.replace($Voidvault::Replace::FILE-RC, 'KEYMAP');
    self.replace($Voidvault::Replace::FILE-RC, 'FONT');
    self.replace($Voidvault::Replace::FILE-RC, 'FONT_MAP');
}

method set-timezone(::?CLASS:D: --> Nil)
{
    my Timezone:D $timezone = $.config.timezone;
    run(qqw<
        void-chroot
        /mnt
        ln
        --symbolic
        --force
        /usr/share/zoneinfo/$timezone
        /etc/localtime
    >);
    self.replace($Voidvault::Replace::FILE-RC, 'TIMEZONE');
}

method set-hwclock(::?CLASS:D: --> Nil)
{
    self.replace($Voidvault::Replace::FILE-RC, 'HARDWARECLOCK');
    run(qqw<void-chroot /mnt hwclock --systohc --utc>);
}

method configure-modprobe(::?CLASS:D: --> Nil)
{
    my Str:D $path = 'etc/modprobe.d/modprobe.conf';
    copy(%?RESOURCES{$path}, "/mnt/$path");
}

method configure-modules-load(::?CLASS:D: --> Nil)
{
    my Str:D $path = 'etc/modules-load.d/bbr.conf';
    copy(%?RESOURCES{$path}, "/mnt/$path");
}

method generate-initramfs(::?CLASS:D: --> Nil)
{
    my Str:D $linux-version = dir('/mnt/usr/lib/modules').first.basename;
    my Str:D $xbps-linux-version-raw =
        qx{xbps-query --rootdir /mnt --property pkgver linux}.trim;
    my Str:D $xbps-linux-version =
        $xbps-linux-version-raw.substr(6..*).split(/'.'|'_'/)[^2].join('.');
    my Str:D $xbps-linux = sprintf(Q{linux%s}, $xbps-linux-version);

    # dracut
    self.replace($Voidvault::Replace::FILE-DRACUT);
    run(qqw<void-chroot /mnt dracut --force --kver $linux-version>);

    # xbps-reconfigure
    run(qqw<void-chroot /mnt xbps-reconfigure --force $xbps-linux>);
}

method install-bootloader(::?CLASS:D: --> Nil)
{
    my Str:D $device = $.config.device;
    self.replace($Voidvault::Replace::FILE-GRUB-DEFAULT);
    self.replace($Voidvault::Replace::FILE-GRUB-LINUX);
    self.configure-bootloader('superusers');
    install-bootloader($device);
}

method configure-bootloader(::?CLASS:D: 'superusers' --> Nil)
{
    my UserName:D $user-name-grub = $.config.user-name-grub;
    my Str:D $user-pass-hash-grub = $.config.user-pass-hash-grub;
    my Str:D $grub-superusers = qq:to/EOF/;
    set superusers="$user-name-grub"
    password_pbkdf2 $user-name-grub $user-pass-hash-grub
    EOF
    spurt('/mnt/etc/grub.d/40_custom', $grub-superusers, :append);
}

multi sub install-bootloader(
    Str:D $device
    --> Nil
)
{
    install-bootloader(:legacy, $device);
    install-bootloader(:uefi, 32, $device) if $*KERNEL.bits == 32;
    install-bootloader(:uefi, 64, $device) if $*KERNEL.bits == 64;
    mkdir('/mnt/boot/grub/locale');
    copy(
        '/mnt/usr/share/locale/en@quot/LC_MESSAGES/grub.mo',
        '/mnt/boot/grub/locale/en.mo'
    );
    run(qqw<
        void-chroot
        /mnt
        grub-mkconfig
        --output=/boot/grub/grub.cfg
    >);
}

multi sub install-bootloader(
    Str:D $device,
    Bool:D :legacy($)! where .so
    --> Nil
)
{
    # legacy bios
    run(qqw<
        void-chroot
        /mnt
        grub-install
        --target=i386-pc
        --recheck
    >, $device);
}

multi sub install-bootloader(
    32,
    Str:D $device,
    Bool:D :uefi($)! where .so
    --> Nil
)
{
    # uefi - i686
    run(qqw<
        void-chroot
        /mnt
        grub-install
        --target=i386-efi
        --efi-directory=/boot/efi
        --removable
    >, $device);

    # fix virtualbox uefi
    my Str:D $nsh = q:to/EOF/;
    fs0:
    \EFI\BOOT\BOOTIA32.EFI
    EOF
    spurt('/mnt/boot/efi/startup.nsh', $nsh, :append);
}

multi sub install-bootloader(
    64,
    Str:D $device,
    Bool:D :uefi($)! where .so
    --> Nil
)
{
    # uefi - x86_64
    run(qqw<
        void-chroot
        /mnt
        grub-install
        --target=x86_64-efi
        --efi-directory=/boot/efi
        --removable
    >, $device);

    # fix virtualbox uefi
    my Str:D $nsh = q:to/EOF/;
    fs0:
    \EFI\BOOT\BOOTX64.EFI
    EOF
    spurt('/mnt/boot/efi/startup.nsh', $nsh, :append);
}

method configure-sysctl(::?CLASS:D: --> Nil)
{
    self.replace($Voidvault::Replace::FILE-SYSCTL);
    run(qqw<void-chroot /mnt sysctl --system>);
}

method configure-nftables(::?CLASS:D: --> Nil)
{
    my Str:D @path =
        'etc/nftables.conf',
        'etc/nftables/wireguard/table/inet/filter/forward/wireguard.nft',
        'etc/nftables/wireguard/table/inet/filter/input/wireguard.nft',
        'etc/nftables/wireguard/table/wireguard.nft';
    @path.map(-> Str:D $path {
        my Str:D $base-path = $path.IO.dirname;
        mkdir("/mnt/$base-path");
        copy(%?RESOURCES{$path}, "/mnt/$path");
    });
}

method configure-openssh(::?CLASS:D: --> Nil)
{
    self.configure-openssh('ssh_config');
    self.configure-openssh('sshd_config');
    self.configure-openssh('moduli');
}

multi method configure-openssh(::?CLASS:D: 'ssh_config' --> Nil)
{
    my Str:D $path = 'etc/ssh/ssh_config';
    copy(%?RESOURCES{$path}, "/mnt/$path");
}

multi method configure-openssh(::?CLASS:D: 'sshd_config' --> Nil)
{
    self.replace('sshd_config');
}

multi method configure-openssh(::?CLASS:D: 'moduli' --> Nil)
{
    # filter weak ssh moduli
    self.replace('moduli');
}

method configure-udev(::?CLASS:D: --> Nil)
{
    my Str:D $path = 'etc/udev/rules.d/60-io-schedulers.rules';
    my Str:D $base-path = $path.IO.dirname;
    mkdir("/mnt/$base-path");
    copy(%?RESOURCES{$path}, "/mnt/$path");
}

method configure-hidepid(::?CLASS:D: --> Nil)
{
    my Str:D $file = sprintf(Q{/mnt%s}, $Voidvault::Replace::FILE-FSTAB);
    my Str:D $fstab-hidepid = q:to/EOF/;
    # /proc with hidepid (https://wiki.archlinux.org/index.php/Security#hidepid)
    proc                                      /proc       proc        nodev,noexec,nosuid,hidepid=2,gid=proc 0 0
    EOF
    spurt($file, "\n" ~ $fstab-hidepid, :append);
}

method configure-securetty(::?CLASS:D: --> Nil)
{
    self.replace('securetty');
}


method configure-shell-timeout(::?CLASS:D: --> Nil)
{
    my Str:D $path = 'etc/profile.d/shell-timeout.sh';
    copy(%?RESOURCES{$path}, "/mnt/$path");
}

method configure-pamd(::?CLASS:D: --> Nil)
{
    # raise number of passphrase hashing rounds C<passwd> employs
    self.replace($Voidvault::Replace::FILE-PAM);
}

method configure-xorg(::?CLASS:D: --> Nil)
{
    configure-xorg('Xwrapper.config');
    configure-xorg('10-synaptics.conf');
    configure-xorg('99-security.conf');
}

multi sub configure-xorg('Xwrapper.config' --> Nil)
{
    my Str:D $path = 'etc/X11/Xwrapper.config';
    my Str:D $base-path = $path.IO.dirname;
    mkdir("/mnt/$base-path");
    copy(%?RESOURCES{$path}, "/mnt/$path");
}

multi sub configure-xorg('10-synaptics.conf' --> Nil)
{
    my Str:D $path = 'etc/X11/xorg.conf.d/10-synaptics.conf';
    my Str:D $base-path = $path.IO.dirname;
    mkdir("/mnt/$base-path");
    copy(%?RESOURCES{$path}, "/mnt/$path");
}

multi sub configure-xorg('99-security.conf' --> Nil)
{
    my Str:D $path = 'etc/X11/xorg.conf.d/99-security.conf';
    my Str:D $base-path = $path.IO.dirname;
    mkdir("/mnt/$base-path");
    copy(%?RESOURCES{$path}, "/mnt/$path");
}

method configure-rc-local(::?CLASS:D: --> Nil)
{
    my Str:D $rc-local = q:to/EOF/;
    # create zram swap device
    zramen make

    # disable blinking cursor in Linux tty
    echo 0 > /sys/class/graphics/fbcon/cursor_blink
    EOF
    spurt('/mnt/etc/rc.local', "\n" ~ $rc-local, :append);
}

method configure-rc-shutdown(::?CLASS:D: --> Nil)
{
    my Str:D $rc-shutdown = q:to/EOF/;
    # teardown zram swap device
    zramen toss
    EOF
    spurt('/mnt/etc/rc.shutdown', "\n" ~ $rc-shutdown, :append);
}

method enable-runit-services(::?CLASS:D: --> Nil)
{
    my Bool:D $enable-serial-console = $.config.enable-serial-console;

    my Str:D @service = @Voidvault::Constants::SERVICE;

    # enable serial getty when using serial console, e.g. agetty-ttyS0
    push(@service, sprintf(Q{agetty-%s}, $Voidvault::Constants::SERIAL-CONSOLE))
        if $enable-serial-console.so;

    @service.map(-> Str:D $service {
        run(qqw<
            void-chroot
            /mnt
            ln
            --symbolic
            --force
            /etc/sv/$service
            /etc/runit/runsvdir/default/$service
        >);
    });
}

# interactive console
method augment(::?CLASS:D: --> Nil)
{
    # launch fully interactive Bash console, type 'exit' to exit
    shell('expect -c "spawn /bin/bash; interact"');
}

method unmount(::?CLASS:D: --> Nil)
{
    my VaultName:D $vault-name = $.config.vault-name;
    # resume after error with C<umount -R>, obsolete but harmless
    CATCH { default { .resume } };
    run(qw<umount --recursive --verbose /mnt>);
    run(qqw<cryptsetup luksClose $vault-name>);
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

multi sub void-chroot-mkdir(
    Str:D @dir,
    Str:D $user,
    Str:D $group,
    # permissions should be octal: https://docs.raku.org/routine/chmod
    UInt:D $permissions
    --> Nil
)
{
    @dir.map(-> Str:D $dir {
        void-chroot-mkdir($dir, $user, $group, $permissions)
    });
}

multi sub void-chroot-mkdir(
    Str:D $dir,
    Str:D $user,
    Str:D $group,
    UInt:D $permissions
    --> Nil
)
{
    mkdir("/mnt/$dir", $permissions);
    run(qqw<void-chroot /mnt chown $user:$group $dir>);
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
