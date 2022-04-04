use v6;
use Voidvault::Config;
use Voidvault::Constants;
use Voidvault::Types;
use Voidvault::Utils;
use Void::Constants;
use Void::Utils;
unit role Voidvault::Bootstrap;


# -----------------------------------------------------------------------------
# attributes
# -----------------------------------------------------------------------------

has Voidvault::Config:D $.config is required;


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
    self.configure-bootloader;
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

method mkvault(::?CLASS:D: --> Nil)
{
    my VaultType:D $vault-type = 'LUKS1';
    my Str:D $partition-vault = self.gen-partition('vault');
    my VaultName:D $vault-name = $.config.vault-name;
    my VaultPass $vault-pass = $.config.vault-pass;
    Voidvault::Utils.mkvault(
        :open,
        :$vault-type,
        :$partition-vault,
        :$vault-name,
        :$vault-pass
    );
}

# create and mount btrfs filesystem on opened vault
method mkbtrfs(::?CLASS:D: --> Nil)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my DiskType:D $disk-type = $.config.disk-type;
    my VaultName:D $vault-name = $.config.vault-name;

    # btrfs subvolumes, starting with root / ('')
    my Str:D @subvolume =
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

    # prefix subvolumes with C<@>
    @subvolume .= map({"@$^s"});

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
        gen-subvolume-mount-options(:$subvolume, :mount-option(@mo));
    my Str:D $mount-dir =
        Voidvault::Utils.gen-subvolume-mount-dir(:$subvolume, :$chroot-dir);
    mkdir($mount-dir);
    my Str:D $mount-subvolume-cmdline =
        Voidvault::Utils.build-mount-subvolume-cmdline(
            :$subvolume,
            :@mount-option,
            :$vault-device-mapper,
            :$mount-dir
        );
    shell($mount-subvolume-cmdline);
    set-subvolume-mount-dir-permissions(:$subvolume, :$mount-dir);
}

proto sub gen-subvolume-mount-options(
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

# return target directory at which to mount subvolumes
multi sub gen-subvolume-mount-options(
    Str:D :subvolume($)! where /
        | '@srv'
        | '@var-lib-ex'
        | '@var-log'
        | '@var-spool'
        | '@var-tmp'
    /,
    Str:D :mount-option(@)!
    --> Nil
)
{
    push(@*mount-option, |qw<nodev noexec nosuid>);
}

multi sub gen-subvolume-mount-options(
    Str:D :subvolume($)!,
    Str:D :mount-option(@)!
    --> Nil
)
{*}

multi sub set-subvolume-mount-dir-permissions(
    Str:D :subvolume($)! where /'@var-lib-ex'|'@var-tmp'/,
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

method mount-efi(::?CLASS:D: --> Nil)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my Str:D $partition-efi = self.gen-partition('efi');
    my Str:D $efi-dir =
        sprintf(Q{%s%s}, $chroot-dir, $Voidvault::Constants::EFI-DIR);
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
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my Str:D @directory = qw<
        srv
        var/lib/ex
        var/log
        var/spool
        var/tmp
    >.map(-> Str:D $directory { sprintf(Q{%s/%s}, $chroot-dir, $directory) });
    Voidvault::Utils.disable-cow(|@directory, :recursive);
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
    my Str:D @core = @Voidvault::Constants::CORE-PACKAGE;
    Void::Utils.voidstrap(
        $chroot-dir,
        :@repository,
        :$ignore-conf-repos,
        @core
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
    Void::Utils.voidstrap(
        $chroot-dir,
        :@repository,
        :$ignore-conf-repos,
        @base
    );
}

method install-vault-key(::?CLASS:D: --> Nil)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my VaultPass $vault-pass = $.config.vault-pass;
    my VaultKey:D $vault-key = $.config.vault-key;
    my Str:D $partition-vault = self.gen-partition('vault');

    # add key to vault
    Voidvault::Utils.install-vault-key(
        :$partition-vault,
        :$vault-key,
        :$vault-pass,
        :$chroot-dir
    );

    # configure /etc/crypttab for vault key
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

method genfstab(::?CLASS:D: --> Nil)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my Str:D $file =
        sprintf(Q{%s%s}, $chroot-dir, $Voidvault::Constants::FILE-FSTAB);
    my Str:D $path = 'usr/bin/genfstab';

    # install genfstab
    copy(%?RESOURCES{$path}, "$chroot-dir/$path");

    # generate /etc/fstab
    shell("%?RESOURCES{$path} -U -p $chroot-dir >> $file");

    # customize /etc/fstab
    self.replace($Voidvault::Constants::FILE-FSTAB);
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
    my Str:D $path = 'etc/modprobe.d/modprobe.conf';
    copy(%?RESOURCES{$path}, "$chroot-dir/$path");
}

method configure-modules-load(::?CLASS:D: --> Nil)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my Str:D $path = 'etc/modules-load.d/bbr.conf';
    copy(%?RESOURCES{$path}, "$chroot-dir/$path");
}

method generate-initramfs(::?CLASS:D: --> Nil)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;

    # dracut
    self.replace($Voidvault::Constants::FILE-DRACUT, 'add_dracutmodules');
    self.replace($Voidvault::Constants::FILE-DRACUT, 'add_drivers');
    self.replace($Voidvault::Constants::FILE-DRACUT, 'compress');
    self.replace($Voidvault::Constants::FILE-DRACUT, 'hostonly');
    self.replace($Voidvault::Constants::FILE-DRACUT, 'install_items');
    self.replace($Voidvault::Constants::FILE-DRACUT, 'omit_dracutmodules');
    self.replace($Voidvault::Constants::FILE-DRACUT, 'persistent_policy');
    self.replace($Voidvault::Constants::FILE-DRACUT, 'tmpdir');
    Voidvault::Utils.void-chroot-dracut(:$chroot-dir);

    # xbps-reconfigure
    Voidvault::Utils.void-chroot-xbps-reconfigure-linux(:$chroot-dir);
}

multi method configure-bootloader(::?CLASS:D: --> Nil)
{
    self.configure-bootloader('default');
    self.configure-bootloader('secure');
}

# configure /etc/default/grub
multi method configure-bootloader(::?CLASS:D: 'default' --> Nil)
{
    my Bool:D $enable-serial-console = $.config.enable-serial-console;
    self.replace($Voidvault::Constants::FILE-GRUB-DEFAULT, 'GRUB_CMDLINE_LINUX_DEFAULT');
    self.replace($Voidvault::Constants::FILE-GRUB-DEFAULT, 'GRUB_DISABLE_OS_PROBER');
    self.replace($Voidvault::Constants::FILE-GRUB-DEFAULT, 'GRUB_DISABLE_RECOVERY');
    self.replace($Voidvault::Constants::FILE-GRUB-DEFAULT, 'GRUB_ENABLE_CRYPTODISK');
    self.replace($Voidvault::Constants::FILE-GRUB-DEFAULT, 'GRUB_TERMINAL_INPUT');
    self.replace($Voidvault::Constants::FILE-GRUB-DEFAULT, 'GRUB_TERMINAL_OUTPUT');
    self.replace($Voidvault::Constants::FILE-GRUB-DEFAULT, 'GRUB_SERIAL_COMMAND')
        if $enable-serial-console;
}

# allow any user to boot os, but only allow superuser to edit boot
# entries or access grub command console
multi method configure-bootloader(::?CLASS:D: 'secure' --> Nil)
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

method install-bootloader(::?CLASS:D: --> Nil)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my Str:D $device = $.config.device;
    install-bootloader(:legacy, $device, :$chroot-dir);
    install-bootloader(:uefi, 32, $device, :$chroot-dir) if $*KERNEL.bits == 32;
    install-bootloader(:uefi, 64, $device, :$chroot-dir) if $*KERNEL.bits == 64;
    mkdir("$chroot-dir/boot/grub/locale");
    copy(
        "$chroot-dir/usr/share/locale/en@quot/LC_MESSAGES/grub.mo",
        "$chroot-dir/boot/grub/locale/en.mo"
    );
    run(qqw<
        void-chroot
        $chroot-dir
        grub-mkconfig
        --output=/boot/grub/grub.cfg
    >);
}

multi sub install-bootloader(
    Str:D $device,
    AbsolutePath:D :$chroot-dir! where .so,
    Bool:D :legacy($)! where .so
    --> Nil
)
{
    # legacy bios
    run(qqw<
        void-chroot
        $chroot-dir
        grub-install
        --target=i386-pc
        --recheck
    >, $device);
}

multi sub install-bootloader(
    32,
    Str:D $device,
    AbsolutePath:D :$chroot-dir! where .so,
    Bool:D :uefi($)! where .so
    --> Nil
)
{
    # uefi - i686
    run(qqw<
        void-chroot
        $chroot-dir
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
    spurt("$chroot-dir/boot/efi/startup.nsh", $nsh, :append);
}

multi sub install-bootloader(
    64,
    Str:D $device,
    AbsolutePath:D :$chroot-dir! where .so,
    Bool:D :uefi($)! where .so
    --> Nil
)
{
    # uefi - x86_64
    run(qqw<
        void-chroot
        $chroot-dir
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
    spurt("$chroot-dir/boot/efi/startup.nsh", $nsh, :append);
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
    my Str:D @path =
        'etc/nftables.conf',
        'etc/nftables/wireguard/table/inet/filter/forward/wireguard.nft',
        'etc/nftables/wireguard/table/inet/filter/input/wireguard.nft',
        'etc/nftables/wireguard/table/wireguard.nft';
    @path.map(-> Str:D $path {
        my Str:D $base-path = $path.IO.dirname;
        mkdir("$chroot-dir/$base-path");
        copy(%?RESOURCES{$path}, "$chroot-dir/$path");
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
    my Str:D $path = 'etc/ssh/ssh_config';
    copy(%?RESOURCES{$path}, "$chroot-dir/$path");
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
    my Str:D $path = 'etc/udev/rules.d/60-io-schedulers.rules';
    my Str:D $base-path = $path.IO.dirname;
    mkdir("$chroot-dir/$base-path");
    copy(%?RESOURCES{$path}, "$chroot-dir/$path");
}

method configure-hidepid(::?CLASS:D: --> Nil)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my Str:D $file =
        sprintf(Q{%s%s}, $chroot-dir, $Voidvault::Constants::FILE-FSTAB);
    my Str:D $fstab-hidepid = q:to/EOF/;
    # /proc with hidepid (https://wiki.archlinux.org/index.php/Security#hidepid)
    proc                                      /proc       proc        nodev,noexec,nosuid,hidepid=2,gid=proc 0 0
    EOF
    spurt($file, "\n" ~ $fstab-hidepid, :append);
}

method configure-securetty(::?CLASS:D: --> Nil)
{
    self.replace($Voidvault::Constants::FILE-SECURETTY);
}


method configure-shell-timeout(::?CLASS:D: --> Nil)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my Str:D $path = 'etc/profile.d/shell-timeout.sh';
    copy(%?RESOURCES{$path}, "$chroot-dir/$path");
}

method configure-pamd(::?CLASS:D: --> Nil)
{
    # raise number of passphrase hashing rounds C<passwd> employs
    self.replace($Voidvault::Constants::FILE-PAM);
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
    my Str:D $path = 'etc/X11/Xwrapper.config';
    my Str:D $base-path = $path.IO.dirname;
    mkdir("$chroot-dir/$base-path");
    copy(%?RESOURCES{$path}, "$chroot-dir/$path");
}

multi sub configure-xorg(
    '10-synaptics.conf',
    AbsolutePath:D :$chroot-dir! where .so
    --> Nil
)
{
    my Str:D $path = 'etc/X11/xorg.conf.d/10-synaptics.conf';
    my Str:D $base-path = $path.IO.dirname;
    mkdir("$chroot-dir/$base-path");
    copy(%?RESOURCES{$path}, "$chroot-dir/$path");
}

multi sub configure-xorg(
    '99-security.conf',
    AbsolutePath:D :$chroot-dir! where .so
    --> Nil
)
{
    my Str:D $path = 'etc/X11/xorg.conf.d/99-security.conf';
    my Str:D $base-path = $path.IO.dirname;
    mkdir("$chroot-dir/$base-path");
    copy(%?RESOURCES{$path}, "$chroot-dir/$path");
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
    push(@service, sprintf(Q{agetty-%s}, $Voidvault::Constants::SERIAL-CONSOLE))
        if $enable-serial-console.so;

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

# interactive console
method augment(::?CLASS:D: --> Nil)
{
    # launch fully interactive Bash console, type 'exit' to exit
    shell('expect -c "spawn /bin/bash; interact"');
}

method unmount(::?CLASS:D: --> Nil)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my VaultName:D $vault-name = $.config.vault-name;
    # resume after error with C<umount -R>, obsolete but harmless
    CATCH { default { .resume } };
    run(qqw<umount --recursive --verbose $chroot-dir>);
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

# vim: set filetype=raku foldmethod=marker foldlevel=0:
