use v6;
unit module Voidvault::Constants;

constant $FILE-CRYPTTAB = '/etc/crypttab';
constant $FILE-DHCPCD = '/etc/dhcpcd.conf';
constant $FILE-DNSCRYPT-PROXY = '/etc/dnscrypt-proxy.toml';
constant $FILE-DRACUT = '/etc/dracut.conf.d';
constant $FILE-FSTAB = '/etc/fstab';
constant $FILE-GRUB = '/etc/default/grub';
constant $FILE-HOSTS = '/etc/hosts';
constant $FILE-LOCALES = '/etc/default/libc-locales';
constant $FILE-OPENRESOLV = '/etc/resolvconf.conf';
constant $FILE-OPENSSH-DAEMON = '/etc/ssh/sshd_config';
constant $FILE-OPENSSH-MODULI = '/etc/ssh/moduli';
constant $FILE-PAM = '/etc/pam.d/passwd';
constant $FILE-RC = '/etc/rc.conf';
constant $FILE-SECURETTY = '/etc/securetty';
constant $FILE-SUDOERS = '/etc/sudoers';
constant $FILE-SYSCTL = '/etc/sysctl.d/99-sysctl.conf';

# dependencies needed prior to config instantiation
my constant @DEPENDENCY-PRE-CONFIG = qw<
    expect
    grub
>;

# dependencies needed prior to voidstrap
my constant @DEPENDENCY-PRE-VOIDSTRAP = qw<
    btrfs-progs
    coreutils
    cryptsetup
    dialog
    dosfstools
    e2fsprogs
    efibootmgr
    gptfdisk
    kbd
    kmod
    openssl
    procps-ng
    tzdata
    util-linux
    xbps
>;

constant @DEPENDENCY = |@DEPENDENCY-PRE-CONFIG, |@DEPENDENCY-PRE-VOIDSTRAP;

constant @CORE-PACKAGE = 'base-minimal';

# base packages - void's C<base-minimal> with light additions
# duplicates C<base-minimal>'s C<depends> for thoroughness
constant @BASE-PACKAGE = qw<
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

# runit services to enable
constant @SERVICE = qw<
    dnscrypt-proxy
    nanoklogd
    nftables
    socklog-unix
>;

constant $EFI-DIR = '/boot/efi';

# libcrypt crypt encryption rounds
constant $CRYPT-ROUNDS = 700_000;

# libcrypt crypt encryption scheme
constant $CRYPT-SCHEME = 'SHA512';

# grub-mkpasswd-pbkdf2 iterations
constant $PBKDF2-ITERATIONS = 25_000;

# grub-mkpasswd-pbkdf2 length of generated hash
constant $PBKDF2-LENGTH-HASH = 100;

# grub-mkpasswd-pbkdf2 length of salt
constant $PBKDF2-LENGTH-SALT = 100;

# for sgdisk
constant $GDISK-SIZE-BIOS = '2M';
constant $GDISK-SIZE-EFI = '550M';
constant $GDISK-SIZE-BOOT = '1024M';
constant $GDISK-TYPECODE-BIOS = 'EF02';
constant $GDISK-TYPECODE-EFI = 'EF00';
constant $GDISK-TYPECODE-LINUX = '8300';

# for C<--enable-serial-console>
constant $VIRTUAL-CONSOLE = 'tty0';
constant $SERIAL-CONSOLE = 'ttyS0';
constant $GRUB-SERIAL-PORT-UNIT = '0';
constant $GRUB-SERIAL-PORT-BAUD-RATE = '115200';
constant $GRUB-SERIAL-PORT-PARITY = False;
constant %GRUB-SERIAL-PORT-PARITY =
    ::(True) => %(
        GRUB_SERIAL_COMMAND => 'odd',
        GRUB_CMDLINE_LINUX_DEFAULT => 'o'
    ),
    ::(False) => %(
        GRUB_SERIAL_COMMAND => 'no',
        GRUB_CMDLINE_LINUX_DEFAULT => 'n'
    );
constant $GRUB-SERIAL-PORT-STOP-BITS = '1';
constant $GRUB-SERIAL-PORT-WORD-LENGTH-BITS = '8';

# vim: set filetype=raku foldmethod=marker foldlevel=0:
