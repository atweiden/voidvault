Changes
=======

New in ?.?.?
------------

### Additions

- 1FA Mode
- Add `--chroot-dir` cmdline option

### Changes

- Rename `--partition` cmdline option to `--device`
- Rename `ls-partitions` command to `ls-devices`
- Exit with helpful error message upon attempting to run `ls-devices`,
  `ls-keymaps`, `ls-locales`, or `ls-timezones` with missing requirements

### Internal

- Heavily refactor codebase
