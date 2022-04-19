use v6;
use Voidvault::Types;

role DeviceInfo[DeviceLocator:D $ where DeviceLocator::ID]
{
    # C<DEVLINKS> from C<udevadm>
    has Str:D $.devlinks is required;

    # C<ID_SERIAL_SHORT> from C<udevadm>
    has Str:D $.id-serial-short is required;
}

role DeviceInfo[DeviceLocator:D $ where DeviceLocator::PARTUUID]
{
    # C<ID_PART_ENTRY_UUID> from C<udevadm>, C<blkid -o value -s PARTUUID>
    has Str:D $.partuuid is required;
}

role DeviceInfo[DeviceLocator:D $ where DeviceLocator::UUID]
{
    # C<ID_FS_UUID> from C<udevadm>, C<blkid -o value -s UUID>
    has Str:D $.uuid is required;
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
