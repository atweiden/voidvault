# Troubleshooting

## Archvault Type Errors

If Archvault fails to compile, it will usually be due to Arch Linux system
upgrades rendering Archvault's types (`Keymap`, `Locale`, `Timezone`)
out of date. This is fairly easy to fix manually:

**`Keymap` type is out of date**

```
Type check failed in assignment to @keymap; expected Archvault::Types::Keymap:D but got Str ("amiga-de")
```

The solution is to edit the `%keymaps` constant in
[lib/Archvault/Types.pm6][lib/Archvault/Types.pm6] to include `amiga-de`.

**`Locale` type is out of date**

```
Type check failed in assignment to @locale; expected Archvault::Types::Locale:D but got Str ("aa_DJ")
```

The solution is to edit the `%locales` constant in
[lib/Archvault/Types.pm6][lib/Archvault/Types.pm6] to include `aa_DJ`.

**`Timezone` type is out of date**

```
Type check failed in assignment to @timezones; expected Archvault::Types::Timezone:D but got Str ("Africa/Abidjan")
```

The solution is to edit the `@timezones` constant in
[lib/Archvault/Types.pm6][lib/Archvault/Types.pm6] to include
`Africa/Abidjan`.

## Archvault Wireless Errors

### Failure to Connect to Wireless Access Point

If Archvault fails to connect to a wireless access point, it could
mean anything.

In some cases, the problem is your system's factory wireless card. The
easiest way to find out if this is true is to buy a high gain USB adapter
from [SimpleWiFi][SimpleWiFi], and see if it works. If it does, you know
the factory wireless card is at fault.

If the USB adapter fails, however, it often means something lower level
has gone awry.

The first thing you should try is disabling the [GPE.L6F][GPE.L6F]
function:

```
echo "disable" > /sys/firmware/acpi/interrupts/gpe6F
```

This seems to help with certain Intel Skylake and Kaby Lake processors,
and does not require a reboot.

If disabling the `GPE.L6F` function fails, reboot with
[acpi=off][acpi=off] or [similar][similar] appended to your kernel
command line:

```
# in vim, append acpi=off to GRUB_CMDLINE_LINUX
vim /etc/default/grub
# regenerate grub config
grub-mkconfig -o /boot/grub/grub.cfg
```

You may only have to boot with `acpi=off` once to get wifi working.

If after this, your wifi is still not working yet, try updating your
machine's BIOS.

After trying everything else, if your wifi still fails to connect, it
could indicate a problem with your [dhcpcd][dhcpcd] config. Alternatively,
there could be an issue with your wireless router.

### Failure to Find Wireless Access Point

If your machine fails to find a wireless access point, you may need to
strengthen your wireless signal with a wireless repeater or high gain
adapter. See also: "[Respecting the regulatory domain][Respecting the
regulatory domain]".


## Assorted Errors

Modern computers often have problems running Linux smoothly. Be sure to
scour the web for resources like these:

- https://wiki.archlinux.org/index.php/Laptop/Lenovo
- https://github.com/mikolajb/skylake-on-linux
- https://gist.github.com/StefanoBelli/0aab46b858a797c4eedb90e8799dffa2

Maybe try looking for BIOS updates.

## Booting Archvault From Grub Rescue Shell

If upon booting the Archvault system, you initially enter the wrong
vault password, Grub will drop you into a rescue shell. [Here][here]
is how to recover the system from the Grub rescue shell without rebooting:

**Most systems**

```
grub rescue> ls
(hd0) (hd0,gpt3) (hd0,gpt2) (hd0,gpt1) (proc)
grub rescue> cryptomount hd0,gpt3
Attempting to decrypt master key...
Enter passphrase for hd0,gpt3 (88caa067d343402aabd6b107ab08125a):
Slot 0 opened
grub rescue> insmod normal
grub rescue> normal
```

**VirtualBox UEFI systems**

```
grub rescue> ls
(proc) (hd0) (hd1) (hd1,gpt3) (hd1,gpt2) (hd1,gpt1)
grub rescue> cryptomount hd1,gpt3
Attempting to decrypt master key...
Enter passphrase for hd1,gpt3 (88caa067d343402aabd6b107ab08125a):
Slot 0 opened
grub rescue> insmod normal
grub rescue> normal
```

## Booting Archvault Takes a Really Long Time

It takes a really long time for [Grub][Grub] to decrypt the `/boot`
partition.

## Error While Booting: Kernel Panic

This might be due to an error completing the `mkinitcpio -p linux`
command. Re-run `mkinitcpio -p linux` from a LiveCD after mounting
the system:

```sh
cryptsetup luksOpen /dev/sda3 vault
# see: https://github.com/atweiden/scripts/blob/master/mnt-btrfs.sh
curl -o mnt-btrfs.sh http://ix.io/1iUP
chmod +x mnt-btrfs.sh
./mnt-btrfs.sh
arch-chroot /mnt pacman -Syu
arch-chroot /mnt mkinitcpio -p linux
umount -R /mnt
cryptsetup luksClose vault
```

## Error While Loading Shared Libraries

If during Archvault installation, the system complains about missing
shared libraries, out of date packages are most likely to blame. For
example:

```
/usr/bin/systemd-sysusers: error while loading shared libraries: libjson-c.so.4: cannot open shared object file: No such file or directory
```

The package that provides `libjson-c.so.4` is out of date or missing. To
fix this, update or install pkg `json-c`:

```
pacman -S json-c
```

Or if all else fails, run `pacman -Syu`.

If you're using an outdated Arch Linux installation medium, retry with
the newest version. It's best practice to always use the newest version
of the official Arch Linux installation medium.

## Monitor Resolution Issues

One way to work around monitor resolution issues is to use Vim.

Open vim:

```
vim
```

Create a horizontal split:

```vim
:sp
```

Switch to the bottom split:

- <kbd>Ctrl-w</kbd> <kbd>j</kbd>

Create a vertical split:

```vim
:vsp
```

Switch to the bottom right split, which we'll use as our *main split*:

- <kbd>Ctrl-w</kbd> <kbd>l</kbd>

Create a vertical split within the *main split*:

```vim
:vsp
```

Open a terminal:

```vim
:terminal
```

Maximize the *main split* vertically and horizontally:

- <kbd>Ctrl-w</kbd> <kbd>_</kbd>
- <kbd>Ctrl-w</kbd> <kbd>|</kbd>

Center the *main split*:

- <kbd>Ctrl-w</kbd> <kbd>h</kbd>
- <kbd>Ctrl-w</kbd> <kbd>l</kbd>
- <kbd>Ctrl-w</kbd> <kbd>l</kbd>

Navigate back to the *main split*:

- <kbd>Ctrl-w</kbd> <kbd>h</kbd>

Use <kbd>Ctrl-w</kbd> <kbd><</kbd>, <kbd>Ctrl-w</kbd> <kbd>></kbd>,
<kbd>Ctrl-w</kbd> <kbd>+</kbd>, <kbd>Ctrl-w</kbd> <kbd>-</kbd> to modify
split borders to your liking.


[acpi=off]: https://askubuntu.com/questions/139157/booting-ubuntu-with-acpi-off-grub-parameter
[dhcpcd]: https://wiki.archlinux.org/index.php/Dhcpcd
[GPE.L6F]: http://jhshi.me/2015/11/14/acpi-error-method-parseexecution-failed-_gpe_l6f/index.html#.W19wDdhKjdQ
[Grub]: https://www.reddit.com/r/archlinux/comments/6ahvnk/grub_decryption_really_slow/dhew32m/
[here]: https://unix.stackexchange.com/questions/318745/grub2-encryption-reprompt/321825#321825
[lib/Archvault/Types.pm6]: ../lib/Archvault/Types.pm6
[Respecting the regulatory domain]: https://wiki.archlinux.org/index.php/Wireless_network_configuration#Respecting_the_regulatory_domain
[similar]: https://askubuntu.com/questions/127989/no-acpi-support-for-my-pc-what-can-i-do
[SimpleWiFi]: https://www.simplewifi.com/collections/usb-adapters/products/usb-adapter
