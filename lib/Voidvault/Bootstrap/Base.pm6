use v6;
use Voidvault::Bootstrap;
use Voidvault::Config::Base;
use Voidvault::Constants;
use Voidvault::Replace;
unit class Voidvault::Bootstrap::Base;
also does Voidvault::Bootstrap;
also does Voidvault::Replace[$Voidvault::Constants::FILE-CRYPTTAB];
also does Voidvault::Replace[$Voidvault::Constants::FILE-DHCPCD];
also does Voidvault::Replace[$Voidvault::Constants::FILE-DNSCRYPT-PROXY];
also does Voidvault::Replace[$Voidvault::Constants::FILE-DRACUT];
also does Voidvault::Replace[$Voidvault::Constants::FILE-FSTAB];
also does Voidvault::Replace[$Voidvault::Constants::FILE-GRUB];
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

has Voidvault::Config::Base:D $.config is required;

# vim: set filetype=raku foldmethod=marker foldlevel=0 nowrap:
