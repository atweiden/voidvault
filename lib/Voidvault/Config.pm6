use v6;
use Voidvault::Config::Utils;
use Voidvault::Constants;
use Voidvault::Types;
use Voidvault::Utils;
unit role Voidvault::Config;


# -----------------------------------------------------------------------------
# attributes
# -----------------------------------------------------------------------------

# - attributes appear in specific order for prompting user
# - defaults are geared towards desktop installation

# path within which to mount system for bootstrap
has AbsolutePath:D $.chroot-dir =
    ?%*ENV<VOIDVAULT_CHROOT_DIR>
        ?? gen-absolute-path(%*ENV<VOIDVAULT_CHROOT_DIR>)
        !! '/mnt';

# location of void package repository (prioritized)
has Str:D @.repository =
    ?%*ENV<VOIDVAULT_REPOSITORY>
        ?? %*ENV<VOIDVAULT_REPOSITORY>.split(' ')
        !! Empty;

# only honor repository specified in C<@.repository>
has Bool:D $.ignore-conf-repos =
    ?%*ENV<VOIDVAULT_IGNORE_CONF_REPOS>;

# additional packages to install
has Str:D @.package =
    ?%*ENV<VOIDVAULT_PACKAGES>
        ?? %*ENV<VOIDVAULT_PACKAGES>.split(' ')
        !! Empty;

# name for admin user (default: live)
has UserName:D $.user-name-admin =
    %*ENV<VOIDVAULT_ADMIN_NAME>
        ?? gen-user-name(%*ENV<VOIDVAULT_ADMIN_NAME>)
        !! prompt-name(:user, :admin);

# sha512 password hash for admin user
has Str:D $.user-pass-hash-admin =
    %*ENV<VOIDVAULT_ADMIN_PASS_HASH>
        ?? %*ENV<VOIDVAULT_ADMIN_PASS_HASH>
        !! %*ENV<VOIDVAULT_ADMIN_PASS>
            ?? Voidvault::Utils.gen-pass-hash(%*ENV<VOIDVAULT_ADMIN_PASS>)
            !! Voidvault::Utils.prompt-pass-hash($!user-name-admin);

# name for guest user (default: guest)
has UserName:D $.user-name-guest =
    %*ENV<VOIDVAULT_GUEST_NAME>
        ?? gen-user-name(%*ENV<VOIDVAULT_GUEST_NAME>)
        !! prompt-name(:user, :guest);

# sha512 password hash for guest user
has Str:D $.user-pass-hash-guest =
    %*ENV<VOIDVAULT_GUEST_PASS_HASH>
        ?? %*ENV<VOIDVAULT_GUEST_PASS_HASH>
        !! %*ENV<VOIDVAULT_GUEST_PASS>
            ?? Voidvault::Utils.gen-pass-hash(%*ENV<VOIDVAULT_GUEST_PASS>)
            !! Voidvault::Utils.prompt-pass-hash($!user-name-guest);

# name for sftp user (default: variable)
has UserName:D $.user-name-sftp =
    %*ENV<VOIDVAULT_SFTP_NAME>
        ?? gen-user-name(%*ENV<VOIDVAULT_SFTP_NAME>)
        !! prompt-name(:user, :sftp);

# sha512 password hash for sftp user
has Str:D $.user-pass-hash-sftp =
    %*ENV<VOIDVAULT_SFTP_PASS_HASH>
        ?? %*ENV<VOIDVAULT_SFTP_PASS_HASH>
        !! %*ENV<VOIDVAULT_SFTP_PASS>
            ?? Voidvault::Utils.gen-pass-hash(%*ENV<VOIDVAULT_SFTP_PASS>)
            !! Voidvault::Utils.prompt-pass-hash($!user-name-sftp);

# sha512 password hash for root user
has Str:D $.user-pass-hash-root =
    %*ENV<VOIDVAULT_ROOT_PASS_HASH>
        ?? %*ENV<VOIDVAULT_ROOT_PASS_HASH>
        !! %*ENV<VOIDVAULT_ROOT_PASS>
            ?? Voidvault::Utils.gen-pass-hash(%*ENV<VOIDVAULT_ROOT_PASS>)
            !! Voidvault::Utils.prompt-pass-hash('root');

# name for grub user (default: grub)
has UserName:D $.user-name-grub =
    %*ENV<VOIDVAULT_GRUB_NAME>
        ?? gen-user-name(%*ENV<VOIDVAULT_GRUB_NAME>)
        !! prompt-name(:user, :grub);

# pbkdf2 password hash for grub user
has Str:D $.user-pass-hash-grub =
    %*ENV<VOIDVAULT_GRUB_PASS_HASH>
        ?? %*ENV<VOIDVAULT_GRUB_PASS_HASH>
        !! %*ENV<VOIDVAULT_GRUB_PASS>
            ?? Voidvault::Utils.gen-pass-hash(%*ENV<VOIDVAULT_GRUB_PASS>, :grub)
            !! Voidvault::Utils.prompt-pass-hash(
                $!user-name-grub,
                :grub,
                :@!repository,
                :$!ignore-conf-repos
            );

# name for LUKS encrypted volume (default: vault)
has VaultName:D $.vault-name =
    %*ENV<VOIDVAULT_VAULT_NAME>
        ?? gen-vault-name(%*ENV<VOIDVAULT_VAULT_NAME>)
        !! prompt-name(:vault);

# password for LUKS encrypted volume
has VaultPass $.vault-pass =
    %*ENV<VOIDVAULT_VAULT_PASS>
        ?? gen-vault-pass(%*ENV<VOIDVAULT_VAULT_PASS>)
        !! Nil;

# intended path to LUKS encrypted volume key on bootstrapped system
has VaultKey:D $.vault-key =
    ?%*ENV<VOIDVAULT_VAULT_KEY>
        ?? gen-vault-key(%*ENV<VOIDVAULT_VAULT_KEY>)
        !! sprintf(
            Q{%s/keys/root.key},
            $Voidvault::Constants::SECRET-PREFIX-VAULT
        );

# name for host (default: vault)
has HostName:D $.host-name =
    %*ENV<VOIDVAULT_HOSTNAME>
        ?? gen-host-name(%*ENV<VOIDVAULT_HOSTNAME>)
        !! prompt-name(:host);

# target block device path
has Str:D $.device =
    %*ENV<VOIDVAULT_DEVICE>
        || prompt-device(Voidvault::Utils.ls-devices);

# type of processor (default: other)
has Processor:D $.processor =
    %*ENV<VOIDVAULT_PROCESSOR>
        ?? gen-processor(%*ENV<VOIDVAULT_PROCESSOR>)
        !! prompt-processor();

# type of graphics card (default: intel)
has Graphics:D $.graphics =
    %*ENV<VOIDVAULT_GRAPHICS>
        ?? gen-graphics(%*ENV<VOIDVAULT_GRAPHICS>)
        !! prompt-graphics();

# type of hard drive (default: ssd)
has DiskType:D $.disk-type =
    %*ENV<VOIDVAULT_DISK_TYPE>
        ?? gen-disk-type(%*ENV<VOIDVAULT_DISK_TYPE>)
        !! prompt-disk-type();

# locale (default: en_US)
has Locale:D $.locale =
    %*ENV<VOIDVAULT_LOCALE>
        ?? gen-locale(%*ENV<VOIDVAULT_LOCALE>)
        !! prompt-locale();

# keymap (default: us)
has Keymap:D $.keymap =
    %*ENV<VOIDVAULT_KEYMAP>
        ?? gen-keymap(%*ENV<VOIDVAULT_KEYMAP>)
        !! prompt-keymap();

# timezone (default: America/Los_Angeles)
has Timezone:D $.timezone =
    %*ENV<VOIDVAULT_TIMEZONE>
        ?? gen-timezone(%*ENV<VOIDVAULT_TIMEZONE>)
        !! prompt-timezone();

# augment
has Bool:D $.augment =
    ?%*ENV<VOIDVAULT_AUGMENT>;

# disable ipv6
has Bool:D $.disable-ipv6 =
    ?%*ENV<VOIDVAULT_DISABLE_IPV6>;

# enable serial
has Bool:D $.enable-serial-console =
    ?%*ENV<VOIDVAULT_ENABLE_SERIAL_CONSOLE>;


# -----------------------------------------------------------------------------
# instantiation
# -----------------------------------------------------------------------------

# proto submethod to facilitate extending through role composition
proto submethod TWEAK(--> Nil)
{
    # ensure C<$!chroot-dir> exists as rw dir or create it
    ensure-chroot-dir($!chroot-dir);

    # ensure user names are unique
    ensure-unique-user-names(
        :$!user-name-admin,
        :$!user-name-guest,
        :$!user-name-sftp
    );

    # in case downstream user of C<Voidvault::Config> needs more tweaking
    {*}
}

# proto submethod to facilitate extending through role composition
proto submethod BUILD(
    Str :$admin-name,
    Str :$admin-pass,
    Str :$admin-pass-hash,
    Bool :$augment,
    Str :$chroot-dir,
    Str :$device,
    Bool :$disable-ipv6,
    Str :$disk-type,
    Bool :$enable-serial-console,
    Str :$graphics,
    Str :$grub-name,
    Str :$grub-pass,
    Str :$grub-pass-hash,
    Str :$guest-name,
    Str :$guest-pass,
    Str :$guest-pass-hash,
    Str :$hostname,
    Bool :$ignore-conf-repos,
    Str :$keymap,
    Str :$locale,
    Str :$packages,
    Str :$processor,
    :@repository,
    Str :$root-pass,
    Str :$root-pass-hash,
    Str :$sftp-name,
    Str :$sftp-pass,
    Str :$sftp-pass-hash,
    Str :$timezone,
    Str :$vault-name,
    Str :$vault-pass,
    Str :$vault-key,
    *%
    --> Nil
)
{
    $!augment = $augment
        if $augment;
    $!chroot-dir = gen-absolute-path($chroot-dir)
        if $chroot-dir;
    $!device = $device
        if $device;
    $!disable-ipv6 = $disable-ipv6
        if $disable-ipv6;
    $!disk-type = gen-disk-type($disk-type)
        if $disk-type;
    $!enable-serial-console = $enable-serial-console
        if $enable-serial-console;
    $!graphics = gen-graphics($graphics)
        if $graphics;
    $!host-name = gen-host-name($hostname)
        if $hostname;
    $!ignore-conf-repos = $ignore-conf-repos
        if $ignore-conf-repos;
    $!keymap = gen-keymap($keymap)
        if $keymap;
    $!locale = gen-locale($locale)
        if $locale;
    @!package = $packages.split(' ')
        if $packages;
    $!processor = gen-processor($processor)
        if $processor;
    @!repository = @repository
        if so(@repository.all);
    $!timezone = gen-timezone($timezone)
        if $timezone;
    $!user-name-admin = gen-user-name($admin-name)
        if $admin-name;
    $!user-name-grub = gen-user-name($grub-name)
        if $grub-name;
    $!user-name-guest = gen-user-name($guest-name)
        if $guest-name;
    $!user-name-sftp = gen-user-name($sftp-name)
        if $sftp-name;
    $!user-pass-hash-admin = Voidvault::Utils.gen-pass-hash($admin-pass)
        if $admin-pass;
    $!user-pass-hash-admin = $admin-pass-hash
        if $admin-pass-hash;
    $!user-pass-hash-grub =
        Voidvault::Utils.gen-pass-hash($grub-pass, :grub) if $grub-pass;
    $!user-pass-hash-grub = $grub-pass-hash
        if $grub-pass-hash;
    $!user-pass-hash-guest = Voidvault::Utils.gen-pass-hash($guest-pass)
        if $guest-pass;
    $!user-pass-hash-guest = $guest-pass-hash
        if $guest-pass-hash;
    $!user-pass-hash-root = Voidvault::Utils.gen-pass-hash($root-pass)
        if $root-pass;
    $!user-pass-hash-root = $root-pass-hash
        if $root-pass-hash;
    $!user-pass-hash-sftp = Voidvault::Utils.gen-pass-hash($sftp-pass)
        if $sftp-pass;
    $!user-pass-hash-sftp = $sftp-pass-hash
        if $sftp-pass-hash;
    $!vault-name = gen-vault-name($vault-name)
        if $vault-name;
    $!vault-pass = gen-vault-pass($vault-pass)
        if $vault-pass;
    $!vault-key = gen-vault-key($vault-key)
        if $vault-key;

    # in case downstream user of C<Voidvault::Config> needs more building
    {*}
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
