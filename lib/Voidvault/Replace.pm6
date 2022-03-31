use v6;
use Voidvault::Replace::Crypttab;
use Voidvault::Replace::DNSCryptProxy;
use Voidvault::Replace::Dhcpcd;
use Voidvault::Replace::Dracut;
use Voidvault::Replace::FSTab;
use Voidvault::Replace::GRUB::Default;
use Voidvault::Replace::GRUB::Linux;
use Voidvault::Replace::Hosts;
use Voidvault::Replace::Locales;
use Voidvault::Replace::OpenResolv;
use Voidvault::Replace::PAM;
use Voidvault::Replace::RC;
use Voidvault::Replace::SSH::Moduli;
use Voidvault::Replace::SSH::SSHD;
use Voidvault::Replace::SecureTTY;
use Voidvault::Replace::Sudoers;
use Voidvault::Replace::Sysctl;

my constant $FILE-CRYPTTAB = $Voidvault::Replace::Crypttab::FILE;
my constant $FILE-DNSCRYPT-PROXY = $Voidvault::Replace::DNSCryptProxy::FILE;
my constant $FILE-DHCPCD = $Voidvault::Replace::Dhcpcd::FILE;
my constant $FILE-DRACUT = $Voidvault::Replace::Dracut::FILE;
my constant $FILE-FSTAB = $Voidvault::Replace::FSTab::FILE;
my constant $FILE-GRUB-DEFAULT = $Voidvault::Replace::GRUB::Default::FILE;
my constant $FILE-GRUB-LINUX = $Voidvault::Replace::GRUB::Linux::FILE;
my constant $FILE-HOSTS = $Voidvault::Replace::Hosts::FILE;
my constant $FILE-LOCALES = $Voidvault::Replace::Locales::FILE;
my constant $FILE-OPENRESOLV = $Voidvault::Replace::OpenResolv::FILE;
my constant $FILE-PAM = $Voidvault::Replace::PAM::FILE;
my constant $FILE-RC = $Voidvault::Replace::RC::FILE;
my constant $FILE-SSH-MODULI = $Voidvault::Replace::SSH::Moduli::FILE;
my constant $FILE-SSH-SSHD = $Voidvault::Replace::SSH::SSHD::FILE;
my constant $FILE-SECURETTY = $Voidvault::Replace::SecureTTY::FILE;
my constant $FILE-SUDOERS = $Voidvault::Replace::Sudoers::FILE;
my constant $FILE-SYSCTL = $Voidvault::Replace::Sysctl::FILE;

role Voidvault::Replace[Str:D $ where $FILE-CRYPTTAB]
{
    also does Voidvault::Replace::Crypttab;
}

role Voidvault::Replace[Str:D $ where $FILE-DNSCRYPT-PROXY]
{
    also does Voidvault::Replace::DNSCryptProxy;
}

role Voidvault::Replace[Str:D $ where $FILE-DHCPCD]
{
    also does Voidvault::Replace::Dhcpcd;
}

role Voidvault::Replace[Str:D $ where $FILE-DRACUT]
{
    also does Voidvault::Replace::Dracut;
}

role Voidvault::Replace[Str:D $ where $FILE-FSTAB]
{
    also does Voidvault::Replace::FSTab;
}

role Voidvault::Replace[Str:D $ where $FILE-GRUB-DEFAULT]
{
    also does Voidvault::Replace::GRUB::Default;
}

role Voidvault::Replace[Str:D $ where $FILE-GRUB-LINUX]
{
    also does Voidvault::Replace::GRUB::Linux;
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

role Voidvault::Replace[Str:D $ where $FILE-PAM]
{
    also does Voidvault::Replace::PAM;
}

role Voidvault::Replace[Str:D $ where $FILE-RC]
{
    also does Voidvault::Replace::RC;
}

role Voidvault::Replace[Str:D $ where $FILE-SSH-MODULI]
{
    also does Voidvault::Replace::SSH::Moduli;
}

role Voidvault::Replace[Str:D $ where $FILE-SSH-SSHD]
{
    also does Voidvault::Replace::SSH::SSHD;
}

role Voidvault::Replace[Str:D $ where $FILE-SECURETTY]
{
    also does Voidvault::Replace::SecureTTY;
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
