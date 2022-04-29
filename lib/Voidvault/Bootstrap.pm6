use v6;
use Voidvault::Config;
use Voidvault::Constants;
use Voidvault::Replace;
use Voidvault::Types;
use Voidvault::Utils;
use Void::Constants;
use Void::Utils;
unit role Voidvault::Bootstrap;
also does Voidvault::Replace[$Voidvault::Constants::FILE-CRYPTTAB];
also does Voidvault::Replace[$Voidvault::Constants::FILE-DHCPCD];
also does Voidvault::Replace[$Voidvault::Constants::FILE-DNSCRYPT-PROXY];
also does Voidvault::Replace[$Voidvault::Constants::FILE-DRACUT];
also does Voidvault::Replace[$Voidvault::Constants::FILE-EFI-STARTUP];
also does Voidvault::Replace[$Voidvault::Constants::FILE-FSTAB];
also does Voidvault::Replace[$Voidvault::Constants::FILE-GRUB-DEFAULT];
also does Voidvault::Replace[$Voidvault::Constants::FILE-GRUB-LINUX];
also does Voidvault::Replace[$Voidvault::Constants::FILE-HOSTS];
also does Voidvault::Replace[$Voidvault::Constants::FILE-LOCALES];
also does Voidvault::Replace[$Voidvault::Constants::FILE-OPENRESOLV];
also does Voidvault::Replace[$Voidvault::Constants::FILE-OPENSSH-DAEMON];
also does Voidvault::Replace[$Voidvault::Constants::FILE-OPENSSH-MODULI];
also does Voidvault::Replace[$Voidvault::Constants::FILE-PAM];
also does Voidvault::Replace[$Voidvault::Constants::FILE-RC];
also does Voidvault::Replace[$Voidvault::Constants::FILE-SECURETTY];
also does Voidvault::Replace[$Voidvault::Constants::FILE-SUDOERS];
also does Voidvault::Replace[$Voidvault::Constants::FILE-SYSCTL];


# -----------------------------------------------------------------------------
# attributes
# -----------------------------------------------------------------------------

has Voidvault::Config:D $.config is required;

# C<--bind> mounted directories in order of being mounted, for C<umount>
has Str:D @!secure-mount;

# -----------------------------------------------------------------------------
# bootstrap
# -----------------------------------------------------------------------------

multi method bootstrap(::?CLASS:D: --> Nil)
{
    my Bool:D $augment = $.config.augment;
    self.mkdisk;
    self.voidstrap-base;
    self.install-vault-key-file;
    self.configure-crypttab;
    self.configure-users;
    self.configure-sudoers;
    self.secure-mount;
    # mounting efi partition isn't done here in all modes
    self.bootstrap('mount-efi');
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
    self.configure-bootloader;
    self.install-bootloader;
    self.configure-sysctl;
    self.configure-nftables;
    self.configure-openssh;
    self.configure-udev;
    self.configure-securetty;
    self.configure-security-limits;
    self.configure-shell-timeout;
    self.configure-pamd;
    self.configure-shadow;
    self.configure-xorg;
    self.configure-dbus;
    self.configure-rc-local;
    self.configure-rc-shutdown;
    self.enable-runit-services;
    self.secure-secret-prefix;
    self.augment if $augment;
    self.unmount;
}

# prevents having to reimplement method C<bootstrap> in other modes
multi method bootstrap(::?CLASS:D: 'mount-efi' --> Nil)
{
    self.mount-efi;
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

method mkvault(::?CLASS:D: --> Nil)
{
    my VaultType:D $vault-type = 'LUKS1';
    my Str:D $partition-vault = self.gen-partition('vault');
    my VaultName:D $vault-name = $.config.vault-name;
    my VaultPass $vault-pass = $.config.vault-pass;
    my Str:D $vault-cipher = $.config.vault-cipher;
    my Str:D $vault-hash = $.config.vault-hash;
    my Str:D $vault-iter-time = $.config.vault-iter-time;
    my Str:D $vault-key-size = $.config.vault-key-size;
    my Str $vault-offset = $.config.vault-offset;
    my Str $vault-sector-size = $.config.vault-sector-size;
    Voidvault::Utils.mkvault(
        :open,
        :$vault-type,
        :$partition-vault,
        :$vault-name,
        :$vault-pass,
        :$vault-cipher,
        :$vault-hash,
        :$vault-iter-time,
        :$vault-key-size,
        :$vault-offset,
        :$vault-sector-size
    );
}

# create and mount btrfs filesystem on opened vault
method mkbtrfs(::?CLASS:D: --> Nil)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my DiskType:D $disk-type = $.config.disk-type;
    my VaultName:D $vault-name = $.config.vault-name;
    my Str:D @subvolume = @Voidvault::Constants::SUBVOLUME;

    # missing C<xxhash_generic> seemingly breaks C<--csum xxhash>
    my Str:D @kernel-module = qw<btrfs xxhash_generic>;

    # use xxhash checksum algorithm
    my Str:D @mkfs-option = qw<--csum xxhash>;

    # main btrfs filesystem mount options - also used with subvolumes
    my Str:D @mount-option = qw<
        rw
        noatime
        compress-force=zstd
        space_cache=v2
    >;
    push(@mount-option, 'ssd') if $disk-type eq 'SSD';

    Voidvault::Utils.mkbtrfs(
        :$chroot-dir,
        :$vault-name,
        :@subvolume,
        :&mount-subvolume,
        :@kernel-module,
        :@mkfs-option,
        :@mount-option
    );
}

sub mount-subvolume(
    Str:D :$subvolume! where .so,
    Str:D :$vault-device-mapper! where .so,
    Str:D :$chroot-dir! where .so,
    # for passing main btrfs filesystem mount options to subvolumes
    Str:D :mount-option(@mo)
    --> Nil
)
{
    my Str:D @mount-option =
        gen-btrfs-subvolume-mount-options(:$subvolume, :mount-option(@mo));
    my Str:D $mount-dir =
        gen-btrfs-subvolume-mount-dir(:$subvolume, :$chroot-dir);
    mkdir($mount-dir);
    my Str:D $mount-btrfs-subvolume-cmdline =
        Voidvault::Utils.build-mount-btrfs-cmdline(
            :@mount-option,
            :$vault-device-mapper,
            :$mount-dir
        );
    shell($mount-btrfs-subvolume-cmdline);
    set-subvolume-mount-dir-permissions(:$subvolume, :$mount-dir);
}

proto sub gen-btrfs-subvolume-mount-options(
    Str:D :$subvolume! where .so,
    Str:D :@mount-option!
    --> Array[Str:D]
)
{
    # begin by duplicating mount options given to main btrfs filesystem
    my Str:D @*mount-option = |@mount-option;

    # gather subvolume-specific mount options, if any
    {*}

    # finish with mount option applicable to all subvolumes
    push(@*mount-option, sprintf(Q{subvol=%s}, $subvolume));
}

multi sub gen-btrfs-subvolume-mount-options(
    Str:D :subvolume($)! where {
        @Voidvault::Constants::SUBVOLUME-NODEV-NOEXEC-NOSUID.grep($_)
    },
    Str:D :mount-option(@)!
    --> Nil
)
{
    push(@*mount-option, |qw<nodev noexec nosuid>);
}

multi sub gen-btrfs-subvolume-mount-options(
    Str:D :subvolume($)! where {
        @Voidvault::Constants::SUBVOLUME-NODEV-NOSUID.grep($_)
    },
    Str:D :mount-option(@)!
    --> Nil
)
{
    push(@*mount-option, |qw<nodev nosuid>);
}

multi sub gen-btrfs-subvolume-mount-options(
    Str:D :subvolume($)! where {
        @Voidvault::Constants::SUBVOLUME-NODEV.grep($_)
    },
    Str:D :mount-option(@)!
    --> Nil
)
{
    push(@*mount-option, |qw<nodev>);
}

multi sub gen-btrfs-subvolume-mount-options(
    Str:D :subvolume($)!,
    Str:D :mount-option(@)!
    --> Nil
)
{*}

# return target directory at which to mount subvolume
sub gen-btrfs-subvolume-mount-dir(
    Str:D :$subvolume! where .so,
    AbsolutePath:D :$chroot-dir! where .so
    --> Str:D
)
{
    my Str:D $mount-dir = $subvolume.substr(1).subst('-', '/', :g);
    sprintf(Q{%s/%s}, $chroot-dir, $mount-dir);
}

multi sub set-subvolume-mount-dir-permissions(
    Str:D :subvolume($)! where {
        @Voidvault::Constants::SUBVOLUME-STICKY-BIT-A-PLUS-RWX.grep($_)
    },
    Str:D :$mount-dir! where .so
    --> Nil
)
{
    # these target directories normally appear with 1777 permissions
    my Str:D $chmod-subvolume-cmdline = sprintf(Q{chmod 1777 %s}, $mount-dir);
    shell($chmod-subvolume-cmdline);
}

multi sub set-subvolume-mount-dir-permissions(
    Str:D :subvolume($)!,
    Str:D :mount-dir($)!
    --> Nil
)
{*}

method disable-cow(::?CLASS:D: --> Nil)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    # these directories were previously made during C<self.mkbtrfs>
    my Str:D @dir =
        @Voidvault::Constants::DIRECTORY-BTRFS-NODATACOW.map(-> Str:D $dir {
            sprintf(Q{%s%s}, $chroot-dir, $dir)
        });
    Voidvault::Utils.disable-cow(|@dir, :recursive);
}

# bootstrap initial chroot with voidstrap
method voidstrap-base(::?CLASS:D: --> Nil)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my Str:D @repository = $.config.repository;
    my Bool:D $ignore-conf-repos = $.config.ignore-conf-repos;
    my Str:D @package = $.config.package;
    my Processor:D $processor = $.config.processor;
    my LibcFlavor:D $libc-flavor = $Void::Constants::LIBC-FLAVOR;

    # download and install core packages with voidstrap in chroot
    my Str:D @core = @Voidvault::Constants::PACKAGE-CORE;
    Void::Utils.voidstrap(
        $chroot-dir,
        :@repository,
        :$ignore-conf-repos,
        @core
    );

    # base packages - void's C<base-minimal> with light additions
    # duplicates C<base-minimal>'s C<depends> for thoroughness
    my Str:D @base = @Voidvault::Constants::PACKAGE-BASE;
    push(@base, 'glibc') if $libc-flavor eq 'GLIBC';
    push(@base, 'musl') if $libc-flavor eq 'MUSL';
    push(@base, 'grub-i386-efi') if $*KERNEL.bits == 32;
    push(@base, 'grub-x86_64-efi') if $*KERNEL.bits == 64;
    # https://www.archlinux.org/news/changes-to-intel-microcodeupdates/
    push(@base, 'intel-ucode') if $processor eq 'INTEL';
    push(@base, $_) for @package;

    # download and install base packages with voidstrap in chroot
    Void::Utils.voidstrap(
        $chroot-dir,
        :@repository,
        :$ignore-conf-repos,
        @base
    );
}

method install-vault-key-file(::?CLASS:D: --> Nil)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my VaultPass $vault-pass = $.config.vault-pass;
    my VaultKeyFile:D $vault-key-file = $.config.vault-key-file;
    my Str:D $partition-vault = self.gen-partition('vault');

    # add key to vault
    Voidvault::Utils.install-vault-key-file(
        :$partition-vault,
        :$vault-key-file,
        :$vault-pass,
        :$chroot-dir
    );
}

multi method configure-crypttab(::?CLASS:D: --> Nil)
{
    # configure /etc/crypttab for vault key file
    self.replace($Voidvault::Constants::FILE-CRYPTTAB);
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
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my UserName:D $user-name-admin = $.config.user-name-admin;
    my Str:D $file =
        sprintf(Q{%s%s}, $chroot-dir, $Voidvault::Constants::FILE-SUDOERS);
    self.useradd('admin');
    say("Giving sudo privileges to admin user $user-name-admin...");
    my Str:D $sudoers = qq:to/EOF/;
    $user-name-admin ALL=(ALL) ALL
    $user-name-admin ALL=(ALL) NOPASSWD: /usr/bin/reboot
    $user-name-admin ALL=(ALL) NOPASSWD: /usr/bin/shutdown
    EOF
    spurt($file, "\n" ~ $sudoers, :append);
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
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
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
    Voidvault::Utils.groupadd(:system, 'proc', :$chroot-dir);
    Voidvault::Utils.groupadd($user-name-admin, :$chroot-dir);
    run(qqw<
        void-chroot
        $chroot-dir
        useradd
        --create-home
        --gid $user-name-admin
        --groups $user-group-admin
        --password '$user-pass-hash-admin'
        --shell $user-shell-admin
        $user-name-admin
    >);
    chmod(0o700, "$chroot-dir/home/$user-name-admin");
}

multi method useradd(::?CLASS:D: 'guest' --> Nil)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my UserName:D $user-name-guest = $.config.user-name-guest;
    my Str:D $user-pass-hash-guest = $.config.user-pass-hash-guest;
    my Str:D $user-group-guest = qw<
        guests
        users
    >.join(',');
    my Str:D $user-shell-guest = '/bin/bash';

    say("Creating new guest user named $user-name-guest...");
    Voidvault::Utils.groupadd($user-name-guest, 'guests', :$chroot-dir);
    run(qqw<
        void-chroot
        $chroot-dir
        useradd
        --create-home
        --gid $user-name-guest
        --groups $user-group-guest
        --password '$user-pass-hash-guest'
        --shell $user-shell-guest
        $user-name-guest
    >);
    chmod(0o700, "$chroot-dir/home/$user-name-guest");
}

multi method useradd(::?CLASS:D: 'sftp' --> Nil)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
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
    Voidvault::Utils.void-chroot-mkdir(
        @root-dir,
        :user<root>,
        :group<root>,
        :permissions(0o755),
        :$chroot-dir
    );
    Voidvault::Utils.groupadd($user-name-sftp, $user-group-sftp, :$chroot-dir);
    run(qqw<
        void-chroot
        $chroot-dir
        useradd
        --no-create-home
        --home-dir $home-dir
        --gid $user-name-sftp
        --groups $user-group-sftp
        --password '$user-pass-hash-sftp'
        --shell $user-shell-sftp
        $user-name-sftp
    >);
    Voidvault::Utils.void-chroot-mkdir(
        $home-dir,
        :user($user-name-sftp),
        :group($user-name-sftp),
        :permissions(0o700),
        :$chroot-dir
    );
}

method usermod(::?CLASS:D: 'root' --> Nil)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my Str:D $user-pass-hash-root = $.config.user-pass-hash-root;
    say('Updating root password...');
    run(qqw<
        void-chroot
        $chroot-dir
        usermod
        --password '$user-pass-hash-root'
        root
    >);
    say('Changing root shell to bash...');
    run(qqw<
        void-chroot
        $chroot-dir
        usermod
        --shell /bin/bash
        root
    >);
}

method configure-sudoers(::?CLASS:D: --> Nil)
{
    self.replace($Voidvault::Constants::FILE-SUDOERS);
}

# add protective mount options to select directories
proto method secure-mount(::?CLASS:D: --> Nil)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;

    my Str:D @*directory-bind-mounted =
        @Voidvault::Constants::DIRECTORY-BIND-MOUNTED;

    maybe-grep-multilib(@*directory-bind-mounted);

    # facilitate cross-mode modification of C<@*directory-bind-mounted>
    {*}

    push(@!secure-mount, secure-mount($_, :$chroot-dir))
        for @*directory-bind-mounted;
}

# no further modification to C<@*directory-bind-mounted> needed
multi method secure-mount(::?CLASS:D: --> Nil)
{*}

multi sub secure-mount(
    Str:D $path where '/boot',
    AbsolutePath:D :$chroot-dir! where .so
    --> Str:D
)
{
    Voidvault::Utils.secure-mount(
        $path,
        :$chroot-dir,
        :nodev,
        :noexec,
        :nosuid
    );
}

multi sub secure-mount(
    Str:D $path where '/etc',
    AbsolutePath:D :$chroot-dir! where .so
    --> Str:D
)
{
    Voidvault::Utils.secure-mount($path, :$chroot-dir, :nodev, :nosuid);
}

multi sub secure-mount(
    Str:D $path where '/mnt',
    AbsolutePath:D :$chroot-dir! where .so
    --> Str:D
)
{
    Voidvault::Utils.secure-mount($path, :$chroot-dir, :nodev);
}

multi sub secure-mount(
    Str:D $path where '/root',
    AbsolutePath:D :$chroot-dir! where .so
    --> Str:D
)
{
    Voidvault::Utils.secure-mount($path, :$chroot-dir, :nodev);
}

multi sub secure-mount(
    Str:D $path where '/usr',
    AbsolutePath:D :$chroot-dir! where .so
    --> Str:D
)
{
    Voidvault::Utils.secure-mount($path, :$chroot-dir, :nodev);
}

multi sub secure-mount(
    Str:D $path where '/usr/lib',
    AbsolutePath:D :$chroot-dir! where .so
    --> Str:D
)
{
    Voidvault::Utils.secure-mount($path, :$chroot-dir, :nodev, :nosuid);
}

multi sub secure-mount(
    Str:D $path where '/usr/lib32',
    AbsolutePath:D :$chroot-dir! where .so
    --> Str:D
)
{
    Voidvault::Utils.secure-mount($path, :$chroot-dir, :nodev, :nosuid);
}

method mount-efi(::?CLASS:D: --> Nil)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my Str:D $partition-efi = self.gen-partition('efi');
    my Str:D $directory-efi =
        sprintf(Q{%s%s}, $chroot-dir, $Voidvault::Constants::DIRECTORY-EFI);
    Voidvault::Utils.secure-mount-efi(:$partition-efi, :$directory-efi);
    push(@!secure-mount, $directory-efi);
}

method genfstab(::?CLASS:D: --> Nil)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my Str:D $file =
        sprintf(Q{%s%s}, $chroot-dir, $Voidvault::Constants::FILE-FSTAB);
    my RelativePath:D $resource = 'usr/bin/genfstab';

    # install genfstab
    Voidvault::Utils.install-resource($resource, :$chroot-dir);

    # generate /etc/fstab
    shell("%?RESOURCES{$resource} -U -p $chroot-dir >> $file");

    # configure /etc/fstab
    self.configure-fstab;
}

multi method configure-fstab(::?CLASS:D: --> Nil)
{
    my Str:D @directory-bind-mounted =
        @Voidvault::Constants::DIRECTORY-BIND-MOUNTED;
    my Str:D $directory-efi = $Voidvault::Constants::DIRECTORY-EFI;

    # configure C</proc> and C</tmp> fstab entries
    self.replace($Voidvault::Constants::FILE-FSTAB);

    # fix C<genfstab>-generated C<--bind> mounted directories
    maybe-grep-multilib(@directory-bind-mounted);
    self.configure-fstab(:@directory-bind-mounted);

    # reposition C</boot/efi> below C<--bind> mounted C</boot> fstab entry
    self.configure-fstab(:$directory-efi);
}

multi method configure-fstab(
    ::?CLASS:D:
    Str:D :@directory-bind-mounted!
    --> Nil
)
{
    self.replace($Voidvault::Constants::FILE-FSTAB, $_)
        for @directory-bind-mounted;
}

multi method configure-fstab(
    ::?CLASS:D:
    Str:D :$directory-efi! where .so
    --> Nil
)
{
    self.replace($Voidvault::Constants::FILE-FSTAB, $directory-efi);
}

method set-hostname(::?CLASS:D: --> Nil)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my HostName:D $host-name = $.config.host-name;
    spurt("$chroot-dir/etc/hostname", $host-name ~ "\n");
}

method configure-hosts(::?CLASS:D: --> Nil)
{
    self.replace($Voidvault::Constants::FILE-HOSTS);
}

method configure-dhcpcd(::?CLASS:D: --> Nil)
{
    self.replace($Voidvault::Constants::FILE-DHCPCD);
}

method configure-dnscrypt-proxy(::?CLASS:D: --> Nil)
{
    self.replace($Voidvault::Constants::FILE-DNSCRYPT-PROXY);
}

method set-nameservers(::?CLASS:D: --> Nil)
{
    self.replace($Voidvault::Constants::FILE-OPENRESOLV);
}

method set-locale(::?CLASS:D: --> Nil)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my Locale:D $locale = $.config.locale;
    my Str:D $locale-fallback = $locale.substr(0, 2);
    my LibcFlavor:D $libc-flavor = $Void::Constants::LIBC-FLAVOR;

    # customize /etc/locale.conf
    my Str:D $locale-conf = qq:to/EOF/;
    LANG=$locale.UTF-8
    LANGUAGE=$locale:$locale-fallback
    LC_TIME=$locale.UTF-8
    EOF
    spurt("$chroot-dir/etc/locale.conf", $locale-conf);

    # musl doesn't support locales
    self.set-locale-glibc if $libc-flavor eq 'GLIBC';
}

method set-locale-glibc(::?CLASS:D: --> Nil)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    # customize /etc/default/libc-locales
    self.replace($Voidvault::Constants::FILE-LOCALES);
    # regenerate locales
    run(qqw<void-chroot $chroot-dir xbps-reconfigure --force glibc-locales>);
}

method set-keymap(::?CLASS:D: --> Nil)
{
    self.replace($Voidvault::Constants::FILE-RC, 'KEYMAP');
    self.replace($Voidvault::Constants::FILE-RC, 'FONT');
    self.replace($Voidvault::Constants::FILE-RC, 'FONT_MAP');
}

method set-timezone(::?CLASS:D: --> Nil)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my Timezone:D $timezone = $.config.timezone;
    run(qqw<
        void-chroot
        $chroot-dir
        ln
        --symbolic
        --force
        /usr/share/zoneinfo/$timezone
        /etc/localtime
    >);
    self.replace($Voidvault::Constants::FILE-RC, 'TIMEZONE');
}

method set-hwclock(::?CLASS:D: --> Nil)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    self.replace($Voidvault::Constants::FILE-RC, 'HARDWARECLOCK');
    run(qqw<void-chroot $chroot-dir hwclock --systohc --utc>);
}

method configure-modprobe(::?CLASS:D: --> Nil)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my RelativePath:D $resource = 'etc/modprobe.d/modprobe.conf';
    Voidvault::Utils.install-resource($resource, :$chroot-dir);
}

method configure-modules-load(::?CLASS:D: --> Nil)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my RelativePath:D $resource = 'etc/modules-load.d/bbr.conf';
    Voidvault::Utils.install-resource($resource, :$chroot-dir);
}

multi method generate-initramfs(::?CLASS:D: --> Nil)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;

    # dracut
    self.generate-initramfs('add_dracutmodules');
    self.generate-initramfs('add_drivers');
    self.generate-initramfs('compress');
    self.generate-initramfs('hostonly');
    self.generate-initramfs('install_items');
    self.generate-initramfs('omit_dracutmodules');
    self.generate-initramfs('persistent_policy');
    self.generate-initramfs('tmpdir');
    Voidvault::Utils.void-chroot-dracut(:$chroot-dir);

    # xbps-reconfigure
    Voidvault::Utils.void-chroot-xbps-reconfigure-linux(:$chroot-dir);
}

multi method generate-initramfs(
    ::?CLASS:D:
    Str:D $subject where 'add_dracutmodules'
    --> Nil
)
{
    self.replace($Voidvault::Constants::FILE-DRACUT, $subject);
}

multi method generate-initramfs(
    ::?CLASS:D:
    Str:D $subject where 'add_drivers'
    --> Nil
)
{
    self.replace($Voidvault::Constants::FILE-DRACUT, $subject);
}

multi method generate-initramfs(
    ::?CLASS:D:
    Str:D $subject where 'compress'
    --> Nil
)
{
    self.replace($Voidvault::Constants::FILE-DRACUT, $subject);
}

multi method generate-initramfs(
    ::?CLASS:D:
    Str:D $subject where 'hostonly'
    --> Nil
)
{
    self.replace($Voidvault::Constants::FILE-DRACUT, $subject);
}

multi method generate-initramfs(
    ::?CLASS:D:
    Str:D $subject where 'install_items'
    --> Nil
)
{
    self.replace($Voidvault::Constants::FILE-DRACUT, $subject);
}

multi method generate-initramfs(
    ::?CLASS:D:
    Str:D $subject where 'omit_dracutmodules'
    --> Nil
)
{
    self.replace($Voidvault::Constants::FILE-DRACUT, $subject);
}

multi method generate-initramfs(
    ::?CLASS:D:
    Str:D $subject where 'persistent_policy'
    --> Nil
)
{
    self.replace($Voidvault::Constants::FILE-DRACUT, $subject);
}

multi method generate-initramfs(
    ::?CLASS:D:
    Str:D $subject where 'tmpdir'
    --> Nil
)
{
    self.replace($Voidvault::Constants::FILE-DRACUT, $subject);
}

multi method configure-bootloader(::?CLASS:D: --> Nil)
{
    my Bool:D $enable-serial-console = $.config.enable-serial-console;
    self.configure-bootloader('default', 'GRUB_CMDLINE_LINUX_DEFAULT');
    self.configure-bootloader('default', 'GRUB_DISABLE_OS_PROBER');
    self.configure-bootloader('default', 'GRUB_DISABLE_RECOVERY');
    self.configure-bootloader('default', 'GRUB_ENABLE_CRYPTODISK');
    self.configure-bootloader('default', 'GRUB_TERMINAL_INPUT');
    self.configure-bootloader('default', 'GRUB_TERMINAL_OUTPUT');
    self.configure-bootloader('default', 'GRUB_SERIAL_COMMAND')
        if $enable-serial-console;
    self.configure-bootloader('secure');
    self.configure-bootloader('locale');
}

multi method configure-bootloader(
    ::?CLASS:D:
    # named as such for its role in configuring C</etc/default/grub>
    'default',
    Str:D $subject where 'GRUB_CMDLINE_LINUX_DEFAULT'
    --> Nil
)
{
    self.replace($Voidvault::Constants::FILE-GRUB-DEFAULT, $subject);
}

multi method configure-bootloader(
    ::?CLASS:D:
    'default',
    Str:D $subject where 'GRUB_DISABLE_OS_PROBER'
    --> Nil
)
{
    self.replace($Voidvault::Constants::FILE-GRUB-DEFAULT, $subject);
}

multi method configure-bootloader(
    ::?CLASS:D:
    'default',
    Str:D $subject where 'GRUB_DISABLE_RECOVERY'
    --> Nil
)
{
    self.replace($Voidvault::Constants::FILE-GRUB-DEFAULT, $subject);
}

multi method configure-bootloader(
    ::?CLASS:D:
    'default',
    Str:D $subject where 'GRUB_ENABLE_CRYPTODISK'
    --> Nil
)
{
    self.replace($Voidvault::Constants::FILE-GRUB-DEFAULT, $subject);
}

multi method configure-bootloader(
    ::?CLASS:D:
    'default',
    Str:D $subject where 'GRUB_TERMINAL_INPUT'
    --> Nil
)
{
    self.replace($Voidvault::Constants::FILE-GRUB-DEFAULT, $subject);
}

multi method configure-bootloader(
    ::?CLASS:D:
    'default',
    Str:D $subject where 'GRUB_TERMINAL_OUTPUT'
    --> Nil
)
{
    self.replace($Voidvault::Constants::FILE-GRUB-DEFAULT, $subject);
}

multi method configure-bootloader(
    ::?CLASS:D:
    'default',
    Str:D $subject where 'GRUB_SERIAL_COMMAND'
    --> Nil
)
{
    self.replace($Voidvault::Constants::FILE-GRUB-DEFAULT, $subject);
}

# allow any user to boot os, but only allow superuser to edit boot
# entries or access grub command console
multi method configure-bootloader(
    ::?CLASS:D:
    'secure'
    --> Nil
)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my UserName:D $user-name-grub = $.config.user-name-grub;
    my Str:D $user-pass-hash-grub = $.config.user-pass-hash-grub;

    self.replace($Voidvault::Constants::FILE-GRUB-LINUX);

    my Str:D $grub-superusers = qq:to/EOF/;
    set superusers="$user-name-grub"
    password_pbkdf2 $user-name-grub $user-pass-hash-grub
    EOF
    spurt("$chroot-dir/etc/grub.d/40_custom", $grub-superusers, :append);
}

# set locale for grub
multi method configure-bootloader(
    ::?CLASS:D:
    'locale'
    --> Nil
)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    mkdir("$chroot-dir/boot/grub/locale");
    copy(
        "$chroot-dir/usr/share/locale/en@quot/LC_MESSAGES/grub.mo",
        "$chroot-dir/boot/grub/locale/en.mo"
    );
}

multi method install-bootloader(::?CLASS:D: --> Nil)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my Int:D $kernel-bits = $*KERNEL.bits;
    self.install-bootloader(:legacy);
    self.install-bootloader(:uefi, $kernel-bits);
    Voidvault::Utils.void-chroot-grub-mkconfig(:$chroot-dir);
    # fix virtualbox uefi
    self.replace($Voidvault::Constants::FILE-EFI-STARTUP, $kernel-bits);
}

multi method install-bootloader(
    ::?CLASS:D:
    Bool:D :legacy($)! where .so
    --> Nil
)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my Str:D $device = $.config.device;
    Voidvault::Utils.void-chroot-grub-install(:legacy, :$device, :$chroot-dir);
}

multi method install-bootloader(
    ::?CLASS:D:
    Int:D $kernel-bits,
    Bool:D :uefi($)! where .so
    --> Nil
)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my Str:D $device = $.config.device;
    Voidvault::Utils.void-chroot-grub-install(
        :uefi,
        :$device,
        :$chroot-dir,
        $kernel-bits
    );
}

method configure-sysctl(::?CLASS:D: --> Nil)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    self.replace($Voidvault::Constants::FILE-SYSCTL);
    run(qqw<void-chroot $chroot-dir sysctl --system>);
}

method configure-nftables(::?CLASS:D: --> Nil)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my RelativePath:D @resource =
        'etc/nftables.conf',
        'etc/nftables/wireguard/table/inet/filter/forward/wireguard.nft',
        'etc/nftables/wireguard/table/inet/filter/input/wireguard.nft',
        'etc/nftables/wireguard/table/wireguard.nft';
    @resource.map(-> RelativePath:D $resource {
        Voidvault::Utils.install-resource($resource, :$chroot-dir);
    });
}

multi method configure-openssh(::?CLASS:D: --> Nil)
{
    self.configure-openssh('ssh_config');
    self.configure-openssh('sshd_config');
    self.configure-openssh('moduli');
}

multi method configure-openssh(::?CLASS:D: 'ssh_config' --> Nil)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my RelativePath:D $resource = 'etc/ssh/ssh_config';
    Voidvault::Utils.install-resource($resource, :$chroot-dir);
}

multi method configure-openssh(::?CLASS:D: 'sshd_config' --> Nil)
{
    self.replace($Voidvault::Constants::FILE-OPENSSH-DAEMON);
}

multi method configure-openssh(::?CLASS:D: 'moduli' --> Nil)
{
    # filter weak ssh moduli
    self.replace($Voidvault::Constants::FILE-OPENSSH-MODULI);
}

method configure-udev(::?CLASS:D: --> Nil)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my RelativePath:D $resource = 'etc/udev/rules.d/60-io-schedulers.rules';
    Voidvault::Utils.install-resource($resource, :$chroot-dir);
}

method configure-securetty(::?CLASS:D: --> Nil)
{
    self.replace($Voidvault::Constants::FILE-SECURETTY);
}


method configure-security-limits(::?CLASS:D: --> Nil)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my RelativePath:D $resource = 'etc/security/limits.d/coredump.conf';
    Voidvault::Utils.install-resource($resource, :$chroot-dir);
}

method configure-shell-timeout(::?CLASS:D: --> Nil)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my RelativePath:D $resource = 'etc/profile.d/shell-timeout.sh';
    Voidvault::Utils.install-resource($resource, :$chroot-dir);
}

method configure-pamd(::?CLASS:D: --> Nil)
{
    # raise number of passphrase hashing rounds C<passwd> employs
    self.replace($Voidvault::Constants::FILE-PAM);
}

method configure-shadow(--> Nil)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my Str:D $crypt-rounds = ~$Voidvault::Constants::CRYPT-ROUNDS;
    my Str:D $crypt-scheme = $Voidvault::Constants::CRYPT-SCHEME;

    # set C<shadow> (group) passphrase encryption method and hashing
    # rounds in line with pam
    my Str:D $replace = qq:to/EOF/;
    #
    # Encrypt group passwords with {$crypt-scheme}-based algorithm ($crypt-rounds SHA rounds)
    #
    ENCRYPT_METHOD $crypt-scheme
    SHA_CRYPT_MIN_ROUNDS $crypt-rounds
    SHA_CRYPT_MAX_ROUNDS $crypt-rounds
    EOF
    spurt("$chroot-dir/etc/login.defs", "\n" ~ $replace, :append);
}

method configure-xorg(::?CLASS:D: --> Nil)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    configure-xorg('Xwrapper.config', :$chroot-dir);
    configure-xorg('10-synaptics.conf', :$chroot-dir);
    configure-xorg('99-security.conf', :$chroot-dir);
}

multi sub configure-xorg(
    'Xwrapper.config',
    AbsolutePath:D :$chroot-dir! where .so
    --> Nil
)
{
    my RelativePath:D $resource = 'etc/X11/Xwrapper.config';
    Voidvault::Utils.install-resource($resource, :$chroot-dir);
}

multi sub configure-xorg(
    '10-synaptics.conf',
    AbsolutePath:D :$chroot-dir! where .so
    --> Nil
)
{
    my RelativePath:D $resource = 'etc/X11/xorg.conf.d/10-synaptics.conf';
    Voidvault::Utils.install-resource($resource, :$chroot-dir);
}

multi sub configure-xorg(
    '99-security.conf',
    AbsolutePath:D :$chroot-dir! where .so
    --> Nil
)
{
    my RelativePath:D $resource = 'etc/X11/xorg.conf.d/99-security.conf';
    Voidvault::Utils.install-resource($resource, :$chroot-dir);
}

method configure-dbus(::?CLASS:D: --> Nil)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my RelativePath:D $resource = 'var/lib/dbus/machine-id';
    Voidvault::Utils.install-resource($resource, :$chroot-dir);
}

method configure-rc-local(::?CLASS:D: --> Nil)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my Str:D $rc-local = q:to/EOF/;
    # create zram swap device
    zramen make

    # disable blinking cursor in Linux tty
    echo 0 > /sys/class/graphics/fbcon/cursor_blink
    EOF
    spurt("$chroot-dir/etc/rc.local", "\n" ~ $rc-local, :append);
}

method configure-rc-shutdown(::?CLASS:D: --> Nil)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my Str:D $rc-shutdown = q:to/EOF/;
    # teardown zram swap device
    zramen toss
    EOF
    spurt("$chroot-dir/etc/rc.shutdown", "\n" ~ $rc-shutdown, :append);
}

method enable-runit-services(::?CLASS:D: --> Nil)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my Bool:D $enable-serial-console = $.config.enable-serial-console;

    my Str:D @service = @Voidvault::Constants::SERVICE;

    # enable serial getty when using serial console, e.g. agetty-ttyS0
    push(@service, sprintf(Q{agetty-%s}, $Voidvault::Constants::CONSOLE-SERIAL))
        if $enable-serial-console;

    @service.map(-> Str:D $service {
        run(qqw<
            void-chroot
            $chroot-dir
            ln
            --symbolic
            --force
            /etc/sv/$service
            /etc/runit/runsvdir/default/$service
        >);
    });
}

method secure-secret-prefix(::?CLASS:D: --> Nil)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my Str:D $secret-prefix-vault = $Voidvault::Constants::SECRET-PREFIX-VAULT;
    # remove RWX permissions from group and other classes
    run(qqw<void-chroot $chroot-dir chmod -R g-rwx,o-rwx $secret-prefix-vault>);
}

# interactive console
method augment(::?CLASS:D: --> Nil)
{
    say('Spawning interactive Bash console, type `exit` to exit');
    shell('expect -c "spawn /bin/bash; interact"');
}

proto method unmount(::?CLASS:D: --> Nil)
{
    # unmount C<--bind> mounted directories in reverse order
    @!secure-mount.reverse.map(-> Str:D $secure-mount {
        run(qqw<umount --verbose $secure-mount>);
    });
    {*}
}

multi method unmount(::?CLASS:D: --> Nil)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my VaultName:D $vault-name = $.config.vault-name;

    # resume after error with C<umount -R>, obsolete but harmless
    CATCH { default { .resume } };

    # unmount remaining directories
    run(qqw<umount --recursive --verbose $chroot-dir>);

    # close vault
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

sub maybe-grep-multilib(Str:D @directory-bind-mounted --> Nil)
{
    # C</usr/lib32> only appears on 64-bit systems, for multilib
    @directory-bind-mounted .=
        grep(none '/usr/lib32') unless $*KERNEL.bits == 64;
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
