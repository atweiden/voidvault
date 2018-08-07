use v6;
use Archvault::Config;
use Archvault::Types;
use Archvault::Utils;
unit class Archvault::Bootstrap;


# -----------------------------------------------------------------------------
# attributes
# -----------------------------------------------------------------------------

has Archvault::Config:D $.config is required;


# -----------------------------------------------------------------------------
# bootstrap
# -----------------------------------------------------------------------------

method bootstrap(::?CLASS:D: --> Nil)
{
    my Bool:D $augment = $.config.augment;
    # verify root permissions
    $*USER == 0 or die('root privileges required');
    # ensure pressing Ctrl-C works
    signal(SIGINT).tap({ exit(130) });

    self!setup;
    self!mkdisk;
    self!disable-cow;
    self!pacstrap-base;
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
    self!configure-pacman;
    self!configure-modprobe;
    self!generate-initramfs;
    self!install-bootloader;
    self!configure-sysctl;
    self!configure-nftables;
    self!configure-openssh;
    self!configure-systemd;
    self!configure-hidepid;
    self!configure-securetty;
    self!configure-xorg;
    self!enable-systemd-services;
    self!augment if $augment;
    self!unmount;
}


# -----------------------------------------------------------------------------
# worker functions
# -----------------------------------------------------------------------------

method !setup(--> Nil)
{
    my Bool:D $reflector = $.config.reflector;

    # initialize pacman-keys
    run(qw<haveged -w 1024>);
    run(qw<pacman-key --init>);
    run(qw<pacman-key --populate archlinux>);
    run(qw<pkill haveged>);

    # fetch dependencies needed prior to pacstrap
    my Str:D @dep = qw<
        arch-install-scripts
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
        haveged
        kbd
        kmod
        openssl
        pacman
        procps-ng
        tzdata
        util-linux
    >;

    my Str:D $pacman-dep-cmdline =
        sprintf('pacman -Sy --needed --noconfirm %s', @dep.join(' '));
    Archvault::Utils.loop-cmdline-proc(
        'Installing dependencies...',
        $pacman-dep-cmdline
    );

    # use readable font
    run(qw<setfont Lat2-Terminus16>);

    # optionally run reflector
    reflector() if $reflector;
}

sub reflector(--> Nil)
{
    my Str:D $pacman-reflector-cmdline =
        'pacman -Sy --needed --noconfirm reflector';
    Archvault::Utils.loop-cmdline-proc(
        'Installing reflector...',
        $pacman-reflector-cmdline
    );

    # rank mirrors
    rename('/etc/pacman.d/mirrorlist', '/etc/pacman.d/mirrorlist.bak');
    my Str:D $reflector-cmdline = qw<
        reflector
        --threads 5
        --protocol https
        --fastest 7
        --number 7
        --save /etc/pacman.d/mirrorlist
    >.join(' ');
    Archvault::Utils.loop-cmdline-proc(
        'Running reflector to optimize pacman mirrors',
        $reflector-cmdline
    );
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
    Archvault::Utils.loop-cmdline-proc(
        'Creating LUKS vault...',
        $cryptsetup-luks-format-cmdline
    );

    # open LUKS encrypted volume, prompt user for vault password
    Archvault::Utils.loop-cmdline-proc(
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
    run(qqw<mkfs.btrfs /dev/mapper/$vault-name>);

    # set mount options
    my Str:D $mount-options = 'rw,lazytime,compress=lzo,space_cache';
    $mount-options ~= ',ssd' if $disk-type eq 'SSD';

    # mount main btrfs filesystem on open vault
    mkdir('/mnt2');
    run(qqw<mount -t btrfs -o $mount-options /dev/mapper/$vault-name /mnt2>);

    # btrfs subvolumes, starting with root / ('')
    my Str:D @btrfs-dir =
        '',
        'boot',
        'home',
        'opt',
        'srv',
        'usr',
        'var',
        'var-cache-pacman',
        'var-lib-ex',
        'var-lib-machines',
        'var-lib-portables',
        'var-lib-postgres',
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
        -t btrfs
        -o $mount-options,nodev,noexec,nosuid,subvol=@$btrfs-dir
        /dev/mapper/$vault-name
        /mnt/$btrfs-dir
    >);
}

multi sub mount-btrfs-subvolume(
    'var-cache-pacman',
    Str:D $mount-options,
    VaultName:D $vault-name
    --> Nil
)
{
    my Str:D $btrfs-dir = 'var/cache/pacman';
    mkdir("/mnt/$btrfs-dir");
    run(qqw<
        mount
        -t btrfs
        -o $mount-options,subvol=@var-cache-pacman
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
        -t btrfs
        -o $mount-options,nodev,noexec,nosuid,subvol=@var-lib-ex
        /dev/mapper/$vault-name
        /mnt/$btrfs-dir
    >);
    run(qqw<chmod 1777 /mnt/$btrfs-dir>);
}

multi sub mount-btrfs-subvolume(
    'var-lib-machines',
    Str:D $mount-options,
    VaultName:D $vault-name
    --> Nil
)
{
    my Str:D $btrfs-dir = 'var/lib/machines';
    mkdir("/mnt/$btrfs-dir");
    run(qqw<
        mount
        -t btrfs
        -o $mount-options,subvol=@var-lib-machines
        /dev/mapper/$vault-name
        /mnt/$btrfs-dir
    >);
    chmod(0o700, "/mnt/$btrfs-dir");
}

multi sub mount-btrfs-subvolume(
    'var-lib-portables',
    Str:D $mount-options,
    VaultName:D $vault-name
    --> Nil
)
{
    my Str:D $btrfs-dir = 'var/lib/portables';
    mkdir("/mnt/$btrfs-dir");
    run(qqw<
        mount
        -t btrfs
        -o $mount-options,subvol=@var-lib-portables
        /dev/mapper/$vault-name
        /mnt/$btrfs-dir
    >);
    chmod(0o700, "/mnt/$btrfs-dir");
}

multi sub mount-btrfs-subvolume(
    'var-lib-postgres',
    Str:D $mount-options,
    VaultName:D $vault-name
    --> Nil
)
{
    my Str:D $btrfs-dir = 'var/lib/postgres';
    mkdir("/mnt/$btrfs-dir");
    run(qqw<
        mount
        -t btrfs
        -o $mount-options,subvol=@var-lib-postgres
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
        -t btrfs
        -o $mount-options,nodev,noexec,nosuid,subvol=@var-log
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
        -t btrfs
        -o $mount-options,subvol=@var-opt
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
        -t btrfs
        -o $mount-options,nodev,noexec,nosuid,subvol=@var-spool
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
        -t btrfs
        -o $mount-options,nodev,noexec,nosuid,subvol=@var-tmp
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
        -t btrfs
        -o $mount-options,subvol=@$btrfs-dir
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

method !disable-cow(--> Nil)
{
    my Str:D @directory = qw<
        home
        srv
        var/lib/ex
        var/lib/machines
        var/lib/portables
        var/lib/postgres
        var/log
        var/spool
        var/tmp
    >.map(-> Str:D $directory { sprintf(Q{/mnt/%s}, $directory) });
    Archvault::Utils.disable-cow(|@directory, :recursive);
}

# bootstrap initial chroot with pacstrap
method !pacstrap-base(--> Nil)
{
    my Processor:D $processor = $.config.processor;
    my Bool:D $reflector = $.config.reflector;

    # base packages
    my Str:D @pkg = qw<
        acpi
        arch-install-scripts
        base
        base-devel
        bash-completion
        btrfs-progs
        ca-certificates
        crda
        dhclient
        dialog
        dnscrypt-proxy
        dosfstools
        ed
        efibootmgr
        ethtool
        expect
        gptfdisk
        grub
        haveged
        ifplugd
        iproute2
        iw
        kbd
        lz4
        net-tools
        nftables
        openresolv
        openssh
        pacman-contrib
        rsync
        systemd-swap
        tmux
        unzip
        vim
        wget
        wireless-regdb
        wireless_tools
        wpa_actiond
        wpa_supplicant
        zip
    >;

    # https://www.archlinux.org/news/changes-to-intel-microcodeupdates/
    push(@pkg, 'intel-ucode') if $processor eq 'intel';
    push(@pkg, 'reflector') if $reflector;

    # download and install packages with pacman in chroot
    my Str:D $pacstrap-cmdline = sprintf('pacstrap /mnt %s', @pkg.join(' '));
    Archvault::Utils.loop-cmdline-proc(
        'Running pacstrap...',
        $pacstrap-cmdline
    );
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
    my Str:D $user-group-admin = qw<
        audio
        games
        log
        lp
        network
        optical
        power
        proc
        scanner
        storage
        users
        video
        wheel
    >.join(',');
    my Str:D $user-shell-admin = '/bin/bash';

    say("Creating new admin user named $user-name-admin...");
    groupadd($user-name-admin);
    run(qqw<
        arch-chroot
        /mnt
        useradd
        -m
        -g $user-name-admin
        -G $user-group-admin
        -p $user-pass-hash-admin
        -s $user-shell-admin
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
        arch-chroot
        /mnt
        useradd
        -m
        -g $user-name-guest
        -G $user-group-guest
        -p $user-pass-hash-guest
        -s $user-shell-guest
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
    arch-chroot-mkdir(@root-dir, 'root', 'root', 0o755);
    groupadd($user-name-sftp, $user-group-sftp);
    run(qqw<
        arch-chroot
        /mnt
        useradd
        -M
        -d $home-dir
        -g $user-name-sftp
        -G $user-group-sftp
        -p $user-pass-hash-sftp
        -s $user-shell-sftp
        $user-name-sftp
    >);
    arch-chroot-mkdir($home-dir, $user-name-sftp, $user-name-sftp, 0o700);
}

sub usermod(
    'root',
    Str:D $user-pass-hash-root
    --> Nil
)
{
    say('Updating root password...');
    run(qqw<arch-chroot /mnt usermod -p $user-pass-hash-root root>);
}

sub groupadd(*@group-name --> Nil)
{
    @group-name.map(-> Str:D $group-name {
        run(qqw<arch-chroot /mnt groupadd $group-name>);
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
    shell('genfstab -U -p /mnt >> /mnt/etc/fstab');
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
    127.0.1.1        $host-name.localdomain        $host-name
    EOF
    spurt("/mnt/$path", $hosts, :append);
}

method !configure-dhcpcd(--> Nil)
{
    my Str:D $dhcpcd = q:to/EOF/;
    # Set vendor-class-id to empty string
    vendorclassid
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

    # customize /etc/locale.gen
    replace('locale.gen', $locale);
    run(qw<arch-chroot /mnt locale-gen>);

    # customize /etc/locale.conf
    my Str:D $locale-conf = qq:to/EOF/;
    LANG=$locale.UTF-8
    LANGUAGE=$locale:$locale-fallback
    LC_TIME=$locale.UTF-8
    EOF
    spurt('/mnt/etc/locale.conf', $locale-conf);
}

method !set-keymap(--> Nil)
{
    my Keymap:D $keymap = $.config.keymap;
    my Str:D $vconsole = qq:to/EOF/;
    KEYMAP=$keymap
    FONT=Lat2-Terminus16
    FONT_MAP=
    EOF
    spurt('/mnt/etc/vconsole.conf', $vconsole);
}

method !set-timezone(--> Nil)
{
    my Timezone:D $timezone = $.config.timezone;
    run(qqw<
        arch-chroot
        /mnt
        ln
        -sf /usr/share/zoneinfo/$timezone
        /etc/localtime
    >);
}

method !set-hwclock(--> Nil)
{
    run(qw<arch-chroot /mnt hwclock --systohc --utc>);
}

method !configure-pacman(--> Nil)
{
    replace('pacman.conf');
}

method !configure-modprobe(--> Nil)
{
    my Str:D $path = 'etc/modprobe.d/modprobe.conf';
    copy(%?RESOURCES{$path}, "/mnt/$path");
}

method !generate-initramfs(--> Nil)
{
    my DiskType:D $disk-type = $.config.disk-type;
    my Graphics:D $graphics = $.config.graphics;
    my Processor:D $processor = $.config.processor;
    replace('mkinitcpio.conf', $disk-type, $graphics, $processor);
    run(qw<arch-chroot /mnt mkinitcpio -p linux>);
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
    run(qw<
        arch-chroot
        /mnt
        cp
        /usr/share/locale/en@quot/LC_MESSAGES/grub.mo
        /boot/grub/locale/en.mo
    >);
    run(qw<
        arch-chroot
        /mnt
        grub-mkconfig
        -o /boot/grub/grub.cfg
    >);
}

multi sub install-bootloader(
    Str:D $partition,
    Bool:D :legacy($)! where .so
    --> Nil
)
{
    # legacy bios
    run(qw<
        arch-chroot
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
    run(qw<
        arch-chroot
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

method !configure-sysctl(--> Nil)
{
    my DiskType:D $disk-type = $.config.disk-type;
    my Str:D $path = 'etc/sysctl.d/99-sysctl.conf';
    copy(%?RESOURCES{$path}, "/mnt/$path");
    replace('99-sysctl.conf', $disk-type);
    run(qw<arch-chroot /mnt sysctl --system>);
}

method !configure-nftables(--> Nil)
{
    # XXX: customize nftables
    Nil;
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

method !configure-systemd(--> Nil)
{
    configure-systemd('limits');
    configure-systemd('mounts');
    configure-systemd('sleep');
    configure-systemd('swap');
    configure-systemd('tmpfiles');
    configure-systemd('udev');
}

multi sub configure-systemd('limits' --> Nil)
{
    my Str:D $base-path = 'etc/systemd/system.conf.d';
    my Str:D $path = "$base-path/limits.conf";
    mkdir("/mnt/$base-path");
    copy(%?RESOURCES{$path}, "/mnt/$path");
}

multi sub configure-systemd('mounts' --> Nil)
{
    my Str:D $base-path = 'etc/systemd/system/tmp.mount.d';
    my Str:D $path = "$base-path/noexec.conf";
    mkdir("/mnt/$base-path");
    copy(%?RESOURCES{$path}, "/mnt/$path");
}

multi sub configure-systemd('sleep' --> Nil)
{
    my Str:D $path = 'etc/systemd/sleep.conf';
    copy(%?RESOURCES{$path}, "/mnt/$path");
}

multi sub configure-systemd('swap' --> Nil)
{
    my Str:D $base-path = 'etc/systemd/swap.conf.d/';
    my Str:D $path = "$base-path/zram.conf";
    mkdir("/mnt/$base-path");
    copy(%?RESOURCES{$path}, "/mnt/$path");
}

multi sub configure-systemd('tmpfiles' --> Nil)
{
    # https://wiki.archlinux.org/index.php/Tmpfs#Disable_automatic_mount
    my Str:D $path = 'etc/tmpfiles.d/tmp.conf';
    copy(%?RESOURCES{$path}, "/mnt/$path");
}

multi sub configure-systemd('udev' --> Nil)
{
    my Str:D $base-path = 'etc/udev/rules.d';
    my Str:D $path = "$base-path/60-io-schedulers.rules";
    mkdir("/mnt/$base-path");
    copy(%?RESOURCES{$path}, "/mnt/$path");
}

method !configure-hidepid(--> Nil)
{
    my Str:D $base-path = 'etc/systemd/system/systemd-logind.service.d';
    my Str:D $path = "$base-path/hidepid.conf";
    mkdir("/mnt/$base-path");
    copy(%?RESOURCES{$path}, "/mnt/$path");

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
    my Str:D $base-path = 'etc/X11';
    my Str:D $path = "$base-path/Xwrapper.config";
    mkdir("/mnt/$base-path");
    copy(%?RESOURCES{$path}, "/mnt/$path");
}

multi sub configure-xorg('10-synaptics.conf' --> Nil)
{
    my Str:D $base-path = 'etc/X11/xorg.conf.d';
    my Str:D $path = "$base-path/10-synaptics.conf";
    mkdir("/mnt/$base-path");
    copy(%?RESOURCES{$path}, "/mnt/$path");
}

multi sub configure-xorg('99-security.conf' --> Nil)
{
    my Str:D $base-path = 'etc/X11/xorg.conf.d';
    my Str:D $path = "$base-path/99-security.conf";
    mkdir("/mnt/$base-path");
    copy(%?RESOURCES{$path}, "/mnt/$path");
}

method !enable-systemd-services(--> Nil)
{
    my Str:D @service = qw<
        dnscrypt-proxy.service
        nftables
        systemd-swap
    >;
    @service.map(-> Str:D $service {
        run(qqw<arch-chroot /mnt systemctl enable $service>);
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
    shell('umount -R /mnt');
    my VaultName:D $vault-name = $.config.vault-name;
    run(qqw<cryptsetup luksClose $vault-name>);
}


# -----------------------------------------------------------------------------
# helper functions
# -----------------------------------------------------------------------------

# sub arch-chroot-mkdir {{{

multi sub arch-chroot-mkdir(
    Str:D @dir,
    Str:D $user,
    Str:D $group,
    # permissions should be octal: https://doc.perl6.org/routine/chmod
    UInt:D $permissions
    --> Nil
)
{
    @dir.map(-> Str:D $dir {
        arch-chroot-mkdir($dir, $user, $group, $permissions)
    });
}

multi sub arch-chroot-mkdir(
    Str:D $dir,
    Str:D $user,
    Str:D $group,
    UInt:D $permissions
    --> Nil
)
{
    mkdir("/mnt/$dir", $permissions);
    run(qqw<arch-chroot /mnt chown $user:$group $dir>);
}

# end sub arch-chroot-mkdir }}}
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

    # wrap logfile lines at 72 characters
    Defaults loglinelen=72
    EOF
    my Str:D $replace = join("\n", $defaults, $slurp);
    spurt($file, $replace);
}

# --- end sudoers }}}
# --- dnscrypt-proxy.toml {{{

multi sub replace(
    'dnscrypt-proxy.toml'
    --> Nil
)
{
    my Str:D $file = '/mnt/etc/dnscrypt-proxy/dnscrypt-proxy.toml';
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
# --- locale.gen {{{

multi sub replace(
    'locale.gen',
    Locale:D $locale
    --> Nil
)
{
    my Str:D $file = '/mnt/etc/locale.gen';
    my Str:D @line = $file.IO.lines;
    my Str:D $locale-full = sprintf(Q{%s.UTF-8 UTF-8}, $locale);
    my UInt:D $index = @line.first(/^'#'$locale-full/, :k);
    @line[$index] = $locale-full;
    my Str:D $replace = @line.join("\n");
    spurt($file, $replace ~ "\n");
}

# --- end locale.gen }}}
# --- pacman.conf {{{

multi sub replace(
    'pacman.conf'
    --> Nil
)
{
    my Str:D $file = '/mnt/etc/pacman.conf';
    my Str:D @replace =
        $file.IO.lines
        # uncomment Color
        ==> replace('pacman.conf', 'Color')
        # uncomment TotalDownload
        ==> replace('pacman.conf', 'TotalDownload')
        # put ILoveCandy on the line below CheckSpace
        ==> replace('pacman.conf', 'ILoveCandy');
    @replace =
        @replace
        # uncomment multilib section on 64-bit machines
        ==> replace('pacman.conf', 'multilib') if $*KERNEL.bits == 64;
    my Str:D $replace = @replace.join("\n");
    spurt($file, $replace ~ "\n");
}

multi sub replace(
    'pacman.conf',
    Str:D $subject where 'Color',
    Str:D @line
    --> Array[Str:D]
)
{
    my UInt:D $index = @line.first(/^'#'\h*$subject/, :k);
    @line[$index] = $subject;
    @line;
}

multi sub replace(
    'pacman.conf',
    Str:D $subject where 'TotalDownload',
    Str:D @line
    --> Array[Str:D]
)
{
    my UInt:D $index = @line.first(/^'#'\h*$subject/, :k);
    @line[$index] = $subject;
    @line;
}

multi sub replace(
    'pacman.conf',
    Str:D $subject where 'ILoveCandy',
    Str:D @line
    --> Array[Str:D]
)
{
    my UInt:D $index = @line.first(/^CheckSpace/, :k);
    @line.splice($index + 1, 0, $subject);
    @line;
}

multi sub replace(
    'pacman.conf',
    Str:D $subject where 'multilib',
    Str:D @line
    --> Array[Str:D]
)
{
    # uncomment lines starting with C<[multilib]> up to but excluding blank line
    my UInt:D @index = @line.grep({ /^'#'\h*'['$subject']'/ ff^ /^\h*$/ }, :k);
    @index.race.map(-> UInt:D $index { @line[$index] .= subst(/^'#'/, '') });
    @line;
}

# --- end pacman.conf }}}
# --- mkinitcpio.conf {{{

multi sub replace(
    'mkinitcpio.conf',
    DiskType:D $disk-type,
    Graphics:D $graphics,
    Processor:D $processor
    --> Nil
)
{
    my Str:D $file = '/mnt/etc/mkinitcpio.conf';
    my Str:D @replace =
        $file.IO.lines
        ==> replace('mkinitcpio.conf', 'MODULES', $graphics, $processor)
        ==> replace('mkinitcpio.conf', 'HOOKS', $disk-type)
        ==> replace('mkinitcpio.conf', 'FILES')
        ==> replace('mkinitcpio.conf', 'BINARIES')
        ==> replace('mkinitcpio.conf', 'COMPRESSION');
    my Str:D $replace = @replace.join("\n");
    spurt($file, $replace ~ "\n");
}

multi sub replace(
    'mkinitcpio.conf',
    Str:D $subject where 'MODULES',
    Graphics:D $graphics,
    Processor:D $processor,
    Str:D @line
    --> Array[Str:D]
)
{
    # prepare modules
    my Str:D @modules;
    push(@modules, $processor eq 'INTEL' ?? 'crc32c-intel' !! 'crc32c');
    push(@modules, 'i915') if $graphics eq 'INTEL';
    push(@modules, 'nouveau') if $graphics eq 'NVIDIA';
    push(@modules, 'radeon') if $graphics eq 'RADEON';
    # for systemd-swap lz4
    push(@modules, |qw<lz4 lz4_compress>);
    # replace modules
    my UInt:D $index = @line.first(/^$subject/, :k);
    my Str:D $replace = sprintf(Q{%s=(%s)}, $subject, @modules.join(' '));
    @line[$index] = $replace;
    @line;
}

multi sub replace(
    'mkinitcpio.conf',
    Str:D $subject where 'HOOKS',
    DiskType:D $disk-type,
    Str:D @line
    --> Array[Str:D]
)
{
    # prepare hooks
    my Str:D @hooks = qw<
        base
        udev
        autodetect
        modconf
        keyboard
        keymap
        encrypt
        btrfs
        filesystems
        fsck
        shutdown
        usr
    >;
    $disk-type eq 'USB'
        ?? @hooks.splice(2, 0, 'block')
        !! @hooks.splice(4, 0, 'block');
    # replace hooks
    my UInt:D $index = @line.first(/^$subject/, :k);
    my Str:D $replace = sprintf(Q{%s=(%s)}, $subject, @hooks.join(' '));
    @line[$index] = $replace;
    @line;
}

multi sub replace(
    'mkinitcpio.conf',
    Str:D $subject where 'FILES',
    Str:D @line
    --> Array[Str:D]
)
{
    # prepare files
    my Str:D @files = '/etc/modprobe.d/modprobe.conf';
    # replace files
    my UInt:D $index = @line.first(/^$subject/, :k);
    my Str:D $replace = sprintf(Q{%s=(%s)}, $subject, @files.join(' '));
    @line[$index] = $replace;
    @line;
}

multi sub replace(
    'mkinitcpio.conf',
    Str:D $subject where 'BINARIES',
    Str:D @line
    --> Array[Str:D]
)
{
    # prepare binaries
    my Str:D @binaries = '/usr/bin/btrfs';
    # replace binaries
    my UInt:D $index = @line.first(/^$subject/, :k);
    my Str:D $replace = sprintf(Q{%s=(%s)}, $subject, @binaries.join(' '));
    @line[$index] = $replace;
    @line;
}

multi sub replace(
    'mkinitcpio.conf',
    Str:D $subject where 'COMPRESSION',
    Str:D @line
    --> Array[Str:D]
)
{
    my Str:D $algorithm = 'lz4';
    my Str:D $compression = sprintf(Q{%s="%s"}, $subject, $algorithm);
    my UInt:D $index = @line.first(/^'#'$compression/, :k);
    @line[$index] = $compression;
    @line;
}

# --- end mkinitcpio.conf }}}
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
        ==> replace('grub', 'GRUB_CMDLINE_LINUX', |@opts)
        ==> replace('grub', 'GRUB_ENABLE_CRYPTODISK');
    my Str:D $replace = @replace.join("\n");
    spurt($file, $replace ~ "\n");
}

multi sub replace(
    'grub',
    Str:D $subject where 'GRUB_CMDLINE_LINUX',
    Graphics:D $graphics,
    Str:D $partition,
    VaultName:D $vault-name,
    Str:D @line
    --> Array[Str:D]
)
{
    # prepare GRUB_CMDLINE_LINUX
    my Str:D $partition-vault = sprintf(Q{%s3}, $partition);
    my Str:D $vault-uuid = qqx<blkid -s UUID -o value $partition-vault>.trim;
    my Str:D $grub-cmdline-linux =
        sprintf(
            Q{cryptdevice=/dev/disk/by-uuid/%s:%s rootflags=subvol=@},
            $vault-uuid,
            $vault-name
        );
    $grub-cmdline-linux ~= ' radeon.dpm=1' if $graphics eq 'RADEON';
    # replace GRUB_CMDLINE_LINUX
    my UInt:D $index = @line.first(/^$subject'='/, :k);
    my Str:D $replace = sprintf(Q{%s="%s"}, $subject, $grub-cmdline-linux);
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
    my UInt:D $index = @line.first(/^'#'$subject/, :k);
    my Str:D $replace = sprintf(Q{%s=y}, $subject);
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
