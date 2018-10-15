use v6;
use Voidvault::Config;
use Voidvault::Types;
use Voidvault::Utils;
unit class Voidvault::Bootstrap;


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
    my Bool:D $no-mkdisk = $.config.no-mkdisk;
    my Bool:D $no-setup = $.config.no-setup;
    # verify root permissions
    $*USER == 0 or die('root privileges required');
    # ensure pressing Ctrl-C works
    signal(SIGINT).tap({ exit(130) });
    self!setup if $no-setup.not;
    self!mkdisk if $no-mkdisk.not;
    self!voidstrap-base;
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
    self!generate-initramfs;
    self!install-bootloader;
    self!configure-runit-swap;
    self!configure-sysctl;
    self!configure-nftables;
    self!configure-openssh;
    self!configure-udev;
    self!configure-hidepid;
    self!configure-securetty;
    self!configure-xorg;
    self!enable-runit-services;
    self!augment if $augment.so;
    self!unmount;
}


# -----------------------------------------------------------------------------
# worker functions
# -----------------------------------------------------------------------------

method !setup(--> Nil)
{
    my Bool:D $ample-space = $.config.ample-space;

    # free up 100MB of disk space
    run(qw<xbps-remove --force-revdeps --yes linux-firmware-network>)
        if $ample-space.not;

    # fetch dependencies needed prior to voidstrap
    my Str:D @dep = qw<
        btrfs-progs
        coreutils
        cryptsetup
        dialog
        dosfstools
        e2fsprogs
        efibootmgr
        expect
        glibc
        gptfdisk
        grub
        kbd
        kmod
        libressl
        procps-ng
        tzdata
        util-linux
        xbps
    >;

    my Str:D $xbps-install-dep-cmdline =
        sprintf('xbps-install --force --sync --yes %s', @dep.join(' '));
    Voidvault::Utils.loop-cmdline-proc(
        'Installing dependencies...',
        $xbps-install-dep-cmdline
    );

    # use readable font
    run(qw<setfont Lat2-Terminus16>);
}

# secure disk configuration
method !mkdisk(--> Nil)
{
    my DiskType:D $disk-type = $.config.disk-type;
    my Str:D $partition = $.config.partition;
    my VaultName:D $vault-name = $.config.vault-name;
    my VaultPass $vault-pass = $.config.vault-pass;

    # partition disk
    sgdisk($partition);

    # create uefi partition
    mkefi($partition);

    # create vault
    mkvault($partition, $vault-name, :$vault-pass);

    # create and mount btrfs volumes
    mkbtrfs($disk-type, $vault-name);

    # mount efi boot
    mount-efi($partition);

    # disable Btrfs CoW
    disable-cow();
}

# partition disk with gdisk
sub sgdisk(Str:D $partition --> Nil)
{
    # erase existing partition table
    # create 2MB EF02 BIOS boot sector
    # create 100MB EF00 EFI system partition
    # create max sized partition for LUKS encrypted volume
    run(qw<
        sgdisk
        --zap-all
        --clear
        --mbrtogpt
        --new=1:0:+2M
        --typecode=1:EF02
        --new=2:0:+100M
        --typecode=2:EF00
        --new=3:0:0
        --typecode=3:8300
    >, $partition);
}

sub mkefi(Str:D $partition --> Nil)
{
    # target partition for uefi
    my Str:D $partition-efi = sprintf(Q{%s2}, $partition);
    run(qw<modprobe vfat>);
    run(qqw<mkfs.vfat -F 32 $partition-efi>);
}

# create vault with cryptsetup
sub mkvault(
    Str:D $partition,
    VaultName:D $vault-name,
    VaultPass :$vault-pass
    --> Nil
)
{
    # target partition for vault
    my Str:D $partition-vault = sprintf(Q{%s3}, $partition);

    # load kernel modules for cryptsetup
    run(qw<modprobe dm_mod dm-crypt>);

    mkvault-cryptsetup(:$partition-vault, :$vault-name, :$vault-pass);
}

# LUKS encrypted volume password was given
multi sub mkvault-cryptsetup(
    Str:D :$partition-vault where .so,
    VaultName:D :$vault-name where .so,
    VaultPass:D :$vault-pass where .so
    --> Nil
)
{
    my Str:D $cryptsetup-luks-format-cmdline =
        build-cryptsetup-luks-format-cmdline(
            :non-interactive,
            $partition-vault,
            $vault-pass
        );

    my Str:D $cryptsetup-luks-open-cmdline =
        build-cryptsetup-luks-open-cmdline(
            :non-interactive,
            $partition-vault,
            $vault-name,
            $vault-pass
        );

    # make LUKS encrypted volume without prompt for vault password
    shell($cryptsetup-luks-format-cmdline);

    # open vault without prompt for vault password
    shell($cryptsetup-luks-open-cmdline);
}

# LUKS encrypted volume password not given
multi sub mkvault-cryptsetup(
    Str:D :$partition-vault where .so,
    VaultName:D :$vault-name where .so,
    VaultPass :vault-pass($)
    --> Nil
)
{
    my Str:D $cryptsetup-luks-format-cmdline =
        build-cryptsetup-luks-format-cmdline(
            :interactive,
            $partition-vault
        );

    my Str:D $cryptsetup-luks-open-cmdline =
        build-cryptsetup-luks-open-cmdline(
            :interactive,
            $partition-vault,
            $vault-name
        );

    # create LUKS encrypted volume, prompt user for vault password
    Voidvault::Utils.loop-cmdline-proc(
        'Creating LUKS vault...',
        $cryptsetup-luks-format-cmdline
    );

    # open LUKS encrypted volume, prompt user for vault password
    Voidvault::Utils.loop-cmdline-proc(
        'Opening LUKS vault...',
        $cryptsetup-luks-open-cmdline
    );
}

multi sub build-cryptsetup-luks-format-cmdline(
    Str:D $partition-vault where .so,
    Bool:D :interactive($) where .so
    --> Str:D
)
{
    my Str:D $spawn-cryptsetup-luks-format = qqw<
         spawn cryptsetup
         --cipher aes-xts-plain64
         --key-size 512
         --hash sha512
         --iter-time 5000
         --use-random
         --verify-passphrase
         luksFormat $partition-vault
    >.join(' ');
    my Str:D $expect-are-you-sure-send-yes =
        'expect "Are you sure*" { send "YES\r" }';
    my Str:D $interact =
        'interact';
    my Str:D $catch-wait-result =
        'catch wait result';
    my Str:D $exit-lindex-result =
        'exit [lindex $result 3]';

    my Str:D @cryptsetup-luks-format-cmdline =
        $spawn-cryptsetup-luks-format,
        $expect-are-you-sure-send-yes,
        $interact,
        $catch-wait-result,
        $exit-lindex-result;

    my Str:D $cryptsetup-luks-format-cmdline =
        sprintf(q:to/EOF/.trim, |@cryptsetup-luks-format-cmdline);
        expect -c '%s;
                   %s;
                   %s;
                   %s;
                   %s'
        EOF
}

multi sub build-cryptsetup-luks-format-cmdline(
    Str:D $partition-vault where .so,
    VaultPass:D $vault-pass where .so,
    Bool:D :non-interactive($) where .so
    --> Str:D
)
{
    my Str:D $spawn-cryptsetup-luks-format = qqw<
                 spawn cryptsetup
                 --cipher aes-xts-plain64
                 --key-size 512
                 --hash sha512
                 --iter-time 5000
                 --use-random
                 --verify-passphrase
                 luksFormat $partition-vault
    >.join(' ');
    my Str:D $sleep =
                'sleep 0.33';
    my Str:D $expect-are-you-sure-send-yes =
                'expect "Are you sure*" { send "YES\r" }';
    my Str:D $expect-enter-send-vault-pass =
        sprintf('expect "Enter*" { send "%s\r" }', $vault-pass);
    my Str:D $expect-verify-send-vault-pass =
        sprintf('expect "Verify*" { send "%s\r" }', $vault-pass);
    my Str:D $expect-eof =
                'expect eof';

    my Str:D @cryptsetup-luks-format-cmdline =
        $spawn-cryptsetup-luks-format,
        $sleep,
        $expect-are-you-sure-send-yes,
        $sleep,
        $expect-enter-send-vault-pass,
        $sleep,
        $expect-verify-send-vault-pass,
        $sleep,
        $expect-eof;

    my Str:D $cryptsetup-luks-format-cmdline =
        sprintf(q:to/EOF/.trim, |@cryptsetup-luks-format-cmdline);
        expect <<EOS
          %s
          %s
          %s
          %s
          %s
          %s
          %s
          %s
          %s
        EOS
        EOF
}

multi sub build-cryptsetup-luks-open-cmdline(
    Str:D $partition-vault where .so,
    VaultName:D $vault-name where .so,
    Bool:D :interactive($) where .so
    --> Str:D
)
{
    my Str:D $cryptsetup-luks-open-cmdline =
        "cryptsetup luksOpen $partition-vault $vault-name";
}

multi sub build-cryptsetup-luks-open-cmdline(
    Str:D $partition-vault where .so,
    VaultName:D $vault-name where .so,
    VaultPass:D $vault-pass where .so,
    Bool:D :non-interactive($) where .so
    --> Str:D
)
{
    my Str:D $spawn-cryptsetup-luks-open =
                "spawn cryptsetup luksOpen $partition-vault $vault-name";
    my Str:D $sleep =
                'sleep 0.33';
    my Str:D $expect-enter-send-vault-pass =
        sprintf('expect "Enter*" { send "%s\r" }', $vault-pass);
    my Str:D $expect-eof =
                'expect eof';

    my Str:D @cryptsetup-luks-open-cmdline =
        $spawn-cryptsetup-luks-open,
        $sleep,
        $expect-enter-send-vault-pass,
        $sleep,
        $expect-eof;

    my Str:D $cryptsetup-luks-open-cmdline =
        sprintf(q:to/EOF/.trim, |@cryptsetup-luks-open-cmdline);
        expect <<EOS
          %s
          %s
          %s
          %s
          %s
        EOS
        EOF
}

# create and mount btrfs volumes on open vault
sub mkbtrfs(DiskType:D $disk-type, VaultName:D $vault-name --> Nil)
{
    # create btrfs filesystem on opened vault
    run(qw<modprobe btrfs>);
    run(qqw<mkfs.btrfs /dev/mapper/$vault-name>);

    # set mount options
    my Str:D $mount-options = 'rw,lazytime,compress=lzo,space_cache';
    $mount-options ~= ',ssd' if $disk-type eq 'SSD';

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
        'boot',
        'home',
        'opt',
        'srv',
        'var',
        'var-cache-xbps',
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

sub mount-efi(Str:D $partition --> Nil)
{
    # target partition for uefi
    my Str:D $partition-efi = sprintf(Q{%s2}, $partition);
    my Str:D $efi-dir = '/mnt/boot/efi';
    mkdir($efi-dir);
    run(qqw<mount $partition-efi $efi-dir>);
}

sub disable-cow(--> Nil)
{
    my Str:D @directory = qw<
        home
        srv
        var/log
        var/spool
        var/tmp
    >.map(-> Str:D $directory { sprintf(Q{/mnt/%s}, $directory) });
    Voidvault::Utils.disable-cow(|@directory, :recursive);
}

# bootstrap initial chroot with voidstrap
method !voidstrap-base(--> Nil)
{
    my Processor:D $processor = $.config.processor;

    my Str:D @core = qw<
        base-system
        grub
    >;

    # download and install core packages with voidstrap in chroot
    my Str:D $voidstrap-cmdline = "voidstrap /mnt @core[]";
    Voidvault::Utils.loop-cmdline-proc(
        'Running voidstrap...',
        $voidstrap-cmdline
    );

    # base packages
    my Str:D @pkg = qw<
        acpi
        bash
        bash-completion
        binutils
        btrfs-progs
        bzip2
        ca-certificates
        cdrtools
        chrony
        coreutils
        crda
        cronie
        cryptsetup
        curl
        device-mapper
        dhclient
        dhcpcd
        dialog
        diffutils
        dnscrypt-proxy
        dosfstools
        dracut
        dvd+rw-tools
        e2fsprogs
        efibootmgr
        ethtool
        exfat-utils
        expect
        file
        findutils
        gawk
        git
        glibc
        gnupg2
        gptfdisk
        grep
        grub-i386-efi
        grub-x86_64-efi
        gzip
        haveged
        inetutils
        iproute2
        iputils
        iw
        kbd
        kmod
        ldns
        less
        libressl
        linux
        linux-firmware
        linux-firmware-network
        logrotate
        lynx
        lz4
        man-db
        man-pages
        mlocate
        ncurses-term
        net-tools
        nftables
        openresolv
        openssh
        pciutils
        perl
        pinentry
        pkg-config
        procps-ng
        psmisc
        rakudo
        rsync
        runit-swap
        runit-void
        sed
        shadow
        socat
        socklog-void
        sudo
        sysfsutils
        tar
        tmux
        tzdata
        unzip
        usb-modeswitch
        usbutils
        util-linux
        vim
        wget
        which
        wifish
        wireguard
        wireless_tools
        wpa_actiond
        wpa_supplicant
        xbps
        xz
        zip
        zlib
        zstd
    >;

    # https://www.archlinux.org/news/changes-to-intel-microcodeupdates/
    push(@pkg, 'intel-ucode') if $processor eq 'intel';

    # install pkgs
    run(qqw<void-chroot /mnt xbps-install --force --sync --yes>, @pkg);
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
        lp
        mail
        network
        optical
        proc
        scanner
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
    my Str:D $user-group-guest = 'guests,users';
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
    my HostName:D $host-name = $.config.host-name;
    my Str:D $path = 'etc/hosts';
    copy(%?RESOURCES{$path}, "/mnt/$path");
    my Str:D $hosts = qq:to/EOF/;
    127.0.1.1       $host-name.localdomain       $host-name
    EOF
    spurt("/mnt/$path", $hosts, :append);
}

method !configure-dhcpcd(--> Nil)
{
    my Str:D $dhcpcd = q:to/EOF/;
    # Set vendor-class-id to empty string
    vendorclassid

    # Use the same DNS servers every time
    static domain_name_servers=127.0.0.1
    EOF
    spurt('/mnt/etc/dhcpcd.conf', "\n" ~ $dhcpcd, :append);
}

method !configure-dnscrypt-proxy(--> Nil)
{
    replace('dnscrypt-proxy.toml');
}

method !set-nameservers(--> Nil)
{
    my Str:D $path = 'etc/resolv.conf.head';
    copy(%?RESOURCES{$path}, "/mnt/$path");
}

method !set-locale(--> Nil)
{
    my Locale:D $locale = $.config.locale;
    my Str:D $locale-fallback = $locale.substr(0, 2);

    # customize /etc/locale.conf
    my Str:D $locale-conf = qq:to/EOF/;
    LANG=$locale.UTF-8
    LANGUAGE=$locale:$locale-fallback
    LC_TIME=$locale.UTF-8
    EOF
    spurt('/mnt/etc/locale.conf', $locale-conf);

    # customize /etc/default/libc-locales
    replace('libc-locales', $locale);

    # regenerate locales
    run(qqw<void-chroot /mnt xbps-reconfigure --force glibc-locales>);
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
    my Graphics:D $graphics = $.config.graphics;
    my Str:D $partition = $.config.partition;
    my UserName:D $user-name-grub = $.config.user-name-grub;
    my Str:D $user-pass-hash-grub = $.config.user-pass-hash-grub;
    my VaultName:D $vault-name = $.config.vault-name;
    replace('grub', $graphics, $partition, $vault-name);
    replace('10_linux');
    configure-bootloader('superusers', $user-name-grub, $user-pass-hash-grub);
    install-bootloader($partition);
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
    Str:D $partition
    --> Nil
)
{
    install-bootloader(:legacy, $partition);
    install-bootloader(:uefi, $partition);
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
    Str:D $partition,
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
    >, $partition);
}

multi sub install-bootloader(
    Str:D $partition,
    Bool:D :uefi($)! where .so
    --> Nil
)
{
    # uefi
    run(qqw<
        void-chroot
        /mnt
        grub-install
        --target=x86_64-efi
        --efi-directory=/boot/efi
        --removable
    >, $partition);

    # fix virtualbox uefi
    my Str:D $nsh = q:to/EOF/;
    fs0:
    \EFI\BOOT\BOOTX64.EFI
    EOF
    spurt('/mnt/boot/efi/startup.nsh', $nsh, :append);
}

method !configure-runit-swap(--> Nil)
{
    replace('swap.conf');
}

method !configure-sysctl(--> Nil)
{
    my DiskType:D $disk-type = $.config.disk-type;
    my Str:D $path = 'etc/sysctl.d/99-sysctl.conf';
    my Str:D $base-path = $path.IO.dirname;
    mkdir("/mnt/$base-path");
    copy(%?RESOURCES{$path}, "/mnt/$path");
    replace('99-sysctl.conf', $disk-type);
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
    my UserName:D $user-name-sftp = $.config.user-name-sftp;
    configure-openssh('ssh_config');
    configure-openssh('sshd_config', $user-name-sftp);
    configure-openssh('hosts.allow');
    configure-openssh('moduli');
}

multi sub configure-openssh('ssh_config' --> Nil)
{
    my Str:D $path = 'etc/ssh/ssh_config';
    copy(%?RESOURCES{$path}, "/mnt/$path");
}

multi sub configure-openssh('sshd_config', UserName:D $user-name-sftp --> Nil)
{
    my Str:D $path = 'etc/ssh/sshd_config';
    copy(%?RESOURCES{$path}, "/mnt/$path");
    # restrict allowed connections to $user-name-sftp
    replace('sshd_config', $user-name-sftp);
}

multi sub configure-openssh('hosts.allow' --> Nil)
{
    # restrict allowed connections to LAN
    my Str:D $path = 'etc/hosts.allow';
    copy(%?RESOURCES{$path}, "/mnt/$path");
}

multi sub configure-openssh('moduli' --> Nil)
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
    spurt('/mnt/etc/fstab', $fstab-hidepid, :append);
}

method !configure-securetty(--> Nil)
{
    configure-securetty('securetty');
    configure-securetty('shell-timeout');
}

multi sub configure-securetty('securetty' --> Nil)
{
    my Str:D $path = 'etc/securetty';
    copy(%?RESOURCES{$path}, "/mnt/$path");
}

multi sub configure-securetty('shell-timeout' --> Nil)
{
    my Str:D $path = 'etc/profile.d/shell-timeout.sh';
    copy(%?RESOURCES{$path}, "/mnt/$path");
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

method !enable-runit-services(--> Nil)
{
    my Str:D @service = qw<
        dnscrypt-proxy
        nanoklogd
        nftables
        runit-swap
        socklog-unix
    >;
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
    # permissions should be octal: https://doc.perl6.org/routine/chmod
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
# --- dnscrypt-proxy.toml {{{

multi sub replace(
    'dnscrypt-proxy.toml'
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
    Processor:D $processor
    --> Nil
)
{
    replace('dracut.conf', 'compress');
    replace('dracut.conf', 'add_drivers', $graphics, $processor);
    replace('dracut.conf', 'add_dracutmodules');
    replace('dracut.conf', 'omit_dracutmodules');
    replace('dracut.conf', 'persistent_policy');
    replace('dracut.conf', 'tmpdir');
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
        libcrc32c
        lz4
        lz4_compress
    >;
    push(@driver, 'crc32c-intel') if $processor eq 'INTEL';
    push(@driver, 'i915') if $graphics eq 'INTEL';
    push(@driver, 'nouveau') if $graphics eq 'NVIDIA';
    push(@driver, 'radeon') if $graphics eq 'RADEON';
    my Str:D $replace = sprintf(Q{%s=" %s "}, $subject, @driver.join(' '));
    spurt($file, $replace ~ "\n");
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
        kernel-modules
    >;
    my Str:D $replace = sprintf(Q{%s=" %s "}, $subject, @module.join(' '));
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
        plymouth
        usrmount
    >;
    my Str:D $replace = sprintf(Q{%s=" %s "}, $subject, @module.join(' '));
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
        Graphics:D $graphics,
        Str:D $partition,
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
        ==> replace('grub', 'GRUB_ENABLE_CRYPTODISK')
        ==> replace('grub', 'GRUB_TERMINAL_INPUT')
        ==> replace('grub', 'GRUB_TERMINAL_OUTPUT');
    my Str:D $replace = @replace.join("\n");
    spurt($file, $replace ~ "\n");
}

multi sub replace(
    'grub',
    Str:D $subject where 'GRUB_CMDLINE_LINUX_DEFAULT',
    Graphics:D $graphics,
    Str:D $partition,
    VaultName:D $vault-name,
    Str:D @line
    --> Array[Str:D]
)
{
    # prepare GRUB_CMDLINE_LINUX_DEFAULT
    my Str:D $partition-vault = sprintf(Q{%s3}, $partition);
    my Str:D $vault-uuid =
        qqx<blkid --match-tag UUID --output value $partition-vault>.trim;
    my Str:D $grub-cmdline-linux =
        sprintf(
            Q{cryptdevice=/dev/disk/by-uuid/%s:%s rootflags=subvol=@},
            $vault-uuid,
            $vault-name
        );
    $grub-cmdline-linux ~= ' rd.auto=1';
    $grub-cmdline-linux ~= ' rd.luks=1';
    $grub-cmdline-linux ~= " rd.luks.name=$vault-name";
    $grub-cmdline-linux ~= " rd.luks.uuid=$vault-uuid";
    $grub-cmdline-linux ~= ' loglevel=6';
    $grub-cmdline-linux ~= ' slub_debug=P';
    $grub-cmdline-linux ~= ' page_poison=1';
    $grub-cmdline-linux ~= ' printk.time=1';
    $grub-cmdline-linux ~= ' radeon.dpm=1' if $graphics eq 'RADEON';
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
# --- swap.conf {{{

multi sub replace(
    'swap.conf'
    --> Nil
)
{
    my Str:D $file = '/mnt/etc/runit/swap.conf';
    my Str:D @replace =
        $file.IO.lines
        # disable zswap
        ==> replace('swap.conf', 'zswap_enabled')
        # enable zram
        ==> replace('swap.conf', 'zram_enabled');
    my Str:D $replace = @replace.join("\n");
    spurt($file, $replace ~ "\n");
}

multi sub replace(
    'swap.conf',
    Str:D $subject where 'zswap_enabled',
    Str:D @line
    --> Array[Str:D]
)
{
    my UInt:D $index = @line.first(/^$subject/, :k);
    my Str:D $replace = sprintf(Q{%s=0}, $subject);
    @line[$index] = $replace;
    @line;
}

multi sub replace(
    'swap.conf',
    Str:D $subject where 'zram_enabled',
    Str:D @line
    --> Array[Str:D]
)
{
    my UInt:D $index = @line.first(/^$subject/, :k);
    my Str:D $replace = sprintf(Q{%s=1}, $subject);
    @line[$index] = $replace;
    @line;
}

# --- end swap.conf }}}
# --- 99-sysctl.conf {{{

multi sub replace(
    '99-sysctl.conf',
    DiskType:D $disk-type where /SSD|USB/
    --> Nil
)
{
    my Str:D $file = '/mnt/etc/sysctl.d/99-sysctl.conf';
    my Str:D @replace =
        $file.IO.lines
        ==> replace('99-sysctl.conf', 'vm.vfs_cache_pressure')
        ==> replace('99-sysctl.conf', 'vm.swappiness');
    my Str:D $replace = @replace.join("\n");
    spurt($file, $replace ~ "\n");
}

multi sub replace(
    '99-sysctl.conf',
    DiskType:D $disk-type
    --> Nil
)
{*}

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
    UserName:D $user-name-sftp
    --> Nil
)
{
    my Str:D $file = '/mnt/etc/ssh/sshd_config';
    my Str:D @line = $file.IO.lines;
    my UInt:D $index = @line.first(/^AddressFamily/, :k);
    # put AllowUsers on the line below AddressFamily
    my Str:D $allow-users = sprintf(Q{AllowUsers %s}, $user-name-sftp);
    @line.splice($index + 1, 0, $allow-users);
    my Str:D $replace = @line.join("\n");
    spurt($file, $replace ~ "\n");
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
        .grep({ .split(/\h+/)[4] > 2000 })
        .join("\n");
    spurt($file, $replace ~ "\n");
}

# --- end moduli }}}

# end sub replace }}}

# vim: set filetype=perl6 foldmethod=marker foldlevel=0 nowrap:
