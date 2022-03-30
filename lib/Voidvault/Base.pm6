use v6;
use Void::XBPS;
use Voidvault;
use Voidvault::Constants;
use Voidvault::Config;
use Voidvault::Config::Base;
use Voidvault::Types;
use Voidvault::Utils;
use X::Void::XBPS;
unit class Voidvault::Base;
also is Voidvault;


# -----------------------------------------------------------------------------
# attributes
# -----------------------------------------------------------------------------

has Voidvault::Config::Base:D $.config is required;


# -----------------------------------------------------------------------------
# bootstrap
# -----------------------------------------------------------------------------

method bootstrap(::?CLASS:D: --> Nil)
{
    my Bool:D $augment = $.config.augment;
    self!mkdisk;
    self!voidstrap-base;
    self!install-vault-key;
    self!configure-users;
    self!configure-sudoers;
    self!genfstab;
    self!set-hostname;
    self!configure-hosts;
    self!configure-dhcpcd;
    self!configure-dnscrypt-proxy;
    self!set-nameservers;
    self!set-locale;
    self!set-keymap;
    self!set-timezone;
    self!set-hwclock;
    self!configure-modprobe;
    self!configure-modules-load;
    self!generate-initramfs;
    self!install-bootloader;
    self!configure-sysctl;
    self!configure-nftables;
    self!configure-openssh;
    self!configure-udev;
    self!configure-hidepid;
    self!configure-securetty;
    self!configure-pamd;
    self!configure-xorg;
    self!configure-rc-local;
    self!configure-rc-shutdown;
    self!enable-runit-services;
    self!augment if $augment.so;
    self!unmount;
}


# -----------------------------------------------------------------------------
# worker functions
# -----------------------------------------------------------------------------

# secure disk configuration
method !mkdisk(::?CLASS:D: --> Nil)
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
    disable-cow();
}

sub disable-cow(--> Nil)
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
method !voidstrap-base(--> Nil)
{
    my Str:D @repository = $.config.repository;
    my Bool:D $ignore-conf-repos = $.config.ignore-conf-repos;
    my Str:D @package = $.config.package;
    my Processor:D $processor = $.config.processor;
    my LibcFlavor:D $libc-flavor = $Void::XBPS::LIBC-FLAVOR;

    my Str:D @core = 'base-minimal';

    # download and install core packages with voidstrap in chroot
    my Str:D $voidstrap-core-cmdline =
        build-voidstrap-cmdline(@core, :@repository, :$ignore-conf-repos);
    Voidvault::Utils.loop-cmdline-proc(
        'Running voidstrap...',
        $voidstrap-core-cmdline
    );

    # base packages - void's C<base-minimal> with light additions
    # duplicates C<base-minimal>'s C<depends> for thoroughness
    my Str:D @pkg = qw<
        acpi
        base-files
        bash
        bash-completion
        btrfs-progs
        busybox-huge
        bzip2
        ca-certificates
        coreutils
        crda
        cryptsetup
        curl
        dash
        device-mapper
        dhcpcd
        diffutils
        dnscrypt-proxy
        dosfstools
        dracut
        e2fsprogs
        efibootmgr
        eudev
        exfat-utils
        file
        findutils
        gawk
        gptfdisk
        grep
        grub
        gzip
        iana-etc
        iproute2
        iputils
        iw
        kbd
        kmod
        ldns
        less
        linux
        linux-firmware
        linux-firmware-network
        lynx
        lz4
        man-db
        man-pages
        ncurses
        ncurses-term
        nftables
        nvi
        openresolv
        openssh
        openssl
        pciutils
        perl
        pinentry
        pinentry-tty
        procps-ng
        removed-packages
        rsync
        runit-void
        sed
        shadow
        socklog-void
        sudo
        tar
        tzdata
        util-linux
        vim
        which
        wifi-firmware
        wireguard-tools
        wpa_supplicant
        xbps
        xz
        zlib
        zramen
        zstd
    >;

    push(@pkg, 'glibc') if $libc-flavor eq 'GLIBC';
    push(@pkg, 'musl') if $libc-flavor eq 'MUSL';

    push(@pkg, 'grub-i386-efi') if $*KERNEL.bits == 32;
    push(@pkg, 'grub-x86_64-efi') if $*KERNEL.bits == 64;

    # https://www.archlinux.org/news/changes-to-intel-microcodeupdates/
    push(@pkg, 'intel-ucode') if $processor eq 'INTEL';

    push(@pkg, $_) for @package;

    # download and install base packages with voidstrap in chroot
    my Str:D $voidstrap-base-cmdline =
        build-voidstrap-cmdline(@pkg, :@repository, :$ignore-conf-repos);

    # why launch a new shell process for this? superstition.
    Voidvault::Utils.loop-cmdline-proc(
        'Running voidstrap...',
        $voidstrap-base-cmdline
    );
}

multi sub build-voidstrap-cmdline(
    Str:D @pkg,
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
         @pkg[]";
}

multi sub build-voidstrap-cmdline(
    Str:D @pkg,
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
         @pkg[]";
}

multi sub build-voidstrap-cmdline(
    Str:D @pkg,
    Str:D :repository(@),
    Bool:D :ignore-conf-repos($)! where .so
    --> Nil
)
{
    die(X::Void::XBPS::IgnoreConfRepos.new);
}

multi sub build-voidstrap-cmdline(
    Str:D @pkg,
    Str:D :repository(@),
    Bool :ignore-conf-repos($)
    --> Str:D
)
{
    my Str:D $voidstrap-cmdline =
        "voidstrap \\
         /mnt \\
         @pkg[]";
}

method !install-vault-key(--> Nil)
{
    my Str:D $partition-vault = self.gen-partition('vault');
    my VaultName:D $vault-name = $.config.vault-name;
    my Str:D $vault-key = $.config.vault-key;

    Voidvault::Utils.install-vault-key($vault-key);

    # configure /etc/crypttab for vault key
    replace('crypttab', $partition-vault, $vault-name, $vault-key);
}

# secure user configuration
method !configure-users(--> Nil)
{
    my UserName:D $user-name-admin = $.config.user-name-admin;
    my UserName:D $user-name-guest = $.config.user-name-guest;
    my UserName:D $user-name-sftp = $.config.user-name-sftp;
    my Str:D $user-pass-hash-admin = $.config.user-pass-hash-admin;
    my Str:D $user-pass-hash-guest = $.config.user-pass-hash-guest;
    my Str:D $user-pass-hash-root = $.config.user-pass-hash-root;
    my Str:D $user-pass-hash-sftp = $.config.user-pass-hash-sftp;
    configure-users('root', $user-pass-hash-root);
    configure-users('admin', $user-name-admin, $user-pass-hash-admin);
    configure-users('guest', $user-name-guest, $user-pass-hash-guest);
    configure-users('sftp', $user-name-sftp, $user-pass-hash-sftp);
}

multi sub configure-users(
    'admin',
    UserName:D $user-name-admin,
    Str:D $user-pass-hash-admin
    --> Nil
)
{
    useradd('admin', $user-name-admin, $user-pass-hash-admin);
    mksudo($user-name-admin);
}

multi sub configure-users(
    'guest',
    UserName:D $user-name-guest,
    Str:D $user-pass-hash-guest
    --> Nil
)
{
    useradd('guest', $user-name-guest, $user-pass-hash-guest);
}

multi sub configure-users(
    'root',
    Str:D $user-pass-hash-root
    --> Nil
)
{
    usermod('root', $user-pass-hash-root);
}

multi sub configure-users(
    'sftp',
    UserName:D $user-name-sftp,
    Str:D $user-pass-hash-sftp
    --> Nil
)
{
    useradd('sftp', $user-name-sftp, $user-pass-hash-sftp);
}

multi sub useradd(
    'admin',
    UserName:D $user-name-admin,
    Str:D $user-pass-hash-admin
    --> Nil
)
{
    groupadd(:system, 'proc');
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

multi sub useradd(
    'guest',
    UserName:D $user-name-guest,
    Str:D $user-pass-hash-guest
    --> Nil
)
{
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

multi sub useradd(
    'sftp',
    UserName:D $user-name-sftp,
    Str:D $user-pass-hash-sftp
    --> Nil
)
{
    # https://wiki.archlinux.org/index.php/SFTP_chroot
    my Str:D $user-group-sftp = qw<
        sftponly
    >.join(',');
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

sub usermod(
    'root',
    Str:D $user-pass-hash-root
    --> Nil
)
{
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

sub mksudo(UserName:D $user-name-admin --> Nil)
{
    say("Giving sudo privileges to admin user $user-name-admin...");
    my Str:D $sudoers = qq:to/EOF/;
    $user-name-admin ALL=(ALL) ALL
    $user-name-admin ALL=(ALL) NOPASSWD: /usr/bin/reboot
    $user-name-admin ALL=(ALL) NOPASSWD: /usr/bin/shutdown
    EOF
    spurt('/mnt/etc/sudoers', "\n" ~ $sudoers, :append);
}

method !configure-sudoers(--> Nil)
{
    replace('sudoers');
}

method !genfstab(--> Nil)
{
    my Str:D $path = 'usr/bin/genfstab';
    copy(%?RESOURCES{$path}, "/$path");
    copy(%?RESOURCES{$path}, "/mnt/$path");
    shell('/usr/bin/genfstab -U -p /mnt >> /mnt/etc/fstab');
    replace('fstab');
}

method !set-hostname(--> Nil)
{
    my HostName:D $host-name = $.config.host-name;
    spurt('/mnt/etc/hostname', $host-name ~ "\n");
}

method !configure-hosts(--> Nil)
{
    my Bool:D $disable-ipv6 = $.config.disable-ipv6;
    my HostName:D $host-name = $.config.host-name;
    my Str:D $path = 'etc/hosts';
    copy(%?RESOURCES{$path}, "/mnt/$path");
    replace('hosts', $disable-ipv6, $host-name);
}

method !configure-dhcpcd(--> Nil)
{
    my Bool:D $disable-ipv6 = $.config.disable-ipv6;
    replace('dhcpcd.conf', $disable-ipv6);
}

method !configure-dnscrypt-proxy(--> Nil)
{
    my Bool:D $disable-ipv6 = $.config.disable-ipv6;
    replace('dnscrypt-proxy.toml', $disable-ipv6);
}

method !set-nameservers(--> Nil)
{
    my Bool:D $disable-ipv6 = $.config.disable-ipv6;
    my Str:D $path = 'etc/resolvconf.conf';
    copy(%?RESOURCES{$path}, "/mnt/$path");
    replace('resolvconf.conf', $disable-ipv6);
}

method !set-locale(--> Nil)
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
        replace('libc-locales', $locale);
        # regenerate locales
        run(qqw<void-chroot /mnt xbps-reconfigure --force glibc-locales>);
    }
}

method !set-keymap(--> Nil)
{
    my Keymap:D $keymap = $.config.keymap;
    replace('rc.conf', 'KEYMAP', $keymap);
    replace('rc.conf', 'FONT');
    replace('rc.conf', 'FONT_MAP');
}

method !set-timezone(--> Nil)
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
    replace('rc.conf', 'TIMEZONE', $timezone);
}

method !set-hwclock(--> Nil)
{
    replace('rc.conf', 'HARDWARECLOCK');
    run(qqw<void-chroot /mnt hwclock --systohc --utc>);
}

method !configure-modprobe(--> Nil)
{
    my Str:D $path = 'etc/modprobe.d/modprobe.conf';
    copy(%?RESOURCES{$path}, "/mnt/$path");
}

method !configure-modules-load(--> Nil)
{
    my Str:D $path = 'etc/modules-load.d/bbr.conf';
    copy(%?RESOURCES{$path}, "/mnt/$path");
}

method !generate-initramfs(--> Nil)
{
    my Graphics:D $graphics = $.config.graphics;
    my Processor:D $processor = $.config.processor;

    # dracut
    replace('dracut.conf', $graphics, $processor);
    my Str:D $linux-version = dir('/mnt/usr/lib/modules').first.basename;
    run(qqw<void-chroot /mnt dracut --force --kver $linux-version>);

    # xbps-reconfigure
    my Str:D $xbps-linux-version-raw =
        qx{xbps-query --rootdir /mnt --property pkgver linux}.trim;
    my Str:D $xbps-linux-version =
        $xbps-linux-version-raw.substr(6..*).split(/'.'|'_'/)[^2].join('.');
    my Str:D $xbps-linux = sprintf(Q{linux%s}, $xbps-linux-version);
    run(qqw<void-chroot /mnt xbps-reconfigure --force $xbps-linux>);
}

method !install-bootloader(--> Nil)
{
    my Bool:D $disable-ipv6 = $.config.disable-ipv6;
    my Bool:D $enable-serial-console = $.config.enable-serial-console;
    my Graphics:D $graphics = $.config.graphics;
    my Str:D $device = $.config.device;
    my Str:D $partition-vault = self.gen-partition('vault');
    my UserName:D $user-name-grub = $.config.user-name-grub;
    my Str:D $user-pass-hash-grub = $.config.user-pass-hash-grub;
    my VaultName:D $vault-name = $.config.vault-name;
    replace(
        'grub',
        $disable-ipv6,
        $enable-serial-console,
        $graphics,
        $partition-vault,
        $vault-name
    );
    replace('10_linux');
    configure-bootloader('superusers', $user-name-grub, $user-pass-hash-grub);
    install-bootloader($device);
}

sub configure-bootloader(
    'superusers',
    UserName:D $user-name-grub,
    Str:D $user-pass-hash-grub
    --> Nil
)
{
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

method !configure-sysctl(--> Nil)
{
    my Bool:D $disable-ipv6 = $.config.disable-ipv6;
    my DiskType:D $disk-type = $.config.disk-type;
    my Str:D $path = 'etc/sysctl.d/99-sysctl.conf';
    my Str:D $base-path = $path.IO.dirname;
    mkdir("/mnt/$base-path");
    copy(%?RESOURCES{$path}, "/mnt/$path");
    replace('99-sysctl.conf', $disable-ipv6, $disk-type);
    run(qqw<void-chroot /mnt sysctl --system>);
}

method !configure-nftables(--> Nil)
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

method !configure-openssh(--> Nil)
{
    my Bool:D $disable-ipv6 = $.config.disable-ipv6;
    my UserName:D $user-name-sftp = $.config.user-name-sftp;
    configure-openssh('ssh_config');
    configure-openssh('sshd_config', $disable-ipv6, $user-name-sftp);
    configure-openssh('moduli');
}

multi sub configure-openssh(
    'ssh_config'
    --> Nil
)
{
    my Str:D $path = 'etc/ssh/ssh_config';
    copy(%?RESOURCES{$path}, "/mnt/$path");
}

multi sub configure-openssh(
    'sshd_config',
    Bool:D $disable-ipv6,
    UserName:D $user-name-sftp
    --> Nil
)
{
    my Str:D $path = 'etc/ssh/sshd_config';
    copy(%?RESOURCES{$path}, "/mnt/$path");
    replace('sshd_config', $disable-ipv6, $user-name-sftp);
}

multi sub configure-openssh(
    'moduli'
    --> Nil
)
{
    # filter weak ssh moduli
    replace('moduli');
}

method !configure-udev(--> Nil)
{
    my Str:D $path = 'etc/udev/rules.d/60-io-schedulers.rules';
    my Str:D $base-path = $path.IO.dirname;
    mkdir("/mnt/$base-path");
    copy(%?RESOURCES{$path}, "/mnt/$path");
}

method !configure-hidepid(--> Nil)
{
    my Str:D $fstab-hidepid = q:to/EOF/;
    # /proc with hidepid (https://wiki.archlinux.org/index.php/Security#hidepid)
    proc                                      /proc       proc        nodev,noexec,nosuid,hidepid=2,gid=proc 0 0
    EOF
    spurt('/mnt/etc/fstab', "\n" ~ $fstab-hidepid, :append);
}

method !configure-securetty(--> Nil)
{
    my Bool:D $enable-serial-console = $.config.enable-serial-console;
    configure-securetty('securetty');
    configure-securetty('securetty', 'enable-serial-console')
        if $enable-serial-console.so;
    configure-securetty('shell-timeout');
}

multi sub configure-securetty('securetty' --> Nil)
{
    my Str:D $path = 'etc/securetty';
    copy(%?RESOURCES{$path}, "/mnt/$path");
}

multi sub configure-securetty('securetty', 'enable-serial-console' --> Nil)
{
    replace('securetty');
}

multi sub configure-securetty('shell-timeout' --> Nil)
{
    my Str:D $path = 'etc/profile.d/shell-timeout.sh';
    copy(%?RESOURCES{$path}, "/mnt/$path");
}

method !configure-pamd(--> Nil)
{
    # raise number of passphrase hashing rounds C<passwd> employs
    replace('passwd');
}

method !configure-xorg(--> Nil)
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

method !configure-rc-local(--> Nil)
{
    my Str:D $rc-local = q:to/EOF/;
    # create zram swap device
    zramen make

    # disable blinking cursor in Linux tty
    echo 0 > /sys/class/graphics/fbcon/cursor_blink
    EOF
    spurt('/mnt/etc/rc.local', "\n" ~ $rc-local, :append);
}

method !configure-rc-shutdown(--> Nil)
{
    my Str:D $rc-shutdown = q:to/EOF/;
    # teardown zram swap device
    zramen toss
    EOF
    spurt('/mnt/etc/rc.shutdown', "\n" ~ $rc-shutdown, :append);
}

method !enable-runit-services(--> Nil)
{
    my Bool:D $enable-serial-console = $.config.enable-serial-console;

    my Str:D @service = qw<
        dnscrypt-proxy
        nanoklogd
        nftables
        socklog-unix
    >;

    # enable serial getty when using serial console, e.g. agetty-ttyS0
    push(@service, sprintf(Q{agetty-%s}, $Voidvault::Utils::SERIAL-CONSOLE))
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
method !augment(--> Nil)
{
    # launch fully interactive Bash console, type 'exit' to exit
    shell('expect -c "spawn /bin/bash; interact"');
}

method !unmount(--> Nil)
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

# sub void-chroot-mkdir {{{

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

# end sub void-chroot-mkdir }}}
# sub replace {{{

# --- crypttab {{{

multi sub replace(
    'crypttab',
    Str:D $partition-vault,
    VaultName:D $vault-name,
    Str:D $vault-key
    --> Nil
)
{
    my Str:D $vault-uuid =
        qqx<blkid --match-tag UUID --output value $partition-vault>.trim;
    my Str:D $file = '/mnt/etc/crypttab';
    my Str:D $key = qq:to/EOF/;
    $vault-name   UUID=$vault-uuid   $vault-key   luks
    EOF
    spurt($file, "\n" ~ $key, :append);
}

# --- end crypttab }}}
# --- sudoers {{{

multi sub replace(
    'sudoers'
    --> Nil
)
{
    my Str:D $file = '/mnt/etc/sudoers';
    my Str:D $slurp = slurp($file);
    my Str:D $defaults = q:to/EOF/;
    # reset environment by default
    Defaults env_reset

    # set default editor to rvim, do not allow visudo to use $EDITOR/$VISUAL
    Defaults editor=/usr/bin/rvim, !env_editor

    # force password entry with every sudo
    Defaults timestamp_timeout=0

    # only allow sudo when the user is logged in to a real tty
    Defaults requiretty

    # prevent arbitrary code execution as your user when sudoing to another
    # user due to TTY hijacking via TIOCSTI ioctl
    Defaults use_pty

    # wrap logfile lines at 72 characters
    Defaults loglinelen=72
    EOF
    my Str:D $replace = join("\n", $defaults, $slurp);
    spurt($file, $replace);
}

# --- end sudoers }}}
# --- fstab {{{

multi sub replace(
    'fstab'
    --> Nil
)
{
    my Str:D $file = '/mnt/etc/fstab';
    my Str:D @replace =
        $file.IO.lines
        # rm default /tmp mount in fstab
        ==> replace('fstab', 'rm')
        # add /tmp mount with options
        ==> replace('fstab', 'add');
    my Str:D $replace = @replace.join("\n");
    spurt($file, $replace ~ "\n");
}

multi sub replace(
    'fstab',
    'rm',
    Str:D @line
    --> Array[Str:D]
)
{
    my UInt:D $index = @line.first(/^tmpfs/, :k);
    @line.splice($index, 1);
    @line;
}

multi sub replace(
    'fstab',
    'add',
    Str:D @line
    --> Array[Str:D]
)
{
    my UInt:D $index = @line.elems;
    my Str:D $replace =
        'tmpfs /tmp tmpfs mode=1777,strictatime,nodev,noexec,nosuid 0 0';
    @line[$index] = $replace;
    @line;
}

# --- end fstab }}}
# --- hosts {{{

multi sub replace(
    'hosts',
    Bool:D $disable-ipv6 where .so,
    HostName:D $host-name
    --> Nil
)
{
    my Str:D $file = '/mnt/etc/hosts';
    my Str:D @replace =
        $file.IO.lines
        # remove IPv6 hosts
        ==> replace('hosts', '::1')
        ==> replace('hosts', '127.0.1.1', $host-name);
    my Str:D $replace = @replace.join("\n");
    spurt($file, $replace ~ "\n");
}

multi sub replace(
    'hosts',
    Bool:D $disable-ipv6,
    HostName:D $host-name
    --> Nil
)
{
    my Str:D $file = '/mnt/etc/hosts';
    my Str:D @replace =
        $file.IO.lines
        ==> replace('hosts', '127.0.1.1', $host-name);
    my Str:D $replace = @replace.join("\n");
    spurt($file, $replace ~ "\n");
}

multi sub replace(
    'hosts',
    '::1',
    Str:D @line
    --> Array[Str:D]
)
{
    my UInt:D $index = @line.first(/^'::1'/, :k);
    @line.splice($index, 1);
    @line;
}

multi sub replace(
    'hosts',
    '127.0.1.1',
    HostName:D $host-name,
    Str:D @line
    --> Array[Str:D]
)
{
    my UInt:D $index = @line.elems;
    my Str:D $replace =
        "127.0.1.1       $host-name.localdomain       $host-name";
    @line[$index] = $replace;
    @line;
}

# --- end hosts }}}
# --- dhcpcd.conf {{{

multi sub replace(
    'dhcpcd.conf',
    Bool:D $disable-ipv6 where .so
    --> Nil
)
{
    my Str:D $file = '/mnt/etc/dhcpcd.conf';
    my Str:D $dhcpcd = q:to/EOF/;
    # Set vendor-class-id to empty string
    vendorclassid

    # Use the same DNS servers every time
    static domain_name_servers=127.0.0.1

    # Disable IPv6 router solicitation
    noipv6rs
    noipv6
    EOF
    spurt($file, "\n" ~ $dhcpcd, :append);
}

multi sub replace(
    'dhcpcd.conf',
    Bool:D $disable-ipv6
    --> Nil
)
{
    my Str:D $file = '/mnt/etc/dhcpcd.conf';
    my Str:D $dhcpcd = q:to/EOF/;
    # Set vendor-class-id to empty string
    vendorclassid

    # Use the same DNS servers every time
    static domain_name_servers=127.0.0.1 ::1

    # Disable IPv6 router solicitation
    #noipv6rs
    #noipv6
    EOF
    spurt($file, "\n" ~ $dhcpcd, :append);
}

# --- end dhcpcd.conf }}}
# --- dnscrypt-proxy.toml {{{

multi sub replace(
    'dnscrypt-proxy.toml',
    Bool:D $disable-ipv6 where .so
    --> Nil
)
{
    my Str:D $file = '/mnt/etc/dnscrypt-proxy.toml';
    my Str:D @replace =
        $file.IO.lines
        # do not listen on IPv6 address
        ==> replace('dnscrypt-proxy.toml', 'listen_addresses')
        # server must support DNS security extensions (DNSSEC)
        ==> replace('dnscrypt-proxy.toml', 'require_dnssec')
        # always use TCP to connect to upstream servers
        ==> replace('dnscrypt-proxy.toml', 'force_tcp')
        # create new, unique key for each DNS query
        ==> replace('dnscrypt-proxy.toml', 'dnscrypt_ephemeral_keys')
        # disable TLS session tickets
        ==> replace('dnscrypt-proxy.toml', 'tls_disable_session_tickets')
        # unconditionally use fallback resolver
        ==> replace('dnscrypt-proxy.toml', 'ignore_system_dns')
        # wait for network connectivity before initializing
        ==> replace('dnscrypt-proxy.toml', 'netprobe_timeout')
        # disable DNS cache
        ==> replace('dnscrypt-proxy.toml', 'cache');
    my Str:D $replace = @replace.join("\n");
    spurt($file, $replace ~ "\n");
}

multi sub replace(
    'dnscrypt-proxy.toml',
    Bool:D $disable-ipv6
    --> Nil
)
{
    my Str:D $file = '/mnt/etc/dnscrypt-proxy.toml';
    my Str:D @replace =
        $file.IO.lines
        # server must support DNS security extensions (DNSSEC)
        ==> replace('dnscrypt-proxy.toml', 'require_dnssec')
        # always use TCP to connect to upstream servers
        ==> replace('dnscrypt-proxy.toml', 'force_tcp')
        # create new, unique key for each DNS query
        ==> replace('dnscrypt-proxy.toml', 'dnscrypt_ephemeral_keys')
        # disable TLS session tickets
        ==> replace('dnscrypt-proxy.toml', 'tls_disable_session_tickets')
        # unconditionally use fallback resolver
        ==> replace('dnscrypt-proxy.toml', 'ignore_system_dns')
        # wait for network connectivity before initializing
        ==> replace('dnscrypt-proxy.toml', 'netprobe_timeout')
        # disable DNS cache
        ==> replace('dnscrypt-proxy.toml', 'cache');
    my Str:D $replace = @replace.join("\n");
    spurt($file, $replace ~ "\n");
}

multi sub replace(
    'dnscrypt-proxy.toml',
    Str:D $subject where 'listen_addresses',
    Str:D @line
    --> Array[Str:D]
)
{
    my UInt:D $index = @line.first(/^$subject/, :k);
    my Str:D $replace = sprintf(Q{%s = ['127.0.0.1:53']}, $subject);
    @line[$index] = $replace;
    @line;
}

multi sub replace(
    'dnscrypt-proxy.toml',
    Str:D $subject where 'require_dnssec',
    Str:D @line
    --> Array[Str:D]
)
{
    my UInt:D $index = @line.first(/^$subject/, :k);
    my Str:D $replace = sprintf(Q{%s = true}, $subject);
    @line[$index] = $replace;
    @line;
}

multi sub replace(
    'dnscrypt-proxy.toml',
    Str:D $subject where 'force_tcp',
    Str:D @line
    --> Array[Str:D]
)
{
    my UInt:D $index = @line.first(/^$subject/, :k);
    my Str:D $replace = sprintf(Q{%s = true}, $subject);
    @line[$index] = $replace;
    @line;
}

multi sub replace(
    'dnscrypt-proxy.toml',
    Str:D $subject where 'dnscrypt_ephemeral_keys',
    Str:D @line
    --> Array[Str:D]
)
{
    my UInt:D $index = @line.first(/^'#'\h*$subject/, :k);
    my Str:D $replace = sprintf(Q{%s = true}, $subject);
    @line[$index] = $replace;
    @line;
}

multi sub replace(
    'dnscrypt-proxy.toml',
    Str:D $subject where 'tls_disable_session_tickets',
    Str:D @line
    --> Array[Str:D]
)
{
    my UInt:D $index = @line.first(/^'#'\h*$subject/, :k);
    my Str:D $replace = sprintf(Q{%s = true}, $subject);
    @line[$index] = $replace;
    @line;
}

multi sub replace(
    'dnscrypt-proxy.toml',
    Str:D $subject where 'ignore_system_dns',
    Str:D @line
    --> Array[Str:D]
)
{
    my UInt:D $index = @line.first(/^$subject/, :k);
    my Str:D $replace = sprintf(Q{%s = true}, $subject);
    @line[$index] = $replace;
    @line;
}

multi sub replace(
    'dnscrypt-proxy.toml',
    Str:D $subject where 'netprobe_timeout',
    Str:D @line
    --> Array[Str:D]
)
{
    my UInt:D $index = @line.first(/^$subject/, :k);
    my Str:D $replace = sprintf(Q{%s = 420}, $subject);
    @line[$index] = $replace;
    @line;
}

multi sub replace(
    'dnscrypt-proxy.toml',
    Str:D $subject where 'cache',
    Str:D @line
    --> Array[Str:D]
)
{
    my UInt:D $index = @line.first(/^$subject\h/, :k);
    my Str:D $replace = sprintf(Q{%s = false}, $subject);
    @line[$index] = $replace;
    @line;
}

# --- end dnscrypt-proxy.toml }}}
# --- resolvconf.conf {{{

multi sub replace(
    'resolvconf.conf',
    Bool:D $disable-ipv6 where .so
    --> Nil
)
{
    my Str:D $file = '/mnt/etc/resolvconf.conf';
    my Str:D @replace =
        $file.IO.lines
        ==> replace('resolvconf.conf', 'name_servers');
    my Str:D $replace = @replace.join("\n");
    spurt($file, $replace ~ "\n");
}

multi sub replace(
    'resolvconf.conf',
    Bool:D $disable-ipv6
    --> Nil
)
{*}

multi sub replace(
    'resolvconf.conf',
    Str:D $subject where 'name_servers',
    Str:D @line
    --> Array[Str:D]
)
{
    my UInt:D $index = @line.first(/^$subject/, :k);
    my Str:D $replace = sprintf(Q{%s="127.0.0.1"}, $subject);
    @line[$index] = $replace;
    @line;
}

# --- end resolvconf.conf }}}
# --- libc-locales {{{

multi sub replace(
    'libc-locales',
    Locale:D $locale
    --> Nil
)
{
    my Str:D $file = '/mnt/etc/default/libc-locales';
    my Str:D @line = $file.IO.lines;
    my Str:D $locale-full = sprintf(Q{%s.UTF-8 UTF-8}, $locale);
    my UInt:D $index = @line.first(/^"#$locale-full"/, :k);
    @line[$index] = $locale-full;
    my Str:D $replace = @line.join("\n");
    spurt($file, $replace ~ "\n");
}

# --- end libc-locales }}}
# --- rc.conf {{{

multi sub replace(
    'rc.conf',
    'KEYMAP',
    Keymap:D $keymap
    --> Nil
)
{
    my Str:D $file = '/mnt/etc/rc.conf';
    my Str:D @line = $file.IO.lines;
    my UInt:D $index = @line.first(/^'#'?KEYMAP'='/, :k);
    my Str:D $keymap-line = sprintf(Q{KEYMAP=%s}, $keymap);
    @line[$index] = $keymap-line;
    my Str:D $replace = @line.join("\n");
    spurt($file, $replace ~ "\n");
}

multi sub replace(
    'rc.conf',
    'FONT'
    --> Nil
)
{
    my Str:D $file = '/mnt/etc/rc.conf';
    my Str:D @line = $file.IO.lines;
    my UInt:D $index = @line.first(/^'#'?FONT'='/, :k);
    my Str:D $font-line = 'FONT=Lat2-Terminus16';
    @line[$index] = $font-line;
    my Str:D $replace = @line.join("\n");
    spurt($file, $replace ~ "\n");
}

multi sub replace(
    'rc.conf',
    'FONT_MAP'
    --> Nil
)
{
    my Str:D $file = '/mnt/etc/rc.conf';
    my Str:D @line = $file.IO.lines;
    my UInt:D $index = @line.first(/^'#'?FONT_MAP'='/, :k);
    my Str:D $font-map-line = 'FONT_MAP=';
    @line[$index] = $font-map-line;
    my Str:D $replace = @line.join("\n");
    spurt($file, $replace ~ "\n");
}

multi sub replace(
    'rc.conf',
    'TIMEZONE',
    Timezone:D $timezone
    --> Nil
)
{
    my Str:D $file = '/mnt/etc/rc.conf';
    my Str:D @line = $file.IO.lines;
    my UInt:D $index = @line.first(/^'#'?TIMEZONE'='/, :k);
    my Str:D $timezone-line = sprintf(Q{TIMEZONE=%s}, $timezone);
    @line[$index] = $timezone-line;
    my Str:D $replace = @line.join("\n");
    spurt($file, $replace ~ "\n");
}

multi sub replace(
    'rc.conf',
    'HARDWARECLOCK'
    --> Nil
)
{
    my Str:D $file = '/mnt/etc/rc.conf';
    my Str:D @line = $file.IO.lines;
    my UInt:D $index = @line.first(/^'#'?HARDWARECLOCK'='/, :k);
    my Str:D $hardwareclock-line = 'HARDWARECLOCK="UTC"';
    @line[$index] = $hardwareclock-line;
    my Str:D $replace = @line.join("\n");
    spurt($file, $replace ~ "\n");
}

# --- end rc.conf }}}
# --- dracut.conf {{{

multi sub replace(
    'dracut.conf',
    Graphics:D $graphics,
    Processor:D $processor,
    Str:D $vault-key
    --> Nil
)
{
    replace('dracut.conf', 'add_dracutmodules');
    replace('dracut.conf', 'add_drivers', $graphics, $processor);
    replace('dracut.conf', 'compress');
    replace('dracut.conf', 'hostonly');
    replace('dracut.conf', 'install_items', $vault-key);
    replace('dracut.conf', 'omit_dracutmodules');
    replace('dracut.conf', 'persistent_policy');
    replace('dracut.conf', 'tmpdir');
}

multi sub replace(
    'dracut.conf',
    Str:D $subject where 'add_dracutmodules'
    --> Nil
)
{
    my Str:D $file = sprintf(Q{/mnt/etc/dracut.conf.d/%s.conf}, $subject);
    # modules are found in C</usr/lib/dracut/modules.d>
    my Str:D @module = qw<
        btrfs
        crypt
        dm
        kernel-modules
    >;
    my Str:D $replace = sprintf(Q{%s+=" %s "}, $subject, @module.join(' '));
    spurt($file, $replace ~ "\n");
}

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
        btrfs
        lz4
        lz4hc
        xxhash_generic
    >;
    push(@driver, 'i915') if $graphics eq 'INTEL';
    push(@driver, 'nouveau') if $graphics eq 'NVIDIA';
    push(@driver, 'radeon') if $graphics eq 'RADEON';
    my Str:D $replace = sprintf(Q{%s+=" %s "}, $subject, @driver.join(' '));
    spurt($file, $replace ~ "\n");
}

multi sub replace(
    'dracut.conf',
    Str:D $subject where 'compress'
    --> Nil
)
{
    my Str:D $file = sprintf(Q{/mnt/etc/dracut.conf.d/%s.conf}, $subject);
    my Str:D $replace = sprintf(Q{%s="lz4"}, $subject);
    spurt($file, $replace ~ "\n");
}

multi sub replace(
    'dracut.conf',
    Str:D $subject where 'hostonly'
    --> Nil
)
{
    my Str:D $file = sprintf(Q{/mnt/etc/dracut.conf.d/%s.conf}, $subject);
    my Str:D $replace = sprintf(Q{%s="yes"}, $subject);
    spurt($file, $replace ~ "\n");
}

multi sub replace(
    'dracut.conf',
    Str:D $subject where 'install_items',
    Str:D $vault-key
    --> Nil
)
{
    my Str:D $file = sprintf(Q{/mnt/etc/dracut.conf.d/%s.conf}, $subject);
    my Str:D @item = qqw<
        $vault-key
        /etc/crypttab
    >;
    my Str:D $replace = sprintf(Q{%s+=" %s "}, $subject, @item.join(' '));
    spurt($file, $replace ~ "\n");
}

multi sub replace(
    'dracut.conf',
    Str:D $subject where 'omit_dracutmodules'
    --> Nil
)
{
    my Str:D $file = sprintf(Q{/mnt/etc/dracut.conf.d/%s.conf}, $subject);
    my Str:D @module = qw<
        dracut-systemd
        plymouth
        systemd
        systemd-initrd
        usrmount
    >;
    my Str:D $replace = sprintf(Q{%s+=" %s "}, $subject, @module.join(' '));
    spurt($file, $replace ~ "\n");
}

multi sub replace(
    'dracut.conf',
    Str:D $subject where 'persistent_policy'
    --> Nil
)
{
    my Str:D $file = sprintf(Q{/mnt/etc/dracut.conf.d/%s.conf}, $subject);
    my Str:D $replace = sprintf(Q{%s="by-uuid"}, $subject);
    spurt($file, $replace ~ "\n");
}

multi sub replace(
    'dracut.conf',
    Str:D $subject where 'tmpdir'
    --> Nil
)
{
    my Str:D $file = sprintf(Q{/mnt/etc/dracut.conf.d/%s.conf}, $subject);
    my Str:D $replace = sprintf(Q{%s="/tmp"}, $subject);
    spurt($file, $replace ~ "\n");
}

# --- end dracut.conf }}}
# --- grub {{{

multi sub replace(
    'grub',
    *@opts (
        Bool:D $disable-ipv6,
        Bool:D $enable-serial-console,
        Graphics:D $graphics,
        Str:D $partition-vault,
        VaultName:D $vault-name
    )
    --> Nil
)
{
    my Str:D $file = '/mnt/etc/default/grub';
    my Str:D @replace =
        $file.IO.lines
        ==> replace('grub', 'GRUB_CMDLINE_LINUX_DEFAULT', |@opts)
        ==> replace('grub', 'GRUB_DISABLE_OS_PROBER')
        ==> replace('grub', 'GRUB_DISABLE_RECOVERY')
        ==> replace('grub', 'GRUB_ENABLE_CRYPTODISK')
        ==> replace('grub', 'GRUB_TERMINAL_INPUT', $enable-serial-console)
        ==> replace('grub', 'GRUB_TERMINAL_OUTPUT', $enable-serial-console)
        ==> replace('grub', 'GRUB_SERIAL_COMMAND', $enable-serial-console);
    my Str:D $replace = @replace.join("\n");
    spurt($file, $replace ~ "\n");
}

multi sub replace(
    'grub',
    Str:D $subject where 'GRUB_CMDLINE_LINUX_DEFAULT',
    Bool:D $disable-ipv6,
    Bool:D $enable-serial-console,
    Graphics:D $graphics,
    Str:D $partition-vault,
    VaultName:D $vault-name,
    Str:D @line
    --> Array[Str:D]
)
{
    # prepare GRUB_CMDLINE_LINUX_DEFAULT
    my Str:D $vault-uuid =
        qqx<blkid --match-tag UUID --output value $partition-vault>.trim;
    my Str:D @grub-cmdline-linux = qqw<
        rd.luks=1
        rd.luks.uuid=$vault-uuid
        rd.luks.name=$vault-uuid=$vault-name
        loglevel=6
    >;
    if $enable-serial-console.so
    {
        # e.g. console=tty0
        my Str:D $virtual =
            sprintf('console=%s', $Voidvault::Utils::VIRTUAL-CONSOLE);

        # e.g. console=ttyS0,115200n8
        my Str:D $serial = sprintf(
            'console=%s,%s%s%s',
            $Voidvault::Utils::SERIAL-CONSOLE,
            $Voidvault::Utils::GRUB-SERIAL-PORT-BAUD-RATE,
            %Voidvault::Utils::GRUB-SERIAL-PORT-PARITY{$Voidvault::Utils::GRUB-SERIAL-PORT-PARITY}{$subject},
            $Voidvault::Utils::GRUB-SERIAL-PORT-WORD-LENGTH-BITS
        );

        # enable both serial and virtual console on boot
        push(@grub-cmdline-linux, $virtual);
        push(@grub-cmdline-linux, $serial);
    }
    # enable slub/slab allocator free poisoning (needs CONFIG_SLUB_DEBUG=y)
    push(@grub-cmdline-linux, 'slub_debug=FZ');
    #                                     ||
    #                                     |+--- redzoning (Z)
    #                                     +---- sanity checks (F)
    # disable slab merging (makes many heap overflow attacks more difficult)
    push(@grub-cmdline-linux, 'slab_nomerge=1');
    # always enable Kernel Page Table Isolation (to be safe from Meltdown)
    push(@grub-cmdline-linux, 'pti=on');
    # always panic on uncorrected errors, log corrected errors
    push(@grub-cmdline-linux, 'mce=0');
    push(@grub-cmdline-linux, 'printk.time=1');
    push(@grub-cmdline-linux, 'radeon.dpm=1') if $graphics eq 'RADEON';
    push(@grub-cmdline-linux, 'ipv6.disable=1') if $disable-ipv6.so;
    my Str:D $grub-cmdline-linux = @grub-cmdline-linux.join(' ');
    # replace GRUB_CMDLINE_LINUX_DEFAULT
    my UInt:D $index = @line.first(/^$subject'='/, :k);
    my Str:D $replace = sprintf(Q{%s="%s"}, $subject, $grub-cmdline-linux);
    @line[$index] = $replace;
    @line;
}

multi sub replace(
    'grub',
    Str:D $subject where 'GRUB_DISABLE_OS_PROBER',
    Str:D @line
    --> Array[Str:D]
)
{
    # if C<GRUB_DISABLE_OS_PROBER> not found, append to bottom of file
    my UInt:D $index = @line.first(/^'#'$subject/, :k) // @line.elems;
    my Str:D $replace = sprintf(Q{%s=true}, $subject);
    @line[$index] = $replace;
    @line;
}

multi sub replace(
    'grub',
    Str:D $subject where 'GRUB_DISABLE_RECOVERY',
    Str:D @line
    --> Array[Str:D]
)
{
    # if C<GRUB_DISABLE_RECOVERY> not found, append to bottom of file
    my UInt:D $index = @line.first(/^'#'$subject/, :k) // @line.elems;
    my Str:D $replace = sprintf(Q{%s=true}, $subject);
    @line[$index] = $replace;
    @line;
}

multi sub replace(
    'grub',
    Str:D $subject where 'GRUB_ENABLE_CRYPTODISK',
    Str:D @line
    --> Array[Str:D]
)
{
    # if C<GRUB_ENABLE_CRYPTODISK> not found, append to bottom of file
    my UInt:D $index = @line.first(/^'#'$subject/, :k) // @line.elems;
    my Str:D $replace = sprintf(Q{%s=y}, $subject);
    @line[$index] = $replace;
    @line;
}

multi sub replace(
    'grub',
    Str:D $subject where 'GRUB_TERMINAL_INPUT',
    Bool:D $enable-serial-console where .so,
    Str:D @line
    --> Array[Str:D]
)
{
    # if C<GRUB_TERMINAL_INPUT> not found, append to bottom of file
    my UInt:D $index = @line.first(/^'#'?$subject/, :k) // @line.elems;
    my Str:D $replace = sprintf(Q{%s="console serial"}, $subject);
    @line[$index] = $replace;
    @line;
}

multi sub replace(
    'grub',
    Str:D $subject where 'GRUB_TERMINAL_INPUT',
    Bool:D $enable-serial-console,
    Str:D @line
    --> Array[Str:D]
)
{
    # if C<GRUB_TERMINAL_INPUT> not found, append to bottom of file
    my UInt:D $index = @line.first(/^'#'?$subject/, :k) // @line.elems;
    my Str:D $replace = sprintf(Q{%s="console"}, $subject);
    @line[$index] = $replace;
    @line;
}

multi sub replace(
    'grub',
    Str:D $subject where 'GRUB_TERMINAL_OUTPUT',
    Bool:D $enable-serial-console where .so,
    Str:D @line
    --> Array[Str:D]
)
{
    # if C<GRUB_TERMINAL_OUTPUT> not found, append to bottom of file
    my UInt:D $index = @line.first(/^'#'?$subject/, :k) // @line.elems;
    my Str:D $replace = sprintf(Q{%s="console serial"}, $subject);
    @line[$index] = $replace;
    @line;
}

multi sub replace(
    'grub',
    Str:D $subject where 'GRUB_TERMINAL_OUTPUT',
    Bool:D $enable-serial-console,
    Str:D @line
    --> Array[Str:D]
)
{
    # if C<GRUB_TERMINAL_OUTPUT> not found, append to bottom of file
    my UInt:D $index = @line.first(/^'#'?$subject/, :k) // @line.elems;
    my Str:D $replace = sprintf(Q{%s="console"}, $subject);
    @line[$index] = $replace;
    @line;
}

multi sub replace(
    'grub',
    Str:D $subject where 'GRUB_SERIAL_COMMAND',
    Bool:D $enable-serial-console where .so,
    Str:D @line
    --> Array[Str:D]
)
{
    # if C<GRUB_SERIAL_COMMAND> not found, append to bottom of file
    my UInt:D $index = @line.first(/^'#'?$subject/, :k) // @line.elems;
    my Str:D $speed = $Voidvault::Utils::GRUB-SERIAL-PORT-BAUD-RATE;
    my Str:D $unit = $Voidvault::Utils::GRUB-SERIAL-PORT-UNIT;
    my Str:D $word = $Voidvault::Utils::GRUB-SERIAL-PORT-WORD-LENGTH-BITS;
    my Str:D $parity = %Voidvault::Utils::GRUB-SERIAL-PORT-PARITY{$Voidvault::Utils::GRUB-SERIAL-PORT-PARITY}{$subject};
    my Str:D $stop = $Voidvault::Utils::GRUB-SERIAL-PORT-STOP-BITS;
    my Str:D $grub-serial-command = qqw<
        serial
        --speed=$speed
        --unit=$unit
        --word=$word
        --parity=$parity
        --stop=$stop
    >.join(' ');
    my Str:D $replace = sprintf(Q{%s="%s"}, $subject, $grub-serial-command);
    @line[$index] = $replace;
    @line;
}

multi sub replace(
    'grub',
    Str:D $ where 'GRUB_SERIAL_COMMAND',
    Bool:D $,
    Str:D @line
    --> Array[Str:D]
)
{
    @line;
}

# --- end grub }}}
# --- 10_linux {{{

multi sub replace(
    '10_linux'
    --> Nil
)
{
    my Str:D $file = '/mnt/etc/grub.d/10_linux';
    my Str:D @line = $file.IO.lines;
    my Regex:D $regex = /'${CLASS}'\h/;
    my UInt:D @index = @line.grep($regex, :k);
    @index.race.map(-> UInt:D $index {
        @line[$index] .= subst($regex, '--unrestricted ${CLASS} ')
    });
    my Str:D $replace = @line.join("\n");
    spurt($file, $replace ~ "\n");
}

# --- end 10_linux }}}
# --- 99-sysctl.conf {{{

multi sub replace(
    '99-sysctl.conf',
    Bool:D $disable-ipv6 where .so,
    DiskType:D $disk-type where /SSD|USB/
    --> Nil
)
{
    my Str:D $file = '/mnt/etc/sysctl.d/99-sysctl.conf';
    my Str:D @replace =
        $file.IO.lines
        ==> replace('99-sysctl.conf', 'kernel.pid_max')
        ==> replace('99-sysctl.conf', 'net.ipv6.conf.all.disable_ipv6')
        ==> replace('99-sysctl.conf', 'net.ipv6.conf.default.disable_ipv6')
        ==> replace('99-sysctl.conf', 'net.ipv6.conf.lo.disable_ipv6')
        ==> replace('99-sysctl.conf', 'vm.mmap_rnd_bits')
        ==> replace('99-sysctl.conf', 'vm.vfs_cache_pressure')
        ==> replace('99-sysctl.conf', 'vm.swappiness');
    my Str:D $replace = @replace.join("\n");
    spurt($file, $replace ~ "\n");
}

multi sub replace(
    '99-sysctl.conf',
    Bool:D $disable-ipv6 where .so,
    DiskType:D $disk-type
    --> Nil
)
{
    my Str:D $file = '/mnt/etc/sysctl.d/99-sysctl.conf';
    my Str:D @replace =
        $file.IO.lines
        ==> replace('99-sysctl.conf', 'kernel.pid_max')
        ==> replace('99-sysctl.conf', 'net.ipv6.conf.all.disable_ipv6')
        ==> replace('99-sysctl.conf', 'net.ipv6.conf.default.disable_ipv6')
        ==> replace('99-sysctl.conf', 'net.ipv6.conf.lo.disable_ipv6')
        ==> replace('99-sysctl.conf', 'vm.mmap_rnd_bits');
    my Str:D $replace = @replace.join("\n");
    spurt($file, $replace ~ "\n");
}

multi sub replace(
    '99-sysctl.conf',
    Bool:D $disable-ipv6,
    DiskType:D $disk-type where /SSD|USB/
    --> Nil
)
{
    my Str:D $file = '/mnt/etc/sysctl.d/99-sysctl.conf';
    my Str:D @replace =
        $file.IO.lines
        ==> replace('99-sysctl.conf', 'kernel.pid_max')
        ==> replace('99-sysctl.conf', 'vm.mmap_rnd_bits')
        ==> replace('99-sysctl.conf', 'vm.vfs_cache_pressure')
        ==> replace('99-sysctl.conf', 'vm.swappiness');
    my Str:D $replace = @replace.join("\n");
    spurt($file, $replace ~ "\n");
}

multi sub replace(
    '99-sysctl.conf',
    Bool:D $disable-ipv6,
    DiskType:D $disk-type
    --> Nil
)
{
    my Str:D $file = '/mnt/etc/sysctl.d/99-sysctl.conf';
    my Str:D @replace =
        $file.IO.lines
        ==> replace('99-sysctl.conf', 'kernel.pid_max')
        ==> replace('99-sysctl.conf', 'vm.mmap_rnd_bits');
    my Str:D $replace = @replace.join("\n");
    spurt($file, $replace ~ "\n");
}

multi sub replace(
    '99-sysctl.conf',
    Str:D $subject where 'kernel.pid_max',
    Str:D @line
    --> Array[Str:D]
)
{
    my UInt:D $kernel-bits = $*KERNEL.bits;
    replace('99-sysctl.conf', $subject, @line, :$kernel-bits);
}

multi sub replace(
    '99-sysctl.conf',
    Str:D $subject where 'kernel.pid_max',
    Str:D @line,
    UInt:D :kernel-bits($)! where 64
    --> Array[Str:D]
)
{
    my UInt:D $index = @line.first(/^'#'$subject/, :k);
    # extract C<kernel.pid_max> value from file 99-sysctl.conf
    my Str:D $pid-max = @line[$index].split('=').map({ .trim }).tail;
    my Str:D $replace = sprintf(Q{%s = %s}, $subject, $pid-max);
    @line[$index] = $replace;
    @line;
}

multi sub replace(
    '99-sysctl.conf',
    Str:D $subject where 'kernel.pid_max',
    Str:D @line,
    UInt:D :kernel-bits($)!
    --> Array[Str:D]
)
{
    @line;
}

multi sub replace(
    '99-sysctl.conf',
    Str:D $subject where 'net.ipv6.conf.all.disable_ipv6',
    Str:D @line
    --> Array[Str:D]
)
{
    my UInt:D $index = @line.first(/^'#'$subject/, :k);
    my Str:D $replace = sprintf(Q{%s = 1}, $subject);
    @line[$index] = $replace;
    @line;
}

multi sub replace(
    '99-sysctl.conf',
    Str:D $subject where 'net.ipv6.conf.default.disable_ipv6',
    Str:D @line
    --> Array[Str:D]
)
{
    my UInt:D $index = @line.first(/^'#'$subject/, :k);
    my Str:D $replace = sprintf(Q{%s = 1}, $subject);
    @line[$index] = $replace;
    @line;
}

multi sub replace(
    '99-sysctl.conf',
    Str:D $subject where 'net.ipv6.conf.lo.disable_ipv6',
    Str:D @line
    --> Array[Str:D]
)
{
    my UInt:D $index = @line.first(/^'#'$subject/, :k);
    my Str:D $replace = sprintf(Q{%s = 1}, $subject);
    @line[$index] = $replace;
    @line;
}

multi sub replace(
    '99-sysctl.conf',
    Str:D $subject where 'vm.mmap_rnd_bits',
    Str:D @line
    --> Array[Str:D]
)
{
    my UInt:D $kernel-bits = $*KERNEL.bits;
    replace('99-sysctl.conf', $subject, @line, :$kernel-bits);
}

multi sub replace(
    '99-sysctl.conf',
    Str:D $subject where 'vm.mmap_rnd_bits',
    Str:D @line,
    UInt:D :kernel-bits($)! where 32
    --> Array[Str:D]
)
{
    my UInt:D $index = @line.first(/^$subject/, :k);
    my Str:D $replace = sprintf(Q{%s = 16}, $subject);
    @line[$index] = $replace;
    @line;
}

multi sub replace(
    '99-sysctl.conf',
    Str:D $subject where 'vm.mmap_rnd_bits',
    Str:D @line,
    UInt:D :kernel-bits($)!
    --> Array[Str:D]
)
{
    @line;
}

multi sub replace(
    '99-sysctl.conf',
    Str:D $subject where 'vm.vfs_cache_pressure',
    Str:D @line
    --> Array[Str:D]
)
{
    my UInt:D $index = @line.first(/^'#'$subject/, :k);
    my Str:D $replace = sprintf(Q{%s = 50}, $subject);
    @line[$index] = $replace;
    @line;
}

multi sub replace(
    '99-sysctl.conf',
    Str:D $subject where 'vm.swappiness',
    Str:D @line
    --> Array[Str:D]
)
{
    my UInt:D $index = @line.first(/^'#'$subject/, :k);
    my Str:D $replace = sprintf(Q{%s = 1}, $subject);
    @line[$index] = $replace;
    @line;
}

# --- end 99-sysctl.conf }}}
# --- sshd_config {{{

multi sub replace(
    'sshd_config',
    Bool:D $disable-ipv6 where .so,
    UserName:D $user-name-sftp
    --> Nil
)
{
    my Str:D $file = '/mnt/etc/ssh/sshd_config';
    my Str:D @replace =
        $file.IO.lines
        ==> replace('sshd_config', 'AddressFamily')
        ==> replace('sshd_config', 'AllowUsers', $user-name-sftp)
        ==> replace('sshd_config', 'ListenAddress');
    my Str:D $replace = @replace.join("\n");
    spurt($file, $replace ~ "\n");
}

multi sub replace(
    'sshd_config',
    Bool:D $disable-ipv6,
    UserName:D $user-name-sftp
    --> Nil
)
{
    my Str:D $file = '/mnt/etc/ssh/sshd_config';
    my Str:D @replace =
        $file.IO.lines
        ==> replace('sshd_config', 'AllowUsers', $user-name-sftp);
    my Str:D $replace = @replace.join("\n");
    spurt($file, $replace ~ "\n");
}

multi sub replace(
    'sshd_config',
    Str:D $subject where 'AddressFamily',
    Str:D @line
    --> Array[Str:D]
)
{
    # listen on IPv4 only
    my UInt:D $index = @line.first(/^$subject/, :k);
    my Str:D $replace = sprintf(Q{%s inet}, $subject);
    @line[$index] = $replace;
    @line;
}

multi sub replace(
    'sshd_config',
    Str:D $subject where 'AllowUsers',
    UserName:D $user-name-sftp,
    Str:D @line
    --> Array[Str:D]
)
{
    # put AllowUsers on the line below AddressFamily
    my UInt:D $index = @line.first(/^AddressFamily/, :k);
    my Str:D $replace = sprintf(Q{%s %s}, $subject, $user-name-sftp);
    @line.splice($index + 1, 0, $replace);
    @line;
}

multi sub replace(
    'sshd_config',
    Str:D $subject where 'ListenAddress',
    Str:D @line
    --> Array[Str:D]
)
{
    # listen on IPv4 only
    my UInt:D $index = @line.first(/^"$subject ::"/, :k);
    @line.splice($index, 1);
    @line;
}

# --- end sshd_config }}}
# --- moduli {{{

multi sub replace(
    'moduli'
    --> Nil
)
{
    my Str:D $file = '/mnt/etc/ssh/moduli';
    my Str:D $replace =
        $file.IO.lines
        .grep(/^\w/)
        .grep({ .split(/\h+/)[4] > 3071 })
        .join("\n");
    spurt($file, $replace ~ "\n");
}

# --- end moduli }}}
# --- securetty {{{

multi sub replace(
    'securetty'
    --> Nil
)
{
    my Str:D $file = '/mnt/etc/securetty';
    my Str:D @line = $file.IO.lines;
    my UInt:D $index =
        @line.first(/^'#'$Voidvault::Utils::SERIAL-CONSOLE/, :k);
    @line[$index] = $Voidvault::Utils::SERIAL-CONSOLE;
    my Str:D $replace = @line.join("\n");
    spurt($file, $replace ~ "\n");
}

# --- end securetty }}}
# --- passwd {{{

multi sub replace(
    'passwd'
    --> Nil
)
{
    my Str:D $file = '/mnt/etc/pam.d/passwd';
    my Str:D $slurp = slurp($file).trim-trailing;
    my Str:D $replace =
        sprintf(Q{%s rounds=%s}, $slurp, $Voidvault::Constants::CRYPT-ROUNDS);
    spurt($file, $replace ~ "\n");
}

# --- end passwd }}}

# end sub replace }}}

# vim: set filetype=raku foldmethod=marker foldlevel=0 nowrap:
