use v6;
use Void::XBPS;
use Voidvault;
use Voidvault::Config;
use Voidvault::Config::Base;
use Voidvault::Constants;
use Voidvault::Types;
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

# vim: set filetype=raku foldmethod=marker foldlevel=0 nowrap:
