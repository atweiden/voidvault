Changes
=======

New in 2.0.0
------------

### Additions

#### Modes

The v2 release series introduces three separate bootstrap modes:

*Base Mode*

```bash
voidvault new
# or, equivalently:
voidvault new base
```

Makes LUKS1 volume with encrypted `/boot`.

The default bootstrap mode. Identical to `voidvault new` in v1 release
series.

*1FA Mode*

```bash
voidvault new 1fa
```

Partitions disk with separate root and boot partitions.

Makes LUKS1 volume for boot partition ("The Bootvault").

Makes LUKS2 volume with detached header for root partition ("The Vault").

Stores Vault detached header, randomized keyfile and kernel in Bootvault.

Creates root filesystem in Vault.

*2FA Mode*

```bash
voidvault new 2fa
```

Similar to 1FA Mode, but requires two separate devices: one for Bootvault,
one for Vault.

Booting is only possible when both devices are present.

#### Security settings

A limited number of security settings have been adopted
from [Whonix][Whonix/security-misc], [Tails][Tails
kernel hardening] and [Plague][whichdoc/plagueos] (see:
https://madaidans-insecurities.github.io/guides/linux-hardening.html).

- Unprivilege RDRAND
- Zero memory at allocation and free time
- Enable page allocator freelist randomization
- Randomize kernel stack offset on syscall entry
- Disable vsyscalls
- Restrict access to debugfs
- Enable all mitigations for spectre variant 2
- Disable speculative store bypass
- Disable TSX, enable all mitigations for TSX Async Abort vulnerability,
  and disable SMT
- Enable all mitigations for MDS vulnerability and disable SMT
- Enable all mitigations for L1TF vulnerability, and disable SMT and
  L1D flush runtime control
- Force disable SMT
- Mark all huge pages in EPT non-executable
- Always perform cache flush when entering guest vm
- Enable IOMMU
- Force IOMMU TLB invalidation
- Disable busmaster bit on all PCI bridges
- Disable core dumps
- Blacklist more kernel modules
- Add [protective mount options][protective mount options]

#### New cmdline options

*Specify custom chroot directory*

Use the newly added `--chroot-dir` cmdline option to specify a custom
chroot directory.

*Specify custom `cryptsetup` options*

Use these new cmdline options to configure `cryptsetup luksFormat`:

All modes

- `--vault-cipher`
- `--vault-hash`
- `--vault-iter-time`
- `--vault-key-size`
- `--vault-offset`
- `--vault-sector-size`

1FA/2FA mode only

- `--bootvault-cipher`
- `--bootvault-hash`
- `--bootvault-iter-time`
- `--bootvault-key-size`
- `--bootvault-offset`
- `--bootvault-sector-size`

Warn: bootstrap will fail if user input is invalid for `cryptsetup`.

Note: `--{,boot}vault-offset` takes human-readable offsets, which
differs from the `cryptsetup` CLI at present. Human-readable
offsets are translated to sector counts as appropriate (see:
[bin/gen-cryptsetup-luks-offset](bin/gen-cryptsetup-luks-offset)).

#### New CLI utility: `gen-cryptsetup-luks-offset`

[bin/gen-cryptsetup-luks-offset](bin/gen-cryptsetup-luks-offset) has
been added.

```
Usage:
  gen-cryptsetup-luks-offset <offset>
  gen-cryptsetup-luks-offset 5G
  cryptsetup --offset $(gen-cryptsetup-luks-offset 5GiB) luksFormat /dev/sda

Options:
  -h, --help
    Print this help message

Offset
  K,KiB     kibibytes
  M,MiB     mebibytes
  G,GiB     gibibtes
  T,TiB     tebibytes
```

### Changes

- The previous `--partition` cmdline option has become `--device`
- The previous `ls partitions` command has become `ls devices`
- Exit with a helpful error message upon attempting to run `ls devices`,
  `ls keymaps`, `ls locales`, or `ls timezones` with missing requirements
- To facilitate allowing any user to boot any given GRUB
  menu entry while only allowing the "GRUB superuser" to
  *edit* menu entries or access the GRUB command console,
  we now append ` --unrestricted` to the `CLASS` variable
  in `/etc/grub.d/10_linux` directly. This differs from the [previous
  approach](https://github.com/atweiden/voidvault/blob/7b159fa237ae4d7e612e6733a84b07cbf84d76b6/lib/Voidvault/Bootstrap.pm6#L2584)
  of globally replacing `${CLASS}` with `--unrestricted ${CLASS}`
  in `/etc/grub.d/10_linux`, but [accomplishes the same thing more
  simply](https://wiki.archlinux.org/title/GRUB/Tips_and_tricks#Password_protection_of_GRUB_edit_and_console_options_only)
- Make alterations to bootstrap ordering, e.g. perform adding randomized
  key to LUKS volume step earlier during bootstrap
- [Change default repo](https://github.com/void-linux/void-packages/commit/3a5377265a48f07e8d8f3073a7d73a5a067a8e1b)
  from alpha.de.repo.voidlinux.org to repo-default.voidlinux.org

### Fixes

- `voidvault --clean disable-cow` now recursively copies in files
  from original directory where CoW was enabled using latest [ArchWiki
  recommendations](https://wiki.archlinux.org/title/Btrfs#Disabling_CoW)

### Internal

- Heavily refactor codebase


[protective mount options]: https://www.softpanorama.org/Commercial_linuxes/Security/protective_partitioning_of_the_system.shtml
[Tails kernel hardening]: https://tails.boum.org/contribute/design/kernel_hardening/
[whichdoc/plagueos]: https://git.arrr.cloud/whichdoc/plagueos
[Whonix/security-misc]: https://github.com/Whonix/security-misc
