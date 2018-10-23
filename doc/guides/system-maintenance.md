# System Maintenance

Change vault password:

```sh
cryptsetup luksChangeKey /dev/sda3
```

Clear pkg cache:

```sh
xbps-remove --clean-cache|-O
```

Remove old kernels:

```sh
vkpurge list
vkpurge rm 4.17.13_1
vkpurge rm all
```

Prune broken symlinks from `/etc/runit/runsvdir/{default,single}`:

```sh
find /etc/runit/runsvdir -xtype l
find /etc/runit/runsvdir -xtype l -delete
```
