# NILFS+LVM Administration

## Create and mount new LVM logical volume

```sh
# create lvm logical volume
lvcreate --name sandbox --extents 100%FREE vg0

# activate lvm logical volume
vgchange --activate y

# format lvm logical volume
mkfs.nilfs2 -L sandbox /dev/vg0/sandbox

# mount lvm logical volume
mkdir /path/to/sandbox
_mount_opts='rw,noatime'
mount \
  --types nilfs2 \
  --options "$_mount_opts" \
  /dev/vg0/sandbox \
  /path/to/sandbox

# add lvm logical volume mount to fstab (may require reboot to obtain UUID)
_uuid="$(blkid --match-tag UUID --output value /dev/vg0/sandbox)"
cat >> /etc/fstab <<"EOF"
# /dev/vg0/sandbox LABEL=sandbox
UUID=$_uuid /path/to/sandbox nilfs2 $_mount_opts 0 0
EOF
```

## Resize LVM logical volume

Shrink:

```sh
# shrink NILFS to under target size
nilfs-resize /dev/vg0/srv 430M
# resize logical volume to target size
lvresize --size 500M vg0/srv
# grow NILFS without dimension to occupy all logical volume free space
nilfs-resize /dev/vg0/srv
```

Grow:

```sh
# resize logical volume to target size
lvresize --size +2G vg0/srv
# grow NILFS without dimension to occupy all logical volume free space
nilfs-resize /dev/vg0/srv
```

Shrink and grow operations must be carried out on live, mounted NILFS
filesystems. They won't work otherwise.

## Restore LVM logical volume from NILFS snapshot

Take NILFS snapshot:

```sh
mkcp --snapshot /dev/vg0/sandbox
```

Create and mount logical volume for holding data restored from NILFS
snapshot:

```sh
lvcreate --name restore --extents 100%FREE vg0
vgchange --activate y
mkfs.nilfs2 -L restore /dev/vg0/restore
mkdir /path/to/restore
mount \
  --types nilfs2 \
  --options 'rw,noatime' \
  /dev/vg0/restore \
  /path/to/restore
```

Mount NILFS snapshot:

```sh
mkdir /path/to/staging
# must mount snapshot read-only
mount \
  --types nilfs2 \
  --options 'cp=7,ro,noatime' \
  /dev/vg0/sandbox \
  /path/to/staging
```

Conserve disk space by `rm -rf`ing the original contents after staging
contains read-only mount of snapshot. Do not destroy the original
filesystem (yet).

Copy snapshotted contents:

```sh
rsync \
  --recursive \
  --perms \
  --times \
  --partial \
  --inplace \
  --verbose \
  --human-readable \
  --progress \
  --itemize-changes \
  --itemize-changes \
  /path/to/staging/ \
  /path/to/restore
```

Unmount staging:

```
umount /path/to/staging
```

Securely delete original LVM logical volume:

```sh
umount /path/to/sandbox
shred -fvz -n 7 /dev/vg0/sandbox
lvremove vg0/sandbox
```

## Work around NILFS2 lack of file capabilities support

Add suid bit to affected binaries:

```sh
chmod u+s /usr/bin/nanoklogd
chmod u+s /usr/bin/iputils-ping
```
