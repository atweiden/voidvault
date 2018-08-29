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
