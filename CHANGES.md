Changes
=======

New in ?.?.?
------------

### Additions

- 1FA Mode
- Add `--chroot-dir` cmdline option

### Changes

- The previous `--partition` cmdline option has become `--device`
- The previous `ls partitions` command has become `ls devices`
- Exit with a helpful error message upon attempting to run `ls devices`,
  `ls keymaps`, `ls locales`, or `ls timezones` with missing requirements
- To facilitate allowing any user to boot any given GRUB menu entry while only
  allowing the "GRUB superuser" to *edit* menu entries or access the GRUB
  command console, we now append ` --unrestricted` to the `CLASS` variable in
  `/etc/grub.d/10_linux` directly. This differs from the [previous
  approach](https://github.com/atweiden/voidvault/blob/7b159fa237ae4d7e612e6733a84b07cbf84d76b6/lib/Voidvault/Bootstrap.pm6#L2584)
  of globally replacing `${CLASS}` with `--unrestricted ${CLASS}` in
  `/etc/grub.d/10_linux`, but [accomplishes the same thing more simply](https://wiki.archlinux.org/title/GRUB/Tips_and_tricks#Password_protection_of_GRUB_edit_and_console_options_only).

### Fixes

- `voidvault --clean disable-cow` now recursively copies in files
  from original directory where CoW was enabled using latest [ArchWiki
  recommendations](https://wiki.archlinux.org/title/Btrfs#Disabling_CoW)

### Internal

- Heavily refactor codebase
