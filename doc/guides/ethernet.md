# Working With Wired Ethernet

## Checking for ethernet cable connection

**Yes, connected**:

```sh
cat /sys/class/net/eth0/{carrier,operstate}
1
up
```

or:

```sh
ethtool eth0 | grep "Link"
Link detected: yes
```

**No, not connected**:

```sh
cat /sys/class/net/eth0/{carrier,operstate}
0
down
```

or

```sh
ethtool eth0 | grep "Link"
Link detected: no
```
