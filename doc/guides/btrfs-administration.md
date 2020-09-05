# Btrfs Administration

## Setup

```sh
# create base directories
mkdir -p /opt/{snapshots,subvolumes}
chmod 700 /opt/{snapshots,subvolumes}

# create example-alpha subvolume
btrfs subvolume create /opt/subvolumes/example-alpha

# mount example-alpha subvolume
_mount_opts+="compress=zstd,"
_mount_opts+="noatime,"
_mount_opts+="rw,"
_mount_opts+="space_cache=v2,"
_mount_opts+="ssd,"
_mount_opts+="subvol=@opt/subvolumes/example-alpha"
mount -t btrfs -o "$_mount_opts" /dev/mapper/vault /home/admin/.example-alpha
chown -R admin:admin /home/admin/.example-alpha

# add example-alpha subvolume mount to fstab
genfstab -U -p / | vipe
```

## Backup subvolumes

```sh
# create read-only snapshot of example-alpha at time A
_snaptime_a="$(date '+%FT%H:%M')"
mkdir -p "/opt/snapshots/$_snaptime_a"
btrfs subvolume snapshot -r /opt/subvolumes/example-alpha "/opt/snapshots/$_snaptime_a"
sync

# create read-only snapshot of example-alpha at time B
_snaptime_b="$(date '+%FT%H:%M')"
mkdir -p "/opt/snapshots/$_snaptime_b"
btrfs subvolume snapshot -r /opt/subvolumes/example-alpha "/opt/snapshots/$_snaptime_b"
sync

# backup read-only incremental snapshot of example-alpha
btrfs send -p "/opt/snapshots/$_snaptime_a/example-alpha" "/opt/snapshots/$_snaptime_b/example-alpha"
```

```sh
MASTER_INTERFACE="enp4s0f2"
SLAVE_IPV6="fe80::6497:17de:fee3:1942"
SLAVE_USER_NAME="admin"

# [master] snapshot example-alpha
_seconds_since_epoch="$(date --utc '+%s')"
_snapshot="example-alpha.snapshot.$_seconds_since_epoch"
btrfs subvolume snapshot -r /opt/subvolumes/example-alpha "/opt/snapshots/$_snapshot"
sync

# [master] send/receive full example-alpha snapshot
btrfs send -v "/opt/snapshots/$_snapshot" \
  | ssh -T -i "/path/to/id_ed25519" \
      ${SLAVE_USER_NAME}@${SLAVE_IPV6}%${MASTER_INTERFACE} \
      "btrfs receive /opt/snapshots"

# [master] save full example-alpha snapshot to file for sending
_snapshot_type="full"
_snapshot_file="$_snapshot.$_snapshot_type"
btrfs send -f "$_snapshot_file" "/opt/snapshots/$_snapshot"
sync
chown $USER:$USER "$_snapshot_file"

# [master] rsync the full example-alpha snapshot file to slave
rsync \
  --dry-run \
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
  --rsh 'ssh -T -i /path/to/id_ed25519' \
  "$_snapshot_file" \
  ${SLAVE_USER_NAME}@[${SLAVE_IPV6}]:/home/staged/snapshots/$_snapshot_file

# [slave] receive snapshot from file
btrfs receive -f "/home/staged/snapshots/$_snapshot_file" /opt/snapshots
rm "/home/staged/snapshots/$_snapshot_file"
sync

# [slave] take rw snapshot of ro snapshot
btrfs subvolume snapshot "/opt/snapshots/$_snapshot" /opt/subvolumes/example-alpha
sync
```

```sh
#!/bin/bash

MASTER_INTERFACE="enp4s0f2"
SLAVE_IPV6="fe80::6497:17de:fee3:1942"
SLAVE_USER_NAME="admin"

# send / receive
ssh -T -i "$HOME/.ssh/box/id_ed25519" \
  ${SLAVE_USER_NAME}@${SLAVE_IPV6}%${MASTER_INTERFACE} \
  "btrfs send /opt/snapshots/$_snapshot" \
    | btrfs receive -v /opt/snapshots

# incremental send / receive
ssh -T -i "$HOME/.ssh/box/id_ed25519" \
  ${SLAVE_USER_NAME}@${SLAVE_IPV6}%${MASTER_INTERFACE} \
  "btrfs send -p /opt/snapshots/$_snapshot_parent /opt/snapshots/$_snapshot" \
      | btrfs receive -v /opt/snapshots

# syncing file
rsync \
  --dry-run \
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
  --rsh "ssh -T -i \"$HOME/.ssh/box/id_ed25519\"" \
  ${SLAVE_USER_NAME}@[${SLAVE_IPV6}%${MASTER_INTERFACE}]:/home/${SLAVE_USER_NAME}/${_snapshot_file} \
  "$HOME"
```

## Refresh snapshots

```sh
#!/bin/bash

# delete existing snapshots
# btrfs subvolume list /
# btrfs subvolume delete /opt/snapshots/...

_seconds_since_epoch="$(date --utc '+%s')"
# refresh snapshots
for _name in example-alpha \
             example-bravo; do
  _snapshot="$_name.snapshot.$_seconds_since_epoch"
  sudo btrfs subvolume snapshot -r "/opt/subvolumes/$_name" "/opt/snapshots/$_snapshot"
done
sudo sync
```

## Restore from snapshot

For when you have accidentally deleted `~/.example-alpha/important-file`.

```sh
# unmount ~/.example-alpha
umount ~/.example-alpha

# delete example-alpha subvolume
btrfs subvolume delete /opt/subvolumes/example-alpha

# take rw snapshot of most recent example-alpha snapshot
btrfs subvolume snapshot "/opt/snapshots/example-alpha.snapshot.1476147345" /opt/subvolumes/example-alpha

# retrieve subvolume ID of newly created example-alpha subvolume
btrfs subvolume list /
_NEW_ID=701

# the `mount` command, run as root, needs the absolute path to your `~`
_HOME="$HOME"

# mount this new snapshot as example-alpha at ~/.example-alpha
# /dev/mapper/vault is root
mount -t btrfs -o rw,nodatacow,noatime,compress=zstd,ssd,space_cache=v2,subvolid=$_NEW_ID,subvol=/@opt/subvolumes/example-alpha /dev/mapper/vault "$_HOME/.example-alpha"

# update fstab (with `subvolid=$_NEW_ID`)
genfstab -U /
```
