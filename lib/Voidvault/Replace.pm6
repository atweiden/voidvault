use v6;
use Voidvault::Constants;
use Voidvault::Replace::Crypttab;
use Voidvault::Replace::Dhcpcd;
use Voidvault::Replace::DnscryptProxy;
use Voidvault::Replace::Dracut;
use Voidvault::Replace::EFI::Startup;
use Voidvault::Replace::Fstab;
use Voidvault::Replace::Grub::Default;
use Voidvault::Replace::Grub::Linux;
use Voidvault::Replace::Hosts;
use Voidvault::Replace::Locales;
use Voidvault::Replace::OpenResolv;
use Voidvault::Replace::OpenSSH::Daemon;
use Voidvault::Replace::OpenSSH::Moduli;
use Voidvault::Replace::PAM;
use Voidvault::Replace::RC;
use Voidvault::Replace::Securetty;
use Voidvault::Replace::Sudoers;
use Voidvault::Replace::Sysctl;

role Voidvault::Replace[Str:D $ where $Voidvault::Constants::FILE-CRYPTTAB]
{
    also does Voidvault::Replace::Crypttab;
}

role Voidvault::Replace[Str:D $ where $Voidvault::Constants::FILE-DHCPCD]
{
    also does Voidvault::Replace::Dhcpcd;
}

role Voidvault::Replace[Str:D $ where $Voidvault::Constants::FILE-DNSCRYPT-PROXY]
{
    also does Voidvault::Replace::DnscryptProxy;
}

role Voidvault::Replace[Str:D $ where $Voidvault::Constants::FILE-DRACUT]
{
    also does Voidvault::Replace::Dracut;
}

role Voidvault::Replace[Str:D $ where $Voidvault::Constants::FILE-EFI-STARTUP]
{
    also does Voidvault::Replace::EFI::Startup;
}

role Voidvault::Replace[Str:D $ where $Voidvault::Constants::FILE-FSTAB]
{
    also does Voidvault::Replace::Fstab;
}

role Voidvault::Replace[Str:D $ where $Voidvault::Constants::FILE-GRUB-DEFAULT]
{
    also does Voidvault::Replace::Grub::Default;
}

role Voidvault::Replace[Str:D $ where $Voidvault::Constants::FILE-GRUB-LINUX]
{
    also does Voidvault::Replace::Grub::Linux;
}

role Voidvault::Replace[Str:D $ where $Voidvault::Constants::FILE-HOSTS]
{
    also does Voidvault::Replace::Hosts;
}

role Voidvault::Replace[Str:D $ where $Voidvault::Constants::FILE-LOCALES]
{
    also does Voidvault::Replace::Locales;
}

role Voidvault::Replace[Str:D $ where $Voidvault::Constants::FILE-OPENRESOLV]
{
    also does Voidvault::Replace::OpenResolv;
}

role Voidvault::Replace[Str:D $ where $Voidvault::Constants::FILE-OPENSSH-DAEMON]
{
    also does Voidvault::Replace::OpenSSH::Daemon;
}

role Voidvault::Replace[Str:D $ where $Voidvault::Constants::FILE-OPENSSH-MODULI]
{
    also does Voidvault::Replace::OpenSSH::Moduli;
}

role Voidvault::Replace[Str:D $ where $Voidvault::Constants::FILE-PAM]
{
    also does Voidvault::Replace::PAM;
}

role Voidvault::Replace[Str:D $ where $Voidvault::Constants::FILE-RC]
{
    also does Voidvault::Replace::RC;
}

role Voidvault::Replace[Str:D $ where $Voidvault::Constants::FILE-SECURETTY]
{
    also does Voidvault::Replace::Securetty;
}

role Voidvault::Replace[Str:D $ where $Voidvault::Constants::FILE-SUDOERS]
{
    also does Voidvault::Replace::Sudoers;
}

role Voidvault::Replace[Str:D $ where $Voidvault::Constants::FILE-SYSCTL]
{
    also does Voidvault::Replace::Sysctl;
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
