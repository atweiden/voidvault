use v6;
use Voidvault::Replace::Crypttab;
use Voidvault::Replace::Dhcpcd;
use Voidvault::Replace::DnscryptProxy;
use Voidvault::Replace::Dracut;
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

constant $FILE-CRYPTTAB = $Voidvault::Replace::Crypttab::FILE;
constant $FILE-DHCPCD = $Voidvault::Replace::Dhcpcd::FILE;
constant $FILE-DNSCRYPT-PROXY = $Voidvault::Replace::DnscryptProxy::FILE;
constant $FILE-DRACUT = $Voidvault::Replace::Dracut::FILE;
constant $FILE-FSTAB = $Voidvault::Replace::Fstab::FILE;
constant $FILE-GRUB-DEFAULT = $Voidvault::Replace::Grub::Default::FILE;
constant $FILE-GRUB-LINUX = $Voidvault::Replace::Grub::Linux::FILE;
constant $FILE-HOSTS = $Voidvault::Replace::Hosts::FILE;
constant $FILE-LOCALES = $Voidvault::Replace::Locales::FILE;
constant $FILE-OPENRESOLV = $Voidvault::Replace::OpenResolv::FILE;
constant $FILE-OPENSSH-DAEMON = $Voidvault::Replace::OpenSSH::Daemon::FILE;
constant $FILE-OPENSSH-MODULI = $Voidvault::Replace::OpenSSH::Moduli::FILE;
constant $FILE-PAM = $Voidvault::Replace::PAM::FILE;
constant $FILE-RC = $Voidvault::Replace::RC::FILE;
constant $FILE-SECURETTY = $Voidvault::Replace::Securetty::FILE;
constant $FILE-SUDOERS = $Voidvault::Replace::Sudoers::FILE;
constant $FILE-SYSCTL = $Voidvault::Replace::Sysctl::FILE;

role Voidvault::Replace[Str:D $ where $FILE-CRYPTTAB]
{
    also does Voidvault::Replace::Crypttab;
}

role Voidvault::Replace[Str:D $ where $FILE-DHCPCD]
{
    also does Voidvault::Replace::Dhcpcd;
}

role Voidvault::Replace[Str:D $ where $FILE-DNSCRYPT-PROXY]
{
    also does Voidvault::Replace::DnscryptProxy;
}

role Voidvault::Replace[Str:D $ where $FILE-DRACUT]
{
    also does Voidvault::Replace::Dracut;
}

role Voidvault::Replace[Str:D $ where $FILE-FSTAB]
{
    also does Voidvault::Replace::Fstab;
}

role Voidvault::Replace[Str:D $ where $FILE-GRUB-DEFAULT]
{
    also does Voidvault::Replace::Grub::Default;
}

role Voidvault::Replace[Str:D $ where $FILE-GRUB-LINUX]
{
    also does Voidvault::Replace::Grub::Linux;
}

role Voidvault::Replace[Str:D $ where $FILE-HOSTS]
{
    also does Voidvault::Replace::Hosts;
}

role Voidvault::Replace[Str:D $ where $FILE-LOCALES]
{
    also does Voidvault::Replace::Locales;
}

role Voidvault::Replace[Str:D $ where $FILE-OPENRESOLV]
{
    also does Voidvault::Replace::OpenResolv;
}

role Voidvault::Replace[Str:D $ where $FILE-OPENSSH-DAEMON]
{
    also does Voidvault::Replace::OpenSSH::Daemon;
}

role Voidvault::Replace[Str:D $ where $FILE-OpenSSH-MODULI]
{
    also does Voidvault::Replace::OpenSSH::Moduli;
}

role Voidvault::Replace[Str:D $ where $FILE-PAM]
{
    also does Voidvault::Replace::PAM;
}

role Voidvault::Replace[Str:D $ where $FILE-RC]
{
    also does Voidvault::Replace::RC;
}

role Voidvault::Replace[Str:D $ where $FILE-SECURETTY]
{
    also does Voidvault::Replace::Securetty;
}

role Voidvault::Replace[Str:D $ where $FILE-SUDOERS]
{
    also does Voidvault::Replace::Sudoers;
}

role Voidvault::Replace[Str:D $ where $FILE-SYSCTL]
{
    also does Voidvault::Replace::Sysctl;
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
