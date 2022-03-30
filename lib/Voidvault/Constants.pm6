use v6;
unit module Voidvault::Constants;

# libcrypt crypt encryption rounds
constant $CRYPT-ROUNDS = 700_000;

# libcrypt crypt encryption scheme
constant $CRYPT-SCHEME = 'SHA512';

# grub-mkpasswd-pbkdf2 iterations
constant $PBKDF2-ITERATIONS = 25_000;

# grub-mkpasswd-pbkdf2 length of generated hash
constant $PBKDF2-LENGTH-HASH = 100;

# grub-mkpasswd-pbkdf2 length of salt
constant $PBKDF2-LENGTH-SALT = 100;

# for sgdisk
constant $GDISK-SIZE-BIOS = '2M';
constant $GDISK-SIZE-EFI = '550M';
constant $GDISK-SIZE-BOOT = '1024M';
constant $GDISK-TYPECODE-BIOS = 'EF02';
constant $GDISK-TYPECODE-EFI = 'EF00';
constant $GDISK-TYPECODE-LINUX = '8300';

# for C<--enable-serial-console>
constant $VIRTUAL-CONSOLE = 'tty0';
constant $SERIAL-CONSOLE = 'ttyS0';
constant $GRUB-SERIAL-PORT-UNIT = '0';
constant $GRUB-SERIAL-PORT-BAUD-RATE = '115200';
constant $GRUB-SERIAL-PORT-PARITY = False;
constant %GRUB-SERIAL-PORT-PARITY =
    ::(True) => %(
        GRUB_SERIAL_COMMAND => 'odd',
        GRUB_CMDLINE_LINUX_DEFAULT => 'o'
    ),
    ::(False) => %(
        GRUB_SERIAL_COMMAND => 'no',
        GRUB_CMDLINE_LINUX_DEFAULT => 'n'
    );
constant $GRUB-SERIAL-PORT-STOP-BITS = '1';
constant $GRUB-SERIAL-PORT-WORD-LENGTH-BITS = '8';

# vim: set filetype=raku foldmethod=marker foldlevel=0:
