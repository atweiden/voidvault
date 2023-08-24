# WireGuard

## Configure

**On the client**:

Generate keys:

```sh
# make sure credentials don't leak in a race condition
umask 077

# generate keypair
wg genkey | tee privatekey | wg pubkey > publickey
```

Configure WireGuard:

```sh
readonly CLIENT_PRIVATE_KEY="$(cat privatekey)"
readonly SERVER_PUBLIC_KEY="..."
readonly SERVER_IP="..."

# make config file
cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
# virtual ip address, with subnet mask for vpn
Address = 10.192.122.2/32
PrivateKey = $CLIENT_PRIVATE_KEY
DNS = 10.192.122.1
# true makes commenting, formatting impossible
SaveConfig = false

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = $SERVER_IP:51820
# gateway rule - send all traffic out over the vpn
AllowedIPs = 0.0.0.0/0, ::/0
# keep stateful firewall or nat mapping valid every n seconds
#PersistentKeepalive = 25
EOF

chmod 600 /etc/wireguard/wg0.conf
```

**On the server**:

Generate keys:

```sh
# make sure credentials don't leak in a race condition
umask 077

# generate keypair
wg genkey | tee privatekey | wg pubkey > publickey
```

Configure WireGuard:

```sh
readonly CLIENT_PUBLIC_KEY="..."
readonly SERVER_PRIVATE_KEY="$(cat privatekey)"

# make wg-quick config file
cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
# virtual ip address, with subnet mask for vpn
Address = 10.192.122.1/24
ListenPort = 51820
PrivateKey = $SERVER_PRIVATE_KEY
# true makes commenting, formatting impossible
SaveConfig = false
PostUp = /etc/wireguard/wg0.conf.post-up.sh
PostDown = /etc/wireguard/wg0.conf.post-down.sh

[Peer]
PublicKey = $CLIENT_PUBLIC_KEY
# identical to client's interface address, using same subnet mask
AllowedIPs = 10.192.122.2/32
EOF

chmod 600 /etc/wireguard/wg0.conf

# make wg-quick PostUp script
cat > /etc/wireguard/wg0.conf.post-up.sh <<EOF
#!/bin/bash
# load kernel modules
modprobe nft_masq
modprobe nft_masq_ipv4
modprobe nft_masq_ipv6
modprobe nft_nat
modprobe nft_chain_nat_ipv4
modprobe nft_chain_nat_ipv6
# configure kernel parameters
sysctl --write net.ipv4.ip_forward=1
sysctl --write net.ipv4.conf.all.forwarding=1
sysctl --write net.ipv4.conf.default.forwarding=1
sysctl --write net.ipv6.conf.all.forwarding=1
sysctl --write net.ipv6.conf.default.forwarding=1
sysctl --write net.ipv4.conf.all.proxy_arp=1
sysctl --write net.ipv4.conf.default.proxy_arp=1
sysctl --write net.ipv6.conf.all.proxy_ndp=1
sysctl --write net.ipv6.conf.default.proxy_ndp=1
sysctl --write net.ipv4.ip_dynaddr=7
# activate nftables includes for wireguard
mkdir --parents /etc/nftables/includes/table/inet/filter/forward
mkdir --parents /etc/nftables/includes/table/inet/filter/input
ln \
  --symbolic \
  --force \
  /etc/nftables/wireguard/table/wireguard.nft \
  /etc/nftables/includes/table
ln \
  --symbolic \
  --force \
  /etc/nftables/wireguard/table/inet/filter/forward/wireguard.nft \
  /etc/nftables/includes/table/inet/filter/forward
ln \
  --symbolic \
  --force \
  /etc/nftables/wireguard/table/inet/filter/input/wireguard.nft \
  /etc/nftables/includes/table/inet/filter/input
# reload nftables with includes for wireguard
nft --file /etc/nftables.conf
# make dnscrypt-proxy listen on wireguard interface
sed \
  -i \
  -e "/^listen_addresses/s/\(.*\)/#\1/" \
  -e "/^#listen_addresses/p" \
  -e "s/^#\(listen_addresses = \[.*\)\]/\1, '10.192.122.1:53']/" \
  /etc/dnscrypt-proxy/dnscrypt-proxy.toml
sv restart dnscrypt-proxy
EOF

chmod 700 /etc/wireguard/wg0.conf.post-up.sh

# make wg-quick PostDown script
cat > /etc/wireguard/wg0.conf.post-down.sh <<EOF
#!/bin/bash
# deactivate nftables includes for wireguard
rm --force /etc/nftables/includes/table/wireguard.nft
rm --force /etc/nftables/includes/table/inet/filter/forward/wireguard.nft
rm --force /etc/nftables/includes/table/inet/filter/input/wireguard.nft
rmdir \
  --ignore-fail-on-non-empty \
  --parents \
  /etc/nftables/includes/table/inet/filter/forward
rmdir \
  --ignore-fail-on-non-empty \
  --parents \
  /etc/nftables/includes/table/inet/filter/input
# reload nftables without includes for wireguard
nft --file /etc/nftables.conf
# unload kernel modules
rmmod nft_masq_ipv4
rmmod nft_masq_ipv6
rmmod nft_masq
rmmod nft_chain_nat_ipv4
rmmod nft_chain_nat_ipv6
rmmod nft_nat
# reconfigure kernel parameters
sysctl --write net.ipv4.ip_forward=0
sysctl --write net.ipv4.conf.all.forwarding=0
sysctl --write net.ipv4.conf.default.forwarding=0
sysctl --write net.ipv6.conf.all.forwarding=0
sysctl --write net.ipv6.conf.default.forwarding=0
sysctl --write net.ipv4.conf.all.proxy_arp=0
sysctl --write net.ipv4.conf.default.proxy_arp=0
sysctl --write net.ipv6.conf.all.proxy_ndp=0
sysctl --write net.ipv6.conf.default.proxy_ndp=0
sysctl --write net.ipv4.ip_dynaddr=0
# make dnscrypt-proxy not listen on wireguard interface
sed \
  -i \
  -e "/^listen_addresses/d" \
  -e "/^#listen_addresses/s/^#\(.*\)/\1/" \
  /etc/dnscrypt-proxy/dnscrypt-proxy.toml
sv restart dnscrypt-proxy
EOF

chmod 700 /etc/wireguard/wg0.conf.post-down.sh
```

## Execute

**On the server**:

Bring up WireGuard:

```sh
wg-quick up wg0
```

Check to make sure dnscrypt-proxy is listening on WireGuard interface:

```sh
netstat -tulpn
```

**On the client**:

```sh
wg-quick up wg0
```

## Troubleshooting

### Slow internet speeds

The solution is to [configure the WireGuard client's
MTU](https://www.reddit.com/r/WireGuard/comments/aru07q/wireguard_slow/).

On the client, set `MTU = $MTU` in the `[Interface]` section of
`/etc/wireguard/wg0.conf`. Alternatively, configure WireGuard's MTU with:

```sh
ip link set mtu $MTU dev wg0
```

To determine `$MTU`:

- run `ping google.com -f -l $MTU` on the client
  - where `$MTU` is `2500` or other large value
- when `$MTU` is too high, `ping`'s output will indicate the response
  needed to be fragmented
  - drop `$MTU` by large numbers until the response stops fragmenting
  - increase `$MTU` until the response fragments
- take the highest non-fragmented value of `$MTU`
  - add `28` to it to account for ICMP headers

<!-- vim: set filetype=markdown foldmethod=marker foldlevel=0 nowrap -->
